import 'package:flutter/material.dart';
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
import 'services/security_service.dart';
import 'models/chat_models.dart';
import 'models/user_model.dart';
import 'widgets/user_avatar.dart' show UserAvatar;
import 'theme/novyn_theme.dart';
import 'screens/splash/splash_screen_v2.dart';
import 'widgets/app_lock_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseConfiguration.options,
  );

  // Register background message handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final settings = SettingsService();
  await settings.load();
  // Re-apply native screen-capture protection after every cold start.
  await SecurityService.setSafeMode(settings.stealthModeEnabled);

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
  await ApiService.initializeSessionStorage();

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
          final socket = SocketService();
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
                child: AppLockWrapper(child: child!),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthService>().restoreSessionOnResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
