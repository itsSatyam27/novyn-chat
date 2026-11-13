import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/firebase_configuration.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/friend_service.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'services/hybrid_db_service.dart';
import 'services/sync_service.dart';
import 'services/draft_service.dart';
import 'services/haptic_service.dart';
import 'models/chat_models.dart';
import 'models/user_model.dart';
import 'widgets/user_avatar.dart' show UserAvatar;
import 'theme/novyn_theme.dart';
import 'screens/splash/splash_screen_v2.dart';
import 'widgets/app_lock_wrapper.dart';
import 'services/call_overlay_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture uncaught framework and asynchronous Dart errors from devices that
  // may exercise different Android/plugin code paths. Keep diagnostics in the
  // platform log instead of allowing an unhandled Dart exception to terminate
  // the app process without context.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[NovynFlutterError] ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('[NovynAsyncError] $error');
    debugPrintStack(stackTrace: stackTrace);
    return true;
  };

  await Firebase.initializeApp(
    options: FirebaseConfiguration.options,
  );

  // Register background message handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final settings = SettingsService();
  await settings.load();

  // Initialize haptics with user settings
  HapticService.init(settings);
  // Initialize Hive first (required for adapters)
  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(ChatAdapter());
  Hive.registerAdapter(MessageAdapter());
  Hive.registerAdapter(UserModelAdapter());

  // Initialize hybrid database (Drift + Hive) for 3-5x faster queries
  await HybridDbService.init();

  // Initialize draft service for saving unsent messages
  await DraftService.init();

  // Initialize avatar cache for instant profile picture loads
  await UserAvatar.initCache();

  // Restore the encrypted mobile auth cookie before AuthService starts.
  try {
    await ApiService.initializeSessionStorage().timeout(
      const Duration(seconds: 4),
      onTimeout: () => false,
    );
  } catch (error) {
    // Do not block runApp on a temporarily unavailable Android Keystore.
    debugPrint('[NovynStartup] Secure session storage is not ready yet: $error');
  }

  // Wake up backend server (eliminates 30s cold start on Render.com)
  ApiService.ping();

  runApp(NovynApp(settings: settings));
}

class NovynApp extends StatelessWidget {
  final SettingsService settings;
  const NovynApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<SocketService>(create: (ctx) {
          final socket = SocketService(
            initialStealthModeEnabled: ctx.read<SettingsService>().stealthModeEnabled,
          );
          // Connect once auth is ready via post-frame callback
          return socket;
        }),
        ChangeNotifierProvider<AuthService>(create: (ctx) {
          final socket = ctx.read<SocketService>();
          final auth = AuthService(
            savePresence: socket.updatePresence,
            savePassword: socket.changePassword,
            clearNotificationsToken: NotificationService.clearToken,
            onAccountReset: () async { socket.disconnect(); },
            onSessionRefreshed: socket.reconnectWithCurrentSession,
          );
          socket.onProfileData = auth.applyProfileUpdate;
          // Respect both the user's global notification switch and Busy presence.
          // Settings are loaded before runApp and provided above AuthService.
          socket.notificationsMuted = () =>
              !ctx.read<SettingsService>().notificationsOn ||
              !ctx.read<SettingsService>().inAppSounds ||
              auth.user?.presenceMode == 'busy';
          socket.notificationsVibrate = () async {
            final preferences = ctx.read<SettingsService>();
            if (preferences.notificationsOn &&
                preferences.inAppVibration &&
                auth.user?.presenceMode != 'busy') {
              await HapticService.vibrateNotification();
            }
          };
          socket.notificationTone = () =>
              ctx.read<SettingsService>().notificationTone;
          socket.messageSoundVolume = () =>
              ctx.read<SettingsService>().messageVolume;
          return auth;
        }),
        Provider<FriendService>(
          create: (ctx) => FriendService(ctx.read<SocketService>()),
        ),
        ChangeNotifierProvider<SyncService>(create: (_) => SyncService()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, s, _) {
          return MaterialApp(
            title: 'Novyn',
            debugShowCheckedModeBanner: false,
            theme: NovynTheme.lightTheme(accent: s.accentColorEnabled ? Color(s.accentColorValue) : NovynTheme.indigo, fontScale: s.fontSize, highContrast: s.highContrast),
            darkTheme: NovynTheme.darkTheme(accent: s.accentColorEnabled ? Color(s.accentColorValue) : NovynTheme.indigo, fontScale: s.fontSize, highContrast: s.highContrast),
            themeMode: s.themeMode,
            locale: Locale(s.language),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
              Locale('mr'),
              Locale('bn'),
              Locale('ta'),
              Locale('te'),
              Locale('es'),
              Locale('fr'),
              Locale('de'),
              Locale('it'),
              Locale('ja'),
              Locale('ko'),
              Locale('ru'),
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: s.reduceMotion),
              child: SessionLifecycleGuard(
                child: AppLockWrapper(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      child!,
                      ValueListenableBuilder<Widget?>(
                        valueListenable: CallOverlayService.miniCall,
                        builder: (context, miniCall, _) =>
                            miniCall ?? const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            home: const SplashScreenV2(),
          );
        },
      ),
    );
  }
}


class SessionLifecycleGuard extends StatefulWidget {
  const SessionLifecycleGuard({super.key, required this.child});
  final Widget child;

  @override
  State<SessionLifecycleGuard> createState() => _SessionLifecycleGuardState();
}

class _SessionLifecycleGuardState extends State<SessionLifecycleGuard>
    with WidgetsBindingObserver {
  static const _autoAwayDelay = Duration(minutes: 5);
  Timer? _autoAwayTimer;
  bool _setAwayAutomatically = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _scheduleAutoAway() {
    _autoAwayTimer?.cancel();
    final auth = context.read<AuthService>();
    // Auto-Away must never overwrite a user-selected Busy, Invisible or Away mode.
    if (auth.user?.presenceMode != 'online') return;

    _autoAwayTimer = Timer(_autoAwayDelay, () async {
      if (!mounted) return;
      final currentAuth = context.read<AuthService>();
      // Re-check before changing presence in case the user changed it elsewhere.
      if (currentAuth.user?.presenceMode != 'online') return;
      try {
        await currentAuth.updateStatus('away');
        _setAwayAutomatically = true;
      } catch (error) {
        debugPrint('[NovynPresence] Auto-Away update failed: $error');
      }
    });
  }

  Future<void> _restoreOnlineAfterAutoAway() async {
    if (!_setAwayAutomatically) return;
    _setAwayAutomatically = false;
    final auth = context.read<AuthService>();
    // Restore only if the status is still Away; never override a newer manual choice.
    if (auth.user?.presenceMode != 'away') return;
    try {
      await auth.updateStatus('online');
    } catch (error) {
      debugPrint('[NovynPresence] Could not restore Online after Auto-Away: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoAwayTimer?.cancel();
      context.read<SocketService>().setAppForeground(true);
      context.read<AuthService>().restoreSessionOnResume();
      unawaited(_restoreOnlineAfterAutoAway());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<SocketService>().setAppForeground(false);
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        _scheduleAutoAway();
      }
    }
  }

  @override
  void dispose() {
    _autoAwayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
