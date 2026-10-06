import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../widgets/navigation_icons.dart';
import '../widgets/neomorphic_widgets.dart';
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;

  // One jelly controller per tab
  late final List<AnimationController> _jellyControllers;
  late final List<Animation<double>> _scaleX;
  late final List<Animation<double>> _scaleY;

  late final List<Widget> _screens;

  static final _tabs = [
    _TabData(
      label: 'Chats',
      iconBuilder: (filled) => NovynNavIcons.chats(active: filled),
      activeColor: const Color(0xFF7C6FF7),
      activeBg:   const Color(0xFFECEAFD),
    ),
    _TabData(
      label: 'Calls',
      iconBuilder: (filled) => NovynNavIcons.calls(active: filled),
      activeColor: const Color(0xFF10B981),
      activeBg:   const Color(0xFFD1FAE5),
    ),
    _TabData(
      label: 'Discover',
      iconBuilder: (filled) => NovynNavIcons.discover(active: filled),
      activeColor: const Color(0xFFF59E0B),
      activeBg:   const Color(0xFFFEF3C7),
    ),
    _TabData(
      label: 'People',
      iconBuilder: (filled) => NovynNavIcons.people(active: filled),
      activeColor: const Color(0xFF0EA5E9),
      activeBg:   const Color(0xFFE0F4FE),
    ),
    _TabData(
      label: 'Profile',
      iconBuilder: (filled) => NovynNavIcons.profile(active: filled),
      activeColor: const Color(0xFFEC4899),
      activeBg:   const Color(0xFFFCE7F3),
    ),
  ];

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

    // Mark user as online + connect socket + init notifications
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthService>();
      auth.setOnline(true);
      final username = auth.user?.username;
      if (username != null) {
        // Connect socket to the shared novyn-chat backend
        final socket = context.read<SocketService>();
        socket.connect(ApiService.baseUrl, username);

        // Listen for user presence changes — update friend cache
        socket.onUserStatusChanged = (peerUsername, isOnline) {
          context.read<FriendService>().updateCachedStatus(peerUsername, isOnline);
        };

        // Pre-warm the backend
        ApiService.ping();

        // Init FCM notifications
        await NotificationService.init(context);
        await NotificationService.saveTokenForUser(username);

        // Listen for incoming calls globally
        socket.onCallInvite((data) async {
          final callerId = data['from']?.toString() ?? data['callerId']?.toString() ?? '';
          final callType = data['isVideo'] == true ? 'video' : 'voice';
          if (callerId.isEmpty || callerId == username || !mounted) return;

          // Build a minimal UserModel from the call data
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
                peer:       caller,
                callType:   callType,
                isIncoming: true,
                callerId:   callerId,
              ),
            ),
          );
        });
      }
    });

    _jellyControllers = List.generate(
      _tabs.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    // scaleX: squish wide then snap back (jelly squeeze)
    _scaleX = _jellyControllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 1.28)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 20),
        TweenSequenceItem(
            tween: Tween(begin: 1.28, end: 0.88)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 20),
        TweenSequenceItem(
            tween: Tween(begin: 0.88, end: 1.0)
                .chain(CurveTween(curve: Curves.elasticOut)),
            weight: 60),
      ]).animate(c);
    }).toList();

    // scaleY: inverse of scaleX (conservation of volume feel)
    _scaleY = _jellyControllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(
            tween: Tween(begin: 1.0, end: 0.78)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 20),
        TweenSequenceItem(
            tween: Tween(begin: 0.78, end: 1.14)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 20),
        TweenSequenceItem(
            tween: Tween(begin: 1.14, end: 1.0)
                .chain(CurveTween(curve: Curves.elasticOut)),
            weight: 60),
      ]).animate(c);
    }).toList();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AuthService>().setOnline(false);
    for (final c in _jellyControllers) {
      c.dispose();
    }
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
    HapticFeedback.lightImpact();
    setState(() => _selectedIndex = index);
    _jellyControllers[index].forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Total unread from cached chats
    final totalUnread = ChatsScreen.totalUnread;

    return _ChatsUnreadCount(
      count: totalUnread,
      child: Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: Stack(
        children: [
          Column(
            children: [
              // Offline banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: socket.isConnected ? 0 : 28,
                color: const Color(0xFFF59E0B),
                child: socket.isConnected
                    ? const SizedBox.shrink()
                    : const Center(
                        child: Text(
                          'Reconnecting...',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
          // Floating Bottom Nav overlaid on top
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
      ),  // close Scaffold
    );   // close _ChatsUnreadCount
  }

  Widget _buildBottomNav() {
    final pageBg = NovynTheme.pageBg(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: NeoContainer(
        borderRadius: 36,
        distance: 5,
        blur: 10,
        color: pageBg,
        height: 72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            _tabs.length,
            (i) => _buildNavItem(i),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isActive = _selectedIndex == index;
    final tab = _tabs[index];
    final iconColor = isActive ? tab.activeColor : const Color(0xFF94A3B8);

    // Unread badge — only on Chats tab (index 0)
    final showBadge = index == 0 && _ChatsUnreadCount.of(context) > 0;
    final badgeCount = _ChatsUnreadCount.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTap(index),
      child: SizedBox(
        width: 60,
        child: Center(
          child: AnimatedBuilder(
            animation: _jellyControllers[index],
            builder: (context, child) {
              return Transform.scale(
                scaleX: _scaleX[index].value,
                scaleY: _scaleY[index].value,
                child: child,
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                NeoContainer(
                  borderRadius: 20,
                  distance: isActive ? 2.5 : 0,
                  blur: isActive ? 5 : 0,
                  isSunken: isActive,
                  width: 48,
                  height: 48,
                  child: Center(
                    child: _ColoredIcon(
                      icon: tab.iconBuilder(isActive),
                      color: iconColor,
                    ),
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Unread count provider for tab badge ───────────────────────────────────
class _ChatsUnreadCount extends InheritedWidget {
  final int count;
  const _ChatsUnreadCount({required this.count, required super.child});

  static int of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_ChatsUnreadCount>()
            ?.count ??
        0;
  }

  @override
  bool updateShouldNotify(_ChatsUnreadCount old) => old.count != count;
}

// ── Tab data ──────────────────────────────────────────────────────────────────
class _TabData {
  final String label;
  final Widget Function(bool isFilled) iconBuilder;
  final Color activeColor;
  final Color activeBg;
  const _TabData({
    required this.label,
    required this.iconBuilder,
    required this.activeColor,
    required this.activeBg,
  });
}

// Wraps a custom icon painter and injects the current colour
class _ColoredIcon extends StatelessWidget {
  final Widget icon;
  final Color color;
  const _ColoredIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: color, size: 22),
      child: icon,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Custom icon painters — drawn to match the reference screenshot style
//  All use IconTheme colour so active/inactive tinting is automatic.
// ═══════════════════════════════════════════════════════════════════════════


