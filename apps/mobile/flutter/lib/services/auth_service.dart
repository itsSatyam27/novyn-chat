import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Novyn Auth Service — bridges Firebase Auth with novyn-chat's backend.
///
/// Flow:
///   1. Firebase Auth handles credential verification (email/password or Google).
///   2. For Google sign-in, Firebase issues an idToken which is forwarded to
///      novyn-chat's POST /api/auth/google endpoint.
///   3. novyn-chat's server verifies the idToken with Firebase Admin SDK,
///      creates or matches a username-based account, and issues a JWT cookie.
///   4. All subsequent requests use that cookie via ApiService._sessionCookie.
///   5. The local identity is the `username` string (not a Firebase UID).
///
/// For email/password, Firebase is NOT used for the actual credential check —
/// we send directly to novyn-chat's /api/auth/signin and /api/auth/signup so
/// that the server owns the account record. Firebase Auth is only used as an
/// identity broker for Google SSO.

class NovynUser {
  final String username;
  final String displayName;
  final String email;
  final String avatarId;
  final String bio;
  final String presenceMode;

  const NovynUser({
    required this.username,
    required this.displayName,
    required this.email,
    this.avatarId = '',
    this.bio = '',
    this.presenceMode = 'online',
  });

  NovynUser copyWith({
    String? username,
    String? displayName,
    String? email,
    String? avatarId,
    String? bio,
    String? presenceMode,
  }) {
    return NovynUser(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarId: avatarId ?? this.avatarId,
      bio: bio ?? this.bio,
      presenceMode: presenceMode ?? this.presenceMode,
    );
  }

  factory NovynUser.fromMap(Map<String, dynamic> m) => NovynUser(
        username: m['username']?.toString() ?? '',
        displayName:
            m['displayName']?.toString() ?? m['username']?.toString() ?? '',
        email: m['email']?.toString() ?? '',
        avatarId: m['avatarId']?.toString() ?? '',
        bio: m['bio']?.toString() ?? '',
        presenceMode: m['presenceMode']?.toString() ?? 'online',
      );
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  NovynUser? _user;
  bool _authReady = false;

  NovynUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get authReady => _authReady;

  AuthService() {
    _restoreSession();
  }

  // ── Restore session from novyn-chat JWT cookie on app start ───────────────
  Future<void> _restoreSession() async {
    try {
      final session = await ApiService.getSession();
      if (session != null && session['authenticated'] == true) {
        _user = NovynUser.fromMap(session);
      }
    } catch (_) {}
    _authReady = true;
    notifyListeners();
  }

  // ── Refresh (call after profile edits) ────────────────────────────────────
  Future<void> refreshProfile() async {
    try {
      final session = await ApiService.getSession();
      if (session != null && session['authenticated'] == true) {
        _user = NovynUser.fromMap(session);
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  // Returns null on success, an error message string on failure.
  Future<String?> signInWithGoogle() async {
    try {
      // 1. Trigger Google account picker
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Sign-in cancelled.';

      // 2. Get Google auth tokens
      final googleAuth = await googleUser.authentication;

      // 3. Sign into Firebase (needed to get a valid idToken for our server)
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await _firebaseAuth.signInWithCredential(credential);

      // 4. Get the Firebase ID token
      final idToken = await userCred.user?.getIdToken();
      if (idToken == null) return 'Failed to retrieve authentication token.';

      // 5. Send to novyn-chat backend — this creates/matches a username account
      final result = await ApiService.signInWithGoogle(
        idToken: idToken,
        remember: true,
      );

      if (result == null) return 'No response from server.';
      if (result['username'] == null) {
        return result['message']?.toString() ?? 'Google sign-in failed.';
      }

      // 6. Load the full session profile
      final session = await ApiService.getSession();
      if (session != null && session['authenticated'] == true) {
        _user = NovynUser.fromMap(session);
      } else {
        // Fallback from the google response itself
        _user = NovynUser(
          username: result['username'].toString(),
          displayName: result['displayName']?.toString() ??
              result['username'].toString(),
          email: result['email']?.toString() ?? googleUser.email,
        );
      }

      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _friendlyFirebaseError(e.code);
    } catch (e) {
      return 'Google sign-in failed: ${e.toString()}';
    }
  }

  // ── Email / Password Sign-In ──────────────────────────────────────────────
  // Goes directly to novyn-chat's /api/auth/signin — Firebase not involved.
  Future<String?> login({
    required String identifier, // username or email
    required String password,
    bool remember = true,
  }) async {
    final result = await ApiService.signIn(
      identifier: identifier,
      password: password,
      remember: remember,
    );

    if (result == null) return 'No response from server.';
    if (result['username'] == null) {
      return result['message']?.toString() ?? 'Login failed.';
    }

    final session = await ApiService.getSession();
    if (session != null && session['authenticated'] == true) {
      _user = NovynUser.fromMap(session);
    } else {
      _user = NovynUser(
        username: result['username'].toString(),
        displayName: result['displayName']?.toString() ??
            result['username'].toString(),
        email: result['email']?.toString() ?? '',
      );
    }

    notifyListeners();
    return null; // success
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<String?> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final result = await ApiService.signUp(
      name: name,
      username: username,
      email: email,
      password: password,
    );

    if (result == null) return 'No response from server.';
    if (result['username'] == null) {
      return result['message']?.toString() ?? 'Registration failed.';
    }

    final session = await ApiService.getSession();
    if (session != null && session['authenticated'] == true) {
      _user = NovynUser.fromMap(session);
    } else {
      _user = NovynUser(
        username: result['username'].toString(),
        displayName: name,
        email: email,
      );
    }

    notifyListeners();
    return null; // success
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    // Sign out from Firebase (Google SSO cleanup)
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (_) {}

    // Invalidate novyn-chat JWT cookie
    await ApiService.logout();

    _user = null;
    notifyListeners();
  }

  // ── userProfile getter (alias so old screens still compile) ─────────────
  // Returns a minimal object that screens can call .name, .username etc. on.
  NovynUser? get userProfile => _user;

  // ── firebaseUser stub — old screens used auth.firebaseUser?.uid ──────────
  // We return a thin shim so callers get the username as the "uid".
  _NovynFirebaseUserShim? get firebaseUser =>
      _user != null ? _NovynFirebaseUserShim(_user!.username) : null;

  // ── setOnline — tells the server about presence via socket ───────────────
  // The actual emit is done by SocketService; this is a no-op here but
  // kept so screens that call auth.setOnline() compile without changes.
  Future<void> setOnline(bool online) async {}

  // ── updateStatus — emits set_presence_mode via the backend ──────────────
  // Screens call auth.updateStatus('Online'|'Away'|'Busy'|'Invisible').
  // We update locally and persist via the server session refresh.
  Future<void> updateStatus(String status) async {
    if (_user == null) return;
    _user = _user!.copyWith(presenceMode: status.toLowerCase());
    notifyListeners();
    // Fire-and-forget — the socket will broadcast the change
    try {
      await ApiService.updatePresence(status.toLowerCase());
    } catch (_) {}
  }

  // ── isUsernameAvailable ───────────────────────────────────────────────────
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await ApiService.checkUsername(username);
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── updateProfile ─────────────────────────────────────────────────────────
  Future<String?> updateProfile({
    required String name,
    required String bio,
    String? username,
    int? age,
    String? gender,
  }) async {
    try {
      final result = await ApiService.updateProfile(
        name: name,
        bio: bio,
        username: username,
        age: age,
        gender: gender,
      );
      if (result != null && result['error'] != null) {
        return result['error'].toString();
      }
      await refreshProfile();
      return null;
    } catch (e) {
      return 'Failed to update profile: $e';
    }
  }

  // ── updatePrivacySettings ─────────────────────────────────────────────────
  Future<void> updatePrivacySettings({
    String? lastSeenVisibility,
    String? profilePhotoVisibility,
    bool? readReceipts,
  }) async {
    try {
      await ApiService.updatePrivacySettings(
        lastSeenVisibility: lastSeenVisibility,
        profilePhotoVisibility: profilePhotoVisibility,
        readReceipts: readReceipts,
      );
      await refreshProfile();
    } catch (_) {}
  }

  // ── changePassword ────────────────────────────────────────────────────────
  Future<String?> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final result = await ApiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (result != null && result['error'] != null) {
        return result['error'].toString();
      }
      return null;
    } catch (e) {
      return 'Failed to change password: $e';
    }
  }

  // ── uploadProfilePicture ──────────────────────────────────────────────────
  Future<String?> uploadProfilePicture(dynamic imageFile) async {
    try {
      // Read file bytes and upload via ApiService
      final bytes = await imageFile.readAsBytes();
      final url = await ApiService.uploadMedia(
        bytes,
        'avatar.jpg',
        'image/jpeg',
      );
      if (url == null) return 'Upload failed.';
      // Update local profile
      _user = _user?.copyWith(avatarId: url);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Upload error: $e';
    }
  }

  // ── deleteProfilePicture ──────────────────────────────────────────────────
  Future<String?> deleteProfilePicture() async {
    try {
      await ApiService.updateProfile(
        name: _user?.displayName ?? '',
        bio: _user?.bio ?? '',
        avatarId: '',
      );
      _user = _user?.copyWith(avatarId: '');
      notifyListeners();
      return null;
    } catch (e) {
      return 'Delete error: $e';
    }
  }

  // ── Update local user fields optimistically ───────────────────────────────
  // Call this after a socket 'profile_updated' event arrives.
  void applyProfileUpdate(Map<String, dynamic> update) {
    if (_user == null) return;
    _user = _user!.copyWith(
      displayName: update['displayName']?.toString(),
      bio: update['bio']?.toString(),
      avatarId: update['avatarId']?.toString(),
      presenceMode: update['presenceMode']?.toString(),
    );
    notifyListeners();
  }

  // ── Firebase error → human-readable message ───────────────────────────────
  String _friendlyFirebaseError(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a different sign-in method.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

// ── Thin shim so screens that use auth.firebaseUser?.uid compile ──────────
// Returns the novyn-chat username as the "uid" since that is our identity.
class _NovynFirebaseUserShim {
  final String uid; // actually the novyn-chat username
  const _NovynFirebaseUserShim(this.uid);
}

// ── Extend NovynUser with fields that old screens reference ───────────────
extension NovynUserCompat on NovynUser {
  // Screens reference profile.name, profile.username, profile.status etc.
  String get name => displayName;
  String get status => presenceMode;
  String get photoUrl => avatarId; // avatarId stores the photo URL
  String get gender => '';         // not stored in this model; stub
  int? get age => null;            // not stored in this model; stub
  bool get isOnline => presenceMode != 'invisible' && presenceMode != 'offline';
}
