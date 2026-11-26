import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:shared_preferences/shared_preferences.dart';
import 'message_encryption_service.dart';
import 'firebase_configuration.dart';
import '../models/chat_models.dart';
import '../models/user_model.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'settings_service.dart';
import 'socket_service.dart';
import 'friend_service.dart';
import '../screens/chats/chat_detail_screen.dart';
import '../screens/calls/calls_screen.dart';
import '../screens/calls/call_screen.dart';
import '../screens/calls/group_call_screen.dart';
import '../widgets/user_avatar.dart';

int _callNotificationId(String callId) {
  var hash = 0x811c9dc5;
  for (final unit in callId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

DateTime? _callExpiryFromData(Map<String, dynamic> data) {
  final raw = data['callExpiresAt']?.toString();
  final milliseconds = int.tryParse(raw ?? '');
  if (milliseconds == null || milliseconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

const _incomingCallActions = <AndroidNotificationAction>[
  AndroidNotificationAction(
    'incoming_call_answer',
    'Answer',
    showsUserInterface: true,
    cancelNotification: true,
  ),
  AndroidNotificationAction(
    'incoming_call_decline',
    'Decline',
    showsUserInterface: true,
    cancelNotification: true,
  ),
];


bool _preferenceEnabled(SharedPreferences prefs, String key) =>
    prefs.getBool(key) ?? true;

bool _isQuietHoursActiveFromPrefs(SharedPreferences prefs, [DateTime? now]) {
  if (prefs.getBool('notification_quiet_hours_enabled') != true) return false;
  final start = prefs.getString('notification_quiet_hours_start') ?? '22:00';
  final end = prefs.getString('notification_quiet_hours_end') ?? '07:00';
  final pattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  if (!pattern.hasMatch(start) || !pattern.hasMatch(end) || start == end) {
    return false;
  }
  int minutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
  final offset = prefs.getInt('notification_quiet_hours_offset') ??
      (now ?? DateTime.now()).timeZoneOffset.inMinutes;
  final local = (now ?? DateTime.now()).toUtc().add(Duration(minutes: offset));
  final current = local.hour * 60 + local.minute;
  final from = minutes(start);
  final until = minutes(end);
  return from < until
      ? current >= from && current < until
      : current >= from || current < until;
}

bool _canDisplayNotification(
  SharedPreferences prefs,
  String type, {
  bool isGroup = false,
  bool mentionOrReply = false,
}) {
  if (!(prefs.getBool('notifications_on') ?? true)) return false;
  switch (type) {
    case 'message':
      if (mentionOrReply) {
        if (!_preferenceEnabled(prefs, 'notification_mentions_replies')) return false;
      } else if (isGroup) {
        if (!_preferenceEnabled(prefs, 'notification_group_messages')) return false;
      } else if (!_preferenceEnabled(prefs, 'notification_direct_messages')) {
        return false;
      }
      break;
    case 'friend_request':
    case 'friend_request_declined':
      if (!_preferenceEnabled(prefs, 'notification_friend_requests')) return false;
      break;
    case 'friend_request_accepted':
      if (!_preferenceEnabled(prefs, 'notification_friend_request_accepted')) return false;
      break;
    case 'group_invite':
      if (!_preferenceEnabled(prefs, 'notification_group_invitations')) return false;
      break;
    case 'call':
      break; // Calls intentionally remain available during quiet hours.
    case 'game_invitation':
      if (!_preferenceEnabled(prefs, 'notification_game_invitations')) return false;
      break;
    case 'game_turn':
      if (!_preferenceEnabled(prefs, 'notification_game_turn')) return false;
      break;
    case 'game_result':
      if (!_preferenceEnabled(prefs, 'notification_game_results')) return false;
      break;
  }
  if (type != 'call' && _isQuietHoursActiveFromPrefs(prefs)) return false;
  return true;
}

String _notificationChannelVariant(
  String base,
  bool sound,
  bool vibration,
) => base + '_' + (sound ? 'sound' : 'silent') + '_' +
    (vibration ? 'vibrate' : 'no_vibrate');

// Top-level handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: FirebaseConfiguration.options);
  ui.DartPluginRegistrant.ensureInitialized();
  final data = message.data;
  if (data['type'] == 'call') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final callStatus = data['callStatus']?.toString() ?? 'missed';
    final recipient = data['recipient']?.toString().trim().toLowerCase() ?? '';
    final notificationAccount =
        (prefs.getString('novyn_notification_account') ?? '')
            .trim()
            .toLowerCase();
    if (recipient.isNotEmpty && recipient != notificationAccount) {
      debugPrint(
          '[NovynNotifications] Ignored call alert for another account.');
      return;
    }
    final alertCaller = data['chat']?.toString().trim().toLowerCase() ?? '';
    if (callStatus == 'missed' &&
        notificationAccount.isNotEmpty &&
        alertCaller == notificationAccount) {
      debugPrint(
          '[NovynNotifications] Ignored a missed-call alert for the caller account.');
      return;
    }
    final isIncoming = callStatus == 'incoming';
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
      iOS: DarwinInitializationSettings(),
    ));
    final caller = data['chat']?.toString() ?? 'Novyn contact';
    final callId = data['callId']?.toString() ?? '';
    final callExpiresAt = _callExpiryFromData(data);
    if (callStatus == 'ended') {
      if (callId.isNotEmpty) await plugin.cancel(_callNotificationId(callId));
      return;
    }
    if (isIncoming && callExpiresAt != null &&
        !callExpiresAt.isAfter(DateTime.now())) return;
    if (!(prefs.getBool('notifications_on') ?? true)) return;
    final presenceMode =
        (prefs.getString('active_smart_presence_mode_v1') ?? 'online')
            .toLowerCase();
    if (presenceMode == 'busy' || presenceMode == 'invisible') return;
    final dndEnabled = prefs.getBool('do_not_disturb_enabled') ?? false;
    final favoriteIds = (prefs.getStringList('favorite_chat_ids') ?? [])
        .map((value) => value.toLowerCase())
        .toSet();
    if (dndEnabled && !favoriteIds.contains(caller.trim().toLowerCase()))
      return;
    final isVideo = data['isVideo']?.toString() == '1' ||
        data['isVideo']?.toString().toLowerCase() == 'true';
    if (!_preferenceEnabled(
      prefs,
      isIncoming
          ? (isVideo ? 'notification_video_calls' : 'notification_voice_calls')
          : 'notification_missed_calls',
    )) return;
    final sound = _preferenceEnabled(prefs, 'notification_sound_enabled');
    final vibration = _preferenceEnabled(prefs, 'notification_vibration_enabled');
    final channelId = _notificationChannelVariant(
      isIncoming ? 'novyn_incoming_calls' : 'novyn_calls',
      sound,
      vibration,
    );
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      isIncoming ? 'Incoming calls' : 'Missed calls',
      description: 'Voice and video call alerts',
      importance: Importance.max,
      playSound: sound,
      enableVibration: vibration,
    ));
    final incomingTimeoutMs = callExpiresAt == null
        ? 45000
        : callExpiresAt.difference(DateTime.now()).inMilliseconds.clamp(1, 45000).toInt();
    final title = data['title']?.toString() ??
        (isIncoming
            ? (isVideo ? 'Incoming video call' : 'Incoming voice call')
            : 'Missed call');
    final body = data['body']?.toString() ??
        (isIncoming
            ? caller + ' is calling you'
            : 'You missed a call from ' + caller);
    await plugin.show(
        _callNotificationId(callId),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
              channelId,
              isIncoming ? 'Incoming calls' : 'Missed calls',
              channelDescription: 'Voice and video call alerts',
              importance: Importance.max,
              priority: Priority.max,
              category: isIncoming
                  ? AndroidNotificationCategory.call
                  : AndroidNotificationCategory.missedCall,
              fullScreenIntent: isIncoming,
              ongoing: isIncoming,
              autoCancel: !isIncoming,
              timeoutAfter: isIncoming ? incomingTimeoutMs : null,
              actions: isIncoming ? _incomingCallActions : const [],
              playSound: sound,
              enableVibration: vibration,
              icon: '@drawable/novyn_wings_icon'),
          iOS: DarwinNotificationDetails(
              presentAlert: true, presentBadge: true, presentSound: sound),
        ),
        payload: data['groupCall']?.toString().toLowerCase() == 'true'
            ? 'groupcall:' + callId + '|' +
                (data['groupCallId']?.toString() ?? '') + '|' + caller + '|' +
                (isVideo ? '1' : '0') + '|' +
                (callExpiresAt?.millisecondsSinceEpoch.toString() ?? '')
            : 'call:' + callId + '|' + caller + '|' +
                (isVideo ? '1' : '0') + '|' +
                (callExpiresAt?.millisecondsSinceEpoch.toString() ?? ''));
    return;
  }
  final notificationType = data['type']?.toString() ?? '';
  if (notificationType == 'friend_request' ||
      notificationType == 'friend_request_accepted' ||
      notificationType == 'friend_request_declined' ||
      notificationType == 'group_invite') {
    await NotificationService.showSocialNotification(data);
    return;
  }
  if (notificationType == 'game_invitation' ||
      notificationType == 'game_turn' ||
      notificationType == 'game_result') {
    await NotificationService.showGameNotification(data);
    return;
  }
  if (notificationType != 'message') return;

  final prefs = await SharedPreferences.getInstance();
  // Background FCM runs in its own isolate; refresh the plugin cache before
  // reading account and preview preferences written by the foreground isolate.
  await prefs.reload();
  // FCM retries or duplicate server transports can repeat a message. Persist a
  // short message-ID dedupe window so only one local notification is posted.
  final backgroundMessageId =
      (data['messageId']?.toString().trim().isNotEmpty == true)
          ? data['messageId'].toString().trim()
          : (message.messageId?.trim() ?? '');
  if (backgroundMessageId.isNotEmpty) {
    final dedupeKey = 'novyn_notif_seen_$backgroundMessageId';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final seenAt = prefs.getInt(dedupeKey) ?? 0;
    if (seenAt > 0 && nowMs - seenAt < 60000) {
      debugPrint('[NovynNotifications] Suppressed duplicate background message.');
      return;
    }
    await prefs.setInt(dedupeKey, nowMs);
  }
  final notificationsEnabled = prefs.getBool('notifications_on') ?? true;
  final presenceMode =
      (prefs.getString('active_smart_presence_mode_v1') ?? 'online')
          .toLowerCase();
  if (!notificationsEnabled ||
      presenceMode == 'busy' ||
      presenceMode == 'invisible') return;
  final isGroup = data['kind'] == 'group';
  final mentionOrReply = data['mentionOrReply']?.toString() == '1' ||
      data['mentionOrReply']?.toString().toLowerCase() == 'true';
  if (!_canDisplayNotification(
    prefs,
    notificationType,
    isGroup: isGroup,
    mentionOrReply: mentionOrReply,
  )) return;
  // Resolve and validate the recipient account before reading account-scoped
  // archive preferences or attempting E2EE decryption.
  final storedNotificationAccount =
      (prefs.getString('novyn_notification_account') ?? '').trim().toLowerCase();
  final pushRecipient = data['recipient']?.toString().trim().toLowerCase() ?? '';
  if (storedNotificationAccount.isNotEmpty &&
      pushRecipient.isNotEmpty &&
      storedNotificationAccount != pushRecipient) {
    debugPrint(
        '[NovynNotifications] Ignored message push for a different signed-in account.');
    return;
  }
  // The recipient in the signed FCM payload is bound to this registered device
  // token. Use it only when the local account marker is absent.
  final notificationAccount = storedNotificationAccount.isNotEmpty
      ? storedNotificationAccount
      : pushRecipient;
  if (notificationAccount.isNotEmpty && storedNotificationAccount.isEmpty) {
    await prefs.setString('novyn_notification_account', notificationAccount);
  }

  // Keep honoring explicit silent pushes and account-scoped chat preferences.
  final sender = (data['chat'] ?? '').toString().trim();
  final archivedChats =
      (prefs.getStringList('novyn_archived_$notificationAccount') ?? [])
          .map((value) => value.trim().toLowerCase())
          .toSet();
  if (archivedChats.contains(sender.toLowerCase())) return;
  if (prefs.getBool('novyn_mute_${sender.toLowerCase()}') == true) return;
  final dndEnabled = prefs.getBool('do_not_disturb_enabled') ?? false;
  final favoriteIds = (prefs.getStringList('favorite_chat_ids') ?? [])
      .map((value) => value.toLowerCase())
      .toSet();
  if (dndEnabled && !favoriteIds.contains(sender.toLowerCase())) return;
  if (data['silent']?.toString().toLowerCase() == 'true' ||
      data['silent']?.toString() == '1') {
    debugPrint(
        '[NovynNotifications] Message alert suppressed by a silent push.');
    return;
  }

  // Respect both the locally persisted preference and the server-side value
  // carried with encrypted pushes; either can disable previews.
  final previewEnabled = (prefs.getBool('message_preview') ?? true) &&
      data['previewEnabled']?.toString() != '0';
  final hideContent = prefs.getBool('hide_notification_content') ?? false;
  if (sender.isEmpty) {
    debugPrint(
        '[NovynNotifications] Background message has no sender chat id.');
    return;
  }

  var body = isGroup ? 'New group message' : 'You have a new message';
  if (previewEnabled && !hideContent) {
    // Plaintext Flutter messages carry a safe preview in the FCM data payload.
    // Older encrypted messages still use the legacy local decryption path below.
    final plaintextPreview = data['body']?.toString().trim() ?? '';
    if (plaintextPreview.isNotEmpty &&
        plaintextPreview != 'You have a new message' &&
        plaintextPreview != 'New message') {
      body = plaintextPreview;
    }
  }
  if (previewEnabled && !hideContent && notificationAccount.isNotEmpty && !isGroup) {
    final ciphertext = data['ciphertext']?.toString() ?? '';
    final iv = data['iv']?.toString() ?? '';
    final peerKey = data['senderPublicKey']?.toString() ?? '';
    if (ciphertext.isNotEmpty && iv.isNotEmpty && peerKey.isNotEmpty) {
      try {
        final encrypted = Message(
          id: data['messageId']?.toString() ?? 'notification',
          text: '🔒 Encrypted message',
          isFromMe: false,
          chatId: sender,
          senderId: sender,
          isEncrypted: true,
          ciphertext: ciphertext,
          iv: iv,
        );
        final encryption = MessageEncryptionService();
        Message decrypted;
        // Android may schedule the FCM isolate while the app process is gone.
        // Give the keystore-backed identity a short bounded warm-up window.
        final retryDelays = <int>[350, 700, 1200];
        Object? lastDecryptError;
        while (true) {
          try {
            decrypted = await encryption.decryptForNotification(
              encrypted,
              notificationAccount,
              peerKey,
            );
            lastDecryptError = null;
            break;
          } catch (error) {
            lastDecryptError = error;
            if (retryDelays.isEmpty) rethrow;
            final delay = retryDelays.first;
            retryDelays.removeAt(0);
            await Future<void>.delayed(Duration(milliseconds: delay));
          }
        }
        if (!decrypted.needsMessageKey &&
            decrypted.text != '🔒 Encrypted message' &&
            decrypted.text.trim().isNotEmpty) {
          body = decrypted.text.trim();
          await prefs.remove('novyn_notification_preview_last_failure');
          debugPrint(
              '[NovynNotifications] Background E2EE preview decrypted locally.');
        } else {
          throw lastDecryptError ??
              StateError('Background E2EE preview remained encrypted.');
        }
      } catch (error) {
        final failureCode = error is StateError
            ? 'local_identity_or_conversation_key_unavailable'
            : error is FormatException
                ? 'invalid_encryption_envelope'
                : error.runtimeType.toString();
        await prefs.setString(
          'novyn_notification_preview_last_failure',
          failureCode,
        );
        await prefs.setInt(
          'novyn_notification_preview_last_failure_at',
          DateTime.now().millisecondsSinceEpoch,
        );
        debugPrint(
          '[NovynNotifications] Background E2EE preview could not be decrypted '
          'locally ($failureCode). The notification remains private.');
        // Never expose ciphertext or server-side plaintext as a fallback.
      }
    } else {
      debugPrint(
          '[NovynNotifications] Encrypted push is missing preview key material (ciphertext: ${ciphertext.isNotEmpty}, iv: ${iv.isNotEmpty}, sender key: ${peerKey.isNotEmpty}, account: ${notificationAccount.isNotEmpty}).');
    }
  } else {
    debugPrint(
        '[NovynNotifications] Message preview is disabled or content is hidden.');
  }

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
    iOS: DarwinInitializationSettings(),
  ));
  final sound = _preferenceEnabled(prefs, 'notification_sound_enabled');
  final vibration = _preferenceEnabled(prefs, 'notification_vibration_enabled');
  final channelId = _notificationChannelVariant('novyn_messages', sound, vibration);
  final channel = AndroidNotificationChannel(
    channelId,
    isGroup ? 'Group messages' : 'Direct messages',
    description: 'New messages from your Novyn conversations',
    importance: Importance.max,
    playSound: sound,
    enableVibration: vibration,
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  final timestamp = DateTime.now();
  final senderPerson = fln.Person(name: sender, key: sender);
  final mePerson = fln.Person(name: 'You', key: notificationAccount);
  await plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    sender,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        isGroup ? 'Group messages' : 'Direct messages',
        channelDescription: 'New messages from your Novyn conversations',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        styleInformation: fln.MessagingStyleInformation(
          mePerson,
          messages: [fln.Message(body, timestamp, senderPerson)],
          groupConversation: isGroup,
        ),
        playSound: sound,
        enableVibration: vibration,
        icon: '@drawable/novyn_wings_icon',
        ticker: '$sender: $body',
        onlyAlertOnce: false,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: sound,
      ),
    ),
    payload: isGroup ? 'group:$sender' : sender,
  );
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const String _messageChannelId = 'novyn_messages';
  static const String _messageChannelName = 'Messages';
  static bool _localNotificationsReady = false;
  static final Map<int, Timer> _callReminderTimers = {};
  static OverlayEntry? _inAppBannerEntry;
  static Timer? _inAppBannerTimer;
  // Deduplicate socket-driven banners/system alerts in the foreground when
  // the server or transport briefly repeats the same sender+content event.
  static final Map<String, DateTime> _recentForegroundMessages = <String, DateTime>{};
  static bool _isDuplicateForegroundMessage(String sender, String body) {
    final key = sender.trim().toLowerCase() + '|' + body.trim();
    final now = DateTime.now();
    final previous = _recentForegroundMessages[key];
    _recentForegroundMessages.removeWhere(
      (_, value) => now.difference(value) > const Duration(seconds: 5),
    );
    if (previous != null && now.difference(previous) < const Duration(seconds: 3)) {
      return true;
    }
    _recentForegroundMessages[key] = now;
    return false;
  }
  static AuthService? _presenceAuth;
  static SettingsService? _settings;
  static SocketService? _socket;
  static String? _activeUsername;
  static String? _lastRegisteredToken;
  static String? _lastSyncedPreferences;
  static String? _preferencesLoadedForUser;
  static String? _permissionRequestedForUser;
  static bool _syncingPreferences = false;
  static bool _syncingDeviceToken = false;
  static int _preferenceRetryCount = 0;
  static int _tokenRetryCount = 0;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static bool? _lastAlertsEnabled;
  static bool? _lastSoundEnabled;
  static ValueChanged<String>? _activeCallActionHandler;
  static ValueChanged<String>? _socialNotificationTapHandler;
  static VoidCallback? _groupNotificationTapHandler;
  static final Set<String> _archivedChatNotificationIds = <String>{};
  static const int _activeCallNotificationId = 781204;
  static const int _appUpdateNotificationId = 781205;
  static const int _appUpdateDownloadNotificationId = 781206;
  static ValueChanged<BuildContext>? _appUpdateTapHandler;

  static void setSocialNotificationTapHandler(ValueChanged<String>? handler) {
    _socialNotificationTapHandler = handler;
  }

  static void setGroupNotificationTapHandler(VoidCallback? handler) {
    _groupNotificationTapHandler = handler;
  }

  static void setChatArchivedForNotifications(String chatId, bool archived) {
    final normalizedChatId = chatId.trim().toLowerCase();
    if (normalizedChatId.isEmpty) return;
    if (archived) {
      _archivedChatNotificationIds.add(normalizedChatId);
    } else {
      _archivedChatNotificationIds.remove(normalizedChatId);
    }
    unawaited(_persistArchivedChatsForNotifications());
  }

  static Future<void> _persistArchivedChatsForNotifications() async {
    final account = (_presenceAuth?.user?.username ?? _activeUsername ?? '')
        .trim()
        .toLowerCase();
    if (account.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'novyn_archived_$account',
      _archivedChatNotificationIds.toList()..sort(),
    );
  }

  static void _handleSocialTap(String type) {
    if (type == 'group_invite') {
      _groupNotificationTapHandler?.call();
    } else {
      _socialNotificationTapHandler?.call(type);
    }
  }

  static Future<void> showSocialNotification(Map<String, dynamic> data) async {
    final type = data['type']?.toString() ?? '';
    const supportedTypes = <String>{
      'friend_request',
      'friend_request_accepted',
      'friend_request_declined',
      'group_invite',
    };
    if (!supportedTypes.contains(type)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final account = (prefs.getString('novyn_notification_account') ?? '')
        .trim()
        .toLowerCase();
    final recipient = data['recipient']?.toString().trim().toLowerCase() ?? '';
    if (account.isEmpty || (recipient.isNotEmpty && recipient != account)) return;
    if (!_canDisplayNotification(prefs, type)) return;
    final sender = (data['from']?.toString() ?? data['chat']?.toString() ?? '')
        .trim().toLowerCase();
    final dndEnabled = prefs.getBool('do_not_disturb_enabled') ?? false;
    final favorites = (prefs.getStringList('favorite_chat_ids') ?? [])
        .map((value) => value.trim().toLowerCase())
        .toSet();
    if (dndEnabled && !favorites.contains(sender)) return;
    final presence = (prefs.getString('active_smart_presence_mode_v1') ?? 'online')
        .toLowerCase();
    if (presence == 'busy' || presence == 'invisible') return;

    final sound = _preferenceEnabled(prefs, 'notification_sound_enabled');
    final vibration = _preferenceEnabled(prefs, 'notification_vibration_enabled');
    final channelId = _notificationChannelVariant('novyn_social', sound, vibration);
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
      iOS: DarwinInitializationSettings(),
    ));
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      'Social notifications',
      description: 'Friend requests and group invitations',
      importance: Importance.high,
      playSound: sound,
      enableVibration: vibration,
    ));
    final eventId = data['eventId']?.toString() ??
        (type + ':' + (data['from']?.toString() ?? ''));
    await plugin.show(
      eventId.hashCode,
      data['title']?.toString() ?? 'Novyn',
      data['body']?.toString() ?? 'You have a new notification',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Social notifications',
          channelDescription: 'Friend requests and group invitations',
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          enableVibration: vibration,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: sound,
        ),
      ),
      payload: 'social:' + type,
    );
  }

  static Future<void> showGameNotification(Map<String, dynamic> data) async {
    final type = data['type']?.toString() ?? '';
    if (!const {'game_invitation', 'game_turn', 'game_result'}.contains(type)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final account = (prefs.getString('novyn_notification_account') ?? '')
        .trim()
        .toLowerCase();
    final recipient = data['recipient']?.toString().trim().toLowerCase() ?? '';
    if (account.isEmpty || (recipient.isNotEmpty && recipient != account)) return;

    final isGroup = data['kind']?.toString() == 'group';
    if (!_canDisplayNotification(prefs, type, isGroup: isGroup)) return;
    final presence = (prefs.getString('active_smart_presence_mode_v1') ?? 'online')
        .toLowerCase();
    if (presence == 'busy' || presence == 'invisible') return;

    final chatId = data['chat']?.toString().trim() ?? '';
    if (chatId.isEmpty ||
        prefs.getBool('novyn_mute_' + chatId.toLowerCase()) == true) return;
    final dndEnabled = prefs.getBool('do_not_disturb_enabled') ?? false;
    final favorites = (prefs.getStringList('favorite_chat_ids') ?? [])
        .map((value) => value.toLowerCase()).toSet();
    if (dndEnabled && !favorites.contains(chatId.toLowerCase())) return;

    final sound = _preferenceEnabled(prefs, 'notification_sound_enabled');
    final vibration = _preferenceEnabled(prefs, 'notification_vibration_enabled');
    final channelId = _notificationChannelVariant('novyn_games', sound, vibration);
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
      iOS: DarwinInitializationSettings(),
    ));
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      'Novyn Games',
      description: 'Game invitations, turns and results',
      importance: Importance.high,
      playSound: sound,
      enableVibration: vibration,
    ));
    final eventId = data['eventId']?.toString() ??
        (type + ':' + (data['gameId']?.toString() ?? chatId));
    await plugin.show(
      eventId.hashCode,
      data['title']?.toString() ?? 'Novyn Games',
      data['body']?.toString() ?? 'You have a game notification',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Novyn Games',
          channelDescription: 'Game invitations, turns and results',
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          enableVibration: vibration,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: sound,
        ),
      ),
      payload: 'game:' + (isGroup ? 'group:' : 'friend:') + chatId,
    );
  }

  static void setAppUpdateTapHandler(ValueChanged<BuildContext>? handler) {
    _appUpdateTapHandler = handler;
  }

  static Future<void> showAppUpdateAvailable({
    int? buildNumber,
    bool allowRepeat = false,
  }) async {
    if (!_localNotificationsReady) {
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
          iOS: DarwinInitializationSettings(),
        ),
      );
    }
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_app_updates',
        'App updates',
        description: 'Notifications when a new Novyn version is available',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    final buildText = buildNumber == null ? '' : ' (build $buildNumber)';
    await _localNotifications.show(
      _appUpdateNotificationId,
      'A new Novyn version is available',
      'Novyn$buildText is ready. Tap to open About Novyn and check for updates.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription:
              'Notifications when a new Novyn version is available',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
          onlyAlertOnce: !allowRepeat,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  static Future<void> _ensureUpdateNotificationChannel() async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'novyn_app_updates',
      'App updates',
      description: 'Notifications for Novyn app updates and downloads',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
  }

  static String _formatUpdateBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<void> showUpdateDownloadProgress({
    required int downloadedBytes,
    required int totalBytes,
    required double speedBytesPerSecond,
  }) async {
    await _ensureUpdateNotificationChannel();
    final percent = totalBytes <= 0
        ? 0
        : ((downloadedBytes / totalBytes) * 100).round().clamp(0, 100).toInt();
    final speed = speedBytesPerSecond >= 1024 * 1024
        ? '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s'
        : '${(speedBytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
    await _localNotifications.show(
      _appUpdateDownloadNotificationId,
      'Downloading Novyn update — $percent%',
      '${_formatUpdateBytes(downloadedBytes)} of ${_formatUpdateBytes(totalBytes)} · $speed',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription:
              'Notifications for Novyn app updates and downloads',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@drawable/novyn_wings_icon',
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          onlyAlertOnce: true,
          ongoing: true,
          autoCancel: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: 'app_update',
    );
  }

  static Future<void> showUpdateDownloadComplete() async {
    await _ensureUpdateNotificationChannel();
    await _localNotifications.show(
      _appUpdateDownloadNotificationId,
      'Novyn update downloaded',
      'Tap to open About Novyn and install the update.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription:
              'Notifications for Novyn app updates and downloads',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  static Future<void> showUpdateDownloadPaused({
    required int downloadedBytes,
    required int totalBytes,
    required String message,
  }) async {
    await _ensureUpdateNotificationChannel();
    await _localNotifications.show(
      _appUpdateDownloadNotificationId,
      'Novyn update download paused',
      '$message (${_formatUpdateBytes(downloadedBytes)} of ${_formatUpdateBytes(totalBytes)})',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription:
              'Notifications for Novyn app updates and downloads',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: 'app_update',
    );
  }

  /// Registers the currently visible call screen as the owner of notification
  /// actions. The notification itself stays ongoing while the call is active.
  static void setActiveCallActionHandler(ValueChanged<String>? handler) {
    _activeCallActionHandler = handler;
  }

  static Future<void> clearIncomingCallNotification(String callId) async {
    if (callId.trim().isEmpty) return;
    try {
      await _localNotifications.cancel(_callNotificationId(callId));
    } catch (error) {
      debugPrint('[NovynCalls] Could not clear incoming notification: $error');
    }
  }

  /// Schedules a local reminder while the application process is alive.
  /// Force-stopping the app clears this in-process timer.
  static Future<void> scheduleCallReminder({
    required String caller,
    required Duration delay,
  }) async {
    if (delay <= Duration.zero) return;
    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    _callReminderTimers.remove(id)?.cancel();
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'novyn_call_reminders',
      'Call reminders',
      description: 'Reminders to return calls later',
      importance: Importance.high,
    ));
    _callReminderTimers[id] = Timer(delay, () async {
      _callReminderTimers.remove(id);
      try {
        await _localNotifications.show(
          id,
          'Call $caller back',
          'You asked Novyn to remind you to return this call.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'novyn_call_reminders',
              'Call reminders',
              channelDescription: 'Reminders to return calls later',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@drawable/novyn_wings_icon',
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      } catch (error) {
        debugPrint('[NovynCalls] Could not show call reminder: $error');
      }
    });
  }

  static Future<void> showActiveCallNotification({
    required String callId,
    required String caller,
    required bool isVideo,
    required bool muted,
    required bool speakerOn,
  }) async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'novyn_active_call',
      'Active calls',
      description: 'Controls for ongoing Novyn calls',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    ));
    await _localNotifications.show(
      _activeCallNotificationId,
      isVideo ? 'Video call with $caller' : 'Voice call with $caller',
      'Tap an action to manage your call',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_active_call',
          'Active calls',
          channelDescription: 'Controls for ongoing Novyn calls',
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.call,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'call_toggle_mute',
              muted ? 'Unmute' : 'Mute',
              showsUserInterface: true,
              cancelNotification: false,
            ),
            AndroidNotificationAction(
              'call_toggle_speaker',
              speakerOn ? 'Earpiece' : 'Speaker',
              showsUserInterface: true,
              cancelNotification: false,
            ),
            const AndroidNotificationAction(
              'call_end',
              'End call',
              showsUserInterface: true,
              cancelNotification: false,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: 'active_call:$callId',
    );
  }

  static Future<void> clearActiveCallNotification() async {
    await _localNotifications.cancel(_activeCallNotificationId);
    _activeCallActionHandler = null;
  }

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
    unawaited(_syncBackgroundPreviewPreferences());
    unawaited(_syncUserPreferences());
  }

  static Future<void> _syncBackgroundPreviewPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = _settings;
      if (settings == null) return;
      await prefs.setBool('notifications_on', settings.notificationsOn);
      await prefs.setBool('message_preview', settings.messagePreview);
      await prefs.setBool(
          'hide_notification_content', settings.hideNotificationContent);
      await prefs.setBool(
          'do_not_disturb_enabled', settings.doNotDisturbEnabled);
      await prefs.setStringList('favorite_chat_ids', settings.favoriteChatIds);
      for (final entry in SettingsService.notificationPreferenceStorageKeys.entries) {
        await prefs.setBool(
          entry.value,
          settings.notificationPreference(entry.key),
        );
      }
      await prefs.setString('notification_quiet_hours_start', settings.quietHoursStart);
      await prefs.setString('notification_quiet_hours_end', settings.quietHoursEnd);
      await prefs.setInt(
        'notification_quiet_hours_offset',
        DateTime.now().timeZoneOffset.inMinutes,
      );
      await prefs.setBool('group_notifications', settings.groupNotifications);
      await prefs.setString(
        'novyn_notification_account',
        (_presenceAuth?.user?.username ?? _activeUsername ?? '').trim().toLowerCase(),
      );
    } catch (_) {
      // The foreground preference store remains the source of truth.
    }
  }

  static Future<void> _requestPermission() async {
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Permission can also be managed from the operating system settings.
    }
  }

  static Future<void> _initializeLocalNotifications(
      BuildContext context) async {
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final actionId = response.actionId ?? '';
        if (actionId == 'incoming_call_answer' ||
            actionId == 'incoming_call_decline') {
          unawaited(_handleIncomingCallAction(
            actionId,
            response.payload,
            context,
          ));
          return;
        }
        if (actionId.startsWith('call_')) {
          _activeCallActionHandler?.call(actionId);
          return;
        }
        final payload = response.payload?.trim() ?? '';
        if (!context.mounted || payload.isEmpty) return;
        if (payload == 'app_update') {
          _appUpdateTapHandler?.call(context);
          return;
        }
        if (payload.startsWith('social:')) {
          _handleSocialTap(payload.substring('social:'.length));
          return;
        }
        if (payload.startsWith('game:') || payload.startsWith('group:')) {
          final parts = payload.split(':');
          final isGame = parts.first == 'game';
          final isGroup = isGame ? parts.length >= 3 && parts[1] == 'group' : true;
          final chatId = isGame
              ? (parts.length >= 3 ? parts.sublist(2).join(':') : '')
              : parts.sublist(1).join(':');
          if (chatId.isNotEmpty) {
            unawaited(_openChatFromNotification(chatId, context, isGroup: isGroup));
          }
          return;
        }
        if (payload.startsWith('call:')) {
          final parts = payload.substring(5).split('|');
          if (parts.length >= 3 && parts[0].isNotEmpty) {
            unawaited(_openIncomingCall(
              parts[1],
              parts[0],
              parts[2] == '1',
              context,
              expiresAt: parts.length > 3 ? int.tryParse(parts[3]) : null,
            ));
          } else {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CallsScreen()));
          }
        } else {
          unawaited(_openChatFromNotification(payload, context));
        }
      },
    );
    if (_localNotificationsReady) return;
    const channel = AndroidNotificationChannel(
      _messageChannelId,
      _messageChannelName,
      description: 'New direct messages from your Novyn contacts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    final androidNotifications =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidNotifications?.createNotificationChannel(channel);
    // FCM may display alert payloads directly from Android while the Dart
    // process is stopped. Pre-create every channel ID sent by the backend so
    // the OS never falls back to a low-importance default channel.
    for (final base in const [
      'novyn_messages',
      'novyn_social',
      'novyn_games',
      'novyn_app_updates',
    ]) {
      for (final sound in const [true, false]) {
        for (final vibration in const [true, false]) {
          final id = _notificationChannelVariant(base, sound, vibration);
          final name = base == 'novyn_messages'
              ? 'Messages'
              : base == 'novyn_social'
                  ? 'Social notifications'
                  : base == 'novyn_games'
                      ? 'Novyn Games'
                      : 'App updates';
          await androidNotifications?.createNotificationChannel(
            AndroidNotificationChannel(
              id,
              name,
              description: 'Novyn notifications',
              importance: Importance.max,
              playSound: sound,
              enableVibration: vibration,
            ),
          );
        }
      }
    }
    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_incoming_calls',
        'Incoming calls',
        description: 'Incoming voice and video calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_calls',
        'Missed calls',
        description: 'Missed voice and video calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    // Clear legacy incoming-call alerts created before the 45-second timeout
    // existed. Keep missed-call and message notifications untouched.
    try {
      final active = await _localNotifications.getActiveNotifications();
      for (final notification in active) {
        if (notification.channelId == 'novyn_incoming_calls' &&
            notification.id != null) {
          await _localNotifications.cancel(notification.id!);
        }
      }
    } catch (error) {
      debugPrint('[NovynCalls] Could not clean legacy call alerts: $error');
    }
    _localNotificationsReady = true;
  }

  static Future<void> showInAppMessage(
    String username,
    String messageBody,
    BuildContext context, {
    bool isGroup = false,
    bool mentionOrReply = false,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    if (_isDuplicateForegroundMessage(username, messageBody)) {
      debugPrint('[NovynNotifications] Suppressed duplicate foreground banner.');
      return;
    }
    final chatKey = username.trim().toLowerCase();
    if (!_canDisplayNotification(
      preferences,
      'message',
      isGroup: isGroup,
      mentionOrReply: mentionOrReply,
    ) || preferences.getBool('novyn_mute_' + chatKey) == true) return;
    // Keep the host screen context for navigation. The banner's animated
    // builder context is disposed as soon as the overlay entry is removed.
    final navigationContext = context;
    final settings = _settings;
    if (!context.mounted ||
        settings == null ||
        !settings.notificationsOn ||
        _archivedChatNotificationIds.contains(username.trim().toLowerCase()) ||
        (settings.doNotDisturbEnabled &&
            !settings.favoriteChatIds
                .contains(username.trim().toLowerCase())) ||
        (_presenceAuth?.user?.presenceMode == 'busy' ||
            _presenceAuth?.user?.presenceMode == 'invisible')) {
      return;
    }

    final preview = settings.messagePreview && !settings.hideNotificationContent
        ? messageBody.trim()
        : (isGroup ? 'New group message' : 'You have a new message');
    final senderProfile = isGroup ? null : _socket?.contacts.findUser(username);
    String? groupTitle;
    if (isGroup) {
      for (final conversation in _socket?.conversations ?? const []) {
        if (conversation.isGroup &&
            conversation.chatId.toLowerCase() == chatKey) {
          groupTitle = conversation.peer.name.trim();
          break;
        }
      }
    }
    final title = isGroup
        ? (groupTitle?.isNotEmpty == true ? groupTitle! : 'Group message')
        : (senderProfile?.name.trim().isNotEmpty == true
            ? senderProfile!.name.trim()
            : username);
    // Foreground messages use only this branded in-app banner. The operating
    // system notification is reserved for background/terminated delivery.
    _inAppBannerTimer?.cancel();
    _inAppBannerEntry?.remove();
    _inAppBannerEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null) {
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (overlayContext) {
          final topInset = MediaQuery.paddingOf(overlayContext).top;
          return Positioned(
            top: topInset + 10,
            left: 14,
            right: 14,
            child: TweenAnimationBuilder<Offset>(
              tween: Tween<Offset>(
                begin: const Offset(0, -1.15),
                end: Offset.zero,
              ),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) => FractionalTranslation(
                translation: offset,
                child: child,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    _inAppBannerTimer?.cancel();
                    if (_inAppBannerEntry == entry) {
                      entry.remove();
                      _inAppBannerEntry = null;
                    }
                    if (navigationContext.mounted) {
                      unawaited(_openChatFromNotification(
                        username,
                        navigationContext,
                        isGroup: isGroup,
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF242238)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .14),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: .55),
                              width: 1.5,
                            ),
                          ),
                          child: UserAvatar(
                            name: title,
                            photoUrl: senderProfile?.photoUrl ?? '',
                            radius: 24,
                            fallbackColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                preview.isEmpty ? 'New message' : preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 15,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      _inAppBannerEntry = entry;
      overlay.insert(entry);
      _inAppBannerTimer = Timer(const Duration(seconds: 3), () {
        if (_inAppBannerEntry == entry) {
          entry.remove();
          _inAppBannerEntry = null;
        }
      });
    }
  }

  static void _onSocketChanged() {
    unawaited(_syncUserPreferences());
    unawaited(_syncDeviceToken());
  }

  static Future<void> _syncDeviceToken() async {
    final socket = _socket;
    if (socket == null ||
        !socket.isConnected ||
        !socket.isAuthenticated ||
        _activeUsername == null ||
        _syncingDeviceToken) {
      return;
    }
    _syncingDeviceToken = true;
    try {
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('[NovynNotifications] FCM token is not available yet.');
        if (_tokenRetryCount < 3) {
          _tokenRetryCount++;
          Future.delayed(
              const Duration(seconds: 3), () => unawaited(_syncDeviceToken()));
        }
        return;
      }
      if (token == _lastRegisteredToken) return;
      final result = await socket.registerFcmToken(token);
      if (result['ok'] == true) {
        _lastRegisteredToken = token;
        _tokenRetryCount = 0;
        debugPrint('[NovynNotifications] Device token registered with Novyn.');
      } else {
        debugPrint(
            '[NovynNotifications] Device token registration failed: ${result['message']}');
        if (_tokenRetryCount < 3) {
          _tokenRetryCount++;
          Future.delayed(
              const Duration(seconds: 3), () => unawaited(_syncDeviceToken()));
        }
      }
    } catch (error) {
      debugPrint('[NovynNotifications] Device token sync failed: $error');
      if (_tokenRetryCount < 3) {
        _tokenRetryCount++;
        Future.delayed(
            const Duration(seconds: 3), () => unawaited(_syncDeviceToken()));
      }
    } finally {
      _syncingDeviceToken = false;
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
      // Restore server preferences before any local defaults are uploaded.
      if (_preferencesLoadedForUser != username) {
        final remote = await socket.fetchAccountSettings();
        if (remote['ok'] != true || remote['settings'] is! Map) {
          throw StateError(remote['message']?.toString() ??
              'Could not load notification preferences.');
        }
        final values = Map<String, dynamic>.from(remote['settings'] as Map);
        final activeMode = SettingsService.normalizeSmartPresenceMode(
          _presenceAuth?.user?.presenceMode ?? 'online',
        );
        await settings.hydrateSmartPresenceModeFromServer(activeMode, values);
        await settings.applySmartPresenceLocalPolicy(activeMode);
        await settings.hydrateNotificationPreferencesFromServer(values);
        final mutedValues = values['mutedChats'];
        if (mutedValues is List) {
          final mutedIds = mutedValues
              .map((value) => value.toString().trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toSet();
          final local = await SharedPreferences.getInstance();
          await local.reload();
          const mutePrefix = 'novyn_mute_';
          for (final key in local.getKeys().where((key) => key.startsWith(mutePrefix))) {
            final chatId = key.substring(mutePrefix.length).toLowerCase();
            await local.setBool(key, mutedIds.contains(chatId));
          }
          for (final chatId in mutedIds) {
            await local.setBool(mutePrefix + chatId, true);
          }
        }
        _preferencesLoadedForUser = username;
        await _syncBackgroundPreviewPreferences();
        if (settings.notificationsOn &&
            _permissionRequestedForUser != username) {
          _permissionRequestedForUser = username;
          await _requestPermission();
        }
      }

      final payload = <String, dynamic>{
        'notificationsEnabled': settings.notificationsOn,
        'messagePreviewEnabled': settings.messagePreview,
        'hideNotificationContent': settings.hideNotificationContent,
        'doNotDisturbEnabled': settings.doNotDisturbEnabled,
        'favoriteChatIds': settings.favoriteChatIds,
        'groupNotificationsEnabled': settings.groupNotifications,
        ...settings.notificationPreferencesPayload(),
      };
      payload['groupMessagesEnabled'] =
          settings.notificationPreference('groupMessagesEnabled');
      payload['quietHoursOffsetMinutes'] =
          DateTime.now().timeZoneOffset.inMinutes;
      final signature = payload.entries
          .map((entry) => entry.key + ':' + entry.value.toString())
          .join('|');
      if (_lastSyncedPreferences == signature) return;

      final result = await socket.updateAccountSettings(payload);
      if (result['ok'] != true) {
        throw StateError(result['message']?.toString() ??
            'Could not sync notification preferences.');
      }
      _lastSyncedPreferences = signature;
      _preferenceRetryCount = 0;
      await _syncBackgroundPreviewPreferences();
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
    final soundsEnabled = (settings?.inAppSounds ?? true) &&
        (settings?.notificationPreference('notificationSoundEnabled') ?? true);
    final soundEnabled = notificationsEnabled &&
        soundsEnabled &&
        _presenceAuth?.user?.presenceMode != 'busy';
    if (_lastAlertsEnabled == notificationsEnabled &&
        _lastSoundEnabled == soundEnabled) return;
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
    await _initializeLocalNotifications(context);
    _socket!.onIncomingMessage = (
      username,
      body,
      isGroup,
      mentionOrReply,
    ) {
      if (!context.mounted) return;
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (lifecycleState == AppLifecycleState.paused ||
          lifecycleState == AppLifecycleState.hidden ||
          lifecycleState == AppLifecycleState.detached) {
        // Background alerts are rendered by FCM; showing from both transports
        // creates duplicate notifications when the socket remains connected.
        return;
      }
      if (lifecycleState == AppLifecycleState.resumed) {
        unawaited(showInAppMessage(
          username,
          body,
          context,
          isGroup: isGroup,
          mentionOrReply: mentionOrReply,
        ));
      } else {
        unawaited(_showForegroundMessageNotification(
          username,
          body,
          isGroup: isGroup,
          mentionOrReply: mentionOrReply,
        ));
      }
    };
    _socket!.onGroupCallInvitationCallback = (data) {
      if (!context.mounted) return;
      final preferences = _settings;
      final inviter = data['invitedBy']?.toString().trim() ?? '';
      if (inviter.isEmpty) return;
      if (preferences == null ||
          !preferences.notificationsOn ||
          _presenceAuth?.user?.presenceMode == 'busy' ||
          _presenceAuth?.user?.presenceMode == 'invisible') return;
      if (preferences.doNotDisturbEnabled &&
          !preferences.favoriteChatIds.contains(inviter.toLowerCase())) return;
      unawaited(_openIncomingGroupCall(data, context));
    };
    _socket!.onCallInviteCallback = (data) {
      if (!context.mounted) return;
      final caller = data['from']?.toString().trim() ?? '';
      final callId = data['callId']?.toString().trim() ?? '';
      if (caller.isEmpty || callId.isEmpty) return;
      final preferences = _settings;
      if (preferences == null ||
          !preferences.notificationsOn ||
          _presenceAuth?.user?.presenceMode == 'busy' ||
          _presenceAuth?.user?.presenceMode == 'invisible') return;
      if (preferences.doNotDisturbEnabled &&
          !preferences.favoriteChatIds.contains(caller.toLowerCase())) {
        return;
      }
      // This callback opens the active in-app call UI. The per-category
      // notification preference only suppresses alert delivery, not calls
      // while the app is already connected.
      unawaited(
        _openIncomingCall(
          caller,
          callId,
          data['isVideo'] == true,
          context,
          expiresAt: int.tryParse(data['callExpiresAt']?.toString() ?? ''),
        ),
      );
    };
    _socket!.onAuthenticated = () {
      unawaited(_syncUserPreferences());
      unawaited(_syncDeviceToken());
    };
    if (_socket!.isAuthenticated) {
      unawaited(_syncDeviceToken());
      unawaited(_syncUserPreferences());
    }

    // Permission is requested after server preferences are restored on sign-in.

    // 2. Handle foreground messages and notification taps once per app session.
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (context.mounted) _handleForegroundMessage(message, context);
    });

    // 4. App opened from background notification tap
    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (context.mounted) unawaited(_handleNotificationTap(message, context));
    });

    // 5. App opened from terminated state
    final initial = await _fcm.getInitialMessage();
    if (initial != null && context.mounted) {
      unawaited(_handleNotificationTap(initial, context));
    }
    final localLaunch =
        await _localNotifications.getNotificationAppLaunchDetails();
    final localPayload =
        localLaunch?.notificationResponse?.payload?.trim() ?? '';
    if (localLaunch?.didNotificationLaunchApp == true &&
        localPayload.isNotEmpty &&
        context.mounted) {
      final response = localLaunch?.notificationResponse;
      final actionId = response?.actionId ?? '';
      if (actionId == 'incoming_call_answer' ||
          actionId == 'incoming_call_decline') {
        unawaited(_handleIncomingCallAction(
          actionId,
          localPayload,
          context,
        ));
      } else if (localPayload == 'app_update') {
        _appUpdateTapHandler?.call(context);
      } else if (localPayload.startsWith('social:')) {
        _handleSocialTap(localPayload.substring('social:'.length));
      } else if (localPayload.startsWith('game:') || localPayload.startsWith('group:')) {
        final parts = localPayload.split(':');
        final isGame = parts.first == 'game';
        final isGroup = isGame ? parts.length >= 3 && parts[1] == 'group' : true;
        final chatId = isGame
            ? (parts.length >= 3 ? parts.sublist(2).join(':') : '')
            : parts.sublist(1).join(':');
        if (chatId.isNotEmpty) {
          unawaited(_openChatFromNotification(chatId, context, isGroup: isGroup));
        }
      } else if (localPayload.startsWith('groupcall:')) {
        unawaited(_handleIncomingCallAction(
          actionId == 'incoming_call_decline'
              ? 'incoming_call_decline'
              : 'incoming_call_answer',
          localPayload,
          context,
        ));
      } else if (localPayload.startsWith('call:')) {
        final parts = localPayload.substring(5).split('|');
        if (parts.length >= 3 && parts[0].isNotEmpty) {
          unawaited(
              _openIncomingCall(
            parts[1],
            parts[0],
            parts[2] == '1',
            context,
            expiresAt: parts.length > 3 ? int.tryParse(parts[3]) : null,
          ));
        }
      } else {
        unawaited(_openChatFromNotification(localPayload, context));
      }
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
    final prefs = await SharedPreferences.getInstance();
    _archivedChatNotificationIds
      ..clear()
      ..addAll(
        (prefs.getStringList('novyn_archived_${uid.trim().toLowerCase()}') ??
                [])
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty),
      );
    await prefs.setString('novyn_notification_account', uid);
    await prefs.setBool('notifications_on', _settings?.notificationsOn ?? true);
    await prefs.setBool('message_preview', _settings?.messagePreview ?? true);
    await prefs.setBool('hide_notification_content',
        _settings?.hideNotificationContent ?? false);
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
    if (_socket != null) {
      _socket!.onIncomingMessage = null;
      _socket!.onCallInviteCallback = null;
      _socket!.onAuthenticated = null;
    }
    _inAppBannerTimer?.cancel();
    _inAppBannerEntry?.remove();
    _inAppBannerEntry = null;
    _activeUsername = null;
    _archivedChatNotificationIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('novyn_notification_account');
    _lastRegisteredToken = null;
    _lastSyncedPreferences = null;
    _preferencesLoadedForUser = null;
    _permissionRequestedForUser = null;
    _tokenRetryCount = 0;
    _preferenceRetryCount = 0;
    _syncingDeviceToken = false;
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
    if (type == 'game_invitation' || type == 'game_turn' || type == 'game_result') {
      unawaited(showGameNotification(message.data));
      return;
    }
    if (type == 'friend_request' ||
        type == 'friend_request_accepted' ||
        type == 'friend_request_declined' ||
        type == 'group_invite') {
      unawaited(showSocialNotification(message.data));
      return;
    }
    if (type == 'call') {
      final callStatus = message.data['callStatus']?.toString() ?? 'missed';
      final recipient =
          message.data['recipient']?.toString().trim().toLowerCase() ?? '';
      final notificationAccount =
          (_presenceAuth?.user?.username ?? _activeUsername ?? '')
              .trim()
              .toLowerCase();
      if (recipient.isNotEmpty && recipient != notificationAccount) {
        debugPrint(
            '[NovynNotifications] Ignored foreground call alert for another account.');
        return;
      }
      final alertCaller =
          message.data['chat']?.toString().trim().toLowerCase() ?? '';
      if (callStatus == 'missed' &&
          notificationAccount.isNotEmpty &&
          alertCaller == notificationAccount) {
        debugPrint(
            '[NovynNotifications] Ignored a missed-call alert for the caller account.');
        return;
      }
      final callId = message.data['callId']?.toString() ?? '';
      if (callStatus == 'ended') {
        if (callId.isNotEmpty)
          unawaited(_localNotifications.cancel(_callNotificationId(callId)));
        return;
      }
      if (!(_settings?.notificationsOn ?? false) ||
          _presenceAuth?.user?.presenceMode == 'busy' ||
          _presenceAuth?.user?.presenceMode == 'invisible') return;
      final caller = message.data['chat']?.toString() ?? 'Novyn contact';
      final activeSettings = _settings;
      if (activeSettings?.doNotDisturbEnabled == true &&
          !activeSettings!.favoriteChatIds
              .contains(caller.trim().toLowerCase())) return;
      if (_socket?.isConnected == true && callStatus == 'incoming') return;
      final isIncoming = callStatus == 'incoming';
      final callExpiresAt = _callExpiryFromData(message.data);
      if (isIncoming && callExpiresAt != null &&
          !callExpiresAt.isAfter(DateTime.now())) {
        if (callId.isNotEmpty) {
          unawaited(clearIncomingCallNotification(callId));
        }
        return;
      }
      final isVideo = message.data['isVideo']?.toString() == '1';
      if (isIncoming &&
          !(_settings?.notificationPreference(
                isVideo ? 'videoCallsEnabled' : 'voiceCallsEnabled',
              ) ?? true)) return;
      if (!isIncoming &&
          !(_settings?.notificationPreference('missedCallsEnabled') ?? true)) return;
      final sound = _settings?.notificationPreference('notificationSoundEnabled') ?? true;
      final vibration = _settings?.notificationPreference('notificationVibrationEnabled') ?? true;
      final channelId = _notificationChannelVariant(
        isIncoming ? 'novyn_incoming_calls' : 'novyn_calls',
        sound,
        vibration,
      );
      final android = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      unawaited(android?.createNotificationChannel(AndroidNotificationChannel(
        channelId,
        isIncoming ? 'Incoming calls' : 'Missed calls',
        description: 'Voice and video call alerts',
        importance: Importance.max,
        playSound: sound,
        enableVibration: vibration,
      )) ?? Future<void>.value());
      final incomingTimeoutMs = callExpiresAt == null
          ? 45000
          : callExpiresAt
              .difference(DateTime.now())
              .inMilliseconds
              .clamp(1, 45000)
              .toInt();
      unawaited(_localNotifications.show(
        _callNotificationId(callId),
        message.data['title']?.toString() ??
            (isIncoming
                ? (isVideo ? 'Incoming video call' : 'Incoming voice call')
                : 'Missed call'),
        message.data['body']?.toString() ??
            (isIncoming
                ? caller + ' is calling you'
                : 'You missed a call from ' + caller),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            isIncoming ? 'Incoming calls' : 'Missed calls',
            channelDescription: 'Voice and video call alerts',
            importance: Importance.max,
            priority: Priority.max,
            category: isIncoming
                ? AndroidNotificationCategory.call
                : AndroidNotificationCategory.missedCall,
            fullScreenIntent: isIncoming,
            ongoing: isIncoming,
            autoCancel: !isIncoming,
            timeoutAfter: isIncoming ? incomingTimeoutMs : null,
            actions: isIncoming ? _incomingCallActions : const [],
            playSound: sound,
            enableVibration: vibration,
          ),
          iOS: DarwinNotificationDetails(
              presentAlert: true, presentBadge: true, presentSound: sound),
        ),
        payload: 'call:' + callId + '|' + caller + '|' + (isVideo ? '1' : '0') + '|' + (callExpiresAt?.millisecondsSinceEpoch.toString() ?? ''),
      ));
      return;
    }
    // Prefer the live socket callback; FCM is a fallback for disconnected
    // sockets or app lifecycle states where the socket callback was missed.
    if (type == 'message') {
      // The authenticated socket handles live foreground message events.
      // FCM remains the fallback when the socket has disconnected.
      if (_socket?.isConnected == true) return;
      final username = message.data['chat']?.toString().trim() ?? '';
      if (username.isNotEmpty) {
        final body = message.data['body']?.toString().trim();
        unawaited(_showForegroundMessageNotification(
          username,
          body?.isNotEmpty == true
              ? body!
              : message.notification?.body ?? 'You have a new message',
          isGroup: message.data['kind'] == 'group',
          mentionOrReply: message.data['mentionOrReply']?.toString() == '1' ||
              message.data['mentionOrReply']?.toString().toLowerCase() == 'true',
        ));
      }
    }
  }

  static Future<void> _showForegroundMessageNotification(
    String username,
    String messageBody, {
    bool isGroup = false,
    bool mentionOrReply = false,
  }) async {
    final sender = username.trim();
    if (_isDuplicateForegroundMessage(sender, messageBody)) {
      debugPrint('[NovynNotifications] Suppressed duplicate foreground system alert.');
      return;
    }
    final settings = _settings;
    if (sender.isEmpty || settings == null || !settings.notificationsOn) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    if (!_canDisplayNotification(
      preferences,
      'message',
      isGroup: isGroup,
      mentionOrReply: mentionOrReply,
    )) return;
    if (preferences.getBool('novyn_mute_' + sender.toLowerCase()) == true) return;
    if (_archivedChatNotificationIds.contains(sender.toLowerCase())) return;
    if (settings.doNotDisturbEnabled &&
        !settings.favoriteChatIds.contains(sender.toLowerCase())) return;
    if (_presenceAuth?.user?.presenceMode == 'busy' ||
        _presenceAuth?.user?.presenceMode == 'invisible') return;

    final body = settings.messagePreview && !settings.hideNotificationContent
        ? (messageBody.trim().isNotEmpty
            ? messageBody.trim()
            : (isGroup ? 'New group message' : 'You have a new message'))
        : (isGroup ? 'New group message' : 'You have a new message');
    final sound = settings.notificationPreference('notificationSoundEnabled');
    final vibration = settings.notificationPreference('notificationVibrationEnabled');
    final channelId = _notificationChannelVariant('novyn_messages', sound, vibration);
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(AndroidNotificationChannel(
      channelId,
      isGroup ? 'Group messages' : 'Direct messages',
      description: 'New messages from your Novyn conversations',
      importance: Importance.max,
      playSound: sound,
      enableVibration: vibration,
    ));
    final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
    try {
      await _localNotifications.show(
        notificationId,
        sender,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            isGroup ? 'Group messages' : 'Direct messages',
            channelDescription: 'New messages from your Novyn conversations',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            playSound: sound,
            enableVibration: vibration,
            icon: '@drawable/novyn_wings_icon',
            onlyAlertOnce: false,
            autoCancel: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: sound,
          ),
        ),
        payload: isGroup ? 'group:' + sender : sender,
      );
    } catch (error) {
      debugPrint(
          '[NovynNotifications] Foreground system notification failed: $error');
    }
  }

  // ── Handle notification tap ───────────────────────────────────────────────
  static Future<void> _handleNotificationTap(
      RemoteMessage message, BuildContext context) async {
    final type = message.data['type'];

    if (type == 'group_invite') {
      _handleSocialTap('group_invite');
      return;
    }
    if (type == 'friend_request' ||
        type == 'friend_request_accepted' ||
        type == 'friend_request_declined') {
      _handleSocialTap(type.toString());
      return;
    }

    if (type == 'game_invitation' || type == 'game_turn' || type == 'game_result') {
      final chatId = message.data['chat']?.toString().trim() ?? '';
      if (chatId.isNotEmpty && context.mounted) {
        await _openChatFromNotification(
          chatId,
          context,
          isGroup: message.data['kind'] == 'group',
        );
      }
      return;
    }

    if (type == 'call') {
      if (!context.mounted) return;
      final groupCallId = message.data['groupCallId']?.toString().trim() ?? '';
      if (groupCallId.isNotEmpty ||
          message.data['groupCall']?.toString().toLowerCase() == 'true') {
        await _openIncomingGroupCall({
          'groupCallId': groupCallId,
          'callId': message.data['callId']?.toString() ?? '',
          'isVideo': message.data['isVideo']?.toString() == '1' ||
              message.data['isVideo']?.toString().toLowerCase() == 'true',
          'invitedBy': message.data['chat']?.toString() ?? '',
          'invitedByDisplayName': message.data['body']?.toString() ?? 'A contact',
          'expiresAt': message.data['callExpiresAt']?.toString() ?? '',
        }, context);
        return;
      }
      final caller = message.data['chat']?.toString().trim() ?? '';
      final callId = message.data['callId']?.toString().trim() ?? '';
      if (message.data['callStatus'] == 'incoming' &&
          caller.isNotEmpty &&
          callId.isNotEmpty) {
        final expiry = _callExpiryFromData(message.data);
        await _openIncomingCall(
          caller,
          callId,
          message.data['isVideo'] == '1',
          context,
          expiresAt: expiry?.millisecondsSinceEpoch,
        );
        return;
      }
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CallsScreen()));
      return;
    }

    if (type != 'message') return;
    final username = message.data['chat']?.toString().trim() ?? '';
    if (username.isEmpty || !context.mounted) return;

    await _openChatFromNotification(
      username,
      context,
      isGroup: message.data['kind'] == 'group',
    );
  }

  static final Set<String> _openingCallIds = <String>{};
  static final Set<String> _openingGroupCallIds = <String>{};

  static Future<void> _openIncomingGroupCall(
    Map invitation,
    BuildContext context, {
    bool autoAccept = false,
  }) async {
    final groupCallId = invitation['groupCallId']?.toString().trim() ?? '';
    final callId = invitation['callId']?.toString().trim() ?? '';
    final inviter = invitation['invitedBy']?.toString().trim() ??
        invitation['from']?.toString().trim() ?? '';
    if (groupCallId.isEmpty || inviter.isEmpty || !context.mounted ||
        !_openingGroupCallIds.add(groupCallId)) return;

    try {
      final expiresAt = int.tryParse(invitation['expiresAt']?.toString() ??
          invitation['callExpiresAt']?.toString() ?? '');
      if (expiresAt != null && expiresAt <= DateTime.now().millisecondsSinceEpoch) {
        await context.read<SocketService>().declineGroupCall(groupCallId);
        return;
      }
      if (!autoAccept) {
        final inviterName = invitation['invitedByDisplayName']?.toString() ??
            invitation['fromDisplayName']?.toString() ?? inviter;
        final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Group call invitation'),
            content: Text(inviterName + ' invited you to a ' +
                (invitation['isVideo'] == true ? 'video' : 'voice') +
                ' call. Join the conversation?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Decline'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Join call'),
              ),
            ],
          ),
        );
        if (!context.mounted) return;
        if (accepted != true) {
          await context.read<SocketService>().declineGroupCall(groupCallId);
          return;
        }
      }

      final socket = context.read<SocketService>();
      final result = await socket.acceptGroupCall(groupCallId);
      if (!context.mounted) {
        if (result['ok'] == true) {
          await socket.leaveGroupCall(groupCallId);
        }
        return;
      }
      if (result['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ??
                'This group call is no longer available.'),
          ),
        );
        return;
      }
      if (callId.isNotEmpty) {
        await clearIncomingCallNotification(callId);
      }
      final raw = result['participants'];
      final participants = raw is List
          ? raw.whereType<Map>()
              .map((person) => Map<String, dynamic>.from(person))
              .toList()
          : <Map<String, dynamic>>[];
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => GroupCallScreen(
          groupCallId: groupCallId,
          callId: callId.isNotEmpty
              ? callId
              : (result['callId']?.toString() ?? ''),
          isVideo: invitation['isVideo'] == true || result['isVideo'] == true,
          participants: participants,
          initialMediaStates: result['mediaStates'] is Map
              ? Map<String, dynamic>.from(result['mediaStates'] as Map)
              : const <String, dynamic>{},
          initialScreenSharer: result['screenSharer']?.toString(),
          initialScreenStreamId: result['screenStreamId']?.toString(),
        ),
      ));
    } catch (error) {
      debugPrint('[NovynCalls] Could not join group call: $error');
    } finally {
      _openingGroupCallIds.remove(groupCallId);
    }
  }

  static Future<void> _handleIncomingCallAction(
    String actionId,
    String? rawPayload,
    BuildContext context,
  ) async {
    final payload = rawPayload?.trim() ?? '';
    if (!context.mounted) return;
    if (payload.startsWith('groupcall:')) {
      final parts = payload.substring('groupcall:'.length).split('|');
      if (parts.length < 4 || parts[0].isEmpty || parts[1].isEmpty) return;
      final callId = parts[0];
      final groupCallId = parts[1];
      if (actionId == 'incoming_call_decline') {
        await context.read<SocketService>().declineGroupCall(groupCallId);
        return;
      }
      await _openIncomingGroupCall({
        'callId': callId,
        'groupCallId': groupCallId,
        'invitedBy': parts[2],
        'isVideo': parts[3] == '1',
        if (parts.length > 4) 'expiresAt': parts[4],
      }, context, autoAccept: true);
      return;
    }
    if (!payload.startsWith('call:')) return;
    final parts = payload.substring(5).split('|');
    if (parts.length < 3 || parts[0].isEmpty || parts[1].isEmpty) return;
    final callId = parts[0];
    final caller = parts[1];
    final isVideo = parts[2] == '1';
    final expiresAt = parts.length > 3 ? int.tryParse(parts[3]) : null;
    await clearIncomingCallNotification(callId);
    if (expiresAt != null && expiresAt <= DateTime.now().millisecondsSinceEpoch) {
      return;
    }

    final socket = _socket;
    for (var attempt = 0;
        attempt < 60 &&
            !(socket?.isConnected == true && socket?.isAuthenticated == true);
        attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!context.mounted) return;
    }
    if (socket?.isConnected != true || socket?.isAuthenticated != true) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not connect to answer this call.')),
        );
      }
      return;
    }

    if (actionId == 'incoming_call_decline') {
      socket!.rejectCall(caller, callId);
      return;
    }
    await _openIncomingCall(
      caller,
      callId,
      isVideo,
      context,
      expiresAt: expiresAt,
      autoAccept: true,
    );
  }

  static Future<void> _openIncomingCall(
    String caller,
    String callId,
    bool isVideo,
    BuildContext context, {
    int? expiresAt,
    bool autoAccept = false,
  }) async {
    if (callId.trim().isEmpty || !_openingCallIds.add(callId)) return;
    if (expiresAt != null &&
        expiresAt <= DateTime.now().millisecondsSinceEpoch) {
      await clearIncomingCallNotification(callId);
      _openingCallIds.remove(callId);
      return;
    }
    try {
      final peer = await context.read<FriendService>().getUser(caller);
      if (peer == null || !context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          peer: peer,
          callType: isVideo ? 'video' : 'voice',
          isIncoming: true,
          callerId: caller,
          callId: callId,
          callExpiresAt: expiresAt == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(expiresAt),
          autoAccept: autoAccept,
        ),
      ));
    } catch (error) {
      debugPrint('[NovynCalls] Could not open incoming call: $error');
    } finally {
      _openingCallIds.remove(callId);
    }
  }

  static Future<void> _openChatFromNotification(
    String username,
    BuildContext context, {
    bool isGroup = false,
  }) async {
    final target = username.trim();
    if (target.isEmpty || !context.mounted) return;
    try {
      final auth = context.read<AuthService>();
      final socket = context.read<SocketService>();

      // Notification taps can arrive before the app has finished restoring
      // its secure cookie and authenticating the socket after process resume.
      for (var attempt = 0; attempt < 40; attempt++) {
        if (!context.mounted) return;
        if (auth.authReady && auth.isLoggedIn && socket.isAuthenticated) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (!context.mounted || !auth.isLoggedIn || !socket.isAuthenticated) {
        return;
      }

      UserModel? peer;
      if (isGroup) {
        for (final conversation in socket.conversations) {
          if (conversation.isGroup &&
              (conversation.chatId.toLowerCase() == target.toLowerCase() ||
                  conversation.peerUid.toLowerCase() == target.toLowerCase() ||
                  conversation.peer.uid.toLowerCase() == target.toLowerCase())) {
            peer = conversation.peer;
            break;
          }
        }
      } else {
        peer = await context.read<FriendService>().getUser(target);
      }
      if (peer == null || !context.mounted) return;

      // A notification must take the user to the conversation, not leave an
      // old Profile Details route visible underneath it. Normalize the root
      // stack before opening the destination.
      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.popUntil((route) => route.isFirst);
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(peer: peer!, isGroup: isGroup),
        ),
      );
    } catch (error) {
      debugPrint(
          '[NovynNotifications] Could not open chat from notification: $error');
    }
  }

  // ── Get current token ─────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}
