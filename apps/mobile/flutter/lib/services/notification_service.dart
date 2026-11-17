import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'firebase_configuration.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'settings_service.dart';
import 'socket_service.dart';
import 'friend_service.dart';
import '../screens/chats/chat_detail_screen.dart';
import '../screens/calls/calls_screen.dart';
import '../screens/calls/call_screen.dart';
import '../widgets/user_avatar.dart';


// Stable IDs let Android replace an existing event notification rather than
// creating a fresh alert every time FCM retries the same message.
int _stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

Future<bool> _wasNotificationHandled(
  SharedPreferences prefs,
  String account,
  String eventId,
) async {
  final id = eventId.trim();
  if (id.isEmpty) return false;
  final key = 'novyn_seen_notifications_${account.trim().toLowerCase()}';
  final seen = prefs.getStringList(key) ?? <String>[];
  if (seen.contains(id)) return true;
  seen.add(id);
  if (seen.length > 120) {
    seen.removeRange(0, seen.length - 120);
  }
  await prefs.setStringList(key, seen);
  return false;
}

bool _isSuppressedByPresenceOrDnd(
  SharedPreferences prefs,
  String sender,
) {
  final presenceMode =
      (prefs.getString('active_smart_presence_mode_v1') ?? 'online').toLowerCase();
  if (presenceMode == 'busy' || presenceMode == 'invisible') return true;
  final dndEnabled = prefs.getBool('do_not_disturb_enabled') ?? false;
  final favorites = (prefs.getStringList('favorite_chat_ids') ?? [])
      .map((value) => value.toLowerCase()).toSet();
  return dndEnabled && !favorites.contains(sender.trim().toLowerCase());
}

// Top-level handler — must be a top-level function. All mobile pushes are
// data-only so the active account and local privacy settings can be checked
// before showing any alert, including when the app is backgrounded.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: FirebaseConfiguration.options);
  ui.DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final data = message.data;
  final type = data['type']?.toString() ?? '';
  final account = (prefs.getString('novyn_notification_account') ?? '')
      .trim().toLowerCase();
  final recipient = (data['recipient'] ?? '').toString().trim().toLowerCase();

  // A token left on the server after an offline logout must never surface the
  // previous account's messages on the next signed-out/account-switched state.
  if (recipient.isNotEmpty &&
      (account.isEmpty || recipient != account)) {
    debugPrint('[NovynNotifications] Ignored push for a different signed-in account.');
    return;
  }
  if (account.isEmpty) return;
  if (!(prefs.getBool('notifications_on') ?? true)) return;
  if (data['silent']?.toString() == '1' ||
      data['silent']?.toString().toLowerCase() == 'true') return;

  if (type == 'call') {
    final callStatus = data['callStatus']?.toString() ?? 'missed';
    final alertCaller = data['chat']?.toString().trim().toLowerCase() ?? '';
    if (callStatus == 'missed' && alertCaller == account) return;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
      iOS: DarwinInitializationSettings(),
    ));
    const incomingChannel = AndroidNotificationChannel(
      'novyn_incoming_calls', 'Incoming calls',
      description: 'Incoming voice and video calls',
      importance: Importance.max, playSound: true, enableVibration: true,
    );
    const missedChannel = AndroidNotificationChannel(
      'novyn_calls', 'Missed calls',
      description: 'Missed voice and video calls',
      importance: Importance.max, playSound: true, enableVibration: true,
    );
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(incomingChannel);
    await androidPlugin?.createNotificationChannel(missedChannel);
    final caller = data['chat']?.toString() ?? 'Novyn contact';
    final callId = data['callId']?.toString() ?? '';
    if (callStatus == 'ended') {
      if (callId.isNotEmpty) await plugin.cancel(_stableNotificationId(callId));
      return;
    }
    if (_isSuppressedByPresenceOrDnd(prefs, caller)) return;
    final isIncoming = callStatus == 'incoming';
    final isVideo = data['isVideo']?.toString() == '1';
    final title = data['title']?.toString() ??
        (isIncoming
            ? (isVideo ? 'Incoming video call' : 'Incoming voice call')
            : 'Missed call');
    final body = data['body']?.toString() ??
        (isIncoming ? '$caller is calling you' : 'You missed a call from $caller');
    await plugin.show(
      _stableNotificationId('call:$callId:$callStatus'),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isIncoming ? 'novyn_incoming_calls' : 'novyn_calls',
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
          timeoutAfter: isIncoming ? 45000 : null,
          playSound: true,
          enableVibration: true,
          icon: '@drawable/novyn_wings_icon',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: 'call:$callId|$caller|${isVideo ? '1' : '0'}',
    );
    return;
  }

  if (type == 'app_update') {
    final build = int.tryParse(data['build']?.toString() ?? '') ?? 0;
    if (build > 0) {
      await NotificationService.showAppUpdateAvailable(buildNumber: build);
    }
    return;
  }

  const socialTypes = {
    'friend_request',
    'friend_request_accepted',
    'friend_request_declined',
    'group_invite',
  };
  if (socialTypes.contains(type)) {
    final sender = (data['from'] ?? data['chat'] ?? '').toString().trim();
    if (_isSuppressedByPresenceOrDnd(prefs, sender)) return;
    final eventId = (data['eventId'] ?? '').toString();
    if (await _wasNotificationHandled(prefs, account, eventId)) return;

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
      iOS: DarwinInitializationSettings(),
    ));
    const channel = AndroidNotificationChannel(
      'novyn_social', 'Social activity',
      description: 'Friend requests and group invitations',
      importance: Importance.high, playSound: true, enableVibration: true,
    );
    await plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    await plugin.show(
      _stableNotificationId(eventId.isNotEmpty ? eventId : '$type:$sender'),
      data['title']?.toString() ?? 'Novyn',
      data['body']?.toString() ?? 'You have a new notification',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_social', 'Social activity',
          channelDescription: 'Friend requests and group invitations',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: 'social|$type|$sender',
    );
    return;
  }

  if (type != 'message') return;
  final isGroup = data['kind'] == 'group';
  if (isGroup && !(prefs.getBool('group_notifications') ?? true)) return;

  final sender = (data['chat'] ?? '').toString().trim();
  final groupId = (data['groupId'] ?? (isGroup ? sender : '')).toString().trim();
  final chatKey = isGroup ? groupId : sender;
  if (chatKey.isEmpty) return;
  if (_isSuppressedByPresenceOrDnd(prefs, chatKey)) return;

  final archivedChats = (prefs.getStringList('novyn_archived_$account') ?? [])
      .map((value) => value.trim().toLowerCase()).toSet();
  final lockedChats = (prefs.getStringList('novyn_locked_chats_$account') ?? [])
      .map((value) => value.trim().toLowerCase()).toSet();
  if (archivedChats.contains(chatKey.toLowerCase())) return;
  final isLockedChat = !isGroup && lockedChats.contains(sender.toLowerCase());

  final eventId = (data['eventId'] ?? data['messageId'] ?? '').toString();
  if (await _wasNotificationHandled(prefs, account, eventId)) return;

  final previewEnabled = (prefs.getBool('message_preview') ?? true) &&
      data['previewEnabled']?.toString() != '0';
  final hideContent = prefs.getBool('hide_notification_content') ?? false;
  final mayShowPreview = previewEnabled && !hideContent && !isLockedChat;
  final rawBody = data['body']?.toString().trim() ?? '';
  final body = mayShowPreview && rawBody.isNotEmpty
      ? rawBody
      : (isGroup ? 'New group message' : 'You have a new message');

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
    iOS: DarwinInitializationSettings(),
  ));
  const channel = AndroidNotificationChannel(
    'novyn_messages', 'Messages',
    description: 'New direct and group messages from your contacts',
    importance: Importance.max, playSound: true, enableVibration: true,
  );
  await plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  final notificationTitle = isGroup
      ? (data['title']?.toString() ?? 'New group message')
      : sender;
  final notificationId = _stableNotificationId(
    eventId.isNotEmpty ? eventId : 'message:$chatKey:${DateTime.now().millisecondsSinceEpoch}',
  );
  final timestamp = DateTime.now();
  final accountPerson = fln.Person(name: 'You', key: account);
  final senderPerson = fln.Person(
    name: isGroup
        ? ((data['from'] ?? rawBody.split(':').first).toString())
        : sender,
    key: isGroup ? (data['from'] ?? sender).toString() : sender,
  );
  await plugin.show(
    notificationId,
    notificationTitle,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'novyn_messages', 'Messages',
        channelDescription: 'New direct and group messages from your contacts',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        styleInformation: fln.MessagingStyleInformation(
          accountPerson,
          messages: [fln.Message(body, timestamp, senderPerson)],
          conversationTitle: isGroup ? notificationTitle : sender,
          groupConversation: isGroup,
        ),
        icon: '@drawable/novyn_wings_icon',
        ticker: '$notificationTitle: $body',
        onlyAlertOnce: false,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      ),
    ),
    payload: isGroup ? 'group|$groupId' : sender,
  );
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final Set<String> _archivedChatNotificationIds = <String>{};

  static void setChatArchivedForNotifications(String chatId, bool archived) {
    final key = chatId.trim().toLowerCase();
    if (key.isEmpty) return;
    if (archived) { _archivedChatNotificationIds.add(key); } else { _archivedChatNotificationIds.remove(key); }
  }

  static Future<({bool archived, bool locked})> _chatNotificationPrivacy(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final account = (prefs.getString('novyn_notification_account') ?? '').trim().toLowerCase();
    final key = chatId.trim().toLowerCase();
    final archived = (prefs.getStringList('novyn_archived_$account') ?? []).map((v) => v.toLowerCase()).contains(key);
    final locked = (prefs.getStringList('novyn_locked_chats_$account') ?? []).map((v) => v.toLowerCase()).contains(key);
    setChatArchivedForNotifications(key, archived);
    return (archived: archived, locked: locked && !archived);
  }
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const String _messageChannelId = 'novyn_messages';
  static const String _messageChannelName = 'Messages';
  static bool _localNotificationsReady = false;
  static final Map<int, Timer> _callReminderTimers = {};
  static OverlayEntry? _inAppBannerEntry;
  static Timer? _inAppBannerTimer;
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
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static bool? _lastAlertsEnabled;
  static bool? _lastSoundEnabled;
  static ValueChanged<String>? _activeCallActionHandler;
  static const int _activeCallNotificationId = 781204;
  static const int _appUpdateNotificationId = 781205;
  static ValueChanged<BuildContext>? _appUpdateTapHandler;

  static void setAppUpdateTapHandler(ValueChanged<BuildContext>? handler) {
    _appUpdateTapHandler = handler;
  }

  static Future<void> showAppUpdateAvailable({
    int? buildNumber,
    bool allowRepeat = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool('notifications_on') ?? true)) return;
    if (buildNumber != null && buildNumber > 0) {
      const handledBuildKey = 'novyn_last_notified_update_build';
      final handledBuild = prefs.getInt(handledBuildKey) ?? 0;
      if (!allowRepeat && buildNumber <= handledBuild) return;
    }
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
    final body = buildNumber != null && buildNumber > 0
        ? 'Android build #$buildNumber is ready. Tap to open About Novyn and install it.'
        : 'Tap to open About Novyn and check for updates.';
    await _localNotifications.show(
      _appUpdateNotificationId,
      'A new Novyn version is available',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription: 'Notifications when a new Novyn version is available',
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
    if (buildNumber != null && buildNumber > 0) {
      await prefs.setInt('novyn_last_notified_update_build', buildNumber);
    }
  }

  static const int _updateDownloadNotificationId = 781206;

  static Future<void> _ensureUpdateDownloadChannel() async {
    if (!_localNotificationsReady) {
      throw StateError('Local notifications are not initialized.');
    }
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_update_downloads',
        'Update downloads',
        description: 'Progress and completion of Novyn app updates',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  /// Shows a quiet, ongoing Android notification for the current APK download.
  static Future<void> showUpdateDownloadProgress({
    required int downloadedBytes,
    required int totalBytes,
    required double speedBytesPerSecond,
  }) async {
    await _ensureUpdateDownloadChannel();
    final safeTotal = totalBytes > 0 ? totalBytes : 1;
    final percent = ((downloadedBytes / safeTotal) * 100)
        .round()
        .clamp(0, 100)
        .toInt();
    final downloadedMb = (downloadedBytes / 1000000).toStringAsFixed(1);
    final totalMb = (totalBytes / 1000000).toStringAsFixed(1);
    final speedLabel = speedBytesPerSecond > 0
        ? (speedBytesPerSecond / 1000000).toStringAsFixed(1) + ' MB/s'
        : 'Calculating speed';
    final remainingBytes = (totalBytes - downloadedBytes).clamp(0, totalBytes);
    final etaSeconds = speedBytesPerSecond > 0
        ? (remainingBytes / speedBytesPerSecond).ceil()
        : 0;
    final etaLabel = speedBytesPerSecond > 0
        ? ' · about ' + _formatUpdateEta(etaSeconds) + ' left'
        : '';

    await _localNotifications.show(
      _updateDownloadNotificationId,
      'Downloading Novyn update · $percent%',
      '$downloadedMb / $totalMb MB · $speedLabel$etaLabel',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_update_downloads',
          'Update downloads',
          channelDescription: 'Progress and completion of Novyn app updates',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@drawable/novyn_wings_icon',
          showProgress: true,
          maxProgress: 100,
          progress: percent,
          indeterminate: false,
          ongoing: true,
          onlyAlertOnce: true,
          autoCancel: false,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: false),
      ),
      payload: 'app_update',
    );
  }

  /// Replaces the ongoing progress alert when the download pauses or fails.
  static Future<void> showUpdateDownloadPaused({
    required int downloadedBytes,
    required int totalBytes,
    required String message,
  }) async {
    await _ensureUpdateDownloadChannel();
    final percent = totalBytes > 0
        ? ((downloadedBytes / totalBytes) * 100).round().clamp(0, 100).toInt()
        : 0;
    final downloadedMb = (downloadedBytes / 1000000).toStringAsFixed(1);
    final totalMb = (totalBytes / 1000000).toStringAsFixed(1);
    await _localNotifications.show(
      _updateDownloadNotificationId,
      downloadedBytes > 0 ? 'Novyn update download paused' : 'Novyn update download failed',
      downloadedBytes > 0
          ? '$downloadedMb / $totalMb MB saved · $message'
          : message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_update_downloads',
          'Update downloads',
          channelDescription: 'Progress and completion of Novyn app updates',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@drawable/novyn_wings_icon',
          showProgress: downloadedBytes > 0,
          maxProgress: 100,
          progress: percent,
          indeterminate: false,
          ongoing: false,
          onlyAlertOnce: true,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: false),
      ),
      payload: 'app_update',
    );
  }

  /// Shows the verified APK as ready and makes the notification tappable.
  static Future<void> showUpdateDownloadComplete() async {
    await _ensureUpdateDownloadChannel();
    await _localNotifications.show(
      _updateDownloadNotificationId,
      'Novyn update ready',
      'Download verified. Tap to open About Novyn and install the update.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_update_downloads',
          'Update downloads',
          channelDescription: 'Progress and completion of Novyn app updates',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@drawable/novyn_wings_icon',
          showProgress: true,
          maxProgress: 100,
          progress: 100,
          indeterminate: false,
          ongoing: false,
          onlyAlertOnce: true,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: false),
      ),
      payload: 'app_update',
    );
  }

  static String _formatUpdateEta(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return minutes.toString() + 'm ' + remainingSeconds.toString() + 's';
    }
    return (minutes ~/ 60).toString() + 'h ' + (minutes % 60).toString() + 'm';
  }

  /// Registers the currently visible call screen as the owner of notification
  /// actions. The notification itself stays ongoing while the call is active.
  static void setActiveCallActionHandler(ValueChanged<String>? handler) {
    _activeCallActionHandler = handler;
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
      await prefs.setBool('hide_notification_content', settings.hideNotificationContent);
      await prefs.setBool('do_not_disturb_enabled', settings.doNotDisturbEnabled);
      await prefs.setStringList('favorite_chat_ids', settings.favoriteChatIds);
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
        if (payload.startsWith('social|')) {
          _openSocialNotificationDestination(context);
          return;
        }
        if (payload.startsWith('group|')) {
          _openGroupNotificationDestination(context);
          return;
        }
        if (payload.startsWith('call:')) {
          final parts = payload.substring(5).split('|');
          if (parts.length >= 3 && parts[0].isNotEmpty) {
            unawaited(_openIncomingCall(parts[1], parts[0], parts[2] == '1', context));
          } else {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallsScreen()));
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
    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidNotifications?.createNotificationChannel(channel);
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
        if (notification.channelId == 'novyn_incoming_calls' && notification.id != null) {
          await _localNotifications.cancel(notification.id!);
        }
      }
    } catch (error) {
      debugPrint('[NovynCalls] Could not clean legacy call alerts: $error');
    }
    _localNotificationsReady = true;
  }

  static Future<void> showInAppMessage(
      String username, String messageBody, BuildContext context) async {
    final privacy = await _chatNotificationPrivacy(username);
    if (privacy.archived) return;
    // Keep the host screen context for navigation. The banner's animated
    // builder context is disposed as soon as the overlay entry is removed.
    final navigationContext = context;
    final settings = _settings;
    if (!context.mounted ||
        settings == null ||
        !settings.notificationsOn ||
        (settings.doNotDisturbEnabled &&
            !settings.favoriteChatIds.contains(username.trim().toLowerCase())) ||
        (_presenceAuth?.user?.presenceMode == 'busy' ||
            _presenceAuth?.user?.presenceMode == 'invisible')) {
      return;
    }

    final preview = settings.messagePreview && !settings.hideNotificationContent && !privacy.locked
        ? messageBody.trim()
        : 'You have a new message';
    final senderProfile = _socket?.contacts.findUser(username);
    final title = senderProfile?.name.trim().isNotEmpty == true
        ? senderProfile!.name.trim()
        : username;
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
                      unawaited(_openChatFromNotification(username, navigationContext));
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
                        color: Theme.of(context).colorScheme.primary
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
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: .55),
                              width: 1.5,
                            ),
                          ),
                          child: UserAvatar(
                            name: title,
                            photoUrl: senderProfile?.photoUrl ?? '',
                            radius: 24,
                            fallbackColor: Theme.of(context).colorScheme.primary,
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
                                  color: Theme.of(context).colorScheme.onSurface,
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
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        if (_tokenRetryCount < 10) {
          _tokenRetryCount++;
          Future.delayed(const Duration(seconds: 3), () => unawaited(_syncDeviceToken()));
        }
        return;
      }
      if (token == _lastRegisteredToken) return;
      final packageInfo = await PackageInfo.fromPlatform();
      final appBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      final result = await socket.registerFcmToken(
        token,
        appBuild: appBuild,
        platform: platform,
      );
      if (result['ok'] == true) {
        _lastRegisteredToken = token;
        _tokenRetryCount = 0;
        debugPrint('[NovynNotifications] Device token registered with Novyn.');
      } else {
        debugPrint('[NovynNotifications] Device token registration failed: ${result['message']}');
        if (_tokenRetryCount < 10) {
          _tokenRetryCount++;
          Future.delayed(const Duration(seconds: 3), () => unawaited(_syncDeviceToken()));
        }
      }
    } catch (error) {
      debugPrint('[NovynNotifications] Device token sync failed: $error');
      if (_tokenRetryCount < 10) {
        _tokenRetryCount++;
        Future.delayed(const Duration(seconds: 3), () => unawaited(_syncDeviceToken()));
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
      // Restore account preferences before writing anything from local defaults.
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
        // Hydrate every privacy/notification key from the account before
        // applying mode defaults. This preserves choices made on another client.
        await settings.hydrateSmartPresenceModeFromServer(activeMode, values);
        await settings.applySmartPresenceLocalPolicy(activeMode);
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
    await _initializeLocalNotifications(context);
    _connectivitySubscription ??=
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((result) => result != ConnectivityResult.none);
      if (!online) return;
      _tokenRetryCount = 0;
      _preferenceRetryCount = 0;
      unawaited(_syncDeviceToken());
      unawaited(_syncUserPreferences());
    });
    final notificationPrefs = await SharedPreferences.getInstance();
    await notificationPrefs.reload();
    final notificationAccount = (notificationPrefs.getString('novyn_notification_account') ?? '').trim().toLowerCase();
    _archivedChatNotificationIds
      ..clear()
      ..addAll((notificationPrefs.getStringList('novyn_archived_$notificationAccount') ?? []).map((v) => v.trim().toLowerCase()));
    _socket!.notificationsMuted = ([String? sender]) => sender != null && _archivedChatNotificationIds.contains(sender.trim().toLowerCase());
    _socket!.onIncomingMessage = (username, body) {
      if (!context.mounted) return;
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        // Keep the branded PR #95 banner for active use; system alerts are
        // used when the app is not currently visible.
        unawaited(showInAppMessage(username, body, context));
      } else {
        unawaited(_showForegroundMessageNotification(username, body));
      }
    };
    _socket!.onCallInviteCallback = (data) {
      if (!context.mounted) return;
      final caller = data['from']?.toString().trim() ?? '';
      final callId = data['callId']?.toString().trim() ?? '';
      if (caller.isEmpty || callId.isEmpty) return;
      final preferences = _settings;
      if (preferences == null || !preferences.notificationsOn ||
          _presenceAuth?.user?.presenceMode == 'busy' ||
          _presenceAuth?.user?.presenceMode == 'invisible') return;
      if (preferences.doNotDisturbEnabled &&
          !preferences.favoriteChatIds.contains(caller.toLowerCase())) {
        return;
      }
      unawaited(_openIncomingCall(caller, callId, data['isVideo'] == true, context));
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
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (context.mounted) unawaited(_handleNotificationTap(message, context));
    });

    // 5. App opened from terminated state
    final initial = await _fcm.getInitialMessage();
    if (initial != null && context.mounted) {
      unawaited(_handleNotificationTap(initial, context));
    }
    final localLaunch = await _localNotifications.getNotificationAppLaunchDetails();
    final localPayload = localLaunch?.notificationResponse?.payload?.trim() ?? '';
    if (localLaunch?.didNotificationLaunchApp == true && localPayload.isNotEmpty && context.mounted) {
      if (localPayload == 'app_update') {
        _appUpdateTapHandler?.call(context);
      } else if (localPayload.startsWith('social|')) {
        _openSocialNotificationDestination(context);
      } else if (localPayload.startsWith('group|')) {
        _openGroupNotificationDestination(context);
      } else if (localPayload.startsWith('call:')) {
        final parts = localPayload.substring(5).split('|');
        if (parts.length >= 3 && parts[0].isNotEmpty) {
          unawaited(_openIncomingCall(parts[1], parts[0], parts[2] == '1', context));
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
    await prefs.setString('novyn_notification_account', uid);
    await prefs.setBool('notifications_on', _settings?.notificationsOn ?? true);
    await prefs.setBool('message_preview', _settings?.messagePreview ?? true);
    await prefs.setBool('hide_notification_content', _settings?.hideNotificationContent ?? false);
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
    String? currentToken;
    try {
      currentToken = await _fcm.getToken();
    } catch (_) {}
    if (_socket?.isConnected == true) {
      try {
        await _socket!.clearFcmToken(currentToken);
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
    final type = message.data['type']?.toString() ?? '';
    final recipient = message.data['recipient']?.toString().trim().toLowerCase() ?? '';
    final notificationAccount =
        (_presenceAuth?.user?.username ?? _activeUsername ?? '').trim().toLowerCase();
    if (recipient.isNotEmpty &&
        (notificationAccount.isEmpty || recipient != notificationAccount)) {
      debugPrint('[NovynNotifications] Ignored foreground push for another account.');
      return;
    }

    if (type == 'call') {
      final callStatus = message.data['callStatus']?.toString() ?? 'missed';
      final alertCaller = message.data['chat']?.toString().trim().toLowerCase() ?? '';
      if (callStatus == 'missed' && notificationAccount.isNotEmpty &&
          alertCaller == notificationAccount) return;
      final callId = message.data['callId']?.toString() ?? '';
      if (callStatus == 'ended') {
        if (callId.isNotEmpty) unawaited(_localNotifications.cancel(_stableNotificationId(callId)));
        return;
      }
      if (!(_settings?.notificationsOn ?? false) ||
          _presenceAuth?.user?.presenceMode == 'busy' ||
          _presenceAuth?.user?.presenceMode == 'invisible') return;
      final caller = message.data['chat']?.toString() ?? 'Novyn contact';
      final activeSettings = _settings;
      if (activeSettings?.doNotDisturbEnabled == true &&
          !activeSettings!.favoriteChatIds.contains(caller.trim().toLowerCase())) return;
      if (_socket?.isConnected == true && callStatus == 'incoming') return;
      final isIncoming = callStatus == 'incoming';
      final isVideo = message.data['isVideo']?.toString() == '1';
      unawaited(_localNotifications.show(
        _stableNotificationId('call:$callId:$callStatus'),
        message.data['title']?.toString() ??
            (isIncoming ? (isVideo ? 'Incoming video call' : 'Incoming voice call') : 'Missed call'),
        message.data['body']?.toString() ??
            (isIncoming ? '$caller is calling you' : 'You missed a call from $caller'),
        NotificationDetails(
          android: AndroidNotificationDetails(
            isIncoming ? 'novyn_incoming_calls' : 'novyn_calls',
            isIncoming ? 'Incoming calls' : 'Missed calls',
            channelDescription: 'Voice and video call alerts',
            importance: Importance.max,
            priority: Priority.max,
            category: isIncoming ? AndroidNotificationCategory.call : AndroidNotificationCategory.missedCall,
            fullScreenIntent: isIncoming,
            ongoing: isIncoming,
            autoCancel: !isIncoming,
            timeoutAfter: isIncoming ? 45000 : null,
            playSound: true,
            enableVibration: true,
            icon: '@drawable/novyn_wings_icon',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true,
          ),
        ),
        payload: 'call:' + callId + '|' + caller + '|' + (isVideo ? '1' : '0'),
      ));
      return;
    }

    if (type == 'app_update') {
      final build = int.tryParse(message.data['build']?.toString() ?? '') ?? 0;
      if (build > 0) unawaited(showAppUpdateAvailable(buildNumber: build));
      return;
    }

    const socialTypes = {
      'friend_request',
      'friend_request_accepted',
      'friend_request_declined',
      'group_invite',
    };
    if (socialTypes.contains(type)) {
      unawaited(_showForegroundSocialNotification(message));
      return;
    }

    if (type == 'message' && message.data['kind'] == 'group') {
      if (_socket?.isConnected == true) return;
      unawaited(_showForegroundGroupNotification(message));
      return;
    }

    if (type == 'message' && _socket?.isConnected == true) return;
    if (type == 'message') {
      final username = message.data['chat']?.toString().trim() ?? '';
      if (username.isNotEmpty) {
        final body = message.data['body']?.toString().trim();
        unawaited(_showForegroundMessageNotification(
          username,
          body?.isNotEmpty == true
              ? body!
              : message.notification?.body ?? 'You have a new message',
          eventId: (message.data['eventId'] ?? message.data['messageId'])?.toString(),
        ));
      }
    }
  }

  static Future<void> _showForegroundSocialNotification(
      RemoteMessage message) async {
    final settings = _settings;
    if (settings == null || !settings.notificationsOn) return;
    final type = message.data['type']?.toString() ?? '';
    final sender = (message.data['from'] ?? message.data['chat'] ?? '').toString().trim();
    if (_presenceAuth?.user?.presenceMode == 'busy' ||
        _presenceAuth?.user?.presenceMode == 'invisible') return;
    if (settings.doNotDisturbEnabled &&
        !settings.favoriteChatIds.contains(sender.toLowerCase())) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final account = (_activeUsername ?? '').trim().toLowerCase();
    final recipient = (message.data['recipient'] ?? '').toString().trim().toLowerCase();
    if (recipient.isNotEmpty && (account.isEmpty || recipient != account)) return;
    final eventId = (message.data['eventId'] ?? '').toString();
    if (await _wasNotificationHandled(prefs, account, eventId)) return;

    const channel = AndroidNotificationChannel(
      'novyn_social', 'Social activity',
      description: 'Friend requests and group invitations',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    await _localNotifications.show(
      _stableNotificationId(eventId.isNotEmpty ? eventId : '$type:$sender'),
      message.data['title']?.toString() ?? 'Novyn',
      message.data['body']?.toString() ?? 'You have a new notification',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_social', 'Social activity',
          channelDescription: 'Friend requests and group invitations',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: 'social|$type|$sender',
    );
  }

  static Future<void> _showForegroundGroupNotification(
      RemoteMessage message) async {
    final settings = _settings;
    if (settings == null || !settings.notificationsOn || !settings.groupNotifications) return;
    if (_presenceAuth?.user?.presenceMode == 'busy' ||
        _presenceAuth?.user?.presenceMode == 'invisible') return;
    final groupId = (message.data['groupId'] ?? message.data['chat'] ?? '').toString().trim();
    if (groupId.isEmpty) return;
    final privacy = await _chatNotificationPrivacy(groupId);
    if (privacy.archived) return;
    if (settings.doNotDisturbEnabled &&
        !settings.favoriteChatIds.contains(groupId.toLowerCase())) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final account = (_activeUsername ?? '').trim().toLowerCase();
    final recipient = (message.data['recipient'] ?? '').toString().trim().toLowerCase();
    if (recipient.isNotEmpty && (account.isEmpty || recipient != account)) return;
    final eventId = (message.data['eventId'] ?? message.data['messageId'] ?? '').toString();
    if (await _wasNotificationHandled(prefs, account, eventId)) return;

    const channel = AndroidNotificationChannel(
      'novyn_messages', 'Messages',
      description: 'New direct and group messages from your contacts',
      importance: Importance.max, playSound: true, enableVibration: true,
    );
    await _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    final mayShowPreview = settings.messagePreview && !settings.hideNotificationContent && !privacy.locked;
    final title = message.data['title']?.toString() ?? 'New group message';
    final rawBody = message.data['body']?.toString().trim() ?? '';
    final body = mayShowPreview && rawBody.isNotEmpty ? rawBody : 'New group message';
    await _localNotifications.show(
      _stableNotificationId(eventId.isNotEmpty ? eventId : 'group:$groupId'),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_messages', 'Messages',
          channelDescription: 'New direct and group messages from your contacts',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      payload: 'group|$groupId',
    );
  }

  static Future<void> _showForegroundMessageNotification(
      String username, String messageBody, {String? eventId}) async {
    final sender = username.trim();
    final privacy = await _chatNotificationPrivacy(sender);
    if (privacy.archived) return;
    final settings = _settings;
    if (sender.isEmpty || settings == null || !settings.notificationsOn) return;
    if (settings.doNotDisturbEnabled &&
        !settings.favoriteChatIds.contains(sender.toLowerCase())) return;
    if (_presenceAuth?.user?.presenceMode == 'busy' ||
        _presenceAuth?.user?.presenceMode == 'invisible') return;
    if (eventId != null && eventId.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final account = (_activeUsername ?? '').trim().toLowerCase();
      if (account.isEmpty || await _wasNotificationHandled(prefs, account, eventId)) return;
    }

    final body = settings.messagePreview && !settings.hideNotificationContent && !privacy.locked
        ? (messageBody.trim().isNotEmpty ? messageBody.trim() : 'You have a new message')
        : 'You have a new message';
    final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
    try {
      await _localNotifications.show(
        notificationId,
        sender,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _messageChannelId,
            _messageChannelName,
            channelDescription: 'New direct messages from your Novyn contacts',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            icon: '@drawable/novyn_wings_icon',
            onlyAlertOnce: false,
            autoCancel: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: sender,
      );
    } catch (error) {
      debugPrint('[NovynNotifications] Foreground system notification failed: $error');
    }
  }

  // ── Handle notification tap ───────────────────────────────────────────────
  static Future<void> _handleNotificationTap(
      RemoteMessage message, BuildContext context) async {
    final type = message.data['type']?.toString() ?? '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final account = (_activeUsername ?? prefs.getString('novyn_notification_account') ?? '').trim().toLowerCase();
    final recipient = (message.data['recipient'] ?? '').toString().trim().toLowerCase();
    if (recipient.isNotEmpty && (account.isEmpty || recipient != account)) return;

    if (type == 'app_update') {
      final build = int.tryParse(message.data['build']?.toString() ?? '') ?? 0;
      if (build > 0) await showAppUpdateAvailable(buildNumber: build);
      if (context.mounted) _appUpdateTapHandler?.call(context);
      return;
    }
    if (type == 'friend_request' ||
        type == 'friend_request_accepted' ||
        type == 'friend_request_declined' ||
        type == 'group_invite') {
      _openSocialNotificationDestination(context);
      return;
    }
    if (type == 'message' && message.data['kind'] == 'group') {
      _openGroupNotificationDestination(context);
      return;
    }

    if (type == 'call') {
      if (!context.mounted) return;
      final caller = message.data['chat']?.toString().trim() ?? '';
      final callId = message.data['callId']?.toString().trim() ?? '';
      if (message.data['callStatus'] == 'incoming' && caller.isNotEmpty && callId.isNotEmpty) {
        await _openIncomingCall(caller, callId, message.data['isVideo'] == '1', context);
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallsScreen()));
      return;
    }

    if (type != 'message' || message.data['kind'] == 'group') return;
    final username = message.data['chat']?.toString().trim() ?? '';
    if (username.isEmpty || !context.mounted) return;

    await _openChatFromNotification(username, context);
  }

  static void _openSocialNotificationDestination(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  static void _openGroupNotificationDestination(BuildContext context) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  static Future<void> _openIncomingCall(String caller, String callId, bool isVideo, BuildContext context) async {
    try {
      final peer = await context.read<FriendService>().getUser(caller);
      if (peer == null || !context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CallScreen(
        peer: peer, callType: isVideo ? 'video' : 'voice', isIncoming: true,
        callerId: caller, callId: callId,
      )));
    } catch (error) {
      debugPrint('[NovynCalls] Could not open incoming call: $error');
    }
  }
  static Future<void> _openChatFromNotification(
      String username, BuildContext context) async {
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

      final peer = await context.read<FriendService>().getUser(target);
      if (peer == null || !context.mounted) return;

      // A notification must take the user to the conversation, not leave an
      // old Profile Details route visible underneath it. Normalize the root
      // stack before opening the destination.
      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.popUntil((route) => route.isFirst);
      await navigator.push(
        MaterialPageRoute(builder: (_) => ChatDetailScreen(peer: peer)),
      );
    } catch (error) {
      debugPrint('[NovynNotifications] Could not open chat from notification: $error');
    }
  }

  // ── Get current token ─────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}
