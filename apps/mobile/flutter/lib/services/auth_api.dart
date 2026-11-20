import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class NovynAccount {
  const NovynAccount({required this.username, required this.displayName, required this.email});
  final String username;
  final String displayName;
  final String email;

  factory NovynAccount.fromMap(Map<String, dynamic> value) {
    final username = value['username']?.toString() ?? '';
    final name = value['displayName']?.toString().trim() ?? '';
    return NovynAccount(username: username, displayName: name.isNotEmpty ? name : username, email: value['email']?.toString() ?? '');
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Minimal mobile auth for the shared Novyn API; cookies are encrypted at rest.
class AuthApi {
  AuthApi._();
  static const baseUrl = String.fromEnvironment('NOVYN_API_URL', defaultValue: 'https://novyn-live.onrender.com');
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const _sessionKey = 'novyn_phase2_session_v1';
  static const _csrfKey = 'novyn_phase2_csrf_v1';
  static String _sessionCookies = '';
  static String? _csrfToken;
  static bool _loaded = false;

  static Future<void> _load() async {
    if (_loaded) return;
    _sessionCookies = await _storage.read(key: _sessionKey) ?? '';
    _csrfToken = await _storage.read(key: _csrfKey);
    _loaded = true;
  }

  static String get _cookieHeader => <String>[
    ..._sessionCookies.split(';').map((v) => v.trim()).where((v) => v.isNotEmpty),
    if (_csrfToken?.isNotEmpty == true) 'novyn_csrf=$_csrfToken',
  ].join('; ');

  static Map<String, String> _headers({bool csrf = true}) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'x-novyn-client': 'mobile',
    if (_cookieHeader.isNotEmpty) 'Cookie': _cookieHeader,
    if (csrf && _csrfToken?.isNotEmpty == true) 'x-novyn-csrf': _csrfToken!,
  };

  static Future<void> _capture(http.Response response) async {
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final values = <String, String>{};
    final matches = RegExp(r'(?:^|,\s*)(novyn_at|novyn_rt|novyn_csrf)=([^;,\s]*)', caseSensitive: false).allMatches(raw);
    for (final match in matches) {
      values[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    final merged = <String, String>{};
    for (final part in _sessionCookies.split(';')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final key = part.substring(0, index).trim();
      if (key == 'novyn_at' || key == 'novyn_rt') merged[key] = part.substring(index + 1).trim();
    }
    final access = values['novyn_at'];
    final refresh = values['novyn_rt'];
    if ((access != null && access.isEmpty) || (refresh != null && refresh.isEmpty)) {
      merged.clear();
    } else {
      if (access != null && access.isNotEmpty) merged['novyn_at'] = access;
      if (refresh != null && refresh.isNotEmpty) merged['novyn_rt'] = refresh;
    }
    _sessionCookies = merged.entries.map((e) => '${e.key}=${e.value}').join('; ');
    if (values.containsKey('novyn_csrf')) {
      final token = values['novyn_csrf']!;
      _csrfToken = token.isEmpty ? null : Uri.decodeComponent(token);
    }
    if (_sessionCookies.isEmpty) {
      await _storage.delete(key: _sessionKey);
    } else {
      await _storage.write(key: _sessionKey, value: _sessionCookies);
    }
    if (_csrfToken == null || _csrfToken!.isEmpty) {
      await _storage.delete(key: _csrfKey);
    } else {
      await _storage.write(key: _csrfKey, value: _csrfToken);
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) return Map<String, dynamic>.from(body);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Future<void> _bootstrapCsrf() async {
    await _load();
    if (_csrfToken?.isNotEmpty == true) return;
    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/session'),
      headers: _headers(csrf: false),
    ).timeout(const Duration(seconds: 35));
    await _capture(response);
    if (_csrfToken?.isNotEmpty != true) {
      throw const AuthApiException('Novyn server is waking up. Please try again in a moment.');
    }
  }

  static Future<http.Response> _sessionRequest() => http.get(
    Uri.parse('$baseUrl/api/auth/session'),
    headers: _headers(csrf: false),
  ).timeout(const Duration(seconds: 35));

  static Future<bool> _refresh() async {
    await _bootstrapCsrf();
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/refresh'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 25));
    await _capture(response);
    return response.statusCode == 200;
  }

  static Future<NovynAccount?> restoreSession() async {
    try {
      await _bootstrapCsrf();
      var response = await _sessionRequest();
      await _capture(response);
      var data = _decode(response);
      if (response.statusCode == 401 && _sessionCookies.contains('novyn_rt=')) {
        if (await _refresh()) {
          response = await _sessionRequest();
          await _capture(response);
          data = _decode(response);
        }
      }
      if (response.statusCode == 200 && data['username']?.toString().isNotEmpty == true) {
        return NovynAccount.fromMap(data);
      }
    } catch (_) {
      // An API outage should not block access to the sign-in screen.
    }
    return null;
  }

  static Future<NovynAccount> signIn({required String identifier, required String password}) async {
    await _bootstrapCsrf();
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/signin'),
      headers: _headers(),
      body: jsonEncode({'identifier': identifier.trim(), 'password': password, 'remember': true}),
    ).timeout(const Duration(seconds: 60));
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw AuthApiException(data['message']?.toString() ?? 'Could not sign in. Please try again.');
    }
    if (data['requiresTwoFactor'] == true) {
      throw const AuthApiException('This account requires two-step verification. The new verification screen is not part of this first foundation.');
    }
    await _capture(response);
    if (!_sessionCookies.contains('novyn_at=') || !_sessionCookies.contains('novyn_rt=')) {
      throw const AuthApiException('The server did not return a valid sign-in session.');
    }
    final session = await _sessionRequest();
    await _capture(session);
    final sessionData = _decode(session);
    if (session.statusCode == 200 && sessionData['username']?.toString().isNotEmpty == true) {
      return NovynAccount.fromMap(sessionData);
    }
    return NovynAccount.fromMap(data);
  }

  static Future<NovynAccount> signUp({required String name, required String username, required String email, required String password}) async {
    await _bootstrapCsrf();
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/signup'),
      headers: _headers(),
      body: jsonEncode({
        'name': name.trim(),
        'username': username.trim().toLowerCase(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'remember': true,
      }),
    ).timeout(const Duration(seconds: 60));
    final data = _decode(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthApiException(data['message']?.toString() ?? 'Could not create your account.');
    }
    await _capture(response);
    if (!_sessionCookies.contains('novyn_at=') || !_sessionCookies.contains('novyn_rt=')) {
      throw const AuthApiException('The server did not return a valid sign-up session.');
    }
    final session = await _sessionRequest();
    await _capture(session);
    final sessionData = _decode(session);
    if (session.statusCode == 200 && sessionData['username']?.toString().isNotEmpty == true) {
      return NovynAccount.fromMap(sessionData);
    }
    return NovynAccount.fromMap({...data, 'displayName': name.trim()});
  }

  static Future<void> signOut() async {
    try {
      await _bootstrapCsrf();
      await http.post(Uri.parse('$baseUrl/api/auth/logout'), headers: _headers()).timeout(const Duration(seconds: 20));
    } catch (_) {
      // Explicit sign-out always clears local credentials.
    } finally {
      _sessionCookies = '';
      _csrfToken = null;
      _loaded = true;
      await _storage.delete(key: _sessionKey);
      await _storage.delete(key: _csrfKey);
    }
  }
}
