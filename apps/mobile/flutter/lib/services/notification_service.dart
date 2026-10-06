import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

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
  static bool? _muted;

  static void _syncPresentation() {
    final muted = _presenceAuth?.user?.presenceMode == 'busy';
    if (_muted == muted) return;
    _muted = muted;
    _fcm
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: !muted,
        )
        .catchError((Object _) {});
  }

  // ── Initialize ────────────────────────────────────────────────────────────
  static Future<void> init(BuildContext context) async {
    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied || !context.mounted) return;

    // 2. Set foreground notification presentation (iOS)
    _presenceAuth?.removeListener(_syncPresentation);
    _presenceAuth = context.read<AuthService>();
    _presenceAuth!.addListener(_syncPresentation);
    _syncPresentation();

    // 3. Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      if (context.mounted) _handleForegroundMessage(message, context);
    });

    // 4. App opened from background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (context.mounted) _handleNotificationTap(message, context);
    });

    // 5. App opened from terminated state
    final initial = await _fcm.getInitialMessage();
    if (initial != null && context.mounted) {
      _handleNotificationTap(initial, context);
    }
  }

  // ── Save FCM token for a user ─────────────────────────────────────────────
  static Future<void> saveTokenForUser(String uid) async {
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
  static void _handleNotificationTap(
      RemoteMessage message, BuildContext context) {
    final type = message.data['type'];

    if (type == 'call') {
      // When user taps the call notification from terminated/background state
      // The app opens and Socket.IO reconnects — call screen shown via socket event
      // For a better UX you could navigate directly here using the callerId from data
    }

    if (type == 'message') {
      // Could navigate to the specific chat here
    }
  }

  // ── Get current token ─────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}
