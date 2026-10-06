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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

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
          context
              .read<FriendService>()
              .updateCachedStatus(peerUsername, isOnline);
        };

        // Pre-warm the backend
        ApiService.ping();

        // Init FCM notifications
        await NotificationService.init(context);
        await NotificationService.saveTokenForUser(username);

        // Listen for incoming calls globally
        socket.onCallInvite((data) async {
          final callerId =
              data['from']?.toString() ?? data['callerId']?.toString() ?? '';
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
                peer: caller,
                callType: callType,
                isIncoming: true,
                callerId: callerId,
              ),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AuthService>().setOnline(false);
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
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.read<SocketService>();
    final connected =
        context.select<SocketService, bool>((socket) => socket.isConnected);

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: Stack(
        children: [
          Column(
            children: [
              // Offline banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: connected ? 0 : 28,
                color: const Color(0xFFF59E0B),
                child: connected
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
                  children: List.generate(
                      _screens.length,
                      (index) => TickerMode(
                          enabled: index == _selectedIndex,
                          child: RepaintBoundary(child: _screens[index]))),
                ),
              ),
            ],
          ),
          // Floating Bottom Nav overlaid on top
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Selector<SocketService, int>(
              selector: (_, service) => service.conversations
                  .fold(0, (total, chat) => total + chat.unreadCount),
              builder: (context, unreadCount, _) => AnimatedBuilder(
                animation: socket.contacts,
                builder: (context, _) => NovynDock(
                  selectedIndex: _selectedIndex,
                  onSelected: _onTabTap,
                  unreadCount: unreadCount,
                  requestCount: socket.contacts.requests.length,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
