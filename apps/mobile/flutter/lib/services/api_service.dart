import 'dart:convert';
import 'package:http/http.dart' as http;
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
      _storeSessionCookie(response);
      _storeCsrfToken(response);
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
  static void _storeSessionCookie(http.Response res) {
    _storeCsrfToken(res);
    final raw = res.headers['set-cookie'];
    if (raw != null && raw.isNotEmpty) {
      // Extract name=value pairs; drop path/expires/httponly etc.
      final parts =
          raw.split(',').expand((s) => s.split(';')).map((s) => s.trim());
      final cookies = parts
          .where((s) =>
              s.contains('=') &&
              !RegExp(r'^(path|expires|max-age|httponly|samesite|secure)$',
                      caseSensitive: false)
                  .hasMatch(s.split('=').first.trim()))
          .join('; ');
      if (cookies.isNotEmpty) _sessionCookie = cookies;
    }
  }

  static void _storeCsrfToken(http.Response res) {
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final match = RegExp(
      r'(?:^|,\s*)novyn_csrf=([^;,\s]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match != null) _csrfToken = Uri.decodeComponent(match.group(1)!);
  }

  // ── Clear session (on logout) ─────────────────────────────────────────────
  static void clearSession() {
    _sessionCookie = null;
    _csrfToken = null;
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
        _storeSessionCookie(res);
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
        _storeSessionCookie(res);
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
        _storeSessionCookie(res);
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
      _storeSessionCookie(res);
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
        _storeSessionCookie(res);
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
    clearSession();
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
          );
        }).toList();
      }
    } catch (_) {}
    return [];
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

  // ── Upload media (multipart) ──────────────────────────────────────────────
  static Future<String?> uploadMedia(
      List<int> bytes, String filename, String mimeType) async {
    try {
      final uri = Uri.parse('$baseUrl/api/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({..._authHeaders}..remove('Content-Type'))
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ));
      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return body['url']?.toString();
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
