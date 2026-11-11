import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/chat_models.dart';

/// REST API service for the shared novyn-chat backend (server.js).
///
/// Identity model: username-based (not Firebase UID).
/// Auth: cookie-based JWT issued by novyn-chat's /api/auth/* endpoints.
/// All requests that need auth must include credentials (cookies are handled
/// by the browser on web; on mobile we forward the Set-Cookie header manually
/// using [_sessionCookie]).
class ApiService {
  // ── Server URL ─────────────────────────────────────────────────────────────
  /// The production backend used by release APKs.
  ///
  /// Override it for local work without editing source code:
  /// `flutter run --dart-define=NOVYN_API_URL=http://10.0.2.2:3000`
  /// A physical device should use the development machine's LAN address.
  static const String baseUrl = String.fromEnvironment(
    'NOVYN_API_URL',
    defaultValue: 'https://novyn-live.onrender.com',
  );

  // Holds the raw cookie string received from Set-Cookie after sign-in.
  // Flutter's http package does not persist cookies automatically on mobile,
  // so we store and forward them manually.
  static String? _sessionCookie;
  static String? _csrfToken;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _sessionCookieKey = 'novyn_auth_cookie_v1';
  static const String _csrfTokenKey = 'novyn_csrf_token_v1';

  static Future<void> initializeSessionStorage() async {
    try {
      _sessionCookie = await _secureStorage.read(key: _sessionCookieKey);
      _csrfToken = await _secureStorage.read(key: _csrfTokenKey);
    } catch (_) {
      _sessionCookie = null;
      _csrfToken = null;
    }
  }

  static Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_cookieHeader.isNotEmpty) 'Cookie': _cookieHeader,
      };

  static String get _cookieHeader {
    final cookies = (_sessionCookie ?? '')
        .split(';')
        .map((cookie) => cookie.trim())
        .where((cookie) =>
            cookie.isNotEmpty &&
            !cookie.toLowerCase().startsWith('novyn_csrf='))
        .toList();
    if (_csrfToken != null) cookies.add('novyn_csrf=$_csrfToken');
    return cookies.join('; ');
  }

  static Future<Map<String, String>> _csrfHeaders() async {
    if (_csrfToken == null) {
      final response = await http
          .get(Uri.parse('$baseUrl/api/auth/session'))
          .timeout(const Duration(seconds: 10));
      await _storeSessionCookie(response);
    }

    final token = _csrfToken;
    if (token == null) {
      throw StateError(
          'Could not initialize the authentication security token.');
    }

    return {
      'Content-Type': 'application/json',
      'Cookie': _cookieHeader,
      'x-novyn-csrf': token,
    };
  }

  // ── Expose cookie for socket handshake ───────────────────────────────────
  static String? get sessionCookie => _sessionCookie;

  // ── Store session cookie from a response ─────────────────────────────────
  static Future<void> _storeSessionCookie(http.Response res) async {
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;

    // Only persist Novyn cookies. A combined Set-Cookie header also contains
    // Domain/Expires/Max-Age attributes, which must never become request cookies.
    final matches = RegExp(
      r'(?:^|,\s*)(novyn_at|novyn_rt|novyn_csrf)=([^;,\s]*)',
      caseSensitive: false,
    ).allMatches(raw);
    if (matches.isEmpty) return;

    final values = <String, String>{};
    for (final match in matches) {
      values[match.group(1)!.toLowerCase()] = match.group(2)!;
    }

    final access = values['novyn_at'];
    final refresh = values['novyn_rt'];
    if ((access != null && access.isEmpty) ||
        (refresh != null && refresh.isEmpty)) {
      _sessionCookie = null;
    } else {
      final merged = <String, String>{};
      for (final part in (_sessionCookie ?? '').split(';')) {
        final index = part.indexOf('=');
        if (index > 0) {
          final key = part.substring(0, index).trim();
          if (key == 'novyn_at' || key == 'novyn_rt') {
            merged[key] = part.substring(index + 1).trim();
          }
        }
      }
      if (access != null && access.isNotEmpty) merged['novyn_at'] = access;
      if (refresh != null && refresh.isNotEmpty) merged['novyn_rt'] = refresh;
      _sessionCookie = merged.isEmpty
          ? null
          : merged.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
    }

    final csrf = values['novyn_csrf'];
    if (csrf != null) {
      _csrfToken = csrf.isEmpty ? null : Uri.decodeComponent(csrf);
      if (_csrfToken == null) {
        await _secureStorage.delete(key: _csrfTokenKey);
      } else {
        await _secureStorage.write(key: _csrfTokenKey, value: _csrfToken);
      }
    }

    if (_sessionCookie == null || _sessionCookie!.isEmpty) {
      await _secureStorage.delete(key: _sessionCookieKey);
    } else {
      await _secureStorage.write(key: _sessionCookieKey, value: _sessionCookie!);
    }
  }

  // ── Clear session (on logout) ─────────────────────────────────────────────
  static Future<void> clearSession() async {
    _sessionCookie = null;
    _csrfToken = null;
    try {
      await _secureStorage.delete(key: _sessionCookieKey);
      await _secureStorage.delete(key: _csrfTokenKey);
    } catch (_) {}
  }

  // ── Health check / wake-up ping ───────────────────────────────────────────
  static Future<void> ping() async {
    try {
      await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ── Auth: Google sign-in via Firebase ID token ────────────────────────────
  // Sends the Firebase idToken to novyn-chat's /api/auth/google endpoint.
  // On success the server creates/matches a username-based account and returns
  // { username, email, linkedExisting, createdAccount }.
  static Future<Map<String, dynamic>?> signInWithGoogle({
    required String idToken,
    bool remember = true,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/google'),
            headers: await _csrfHeaders(),
            body: jsonEncode({'idToken': idToken, 'remember': remember}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        await _storeSessionCookie(res);
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }

      // Return error body so caller can surface the message.
      try {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      } catch (_) {
        return {'message': 'Server error (${res.statusCode})'};
      }
    } catch (e) {
      return {'message': 'Network error: $e'};
    }
  }

  // ── Auth: Email/password sign-in ──────────────────────────────────────────
  static Future<Map<String, dynamic>?> signIn({
    required String identifier, // username or email
    required String password,
    bool remember = true,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/signin'),
            headers: await _csrfHeaders(),
            body: jsonEncode({
              'identifier': identifier,
              'password': password,
              'remember': remember,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        await _storeSessionCookie(res);
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }
      try {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      } catch (_) {
        return {'message': 'Server error (${res.statusCode})'};
      }
    } catch (e) {
      return {'message': 'Network error: $e'};
    }
  }

  // ── Auth: Register ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/signup'),
            headers: await _csrfHeaders(),
            body: jsonEncode({
              'name': name,
              'username': username,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        await _storeSessionCookie(res);
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }
      try {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      } catch (_) {
        return {'message': 'Server error (${res.statusCode})'};
      }
    } catch (e) {
      return {'message': 'Network error: $e'};
    }
  }

  // ── Auth: Get current session ─────────────────────────────────────────────
  // Returns { authenticated, username, displayName, email, avatarId, bio, presenceMode }
  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/api/auth/session'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));
      await _storeSessionCookie(res);
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  // ── Auth: Refresh token ───────────────────────────────────────────────────
  static Future<bool> refreshSession() async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/refresh'),
            headers: await _csrfHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        await _storeSessionCookie(res);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Auth: Logout ──────────────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/auth/logout'),
            headers: await _csrfHeaders(),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
    await clearSession();
  }


  // ── Password reset (email/username + emailed one-time code) ─────────────
  static Future<Map<String, dynamic>> requestPasswordReset(
      String identifier) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/password-reset/request'),
            headers: await _csrfHeaders(),
            body: jsonEncode({'identifier': identifier.trim()}),
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(response.body);
      if (body is Map) {
        return {
          ...Map<String, dynamic>.from(body),
          'httpStatus': response.statusCode,
        };
      }
      return {'ok': false, 'message': 'Unexpected server response.'};
    } catch (_) {
      return {'ok': false, 'message': 'Could not reach Novyn. Check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> confirmPasswordReset({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/password-reset/confirm'),
            headers: await _csrfHeaders(),
            body: jsonEncode({
              'identifier': identifier.trim(),
              'code': code.trim(),
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final body = jsonDecode(response.body);
      if (body is Map) {
        return {
          ...Map<String, dynamic>.from(body),
          'httpStatus': response.statusCode,
        };
      }
      return {'ok': false, 'message': 'Unexpected server response.'};
    } catch (_) {
      return {'ok': false, 'message': 'Could not reach Novyn. Check your connection.'};
    }
  }

  // ── Fetch chat history for a conversation ────────────────────────────────
  // [to]    — username of the other party (or groupId for groups)
  // [kind]  — 'friend' or 'group'
  // [myUsername] — logged-in user's username (to set isFromMe)
  static Future<List<Message>> getHistory(
    String to, {
    String kind = 'friend',
    String? myUsername,
    int limit = 50,
  }) async {
    try {
      final url =
          '$baseUrl/api/history?to=${Uri.encodeComponent(to)}&kind=$kind&limit=$limit';
      final res = await http
          .get(Uri.parse(url), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((m) {
          final sender = m['from'] ?? m['sender'] ?? m['fromKey'] ?? '';
          return Message(
            id: m['id']?.toString() ?? m['messageId']?.toString() ?? '',
            chatId: to,
            text: m['text'] ?? '',
            isEncrypted: m['isEncrypted'] == true,
            ciphertext: m['ciphertext']?.toString(),
            iv: m['iv']?.toString(),
            senderId: sender,
            isFromMe: myUsername != null && sender == myUsername,
            createdAt: DateTime.tryParse(m['timestamp']?.toString() ?? '') ??
                DateTime.now(),
            reactions: Message.parseReactions(m['reactions']),
            replyToId: m['replyTo']?['id']?.toString(),
            replyToText: m['replyTo']?['text']?.toString(),
            replyToSender: m['replyTo']?['from']?.toString(),
            edited: m['edited'] == true,
            attachment: m['attachment'] is Map ? Map<String, dynamic>.from(m['attachment']) : null,
            poll: m['poll'] is Map ? Map<String, dynamic>.from(m['poll']) : null,
            game: m['game'] is Map ? Map<String, dynamic>.from(m['game']) : null,
            riddle: m['riddle'] is Map ? Map<String, dynamic>.from(m['riddle']) : null,
            pinnedAt: m['pinnedAt']?.toString(),
            pinnedBy: m['pinnedBy']?.toString(),
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Revoke all other authenticated devices, preserving this session ────
  static Future<Map<String, dynamic>> revokeOtherSessions() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/revoke-sessions'),
            headers: await _csrfHeaders(),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (body is Map) {
        return {
          ...Map<String, dynamic>.from(body),
          'httpStatus': response.statusCode,
        };
      }
      return {'ok': false, 'message': 'Unexpected server response.'};
    } catch (_) {
      return {'ok': false, 'message': 'Could not reach Novyn. Check your connection.'};
    }
  }

  // ── Fetch call logs for the current user ─────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCallLogs() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/calls'), headers: _authHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return [];
  }

  // ── Friend search ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$baseUrl/api/users/search?q=${Uri.encodeComponent(query)}'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> getLinkPreview(String url) async {
    try {
      final uri = Uri.parse('$baseUrl/api/link-preview').replace(
        queryParameters: {'url': url},
      );
      final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      return body is Map ? Map<String, dynamic>.from(body) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getGiphy({
    String query = '',
    String type = 'gifs',
    int offset = 0,
  }) async {
    try {
      final params = <String, String>{
        'type': type,
        'limit': '24',
        'offset': offset.toString(),
        if (query.trim().isNotEmpty) 'q': query.trim(),
      };
      final uri = Uri.parse('$baseUrl/api/giphy').replace(queryParameters: params);
      final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 12));
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body is Map) {
        return Map<String, dynamic>.from(body);
      }
      return {'error': body is Map ? body['error']?.toString() ?? 'GIF search failed.' : 'GIF search failed.'};
    } catch (_) {
      return {'error': 'GIF search is temporarily unavailable.'};
    }
  }

  // ── Upload media using the authenticated shared backend route ────────────
  static Future<String?> uploadMedia(
      List<int> bytes, String filename, String mimeType) async {
    try {
      final headers = await _csrfHeaders();
      headers.remove('Content-Type');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload-file'))
        ..headers.addAll(headers)
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final url = body['url']?.toString();
        if (url == null || url.isEmpty) return null;
        return Uri.parse(baseUrl).resolve(url).toString();
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> uploadVoice(
      List<int> bytes, String filename, String mimeType) async {
    try {
      final headers = await _csrfHeaders();
      headers.remove('Content-Type');
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload-voice'))
        ..headers.addAll(headers)
        ..files.add(http.MultipartFile.fromBytes(
          'voice',
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final url = body['url']?.toString();
        if (url == null || url.isEmpty) return null;
        return Uri.parse(baseUrl).resolve(url).toString();
      }
    } catch (_) {}
    return null;
  }

  // ── Compatibility methods used by old screens ─────────────────────────────

  // GET /api/chats/:uid — returns raw chat list (old Flutter backend format)
  static Future<List<Map<String, dynamic>>> getChats(String uid) async {
    // novyn-chat exposes friend/conversation list via the socket (friend_list).
    // As a REST fallback, hit the session endpoint and return an empty list —
    // the real data comes through the socket after resume_session.
    return [];
  }

  // Open a chat (no-op on novyn-chat; chatId is derived from usernames)
  static Future<Map<String, dynamic>?> openChat(
      String myUsername, String peerUsername) async {
    // novyn-chat doesn't need a separate "open chat" REST call.
    // chatId is just the peer's username (stored in SocketService.currentChatWith).
    return {'chatId': peerUsername};
  }

  // GET messages for a chat
  static Future<List<Message>> getMessages(
    String chatId, {
    String? myUid, // kept for compatibility; ignored (cookie auth)
    String? myUsername,
    String? before,
    int limit = 50,
  }) {
    return getHistory(
      chatId,
      kind: 'friend',
      myUsername: myUsername ?? myUid,
      limit: limit,
    );
  }

  // Mark messages as read
  static Future<void> markRead(String chatId, String uid) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/chats/$chatId/read'),
            headers: _authHeaders,
            body: jsonEncode({'uid': uid}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // Log a completed call
  static Future<void> logCall({
    required String callerId,
    required String receiverId,
    required String type,
    required String status,
    int duration = 0,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/calls'),
            headers: _authHeaders,
            body: jsonEncode({
              'callerId': callerId,
              'receiverId': receiverId,
              'type': type,
              'status': status,
              'duration': duration,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // Update profile fields
  static Future<Map<String, dynamic>?> updateProfile({
    required String name,
    required String bio,
    String? username,
    int? age,
    String? gender,
    String? avatarId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/profile/update'),
            headers: _authHeaders,
            body: jsonEncode({
              'displayName': name,
              'bio': bio,
              if (username != null) 'username': username,
              if (age != null) 'age': age,
              if (gender != null) 'gender': gender,
              if (avatarId != null) 'avatarId': avatarId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }
      return {'error': jsonDecode(res.body)['message'] ?? 'Update failed'};
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  // Update presence/status
  static Future<void> updatePresence(String mode) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/profile/presence'),
            headers: _authHeaders,
            body: jsonEncode({'mode': mode}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // Check username availability
  static Future<bool?> checkUsername(String username) async {
    try {
      final res = await http
          .get(
            Uri.parse(
                '$baseUrl/api/users/check-username?username=${Uri.encodeComponent(username)}'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['available'] == true;
      }
    } catch (_) {}
    return null;
  }

  // Update privacy settings
  static Future<void> updatePrivacySettings({
    String? lastSeenVisibility,
    String? profilePhotoVisibility,
    bool? readReceipts,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/profile/privacy'),
            headers: _authHeaders,
            body: jsonEncode({
              if (lastSeenVisibility != null)
                'lastSeenVisibility': lastSeenVisibility,
              if (profilePhotoVisibility != null)
                'profilePhotoVisibility': profilePhotoVisibility,
              if (readReceipts != null) 'readReceipts': readReceipts,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // Change password
  static Future<Map<String, dynamic>?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/change-password'),
            headers: _authHeaders,
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return {'ok': true};
      return {
        'error': jsonDecode(res.body)['message'] ?? 'Password change failed'
      };
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }
}
