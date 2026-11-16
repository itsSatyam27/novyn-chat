import 'dart:async';
import 'package:flutter/material.dart';
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
import '../widgets/novyn_page_route.dart';
import '../services/settings_service.dart';
import '../services/app_update_service.dart';
import 'profile/settings/support_screens.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    this.managePresence = true,
    this.onCallHostExit,
  });
  final bool managePresence;
  final VoidCallback? onCallHostExit;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _previousSelectedIndex = 0;
  int _tabTransitionDirection = 1;
  double _horizontalDragDistance = 0;
  AuthService? _authService;
  String? _activeUsername;
  Timer? _updateCheckTimer;
  DateTime? _lastUpdateCheck;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.setAppUpdateTapHandler(_openAboutNovyn);
    _updateCheckTimer = Timer.periodic(
      AppUpdateService.backgroundCheckFrequency,
      (_) => _runUpdateCheck(force: true),
    );
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
      if (!mounted || !widget.managePresence) return;
      _authService = context.read<AuthService>();
      _authService!.addListener(_handleAuthChanged);
      _handleAuthChanged();
    });
  }

  void _openAboutNovyn(BuildContext hostContext) {
    if (!hostContext.mounted) return;
    Navigator.of(hostContext).push<void>(
      NovynPageRoute<void>(child: const AboutNovynScreen()),
    );
  }

  Future<void> _runUpdateCheck({bool force = false}) async {
    if (!mounted) return;
    final now = DateTime.now();
    if (!force &&
        _lastUpdateCheck != null &&
        now.difference(_lastUpdateCheck!) < const Duration(minutes: 15)) {
      return;
    }
    _lastUpdateCheck = now;
    try {
      await AppUpdateService.instance.checkForUpdates(notifyIfAvailable: true);
    } catch (error) {
      debugPrint('[NovynUpdates] Foreground check failed: ' + error.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_runUpdateCheck());
    }
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
    final sameAccount =
        _activeUsername?.toLowerCase() == username.toLowerCase();
    if (sameAccount && socket.isConnected) return;
    // A same-account login can happen while MainScreen remains mounted.
    // Reconnect if its previous socket was disconnected during logout.
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
      unawaited(_runUpdateCheck(force: true));
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
      Navigator.of(context).push<void>(
        NovynPageRoute<void>(
          child: CallScreen(
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
    _updateCheckTimer?.cancel();
    NotificationService.setAppUpdateTapHandler(null);
    _authService?.removeListener(_handleAuthChanged);
    if (widget.managePresence && _authService?.user != null) {
      _authService!.setOnline(false);
    }
    widget.onCallHostExit?.call();
    super.dispose();
  }

  void _setSelectedTab(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _previousSelectedIndex = _selectedIndex;
      _tabTransitionDirection = index > _selectedIndex ? 1 : -1;
      _selectedIndex = index;
    });
  }

  void _onTabTap(int index) => _setSelectedTab(index);

  void _onMainSwipeStart(DragStartDetails details) {
    _horizontalDragDistance = 0;
  }

  void _onMainSwipeUpdate(DragUpdateDetails details) {
    _horizontalDragDistance += details.delta.dx;
  }

  void _onMainSwipeEnd(DragEndDetails details) {
    final distance = _horizontalDragDistance;
    final velocity = details.primaryVelocity ?? 0;
    _horizontalDragDistance = 0;

    // Swipe left -> next tab; swipe right -> previous tab.
    // Requiring either a deliberate drag distance or a clear fling keeps
    // small horizontal movements from unexpectedly changing screens.
    final isSwipeLeft = distance <= -60 || velocity <= -350;
    final isSwipeRight = distance >= 60 || velocity >= 350;
    if (!isSwipeLeft && !isSwipeRight) return;

    final nextIndex = (_selectedIndex + (isSwipeLeft ? 1 : -1))
        .clamp(0, _screens.length - 1);
    if (nextIndex != _selectedIndex) {
      _setSelectedTab(nextIndex);
    }
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
        _setSelectedTab(0);
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
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _onMainSwipeStart,
                  onHorizontalDragUpdate: _onMainSwipeUpdate,
                  onHorizontalDragEnd: _onMainSwipeEnd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: List.generate(_screens.length, (index) {
                      final isSelected = index == _selectedIndex;
                      final isOutgoing =
                          index == _previousSelectedIndex && !isSelected;
                      final slideDirection = isOutgoing
                          ? -_tabTransitionDirection
                          : _tabTransitionDirection;
                      final slideOffset = isSelected
                          ? Offset.zero
                          : Offset(slideDirection * 0.025, 0);

                      return Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !isSelected,
                          child: ExcludeSemantics(
                            excluding: !isSelected,
                            child: TickerMode(
                              enabled: isSelected,
                              child: RepaintBoundary(
                                child: AnimatedSlide(
                                  offset: slideOffset,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    opacity: isSelected ? 1 : 0,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    child: _screens[index],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
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
