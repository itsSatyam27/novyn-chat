import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static AuthService? _presenceAuth;
  static SettingsService? _settings;
  static SocketService? _socket;
  static String? _lastSyncedPreferences;
  static bool _syncingPreferences = false;
  static bool? _lastAlertsEnabled;
  static bool? _lastSoundEnabled;

  static void _onSettingsChanged() {
    final enabled = _settings?.notificationsOn ?? false;
    if (_lastAlertsEnabled == false && enabled) {
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
  }

  static Future<void> _syncUserPreferences() async {
    final socket = _socket;
    final settings = _settings;
    if (socket == null || settings == null || !socket.isConnected || _syncingPreferences) return;

    final notificationsEnabled = settings.notificationsOn;
    final messagePreview = notificationsEnabled && settings.messagePreview && !settings.hideNotificationContent;
    final groupNotifications = notificationsEnabled && settings.groupNotifications;
    final signature = '$notificationsEnabled|$messagePreview|$groupNotifications';
    if (_lastSyncedPreferences == signature) return;

    _syncingPreferences = true;
    try {
      final result = await socket.updateAccountSettings({
        'notificationsEnabled': notificationsEnabled,
        'messagePreviewEnabled': messagePreview,
        'groupNotificationsEnabled': groupNotifications,
      });
      if (result['ok'] == true) _lastSyncedPreferences = signature;
    } catch (_) {
      // Retry on the next socket connection or preference change.
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
    _socket!.addListener(_onSocketChanged);
    _presenceAuth?.removeListener(_syncPresentation);
    _presenceAuth = context.read<AuthService>();
    _presenceAuth!.addListener(_syncPresentation);
    _syncPresentation();

    // 2. Ask the OS only when the user has enabled notifications.
    if (_settings!.notificationsOn) {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!context.mounted) return;
    }

    // 3. Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      if (context.mounted) _handleForegroundMessage(message, context);
    });

    // 4. App opened from background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
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
    await _syncUserPreferences();
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
      });

      // Refresh token when it changes
      _fcm.onTokenRefresh.listen((newToken) async {
        await _db.collection('users').doc(uid).update({
          'fcmToken': newToken,
        });
      });
    } catch (_) {}
  }

  // ── Clear token on logout ─────────────────────────────────────────────────
  static Future<void> clearToken(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({'fcmToken': ''});
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
