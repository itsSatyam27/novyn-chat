import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'firebase_configuration.dart';
import 'hybrid_db_service.dart';
import 'local_db_service.dart';

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
  final bool emailVerified;
  final bool hasPassword;
  final bool isGoogleUser;

  const NovynUser({
    required this.username,
    required this.displayName,
    required this.email,
    this.avatarId = '',
    this.bio = '',
    this.presenceMode = 'online',
    this.emailVerified = false,
    this.hasPassword = true,
    this.isGoogleUser = false,
  });

  NovynUser copyWith({
    String? username,
    String? displayName,
    String? email,
    String? avatarId,
    String? bio,
    String? presenceMode,
    bool? emailVerified,
    bool? hasPassword,
    bool? isGoogleUser,
  }) {
    return NovynUser(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarId: avatarId ?? this.avatarId,
      bio: bio ?? this.bio,
      presenceMode: presenceMode ?? this.presenceMode,
      emailVerified: emailVerified ?? this.emailVerified,
      hasPassword: hasPassword ?? this.hasPassword,
      isGoogleUser: isGoogleUser ?? this.isGoogleUser,
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
        emailVerified: m['emailVerified'] == true,
        hasPassword: m['hasPassword'] != false,
        isGoogleUser: m['isGoogleUser'] == true,
      );
}

class AuthService extends ChangeNotifier {
  static const FlutterSecureStorage _identityStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateWithBackup: true,
    ),
  );
  static const String _cachedIdentityKey = 'novyn_last_signed_in_identity_v1';

  final Future<void> Function(String)? savePresence;
  final Map<String, dynamic> Function(String)? presencePolicy;
  final Future<void> Function(String, Map<String, dynamic>)? savePresencePolicy;
  final Future<void> Function(String, String)? savePassword;
  final Future<void> Function(String)? clearNotificationsToken;
  final Future<void> Function()? onAccountReset;
  final Future<void> Function()? onSessionRefreshed;
  bool _updatingPresence = false;
  bool get updatingPresence => _updatingPresence;
  late final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: FirebaseConfiguration.googleWebClientId,
  );

  NovynUser? _user;
  bool _authReady = false;
  String? _pendingTwoFactorChallenge;
  String? _pendingTwoFactorUsername;
  String? _pendingGoogleIdToken;
  String? _pendingGoogleUsernameSuggestion;
  String? _pendingGoogleEmail;
  Timer? _sessionMaintenanceTimer;
  bool _sessionRestoreInProgress = false;
  int _sessionMutationGeneration = 0;
  bool _sessionInvalidated = false;

  bool get isTwoFactorPending => _pendingTwoFactorChallenge != null;
  bool get isGoogleUsernamePending =>
      _pendingGoogleIdToken?.isNotEmpty == true;
  String get googleUsernameSuggestion =>
      _pendingGoogleUsernameSuggestion ?? 'novynuser';

  NovynUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get authReady => _authReady;
  bool get sessionInvalidated => _sessionInvalidated;

  AuthService(
      {this.savePresence,
      this.presencePolicy,
      this.savePresencePolicy,
      this.savePassword,
      this.clearNotificationsToken,
      this.onAccountReset,
      this.onSessionRefreshed,
      Future<Map<String, dynamic>?> Function()? restoreSession}) {
    _restoreSession(
      restoreSession ??
          (() => ApiService.getSession(timeout: const Duration(seconds: 7))),
    );
    // Keep the refresh-cookie chain warm while the app remains open. Android
    // may suspend this timer in the background; resume handling below performs
    // an immediate check when the app becomes active again.
    _sessionMaintenanceTimer = Timer.periodic(
      const Duration(minutes: 20),
      (_) {
        if (_authReady && _user != null) {
          unawaited(restoreSessionOnResume());
        }
      },
    );
  }

  @override
  void dispose() {
    _sessionMaintenanceTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _identityToMap(NovynUser user) => {
        'username': user.username,
        'displayName': user.displayName,
        'email': user.email,
        'avatarId': user.avatarId,
        'bio': user.bio,
        'presenceMode': user.presenceMode,
        'emailVerified': user.emailVerified,
        'hasPassword': user.hasPassword,
        'isGoogleUser': user.isGoogleUser,
      };

  static const String _cachedIdentityMirrorKey =
      'novyn_last_signed_in_identity_mirror_v1';
  // This marker distinguishes an intentional local sign-out from a missing
  // cookie after a process restart or transient Android storage failure.
  static const String _signedOutMarkerKey = 'novyn_explicit_signed_out_v1';

  Future<bool> _hasSignedOutMarker() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_signedOutMarkerKey) == true;
    } catch (error) {
      debugPrint('[NovynAuth] Sign-out marker read failed: $error');
      return false;
    }
  }

  Future<void> _setSignedOutMarker(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_signedOutMarkerKey, value);
    } catch (error) {
      debugPrint('[NovynAuth] Sign-out marker write failed: $error');
    }
  }

  Future<void> _persistIdentity(
    NovynUser user, {
    int? expectedGeneration,
  }) async {
    // New sign-ins supersede any older startup verification. Background
    // restore passes its captured generation so a late response cannot undo
    // an explicit logout or a newer login.
    final writeGeneration = expectedGeneration ?? ++_sessionMutationGeneration;
    if (writeGeneration != _sessionMutationGeneration) return;
    _sessionInvalidated = false;
    final encoded = jsonEncode(_identityToMap(user));

    try {
      await _identityStorage.write(
        key: _cachedIdentityKey,
        value: encoded,
      ).timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('[NovynAuth] Secure identity cache write failed: $error');
    }
    if (writeGeneration != _sessionMutationGeneration) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (writeGeneration != _sessionMutationGeneration) return;
      // A successful sign-in/session restore supersedes any earlier sign-out.
      await prefs.setBool(_signedOutMarkerKey, false);
      if (writeGeneration != _sessionMutationGeneration) return;
      // Only non-secret display identity is mirrored outside secure storage.
      await prefs.setString(
        _cachedIdentityMirrorKey,
        jsonEncode({
          'username': user.username,
          'displayName': user.displayName,
        }),
      );
    } catch (error) {
      debugPrint('[NovynAuth] Identity mirror write failed: $error');
    }
  }


  /// Read the small, non-secret SharedPreferences identity mirror first so a
  /// returning account can reach its local data without waiting on Keystore.
  Future<NovynUser?> _readCachedIdentityMirror() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedIdentityMirrorKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final identity = NovynUser.fromMap(Map<String, dynamic>.from(decoded));
      return identity.username.trim().isEmpty ? null : identity;
    } catch (error) {
      debugPrint('[NovynAuth] Identity mirror read failed: $error');
      return null;
    }
  }

  Future<NovynUser?> _readCachedIdentity() async {
    String? raw;
    try {
      raw = await _identityStorage
          .read(key: _cachedIdentityKey)
          .timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('[NovynAuth] Secure identity cache is unavailable: $error');
    }

    NovynUser? decodeIdentity(String? value) {
      if (value == null || value.isEmpty) return null;
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map) return null;
        final user = NovynUser.fromMap(Map<String, dynamic>.from(decoded));
        return user.username.trim().isEmpty ? null : user;
      } catch (_) {
        return null;
      }
    }

    final secureIdentity = decodeIdentity(raw);
    if (secureIdentity != null) return secureIdentity;

    // SharedPreferences is only a recovery copy of non-secret display identity.
    // The session cookie is always read from FlutterSecureStorage.
    try {
      final prefs = await SharedPreferences.getInstance();
      return decodeIdentity(prefs.getString(_cachedIdentityMirrorKey));
    } catch (error) {
      debugPrint('[NovynAuth] Identity mirror is unavailable: $error');
      return null;
    }
  }

  Future<void> _clearCachedIdentity() async {
    try {
      await _identityStorage
          .delete(key: _cachedIdentityKey)
          .timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('[NovynAuth] Could not clear secure identity cache: $error');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedIdentityMirrorKey);
    } catch (error) {
      debugPrint('[NovynAuth] Could not clear identity mirror: $error');
    }
  }

  Future<void> _prepareAccount(String username) async {
    if (_user?.username.toLowerCase() != username.toLowerCase()) {
      try {
        await onAccountReset?.call().timeout(const Duration(seconds: 4));
      } catch (error) {
        debugPrint('[NovynAuth] Previous account cleanup was incomplete: $error');
      }
    }
    await HybridDbService.activateAccount(username)
        .timeout(const Duration(seconds: 8));
  }

  // ── Restore session from novyn-chat JWT cookie on app start ───────────────
  // A transient Keystore or backend failure must never be interpreted as a
  // logout. The app keeps a non-secret local identity mirror for recovery,
  // while the actual session cookie remains exclusively in secure storage.
  // A confirmed missing cookie or repeated explicit refresh-token rejection
  // still clears the cached identity and routes to sign-in.
  Future<void> _activateCachedIdentity(
    NovynUser? cachedIdentity, {
    required String reason,
  }) async {
    if (cachedIdentity == null) return;
    try {
      await HybridDbService.activateAccount(cachedIdentity.username)
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('[NovynAuth] Local account cache is not ready yet: $error');
    }
    _user = cachedIdentity;
    _sessionInvalidated = false;
    _authReady = true;
    notifyListeners();
    debugPrint('[NovynAuth] Restored local account identity ($reason).');
  }

  Future<void> _hydrateCachedIdentityDetails(
    String username,
    int expectedGeneration,
  ) async {
    try {
      final cached = await _readCachedIdentity();
      if (cached == null ||
          cached.username.toLowerCase() != username.toLowerCase() ||
          expectedGeneration != _sessionMutationGeneration ||
          _user?.username.toLowerCase() != username.toLowerCase()) {
        return;
      }
      final previous = _user;
      final changed = previous == null ||
          jsonEncode(_identityToMap(previous)) !=
              jsonEncode(_identityToMap(cached));
      if (!changed) return;
      _user = cached;
      notifyListeners();
    } catch (error) {
      debugPrint('[NovynAuth] Cached profile hydration failed: $error');
    }
  }

  Future<void> _applyVerifiedSession(
    Map<String, dynamic> session,
    int expectedGeneration,
  ) async {
    if (expectedGeneration != _sessionMutationGeneration ||
        await _hasSignedOutMarker()) {
      return;
    }
    final restoredUser = NovynUser.fromMap(session);
    if (restoredUser.username.trim().isEmpty) return;

    final previous = _user;
    if (previous?.username.toLowerCase() !=
        restoredUser.username.toLowerCase()) {
      await HybridDbService.activateAccount(restoredUser.username)
          .timeout(const Duration(seconds: 8));
    }
    if (expectedGeneration != _sessionMutationGeneration ||
        await _hasSignedOutMarker()) {
      return;
    }

    final changed = previous == null ||
        jsonEncode(_identityToMap(previous)) !=
            jsonEncode(_identityToMap(restoredUser));
    _user = restoredUser;
    _authReady = true;
    await _persistIdentity(
      restoredUser,
      expectedGeneration: expectedGeneration,
    );
    if (expectedGeneration != _sessionMutationGeneration ||
        await _hasSignedOutMarker()) {
      return;
    }
    if (changed) notifyListeners();
  }

  Future<void> _invalidateSessionAfterStartupRejections(
    int expectedGeneration,
  ) async {
    if (expectedGeneration != _sessionMutationGeneration) return;
    debugPrint(
      '[NovynAuth] Clearing local sign-in after 3 consecutive background refresh rejections.',
    );
    final invalidationGeneration = ++_sessionMutationGeneration;
    await _setSignedOutMarker(true);
    if (invalidationGeneration != _sessionMutationGeneration) return;
    await ApiService.clearSession();
    if (invalidationGeneration != _sessionMutationGeneration) return;
    try {
      await onAccountReset?.call().timeout(const Duration(seconds: 4));
    } catch (error) {
      debugPrint('[NovynAuth] Socket cleanup skipped after session rejection: $error');
    }
    if (invalidationGeneration != _sessionMutationGeneration) return;
    await _clearCachedIdentity();
    if (invalidationGeneration != _sessionMutationGeneration) return;

    _user = null;
    _authReady = true;
    _sessionInvalidated = true;
    notifyListeners();
  }

  /// Verify a locally restored account after navigation. Transient network,
  /// storage and 5xx failures leave its offline cache available; only repeated
  /// explicit refresh-token rejection invalidates the local session.
  Future<void> _verifySessionInBackground(
    Future<Map<String, dynamic>?> Function() loadSession,
  ) async {
    if (_sessionRestoreInProgress) return;
    _sessionRestoreInProgress = true;
    final generation = _sessionMutationGeneration;
    var definitiveRejections = 0;
    try {
      final storageReady = await ApiService.initializeSessionStorage().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
      if (!storageReady) {
        // Keep the previous Keystore recovery behavior, but do it after the
        // user has already reached the local account instead of holding splash.
        unawaited(Future<void>.delayed(const Duration(seconds: 2), () async {
          if (generation != _sessionMutationGeneration || _user == null) return;
          try {
            final ready = await ApiService.initializeSessionStorage().timeout(
              const Duration(seconds: 4),
              onTimeout: () => false,
            );
            if (ready &&
                generation == _sessionMutationGeneration &&
                _user != null) {
              await restoreSessionOnResume();
            }
          } catch (error) {
            debugPrint('[NovynAuth] Background Keystore retry failed: $error');
          }
        }));
        return;
      }
      if (generation != _sessionMutationGeneration ||
          ApiService.sessionCookie == null ||
          ApiService.sessionCookie!.isEmpty) {
        return;
      }
      final cookieBeforeVerification = ApiService.sessionCookie;

      for (var attempt = 0; attempt < 5; attempt++) {
        final session = await loadSession()
            .timeout(const Duration(seconds: 7), onTimeout: () => null);
        if (generation != _sessionMutationGeneration ||
            await _hasSignedOutMarker()) {
          return;
        }
        if (session?['authenticated'] == true) {
          await _applyVerifiedSession(session!, generation);
          if (generation == _sessionMutationGeneration &&
              _user != null &&
              ApiService.sessionCookie != cookieBeforeVerification) {
            // The server may rotate the cookie pair during a background
            // refresh. Reconnect the socket so it does not keep an old session.
            try {
              await onSessionRefreshed?.call();
            } catch (error) {
              debugPrint('[NovynAuth] Socket session refresh deferred: $error');
            }
          }
          return;
        }

        final status = session?['_httpStatus'];
        if (status != 401 && status != 403) return;

        final refreshStatus = await ApiService.refreshSessionStatus().timeout(
          const Duration(seconds: 8),
          onTimeout: () => null,
        );
        if (generation != _sessionMutationGeneration ||
            await _hasSignedOutMarker()) {
          return;
        }
        if (refreshStatus == 200) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
        if (refreshStatus != 401 && refreshStatus != 403) return;

        definitiveRejections++;
        if (definitiveRejections >= 3) {
          await _invalidateSessionAfterStartupRejections(generation);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } catch (error) {
      debugPrint('[NovynAuth] Background session verification deferred: $error');
    } finally {
      _sessionRestoreInProgress = false;
    }
  }

  Future<void> _restoreSession(
      Future<Map<String, dynamic>?> Function() loadSession) async {
    final explicitlySignedOut = await _hasSignedOutMarker();
    if (explicitlySignedOut) {
      // The durable local marker is authoritative. Do not hold the splash
      // while deleting stale cookies/profile copies from secure storage.
      _user = null;
      _sessionInvalidated = false;
      _authReady = true;
      notifyListeners();
      unawaited(ApiService.clearSession());
      unawaited(_clearCachedIdentity());
      return;
    }

    // The mirror contains no password, token, cookie or other secret. It lets
    // us restore the correct account namespace before doing remote validation.
    final mirroredIdentity = await _readCachedIdentityMirror();
    final cachedIdentity = mirroredIdentity ?? await _readCachedIdentity();
    if (cachedIdentity != null) {
      await _activateCachedIdentity(
        cachedIdentity,
        reason: 'local-first startup',
      );
      final generation = _sessionMutationGeneration;
      unawaited(_hydrateCachedIdentityDetails(cachedIdentity.username, generation));
      unawaited(_verifySessionInBackground(loadSession));
      return;
    }

    final clock = Stopwatch()..start();
    var storageReady = ApiService.sessionStorageInitialized;
    var hadSavedCookie = ApiService.sessionCookie != null;
    var attempt = 0;
    var definitiveRejections = 0;

    while (!_authReady && clock.elapsed < const Duration(seconds: 32)) {
      if (!storageReady) {
        try {
          storageReady = await ApiService.initializeSessionStorage()
              .timeout(const Duration(seconds: 4), onTimeout: () => false);
        } catch (_) {
          storageReady = false;
        }
        hadSavedCookie = hadSavedCookie || ApiService.sessionCookie != null;
        if (!storageReady) {
          // A failed Keystore read is not evidence of logout. Recover the
          // non-secret cached identity and let resume retry secure storage.
          if (cachedIdentity != null) {
            await _activateCachedIdentity(
              cachedIdentity,
              reason: 'secure storage temporarily unavailable',
            );
            unawaited(Future<void>.delayed(const Duration(seconds: 2), () async {
              try {
                final ready = await ApiService.initializeSessionStorage()
                    .timeout(const Duration(seconds: 4), onTimeout: () => false);
                if (ready && _user != null) await restoreSessionOnResume();
              } catch (error) {
                debugPrint('[NovynAuth] Background session-storage retry failed: $error');
              }
            }));
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 700));
          continue;
        }
      }

      hadSavedCookie = hadSavedCookie || ApiService.sessionCookie != null;
      if (!hadSavedCookie) {
        if (cachedIdentity != null) {
          // A successful Keystore read returning an empty cookie is not enough
          // to prove the user explicitly signed out. Keep the last account
          // available for its local/offline data and let resume retry storage.
          // Only the durable sign-out marker above may clear this identity.
          await _activateCachedIdentity(
            cachedIdentity,
            reason: 'session cookie unavailable after restart',
          );
          return;
        }
        _user = null;
        _authReady = true;
        notifyListeners();
        return;
      }

      try {
        final session = await loadSession()
            .timeout(const Duration(seconds: 7), onTimeout: () => null);
        if (session?['authenticated'] == true) {
          final restoredUser = NovynUser.fromMap(session!);
          await HybridDbService.activateAccount(restoredUser.username)
              .timeout(const Duration(seconds: 8));
          _user = restoredUser;
          await _persistIdentity(restoredUser);
          _authReady = true;
          notifyListeners();
          return;
        }

        final status = session?['_httpStatus'];
        if (status == 401 || status == 403) {
          final refreshStatus = await ApiService.refreshSessionStatus()
              .timeout(const Duration(seconds: 8), onTimeout: () => null);
          if (refreshStatus == 200) {
            definitiveRejections = 0;
            attempt++;
            await Future<void>.delayed(const Duration(milliseconds: 400));
            continue;
          }
          if (refreshStatus == 401 || refreshStatus == 403) {
            definitiveRejections++;
            if (definitiveRejections >= 3) {
              debugPrint(
                '[NovynAuth] Clearing local sign-in after 3 consecutive refresh rejections.',
              );
              await _setSignedOutMarker(true);
              await ApiService.clearSession();
              await _clearCachedIdentity();
              _user = null;
              _sessionInvalidated = true;
              _authReady = true;
              notifyListeners();
              return;
            }
          } else if (cachedIdentity != null) {
            // An unavailable refresh endpoint is not an expired session.
            await _activateCachedIdentity(
              cachedIdentity,
              reason: 'session server temporarily unavailable',
            );
            return;
          }
        } else if (cachedIdentity != null) {
          // Network errors and 5xx responses must not turn a valid local
          // account into a logout while Render/connection is recovering.
          await _activateCachedIdentity(
            cachedIdentity,
            reason: 'session verification temporarily unavailable',
          );
          return;
        }
      } catch (error) {
        debugPrint('[NovynAuth] Session restore attempt failed: $error');
        if (cachedIdentity != null) {
          await _activateCachedIdentity(
            cachedIdentity,
            reason: 'session verification failed temporarily',
          );
          return;
        }
      }

      attempt++;
      await Future<void>.delayed(
        Duration(milliseconds: (attempt * 900).clamp(900, 3000)),
      );
    }

    // Keep a previously signed-in account available when the secure store or
    // backend could not be checked. Never use this fallback after a confirmed
    // missing session or repeated explicit refresh-token rejection.
    if (cachedIdentity != null &&
        (hadSavedCookie || !storageReady) &&
        definitiveRejections < 3) {
      await _activateCachedIdentity(
        cachedIdentity,
        reason: 'bounded session restore fallback',
      );
      return;
    }

    if (hadSavedCookie && cachedIdentity == null && storageReady) {
      try {
        final owner = await LocalDbService.getAccountScope()
            .timeout(const Duration(seconds: 3));
        if (owner != null && owner.trim().isNotEmpty) {
          await _activateCachedIdentity(
            NovynUser(
              username: owner.trim(),
              displayName: owner.trim(),
              email: '',
            ),
            reason: 'local account database fallback',
          );
          return;
        }
      } catch (_) {}
    }

    _authReady = true;
    notifyListeners();
  }

  Future<void> restoreSessionOnResume() async {
    if (!_authReady || _user == null || _sessionRestoreInProgress) return;
    _sessionRestoreInProgress = true;
    try {
      // Rehydrate encrypted cookies if the in-memory client was recreated.
      if (ApiService.sessionCookie == null ||
          ApiService.sessionCookie!.isEmpty) {
        final storageReady = await ApiService.initializeSessionStorage().timeout(
          const Duration(seconds: 4),
          onTimeout: () => false,
        );
        if (!storageReady) return;
      }

      final cookieBeforeRestore = ApiService.sessionCookie;
      var session = await ApiService.getSession().timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
      final status = session?['_httpStatus'];
      if (session == null || session['authenticated'] != true) {
        // Do not rotate tokens on ordinary network failures. Only attempt a
        // refresh after the server explicitly rejects the access cookie.
        if (status == 401 || status == 403) {
          final refreshStatus = await ApiService.refreshSessionStatus().timeout(
            const Duration(seconds: 8),
            onTimeout: () => null,
          );
          if (refreshStatus == 200) {
            session = await ApiService.getSession().timeout(
              const Duration(seconds: 8),
              onTimeout: () => null,
            );
          }
        }
      }

      if (session != null && session['authenticated'] == true) {
        final refreshedUser = NovynUser.fromMap(session);
        if (_user?.username.toLowerCase() !=
            refreshedUser.username.toLowerCase()) {
          await _prepareAccount(refreshedUser.username);
        }
        final previousUser = _user;
        final identityChanged = previousUser == null ||
            jsonEncode(_identityToMap(previousUser)) !=
                jsonEncode(_identityToMap(refreshedUser));
        _user = refreshedUser;

        // A healthy resume commonly returns the exact same profile. Avoid
        // notifying every auth consumer (tabs, dock, profile) unless data really
        // changed; this prevents a whole-app rebuild on every app switch.
        if (identityChanged) {
          await _persistIdentity(refreshedUser);
          notifyListeners();
        }

        // A successful session lookup can rotate the access/refresh cookies.
        // Existing Socket.IO connections keep the old session ID, so reconnect
        // them with the newly persisted cookie before the next account action.
        if (ApiService.sessionCookie != cookieBeforeRestore) {
          try {
            await onSessionRefreshed?.call();
          } catch (_) {
            // Keep the signed-in account even if the socket reconnect is delayed.
          }
        }
      }
      // A timeout, offline state, or temporary 5xx must never clear the local
      // account. A definitive expired session is handled by the next sign-in
      // gate only when the app is freshly started.
    } catch (_) {
      // Preserve the current user during temporary connectivity loss.
    } finally {
      _sessionRestoreInProgress = false;
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String identifier) =>
      ApiService.requestPasswordReset(identifier);

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String identifier,
    required String code,
    required String newPassword,
  }) =>
      ApiService.confirmPasswordReset(
        identifier: identifier,
        code: code,
        newPassword: newPassword,
      );

  // ── Refresh (call after profile edits) ────────────────────────────────────
  Future<void> refreshProfile() async {
    try {
      final session = await ApiService.getSession();
      if (session != null && session['authenticated'] == true) {
        final sessionUser = NovynUser.fromMap(session);
        // Some session snapshots briefly omit avatarId after a media upload.
        // Preserve the confirmed local URL rather than clearing the photo on refresh.
        final currentAvatar = _user?.avatarId.trim() ?? '';
        final refreshedUser = sessionUser.avatarId.trim().isEmpty && currentAvatar.isNotEmpty
            ? sessionUser.copyWith(avatarId: currentAvatar)
            : sessionUser;
        if (_user?.username.toLowerCase() != refreshedUser.username.toLowerCase()) {
          await _prepareAccount(refreshedUser.username);
        }
        _user = refreshedUser;
        await _persistIdentity(refreshedUser);
        notifyListeners();
      }
    } catch (_) {}
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  // New Google accounts choose a Novyn username before the backend creates them.
  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Sign-in cancelled.';

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await userCred.user?.getIdToken();
      if (idToken == null) return 'Failed to retrieve authentication token.';

      final result = await ApiService.signInWithGoogle(
        idToken: idToken,
        remember: true,
      );
      if (result == null) return 'No response from server.';

      if (result['requiresUsername'] == true) {
        _pendingGoogleIdToken = idToken;
        _pendingGoogleEmail = googleUser.email;
        _pendingGoogleUsernameSuggestion =
            result['usernameSuggestion']?.toString() ?? 'novynuser';
        notifyListeners();
        return null;
      }

      return await _completeGoogleSignInResult(
        result,
        fallbackEmail: googleUser.email,
      );
    } on FirebaseAuthException catch (e) {
      return _friendlyFirebaseError(e.code);
    } on PlatformException catch (e) {
      return _friendlyGoogleSignInError(e);
    } catch (e) {
      return 'Google sign-in failed: ${e.toString()}';
    }
  }

  Future<String?> completeGoogleSignUp(String username) async {
    final idToken = _pendingGoogleIdToken;
    if (idToken == null || idToken.isEmpty) {
      return 'Your Google signup has expired. Please try again.';
    }

    final normalized = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(normalized)) {
      return 'Use 3–24 lowercase letters, numbers, or underscores.';
    }

    try {
      final result = await ApiService.signInWithGoogle(
        idToken: idToken,
        username: normalized,
        remember: true,
      );
      if (result == null) return 'No response from server.';
      if (result['requiresUsername'] == true) {
        return 'Choose a username to finish creating your account.';
      }
      if (result['username'] == null) {
        return result['message']?.toString() ?? 'Google signup failed.';
      }

      final fallbackEmail = _pendingGoogleEmail ?? '';
      _clearPendingGoogleSignup();
      return await _completeGoogleSignInResult(
        result,
        fallbackEmail: fallbackEmail,
      );
    } catch (error) {
      return 'Google signup failed: ${error.toString()}';
    }
  }

  Future<void> cancelGoogleUsernameSelection() async {
    _clearPendingGoogleSignup();
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    notifyListeners();
  }

  void _clearPendingGoogleSignup() {
    _pendingGoogleIdToken = null;
    _pendingGoogleEmail = null;
    _pendingGoogleUsernameSuggestion = null;
  }

  Future<String?> _completeGoogleSignInResult(
    Map<String, dynamic> result, {
    required String fallbackEmail,
  }) async {
    if (result['requiresTwoFactor'] == true) {
      _pendingTwoFactorChallenge = result['challengeToken']?.toString();
      _pendingTwoFactorUsername = result['username']?.toString();
      if (_pendingTwoFactorChallenge == null ||
          _pendingTwoFactorChallenge!.isEmpty) {
        return 'The server did not create a secure verification challenge.';
      }
      notifyListeners();
      return null;
    }
    if (result['username'] == null) {
      return result['message']?.toString() ?? 'Google sign-in failed.';
    }

    final session = await ApiService.getSession();
    if (session != null && session['authenticated'] == true) {
      final signedInUser = NovynUser.fromMap(session);
      await _prepareAccount(signedInUser.username);
      _user = signedInUser;
      await _persistIdentity(signedInUser);
    } else {
      if (!ApiService.hasPersistedSession) {
        return 'Novyn could not save the secure session. Check your connection and try signing in again.';
      }
      final signedInUser = NovynUser(
        username: result['username'].toString(),
        displayName: result['displayName']?.toString() ??
            result['username'].toString(),
        email: result['email']?.toString() ?? fallbackEmail,
      );
      await _prepareAccount(signedInUser.username);
      _user = signedInUser;
      await _persistIdentity(signedInUser);
    }

    notifyListeners();
    return null;
  }

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
    if (result['requiresTwoFactor'] == true) {
      _pendingTwoFactorChallenge = result['challengeToken']?.toString();
      _pendingTwoFactorUsername = result['username']?.toString();
      if (_pendingTwoFactorChallenge == null || _pendingTwoFactorChallenge!.isEmpty) {
        return 'The server did not create a secure verification challenge.';
      }
      notifyListeners();
      return null;
    }
    if (result['username'] == null) {
      return result['message']?.toString() ?? 'Login failed.';
    }

    final session = await ApiService.getSession();
    if (session != null && session['authenticated'] == true) {
      final signedInUser = NovynUser.fromMap(session);
      await _prepareAccount(signedInUser.username);
      _user = signedInUser;
          await _persistIdentity(signedInUser);
    } else {
      if (!ApiService.hasPersistedSession) {
        return 'Novyn could not save the secure session. Check your connection and try signing in again.';
      }
      final signedInUser = NovynUser(
        username: result['username'].toString(),
        displayName:
            result['displayName']?.toString() ?? result['username'].toString(),
        email: result['email']?.toString() ?? '',
      );
      await _prepareAccount(signedInUser.username);
      _user = signedInUser;
          await _persistIdentity(signedInUser);
    }

    notifyListeners();
    return null; // success
  }

  Future<String?> verifyTwoFactor(String code) async {
    final challenge = _pendingTwoFactorChallenge;
    if (challenge == null) return 'Your verification session has expired. Sign in again.';
    final result = await ApiService.verifyTwoFactor(
      challengeToken: challenge,
      code: code,
    );
    if (result == null) return 'No response from server.';
    if (result['username'] == null) {
      return result['message']?.toString() ?? 'Verification failed.';
    }

    _pendingTwoFactorChallenge = null;
    _pendingTwoFactorUsername = null;
    final session = await ApiService.getSession();
    if (session != null && session['authenticated'] == true) {
      final signedInUser = NovynUser.fromMap(session);
      await _prepareAccount(signedInUser.username);
      _user = signedInUser;
          await _persistIdentity(signedInUser);
    } else {
      if (!ApiService.hasPersistedSession) {
        return 'Novyn could not save the secure session. Check your connection and verify again.';
      }
      final signedInUser = NovynUser(
        username: result['username'].toString(),
        displayName: result['username'].toString(),
        email: result['email']?.toString() ?? '',
      );
      await _prepareAccount(signedInUser.username);
      _user = signedInUser;
          await _persistIdentity(signedInUser);
    }
    notifyListeners();
    return null;
  }

  void cancelTwoFactorChallenge() {
    _pendingTwoFactorChallenge = null;
    _pendingTwoFactorUsername = null;
    notifyListeners();
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
      final signedInUser = NovynUser.fromMap(session);
      await _prepareAccount(signedInUser.username);
      _user = signedInUser;
          await _persistIdentity(signedInUser);
    } else {
      if (!ApiService.hasPersistedSession) {
        return 'Your account was created, but Novyn could not save the secure session. Please sign in again when the connection is stable.';
      }
      final signedInUser = NovynUser(
        username: result['username'].toString(),
        displayName: name,
        email: email,
      );
      await _prepareAccount(signedInUser.username);
      _user = signedInUser;
          await _persistIdentity(signedInUser);
    }

    notifyListeners();
    return null; // success
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _sessionMutationGeneration++;
    _sessionInvalidated = false;
    final username = _user?.username;
    // Persist intent before any async cleanup so killing the app mid-logout
    // cannot restore the previous account on the next launch.
    await _setSignedOutMarker(true);

    // Change the local auth state first. Navigation must never wait on push
    // cleanup, Firebase sign-out, a slow backend or a socket disconnect.
    _user = null;
    _authReady = true;
    notifyListeners();
    unawaited(_clearCachedIdentity());

    if (username != null && clearNotificationsToken != null) {
      try {
        await clearNotificationsToken!(username)
            .timeout(const Duration(seconds: 4));
      } catch (error) {
        debugPrint('[NovynAuth] Push-token cleanup skipped: $error');
      }
    }

    try {
      await onAccountReset?.call().timeout(const Duration(seconds: 4));
    } catch (error) {
      debugPrint('[NovynAuth] Socket cleanup skipped during logout: $error');
    }

    // Firebase is only an identity broker for Google sign-in.
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 4));
      await _firebaseAuth.signOut().timeout(const Duration(seconds: 4));
    } catch (error) {
      debugPrint('[NovynAuth] Firebase cleanup skipped: $error');
    }

    // Revoke remotely when possible, but always erase local session material.
    try {
      await ApiService.logout().timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('[NovynAuth] Remote logout skipped: $error');
    } finally {
      await ApiService.clearSession();
      await _clearCachedIdentity();
    }
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

  /// Offline is the user-facing label for the backend's Invisible mode.
  @visibleForTesting
  static String normalizePresenceMode(String status) {
    final requested = status.trim().toLowerCase();
    return requested == 'offline' ? 'invisible' : requested;
  }

  // ── updateStatus — saves through the shared backend socket ──────────────
  // Screens call auth.updateStatus('Online'|'Away'|'Busy'|'Invisible').
  // Update locally, wait for server confirmation, and undo failed saves.
  Future<void> updateStatus(String status) async {
    final mode = normalizePresenceMode(status);
    if (!['online', 'away', 'busy', 'invisible'].contains(mode)) {
      throw ArgumentError.value(status, 'status', 'Unknown presence mode');
    }
    if (_user == null || (savePresence == null && savePresencePolicy == null)) {
      throw StateError('Sign in and reconnect before changing your status.');
    }
    if (_updatingPresence) return;
    final previous = _user!.presenceMode;
    _updatingPresence = true;
    _user = _user!.copyWith(presenceMode: mode);
    notifyListeners();
    try {
      // Background FCM runs in a separate isolate and cannot read this
      // ChangeNotifier. Persist the selected mode so Busy is respected even
      // when the app is backgrounded or its socket temporarily disconnects.
      final prefs = await SharedPreferences.getInstance();
      final persisted = await prefs.setString('novyn_notification_presence_mode', mode);
      if (!persisted) {
        throw StateError('Your device could not save the selected status.');
      }
      if (savePresencePolicy != null) {
        final policy = presencePolicy?.call(mode) ?? const <String, dynamic>{};
        await savePresencePolicy!(mode, policy);
      } else {
        await savePresence!(mode);
      }
    } catch (_) {
      _user = _user?.copyWith(presenceMode: previous);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('novyn_notification_presence_mode', previous);
      } catch (_) {}
      rethrow;
    } finally {
      _updatingPresence = false;
      notifyListeners();
    }
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
    if (_user == null) return 'Please sign in before changing your password.';
    if (currentPassword.isEmpty && _user!.hasPassword) return 'Enter your current password.';
    if (newPassword.length < 12) {
      return 'Use at least 12 characters in your new password.';
    }
    final change = savePassword;
    if (change == null) {
      return 'Password changes are unavailable. Please restart the app.';
    }
    try {
      await change(currentPassword, newPassword);
      return null;
    } on StateError catch (error) {
      return error.message;
    } catch (e) {
      return 'Could not confirm the password change. Please try again.';
    }
  }

  // ── uploadProfilePicture ──────────────────────────────────────────────────
  Future<String?> uploadProfilePicture(File imageFile) async {
    try {
      final current = _user;
      if (current == null) return 'Please sign in before updating your photo.';

      final extension = path.extension(imageFile.path).toLowerCase();
      const mimeByExtension = <String, String>{
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.webp': 'image/webp',
        '.gif': 'image/gif',
      };
      final mimeType = mimeByExtension[extension];
      if (mimeType == null) {
        return 'This photo format is not supported. Please choose a JPG, PNG or WebP image.';
      }

      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) return 'The selected photo is empty. Please choose another one.';
      final filename = 'avatar_\${DateTime.now().millisecondsSinceEpoch}\$extension';
      final url = await ApiService.uploadMedia(bytes, filename, mimeType);
      if (url == null || url.trim().isEmpty) {
        return 'The server did not return a valid photo URL. Please try again.';
      }

      final saved = await ApiService.updateProfile(
        name: current.displayName,
        bio: current.bio,
        avatarId: url,
      );
      if (saved == null || saved['error'] != null) {
        return saved?['error']?.toString() ?? 'Could not save your profile photo.';
      }
      _user = _user?.copyWith(avatarId: url);
      notifyListeners();
      await refreshProfile();
      return null;
    } catch (e) {
      return e is StateError ? e.message.toString() : 'Photo upload failed: \$e';
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
      email: update['email']?.toString(),
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

  String _friendlyGoogleSignInError(PlatformException e) {
    final code = e.code.toLowerCase();
    final details = e.message ?? '';

    if (code.contains('sign_in_failed') ||
        details.toLowerCase().contains('apiexception') ||
        details.toLowerCase().contains('10:')) {
      return 'Google Sign-In is not configured correctly. In Firebase, add the Android SHA-1 certificate and download the matching google-services.json for the app package used by this build.';
    }

    if (code.contains('network_error')) {
      return 'Google Sign-In could not reach Google. Check your connection and try again.';
    }

    if (code.contains('cancelled')) {
      return 'Sign-in cancelled.';
    }

    return 'Google sign-in failed: ${e.message ?? e.code}';
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
  String get gender => ''; // not stored in this model; stub
  int? get age => null; // not stored in this model; stub
  bool get isOnline => presenceMode != 'invisible' && presenceMode != 'offline';
}
