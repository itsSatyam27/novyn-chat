import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'settings_service.dart';
import 'socket_service.dart';
import 'friend_service.dart';
import '../screens/chats/chat_detail_screen.dart';

// Top-level handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // System handles showing the notification automatically
  // No extra work needed here for basic notifications
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static AuthService? _presenceAuth;
  static SettingsService? _settings;
  static SocketService? _socket;
  static String? _activeUsername;
  static String? _lastRegisteredToken;
  static String? _lastSyncedPreferences;
  static String? _preferencesLoadedForUser;
  static String? _permissionRequestedForUser;
  static bool _syncingPreferences = false;
  static int _preferenceRetryCount = 0;
  static int _tokenRetryCount = 0;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static bool? _lastAlertsEnabled;
  static bool? _lastSoundEnabled;

  static void _onSettingsChanged() {
    final enabled = _settings?.notificationsOn ?? false;
    final username = _activeUsername;
    if (_lastAlertsEnabled == false &&
        enabled &&
        username != null &&
        _permissionRequestedForUser != username) {
      _permissionRequestedForUser = username;
      unawaited(_requestPermission());
    }
    _syncPresentation();
    unawaited(_syncUserPreferences());
  }

  static Future<void> _requestPermission() async {
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {
      // Permission can also be managed from the operating system settings.
    }
  }

  static void _onSocketChanged() {
    unawaited(_syncUserPreferences());
    unawaited(_syncDeviceToken());
  }

  static Future<void> _syncDeviceToken() async {
    final socket = _socket;
    if (socket == null || !socket.isConnected || _activeUsername == null) return;
    try {
      final token = await _fcm.getToken();
      if (token == null || token == _lastRegisteredToken) return;
      final result = await socket.registerFcmToken(token);
      if (result['ok'] == true) {
        _lastRegisteredToken = token;
        _tokenRetryCount = 0;
      } else if (_tokenRetryCount < 1) {
        _tokenRetryCount++;
        Future.delayed(const Duration(seconds: 2), () => unawaited(_syncDeviceToken()));
      }
    } catch (_) {
      // Retry after the socket reconnects.
    }
  }

  static Future<void> _syncUserPreferences() async {
    final socket = _socket;
    final settings = _settings;
    final username = _activeUsername;
    if (socket == null ||
        settings == null ||
        username == null ||
        !socket.isConnected ||
        _syncingPreferences) {
      return;
    }

    _syncingPreferences = true;
    try {
      // Restore account preferences before writing anything from local defaults.
      if (_preferencesLoadedForUser != username) {
        final remote = await socket.fetchAccountSettings();
        if (remote['ok'] != true || remote['settings'] is! Map) {
          throw StateError(remote['message']?.toString() ??
              'Could not load notification preferences.');
        }
        final values = Map<String, dynamic>.from(remote['settings'] as Map);
        await settings.setNotifications(values['notificationsEnabled'] != false);
        await settings.setMessagePreview(values['messagePreviewEnabled'] != false);
        await settings.setGroupNotifications(values['groupNotificationsEnabled'] != false);
        _preferencesLoadedForUser = username;
        if (settings.notificationsOn &&
            _permissionRequestedForUser != username) {
          _permissionRequestedForUser = username;
          await _requestPermission();
        }
      }

      final notificationsEnabled = settings.notificationsOn;
      // Keep child preferences independent of the master switch.
      final messagePreview = settings.messagePreview;
      final groupNotifications = settings.groupNotifications;
      final signature = '$notificationsEnabled|$messagePreview|$groupNotifications';
      if (_lastSyncedPreferences == signature) return;

      final result = await socket.updateAccountSettings({
        'notificationsEnabled': notificationsEnabled,
        'messagePreviewEnabled': messagePreview,
        'groupNotificationsEnabled': groupNotifications,
      });
      if (result['ok'] != true) {
        throw StateError(result['message']?.toString() ??
            'Could not sync notification preferences.');
      }
      _lastSyncedPreferences = signature;
      _preferenceRetryCount = 0;
    } catch (_) {
      if (_preferenceRetryCount < 1) {
        _preferenceRetryCount++;
        Future.delayed(
          const Duration(seconds: 2),
          () => unawaited(_syncUserPreferences()),
        );
      }
    } finally {
      _syncingPreferences = false;
    }
  }

  static void _syncPresentation() {
    final settings = _settings;
    final notificationsEnabled = settings?.notificationsOn ?? true;
    final soundsEnabled = settings?.inAppSounds ?? true;
    final soundEnabled = notificationsEnabled && soundsEnabled && _presenceAuth?.user?.presenceMode != 'busy';
    if (_lastAlertsEnabled == notificationsEnabled && _lastSoundEnabled == soundEnabled) return;
    _lastAlertsEnabled = notificationsEnabled;
    _lastSoundEnabled = soundEnabled;
    _fcm
        .setForegroundNotificationPresentationOptions(
          alert: notificationsEnabled,
          badge: notificationsEnabled,
          sound: soundEnabled,
        )
        .catchError((Object _) {});
  }

  // ── Initialize ────────────────────────────────────────────────────────────
  static Future<void> init(BuildContext context) async {
    if (!context.mounted) return;

    // 1. Bind local preferences before requesting permission.
    _settings?.removeListener(_onSettingsChanged);
    _settings = context.read<SettingsService>();
    _settings!.addListener(_onSettingsChanged);
    _socket?.removeListener(_onSocketChanged);
    _socket = context.read<SocketService>();
    _lastSyncedPreferences = null;
    _socket!.addListener(_onSocketChanged);
    _presenceAuth?.removeListener(_syncPresentation);
    _presenceAuth = context.read<AuthService>();
    _presenceAuth!.addListener(_syncPresentation);
    _syncPresentation();

    // Permission is requested after server preferences are restored on sign-in.

    // 2. Handle foreground messages and notification taps once per app session.
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (context.mounted) _handleForegroundMessage(message, context);
    });

    // 4. App opened from background notification tap
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (context.mounted) unawaited(_handleNotificationTap(message, context));
    });

    // 5. App opened from terminated state
    final initial = await _fcm.getInitialMessage();
    if (initial != null && context.mounted) {
      unawaited(_handleNotificationTap(initial, context));
    }
  }

  // ── Save FCM token for a user ─────────────────────────────────────────────
  static Future<void> saveTokenForUser(String uid) async {
    if (_activeUsername != uid) {
      _lastSyncedPreferences = null;
      _preferencesLoadedForUser = null;
      _permissionRequestedForUser = null;
      _lastRegisteredToken = null;
    }
    _activeUsername = uid;
    await _syncUserPreferences();
    if (_preferencesLoadedForUser == uid &&
        (_settings?.notificationsOn ?? false) &&
        _permissionRequestedForUser != uid) {
      _permissionRequestedForUser = uid;
      await _requestPermission();
    }
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _fcm.onTokenRefresh.listen((_) {
      _lastRegisteredToken = null;
      unawaited(_syncDeviceToken());
    });
    await _syncDeviceToken();
  }

  // ── Clear token on logout ─────────────────────────────────────────────────
  static Future<void> clearToken(String uid) async {
    if (_activeUsername != null && _activeUsername != uid) return;
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
    if (_socket?.isConnected == true) {
      try {
        await _socket!.clearFcmToken();
      } catch (_) {}
    }
    _activeUsername = null;
    _lastRegisteredToken = null;
    _lastSyncedPreferences = null;
    _preferencesLoadedForUser = null;
    _permissionRequestedForUser = null;
    _tokenRetryCount = 0;
    _preferenceRetryCount = 0;
    _settings?.removeListener(_onSettingsChanged);
    _socket?.removeListener(_onSocketChanged);
    _presenceAuth?.removeListener(_syncPresentation);
    _settings = null;
    _socket = null;
    _presenceAuth = null;
    _lastAlertsEnabled = null;
    _lastSoundEnabled = null;
    try {
      await _fcm.deleteToken();
    } catch (_) {}
  }

  // ── Handle foreground message ─────────────────────────────────────────────
  static void _handleForegroundMessage(
      RemoteMessage message, BuildContext context) {
    final type = message.data['type'];

    // For calls in foreground — Socket.IO already handles showing the call screen
    // For messages in foreground — Socket.IO already shows in-app
    // Nothing extra needed here
    if (type == 'call') {
      // Socket.IO handles this when app is open
    }
  }

  // ── Handle notification tap ───────────────────────────────────────────────
  static Future<void> _handleNotificationTap(
      RemoteMessage message, BuildContext context) async {
    final type = message.data['type'];

    if (type == 'call') {
      // Socket.IO reconnects after launch; the call invite handler owns call routing.
      return;
    }

    if (type != 'message' || message.data['kind'] == 'group') return;
    final username = message.data['chat']?.toString().trim() ?? '';
    if (username.isEmpty || !context.mounted) return;

    try {
      final peer = await context.read<FriendService>().getUser(username);
      if (peer == null || !context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatDetailScreen(peer: peer)),
      );
    } catch (_) {
      // A failed profile lookup should not interrupt app startup.
    }
  }

  // ── Get current token ─────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}
