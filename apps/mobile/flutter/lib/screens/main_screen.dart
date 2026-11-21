import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../theme/novyn_theme.dart';
import 'chats/chats_screen.dart';
import 'calls/calls_screen.dart';
import 'calls/call_screen.dart';
import 'auth/auth_screen.dart';
import 'people/people_screen.dart';
import 'games/games_screen.dart';
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
import '../services/backup_automation_service.dart';
import '../services/profile_deep_link_service.dart';
import 'profile/public_profile_screen.dart';
import 'profile/settings/about_novyn_screen.dart';

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
  bool _redirectingForInvalidSession = false;
  Timer? _updateCheckTimer;
  DateTime? _lastUpdateCheck;
  StreamSubscription<String>? _profileLinkSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _networkWasUnavailable = false;
  bool _networkRecoveryInProgress = false;
  bool _forceSocketRecoveryPending = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    if (widget.managePresence) {
      NotificationService.setSocialNotificationTapHandler((type) {
        if (!mounted) return;
        // Friend-request events belong in Contacts; a group invitation belongs
        // in Chats so the newly added group is immediately visible.
        _onTabTap(type == 'group_invite' ? 0 : 1);
      });
      NotificationService.setGroupNotificationTapHandler(() {
        if (mounted) _onTabTap(0);
      });
    }
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChanged);
    _profileLinkSubscription = ProfileDeepLinkService.links.listen(_openProfileLink);
    unawaited(ProfileDeepLinkService.initialize().then((_) {
      final pendingLink = ProfileDeepLinkService.takePendingLink();
      if (pendingLink != null) _openProfileLink(pendingLink);
    }));
    NotificationService.setAppUpdateTapHandler(_openAboutNovyn);
    _updateCheckTimer = Timer.periodic(
      AppUpdateService.backgroundCheckFrequency,
      (_) => _runUpdateCheck(force: true),
    );
    // Main navigation: Chats, Contacts, Games, Calls, Settings.
    // Discover is opened from inside Contacts rather than taking a bottom-tab slot.
    _screens = [
      ChatsScreen(onNavigateToPeople: () => _onTabTap(1)),
      const PeopleScreen(),
      const GamesScreen(),
      const CallsScreen(),
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

  void _openProfileLink(String rawLink) {
    final username = ProfileDeepLinkService.usernameFromLink(rawLink);
    if (username == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push<void>(
        NovynPageRoute<void>(child: PublicProfileScreen(username: username)),
      );
    });
  }

  void _openAboutNovyn(BuildContext hostContext) {
    if (!hostContext.mounted) return;
    unawaited(AppUpdateService.instance.markUpdateNotificationOpened());
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
      debugPrint('[NovynUpdates] Foreground check failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_runUpdateCheck());
      // Validate/refresh the REST session before reconnecting Socket.IO. The
      // AuthService coalesces this with SessionLifecycleGuard's resume check.
      unawaited(_restoreSessionAndRecover());
    }
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.any((result) => result != ConnectivityResult.none);
    if (!online) {
      _networkWasUnavailable = true;
      return;
    }
    final networkReturned = _networkWasUnavailable;
    _networkWasUnavailable = false;
    unawaited(_restoreSessionAndRecover(forceSocketReconnect: networkReturned));
  }

  Future<void> _restoreSessionAndRecover({bool forceSocketReconnect = false}) async {
    if (!mounted || !widget.managePresence) return;
    if (_networkRecoveryInProgress) {
      _forceSocketRecoveryPending =
          _forceSocketRecoveryPending || forceSocketReconnect;
      return;
    }
    _networkRecoveryInProgress = true;
    var forceReconnect = forceSocketReconnect;
    try {
      do {
        _forceSocketRecoveryPending = false;
        final auth = _authService ?? context.read<AuthService>();
        // Revalidate/refresh the REST session before rebuilding Socket.IO.
        await auth.restoreSessionOnResume();
        if (!mounted) return;
        final backupUsername = auth.user?.username.trim() ?? '';
        if (backupUsername.isNotEmpty) {
          unawaited(BackupAutomationService.runIfDue(
            username: backupUsername,
            encryption: context.read<SocketService>().encryption,
          ));
        }
        _recoverSocketIfNeeded(forceReconnect: forceReconnect);
        forceReconnect = _forceSocketRecoveryPending;
      } while (mounted && forceReconnect);
    } finally {
      _networkRecoveryInProgress = false;
      if (mounted && _forceSocketRecoveryPending) {
        _forceSocketRecoveryPending = false;
        unawaited(_restoreSessionAndRecover(forceSocketReconnect: true));
      }
    }
  }

  void _recoverSocketIfNeeded({bool forceReconnect = false}) {
    if (!mounted || !widget.managePresence) return;
    final auth = _authService ?? context.read<AuthService>();
    final username = auth.user?.username.trim();
    if (username == null || username.isEmpty) return;

    // Cached identity keeps local data available while offline, but it is not
    // proof of a live backend session. Do not open a socket without an access
    // cookie restored/renewed by AuthService first.
    if (!ApiService.hasAccessSessionCookie) return;

    final socket = context.read<SocketService>();
    final sameAccount =
        socket.myUsername?.toLowerCase() == username.toLowerCase();
    if (!sameAccount) {
      socket.connect(ApiService.baseUrl, username);
      return;
    }

    // Force a replacement only after an actual network transition. For an
    // ordinary resume, let an existing connect/auth handshake finish; calling
    // reconnectWithCurrentSession repeatedly would dispose a healthy in-flight
    // socket handshake and keep the app stuck in "verifying session".
    if (forceReconnect) {
      unawaited(socket.reconnectWithCurrentSession());
    } else if (!socket.isConnected && !socket.isConnecting) {
      socket.connect(ApiService.baseUrl, username);
    }
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    final auth = _authService ?? context.read<AuthService>();
    final username = auth.user?.username.trim();
    if (username == null || username.isEmpty) {
      _activeUsername = null;
      if (auth.sessionInvalidated && !_redirectingForInvalidSession) {
        _redirectingForInvalidSession = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final currentAuth = context.read<AuthService>();
          if (!currentAuth.sessionInvalidated || currentAuth.user != null) {
            _redirectingForInvalidSession = false;
            return;
          }
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
            NovynPageRoute<void>(child: const AuthScreen()),
            (route) => false,
          );
        });
      }
      return;
    }
    _redirectingForInvalidSession = false;

    final socket = context.read<SocketService>();
    final sameAccount =
        _activeUsername?.toLowerCase() == username.toLowerCase();
    if (sameAccount && socket.isConnected && socket.isAuthenticated) {
      context.read<FriendService>().activateAccount(username);
      return;
    }
    // A same-account login can happen while MainScreen remains mounted.
    // Reconnect if its previous socket was disconnected during logout.
    _activeUsername = username;
    auth.setOnline(true);
    // Keep the local account cache available immediately, but do not create a
    // socket handshake until secure cookies have been restored and the REST
    // session check (including any refresh-token rotation) has completed.
    context.read<FriendService>().activateAccount(username);
    socket.onUserStatusChanged = (peerUsername, isOnline) {
      if (!mounted) return;
      context.read<FriendService>().updateCachedStatus(peerUsername, isOnline);
    };
    unawaited(_restoreSessionAndRecover());
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
            callExpiresAt: int.tryParse(data['callExpiresAt']?.toString() ?? '') == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    int.parse(data['callExpiresAt'].toString()),
                  ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileLinkSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _updateCheckTimer?.cancel();
    NotificationService.setAppUpdateTapHandler(null);
    NotificationService.setSocialNotificationTapHandler(null);
    NotificationService.setGroupNotificationTapHandler(null);
    _authService?.removeListener(_handleAuthChanged);
    if (widget.managePresence && _authService?.user != null) {
      _authService!.setOnline(false);
    }
    try {
      final socket = context.read<SocketService>();
      socket.onCallInviteCallback = null;
      socket.onUserStatusChanged = null;
    } catch (_) {}
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
                            child: RepaintBoundary(
                              child: AnimatedSlide(
                                offset: slideOffset,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                child: AnimatedOpacity(
                                  opacity: isSelected ? 1 : 0,
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  child: TickerMode(
                                    enabled: isSelected,
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
