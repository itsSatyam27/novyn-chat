import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:shared_preferences/shared_preferences.dart';
import 'message_encryption_service.dart';
import 'firebase_configuration.dart';
import '../models/chat_models.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'settings_service.dart';
import 'socket_service.dart';
import 'friend_service.dart';
import '../screens/chats/chat_detail_screen.dart';
import '../screens/calls/calls_screen.dart';
import '../screens/calls/call_screen.dart';
import '../widgets/user_avatar.dart';

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
    final isIncoming = callStatus == 'incoming';
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
      iOS: DarwinInitializationSettings(),
    ));
    const incomingChannel = AndroidNotificationChannel('novyn_incoming_calls', 'Incoming calls',
      description: 'Incoming voice and video calls', importance: Importance.max,
      playSound: true, enableVibration: true);
    const missedChannel = AndroidNotificationChannel('novyn_calls', 'Missed calls',
      description: 'Missed voice and video calls', importance: Importance.max,
      playSound: true, enableVibration: true);
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(incomingChannel);
    await androidPlugin?.createNotificationChannel(missedChannel);
    final caller = data['chat']?.toString() ?? 'Novyn contact';
    final callId = data['callId']?.toString() ?? '';
    if (callStatus == 'ended') {
      if (callId.isNotEmpty) await plugin.cancel(callId.hashCode);
      return;
    }
    if (!(prefs.getBool('notifications_on') ?? true)) return;
    final dndEnabled = prefs.getBool('do_not_disturb_enabled') ?? false;
    final favoriteIds = (prefs.getStringList('favorite_chat_ids') ?? [])
        .map((value) => value.toLowerCase()).toSet();
    if (dndEnabled && !favoriteIds.contains(caller.trim().toLowerCase())) return;
    final isVideo = data['isVideo']?.toString() == '1';
    final title = data['title']?.toString() ?? (isIncoming ? (isVideo ? 'Incoming video call' : 'Incoming voice call') : 'Missed call');
    final body = data['body']?.toString() ?? (isIncoming ? caller + ' is calling you' : 'You missed a call from ' + caller);
    await plugin.show(callId.hashCode, title, body, NotificationDetails(
      android: AndroidNotificationDetails(isIncoming ? 'novyn_incoming_calls' : 'novyn_calls',
        isIncoming ? 'Incoming calls' : 'Missed calls',
        channelDescription: 'Voice and video call alerts', importance: Importance.max,
        priority: Priority.max, category: isIncoming ? AndroidNotificationCategory.call : AndroidNotificationCategory.missedCall,
        fullScreenIntent: isIncoming, ongoing: isIncoming, autoCancel: !isIncoming,
        timeoutAfter: isIncoming ? 45000 : null,
        playSound: true, enableVibration: true, icon: '@drawable/novyn_wings_icon'),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    ), payload: 'call:' + callId + '|' + caller + '|' + (isVideo ? '1' : '0'));
    return;
  }
  if (data['type'] != 'message' || data['kind'] == 'group') return;

  final prefs = await SharedPreferences.getInstance();
  // Background FCM runs in its own isolate; refresh the plugin cache before
  // reading account and preview preferences written by the foreground isolate.
  await prefs.reload();
  final notificationsEnabled = prefs.getBool('notifications_on') ?? true;
  if (!notificationsEnabled) return;
  final localPresence = (prefs.getString('novyn_notification_presence_mode') ?? '').toLowerCase();
  // Busy suppresses message alerts in every app lifecycle state. The server
  // also suppresses these pushes; this guard covers delayed/already queued FCM.
  final sender = (data['chat'] ?? '').toString().trim();
  final dndEnabled = prefs.getBool('do_not_disturb_enabled') ?? false;
  final favoriteIds = (prefs.getStringList('favorite_chat_ids') ?? [])
      .map((value) => value.toLowerCase()).toSet();
  if (dndEnabled && !favoriteIds.contains(sender.toLowerCase())) return;
  if (localPresence == 'busy' ||
      data['silent']?.toString().toLowerCase() == 'true' ||
      data['silent']?.toString() == '1') {
    debugPrint('[NovynNotifications] Message alert suppressed while Busy.');
    return;
  }

  // Respect both the locally persisted preference and the server-side value
  // carried with encrypted pushes; either can disable previews.
  final previewEnabled = (prefs.getBool('message_preview') ?? true) &&
      data['previewEnabled']?.toString() != '0';
  final hideContent = prefs.getBool('hide_notification_content') ?? false;
  final account = (prefs.getString('novyn_notification_account') ?? '').trim();
  if (sender.isEmpty) {
    debugPrint('[NovynNotifications] Background message has no sender chat id.');
    return;
  }

  var body = 'You have a new message';
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
  if (previewEnabled && !hideContent && account.isNotEmpty) {
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
        var decrypted = await encryption.decrypt(encrypted, account, peerKey);
        // Secure storage can take longer to become available in Android's
        // background isolate. Retry with bounded backoff; never expose
        // ciphertext or fall back to plaintext from the server.
        const retryDelays = [350, 700, 1200];
        for (final delay in retryDelays) {
          if (!decrypted.needsMessageKey) break;
          await Future<void>.delayed(Duration(milliseconds: delay));
          decrypted = await encryption.decrypt(encrypted, account, peerKey);
        }
        if (!decrypted.needsMessageKey &&
            decrypted.text != '🔒 Encrypted message' &&
            decrypted.text.trim().isNotEmpty) {
          body = decrypted.text.trim();
          debugPrint('[NovynNotifications] Background message preview decrypted successfully.');
        } else {
          debugPrint('[NovynNotifications] Message preview key unavailable for this sender/account.');
        }
      } catch (error) {
        debugPrint('[NovynNotifications] Background preview decryption failed: $error');
        // Never expose ciphertext; fall back to a private generic alert.
      }
    } else {
      debugPrint('[NovynNotifications] Encrypted push is missing preview key material (ciphertext: ${ciphertext.isNotEmpty}, iv: ${iv.isNotEmpty}, sender key: ${peerKey.isNotEmpty}, account: ${account.isNotEmpty}).');
    }
  } else {
    debugPrint('[NovynNotifications] Message preview is disabled or content is hidden.');
  }

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
    iOS: DarwinInitializationSettings(),
  ));
  const channel = AndroidNotificationChannel(
    'novyn_messages', 'Messages',
    description: 'New direct messages from your Novyn contacts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  await plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  final timestamp = DateTime.now();
  final senderPerson = fln.Person(name: sender, key: sender);
  final mePerson = fln.Person(name: 'You', key: account);
  await plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    sender,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'novyn_messages', 'Messages',
        channelDescription: 'New direct messages from your Novyn contacts',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        styleInformation: fln.MessagingStyleInformation(
          mePerson,
          messages: [fln.Message(body, timestamp, senderPerson)],
          conversationTitle: sender,
          groupConversation: false,
        ),
        icon: '@drawable/novyn_wings_icon',
        ticker: '$sender: $body',
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
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const String _messageChannelId = 'novyn_messages';
  static const String _messageChannelName = 'Messages';
  static bool _localNotificationsReady = false;
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
        final payload = response.payload?.trim() ?? '';
        if (!context.mounted || payload.isEmpty) return;
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
    final settings = _settings;
    if (!context.mounted ||
        settings == null ||
        !settings.notificationsOn ||
        (settings.doNotDisturbEnabled &&
            !settings.favoriteChatIds.contains(username.trim().toLowerCase())) ||
        _presenceAuth?.user?.presenceMode == 'busy') {
      return;
    }

    final preview = settings.messagePreview && !settings.hideNotificationContent
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
                    unawaited(_openChatFromNotification(username, context));
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
        if (_tokenRetryCount < 3) {
          _tokenRetryCount++;
          Future.delayed(const Duration(seconds: 3), () => unawaited(_syncDeviceToken()));
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
        debugPrint('[NovynNotifications] Device token registration failed: ${result['message']}');
        if (_tokenRetryCount < 3) {
          _tokenRetryCount++;
          Future.delayed(const Duration(seconds: 3), () => unawaited(_syncDeviceToken()));
        }
      }
    } catch (error) {
      debugPrint('[NovynNotifications] Device token sync failed: $error');
      if (_tokenRetryCount < 3) {
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
    await _initializeLocalNotifications(context);
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
      if (preferences?.doNotDisturbEnabled == true &&
          !preferences!.favoriteChatIds.contains(caller.toLowerCase())) {
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
      if (localPayload.startsWith('call:')) {
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
    if (type == 'call') {
      final callStatus = message.data['callStatus']?.toString() ?? 'missed';
      final callId = message.data['callId']?.toString() ?? '';
      if (callStatus == 'ended') {
        if (callId.isNotEmpty) unawaited(_localNotifications.cancel(callId.hashCode));
        return;
      }
      if (!(_settings?.notificationsOn ?? false)) return;
      final caller = message.data['chat']?.toString() ?? 'Novyn contact';
      final activeSettings = _settings;
      if (activeSettings?.doNotDisturbEnabled == true &&
          !activeSettings!.favoriteChatIds.contains(caller.trim().toLowerCase())) return;
      if (_socket?.isConnected == true && callStatus == 'incoming') return;
      final isIncoming = callStatus == 'incoming';
      final isVideo = message.data['isVideo']?.toString() == '1';
      unawaited(_localNotifications.show(
        callId.hashCode,
        message.data['title']?.toString() ?? (isIncoming ? (isVideo ? 'Incoming video call' : 'Incoming voice call') : 'Missed call'),
        message.data['body']?.toString() ?? (isIncoming ? caller + ' is calling you' : 'You missed a call from ' + caller),
        NotificationDetails(
          android: AndroidNotificationDetails(
            isIncoming ? 'novyn_incoming_calls' : 'novyn_calls',
            isIncoming ? 'Incoming calls' : 'Missed calls',
            channelDescription: 'Voice and video call alerts',
            importance: Importance.max, priority: Priority.max,
            category: isIncoming ? AndroidNotificationCategory.call : AndroidNotificationCategory.missedCall,
            fullScreenIntent: isIncoming, ongoing: isIncoming, autoCancel: !isIncoming,
            timeoutAfter: isIncoming ? 45000 : null,
            playSound: true, enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        payload: 'call:' + callId + '|' + caller + '|' + (isVideo ? '1' : '0'),
      ));
      return;
    }
    // Prefer the live socket callback; FCM is a fallback for disconnected
    // sockets or app lifecycle states where the socket callback was missed.
    if (type == 'message' && message.data['kind'] != 'group') {
      if (_socket?.isConnected == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) return;
      final username = message.data['chat']?.toString().trim() ?? '';
      if (username.isNotEmpty) {
        final body = message.data['body']?.toString().trim();
        unawaited(_showForegroundMessageNotification(
          username,
          body?.isNotEmpty == true
              ? body!
              : message.notification?.body ?? 'You have a new message',
        ));
      }
    }
  }

  static Future<void> _showForegroundMessageNotification(
      String username, String messageBody) async {
    final sender = username.trim();
    final settings = _settings;
    if (sender.isEmpty || settings == null || !settings.notificationsOn) return;
    if (settings.doNotDisturbEnabled &&
        !settings.favoriteChatIds.contains(sender.toLowerCase())) return;
    if (_presenceAuth?.user?.presenceMode == 'busy') return;

    final body = settings.messagePreview && !settings.hideNotificationContent
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
    final type = message.data['type'];

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
