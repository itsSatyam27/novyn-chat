import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/novyn_theme.dart';
import 'chats/chats_screen.dart';
import 'calls/calls_screen.dart';
import 'calls/call_screen.dart';
import 'people/people_screen.dart';
import 'discover/discover_screen.dart';
import 'profile/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../services/friend_service.dart';
import '../models/user_model.dart';
import '../widgets/novyn_dock.dart';
import '../services/settings_service.dart';
import 'package:novyn/services/haptic_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  AuthService? _authService;
  String? _activeUsername;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Build screens — ChatsScreen gets a callback to switch to People tab (index 2)
    _screens = [
      ChatsScreen(onNavigateToPeople: () => _onTabTap(3)), // index 3 now
      const CallsScreen(),
      const DiscoverScreen(),
      const PeopleScreen(),
      const ProfileScreen(),
    ];

    // Auth can change without MainScreen being recreated (logout -> login).
    // Reconnect the socket whenever a signed-in identity becomes available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authService = context.read<AuthService>();
      _authService!.addListener(_handleAuthChanged);
      _handleAuthChanged();
    });
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    final auth = _authService ?? context.read<AuthService>();
    final username = auth.user?.username.trim();
    if (username == null || username.isEmpty) {
      _activeUsername = null;
      return;
    }

    final socket = context.read<SocketService>();
    if (_activeUsername?.toLowerCase() == username.toLowerCase()) {
      return;
    }
    _activeUsername = username;
    auth.setOnline(true);
    socket.connect(ApiService.baseUrl, username);
    socket.onUserStatusChanged = (peerUsername, isOnline) {
      if (!mounted) return;
      context.read<FriendService>().updateCachedStatus(peerUsername, isOnline);
    };
    ApiService.ping();

    unawaited(() async {
      await NotificationService.init(context);
      if (!mounted || auth.user?.username.toLowerCase() != username.toLowerCase()) return;
      await NotificationService.saveTokenForUser(username);
    }());

    socket.onCallInvite((data) async {
      final callerId =
          data['from']?.toString() ?? data['callerId']?.toString() ?? '';
      final callType = data['isVideo'] == true ? 'video' : 'voice';
      if (callerId.isEmpty || callerId.toLowerCase() == username.toLowerCase() || !mounted) return;

      final caller = UserModel(
        uid: callerId,
        name: data['fromDisplayName']?.toString() ?? callerId,
        username: callerId,
        email: '',
        bio: '',
        createdAt: DateTime.now(),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            peer: caller,
            callType: callType,
            isIncoming: true,
            callerId: callerId,
            callId: data['callId']?.toString(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authService?.removeListener(_handleAuthChanged);
    if (_authService?.user != null) _authService!.setOnline(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = context.read<AuthService>();
    if (state == AppLifecycleState.resumed) {
      auth.setOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      auth.setOnline(false);
    }
  }

  void _onTabTap(int index) {
    if (index == _selectedIndex) return;
    HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.navigation);
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.read<SocketService>();
    // The Scaffold resizes its body above the keyboard. Keep the floating dock
    // out of that resized area while typing instead of letting it ride above it.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      // Let Android close the app only from the Chats tab. From every other
      // main tab, the first Back press returns to Chats instead.
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _selectedIndex == 0 || !mounted) return;
        setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: NovynTheme.pageBg(context),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: List.generate(
                      _screens.length,
                      (index) => TickerMode(
                          enabled: index == _selectedIndex,
                          child: RepaintBoundary(child: _screens[index]))),
                ),
              ),
            ],
          ),
          // Floating Bottom Nav. Hide it while the keyboard is open so it
          // never jumps up and competes with the chat composer.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: keyboardVisible ? const Offset(0, 1.15) : Offset.zero,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: IgnorePointer(
                ignoring: keyboardVisible,
                child: AnimatedOpacity(
                  opacity: keyboardVisible ? 0 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: Selector<SettingsService, String>(
                    selector: (_, service) => service.dockStyle,
                    builder: (context, dockStyle, _) => Selector<SocketService, int>(
                      selector: (_, service) => service.conversations
                          .fold(0, (total, chat) => total + chat.unreadCount),
                      builder: (context, unreadCount, _) => AnimatedBuilder(
                        animation: socket.contacts,
                        builder: (context, _) => NovynDock(
                          selectedIndex: _selectedIndex,
                          onSelected: _onTabTap,
                          unreadCount: unreadCount,
                          requestCount: socket.contacts.requests.length,
                          style: dockStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
