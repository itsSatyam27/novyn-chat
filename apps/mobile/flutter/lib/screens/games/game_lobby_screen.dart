import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_models.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/novyn_alert.dart';
import '../../widgets/user_avatar.dart';
import 'game_room_screen.dart';

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({
    super.key,
    required this.gameType,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.playerLevel = 1,
  });

  final String gameType;
  final String title;
  final String subtitle;
  final IconData icon;
  final int playerLevel;

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  StreamSubscription<List<UserModel>>? _friendsSubscription;
  AuthService? _auth;
  SocketService? _socket;
  String? _account;
  List<UserModel> _friends = const <UserModel>[];
  String? _selectedFriend;
  bool _loadingFriends = true;
  bool _sendingInvite = false;
  bool _searchingRandom = false;
  bool _cancellingMatchmaking = false;
  bool _reconnecting = false;
  bool _searchEndedByDisconnect = false;
  bool _friendsLoadFailed = false;
  int _friendInviteSecondsRemaining = 60;
  final ValueNotifier<int> _friendInviteCountdown = ValueNotifier<int>(60);
  final ValueNotifier<bool> _friendInviteAccepted = ValueNotifier<bool>(false);
  final ValueNotifier<int> _queueCountdown = ValueNotifier<int>(60);
  String? _pendingFriendInviteId;
  UserModel? _pendingInviteFriend;
  Map<String, dynamic>? _pendingInviteGame;
  String _pendingInviteOpponentName = '';
  String _pendingInviteCurrentUser = '';
  BuildContext? _friendWaitingSheetContext;
  DateTime? _queueDeadline;
  Timer? _queueTimer;
  Timer? _friendInviteTimer;
  bool _backgroundRouteOpen = false;
  bool _matchmakingRouteOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _auth = context.read<AuthService>();
      _socket = context.read<SocketService>();
      _auth!.addListener(_handleAuthChanged);
      _socket!.onRandomMatchFound = _handleRandomMatchFound;
      _socket!.onRandomMatchTimeout = _handleRandomMatchTimeout;
      _socket!.onGameInviteAccepted = _handleGameInviteAccepted;
      _socket!.onGameInviteTimeout = _handleGameInviteTimeout;
      _socket!.addListener(_handleSocketStateChanged);
      _subscribeToFriends();
    });
  }

  @override
  void dispose() {
    _auth?.removeListener(_handleAuthChanged);
    _queueTimer?.cancel();
    _friendInviteTimer?.cancel();
    _searchController.dispose();
    _friendInviteCountdown.dispose();
    _friendInviteAccepted.dispose();
    _queueCountdown.dispose();
    if (_socket != null) {
      _socket!.removeListener(_handleSocketStateChanged);
      _socket!.onRandomMatchFound = null;
      _socket!.onRandomMatchTimeout = null;
      _socket!.onGameInviteAccepted = null;
      _socket!.onGameInviteTimeout = null;
      if (_searchingRandom) {
        unawaited(_socket!.cancelRandomGame().catchError((_) {}));
      }
    }
    unawaited(_friendsSubscription?.cancel());
    super.dispose();
  }

  bool get _connectionReady =>
      _socket?.isConnected == true && _socket?.isAuthenticated == true;

  void _closeRandomSearchRoutes() {
    // A background-search route can be stacked above the dedicated animated
    // matchmaking route. Remove both in top-first order so match-found,
    // timeout and cancel never leave a stale search screen underneath.
    if (_backgroundRouteOpen) {
      _backgroundRouteOpen = false;
      Navigator.of(context).pop();
    }
    if (_matchmakingRouteOpen) {
      _matchmakingRouteOpen = false;
      Navigator.of(context).pop();
    }
  }

  void _handleSocketStateChanged() {
    if (!mounted || !_searchingRandom || _connectionReady) return;
    _queueTimer?.cancel();
    _closeRandomSearchRoutes();
    setState(() {
      _searchingRandom = false;
      _cancellingMatchmaking = false;
      _queueDeadline = null;
      _searchEndedByDisconnect = true;
    });
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    final username = _auth?.user?.username.trim().toLowerCase();
    if (username != _account) _subscribeToFriends();
  }

  void _subscribeToFriends({bool force = false}) {
    final username = _auth?.user?.username.trim() ?? '';
    final owner = username.toLowerCase();
    if (owner == _account && !force) return;
    _account = owner;
    unawaited(_friendsSubscription?.cancel());
    _friendsSubscription = null;
    _friends = const <UserModel>[];
    _selectedFriend = null;
    _friendsLoadFailed = false;
    if (username.isEmpty) {
      setState(() => _loadingFriends = false);
      return;
    }
    setState(() => _loadingFriends = true);
    _friendsSubscription = context.read<FriendService>().friendsStream(username).listen(
      (friends) {
        if (!mounted || _account != owner) return;
        final sorted = List<UserModel>.from(friends)
          ..sort((a, b) {
            if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        setState(() {
          _friends = sorted;
          _friendsLoadFailed = false;
          if (!_friends.any((friend) =>
              friend.username.toLowerCase() == _selectedFriend)) {
            _selectedFriend = sorted.isEmpty
                ? null
                : sorted.first.username.toLowerCase();
          }
          _loadingFriends = false;
        });
      },
      onError: (_) {
        if (mounted && _account == owner) {
          setState(() {
            _loadingFriends = false;
            _friendsLoadFailed = true;
          });
        }
      },
    );
  }

  UserModel? get _selectedFriendModel {
    for (final friend in _friends) {
      if (friend.username.toLowerCase() == _selectedFriend) return friend;
    }
    return null;
  }

  String _presence(UserModel friend) {
    final value = friend.status.trim().toLowerCase();
    if (!friend.isOnline || value == 'offline' || value == 'invisible') {
      return 'Offline';
    }
    if (value == 'busy' || value == 'dnd') return 'Busy';
    if (value == 'away' || value == 'idle') return 'Away';
    return 'Online';
  }

  Future<void> _playWithFriend(UserModel friend) async {
    if (_sendingInvite || _searchingRandom || _pendingFriendInviteId != null) return;
    setState(() => _sendingInvite = true);
    try {
      final socket = _socket ?? context.read<SocketService>();
      final messageId =
          await socket.sendGameChallenge(widget.gameType, friend.username);
      final messages = await socket.openChat(friend.username, const <Message>[]);
      Message? gameMessage;
      for (final message in messages) {
        if (message.id == messageId && message.game != null) {
          gameMessage = message;
          break;
        }
      }
      if (!mounted) return;
      if (gameMessage == null) {
        throw StateError(
          'The invitation was sent, but the game room could not be loaded. Open the chat and try again.',
        );
      }
      final initialGameData = Map<String, dynamic>.from(gameMessage.game!);
      final opponentName = friend.name.isEmpty ? friend.username : friend.name;
      final currentUserName = socket.myUsername ?? _auth?.user?.username ?? '';
      _friendInviteTimer?.cancel();
      _pendingFriendInviteId = messageId;
      _pendingInviteFriend = friend;
      _pendingInviteGame = initialGameData;
      _pendingInviteOpponentName = opponentName;
      _pendingInviteCurrentUser = currentUserName;
      _friendInviteCountdown.value = 60;
      _friendInviteAccepted.value = false;
      _friendInviteSecondsRemaining = 60;
      _friendInviteTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _pendingFriendInviteId != messageId) {
          timer.cancel();
          return;
        }
        final next = _friendInviteSecondsRemaining - 1;
        _friendInviteSecondsRemaining = next.clamp(0, 60);
        _friendInviteCountdown.value = _friendInviteSecondsRemaining;
        if (_friendInviteSecondsRemaining == 0) {
          timer.cancel();
          _handleGameInviteTimeout({'messageId': messageId, 'gameType': widget.gameType});
        }
      });

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          _friendWaitingSheetContext = sheetContext;
          return _FriendInviteWaitingSheet(
            friend: friend,
            currentUser: _auth?.user,
            accepted: _friendInviteAccepted,
            onStart: _openPendingFriendGame,
            onCancel: () => _cancelPendingFriendInvite(leaveLobby: false),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      NovynAlert.show(
        context,
        error is StateError
            ? error.message.toString()
            : 'Could not open the game room. Check your connection and try again.',
        isError: true,
        title: 'Could not start game',
        icon: Icons.sports_esports_rounded,
      );
    } finally {
      if (mounted) setState(() => _sendingInvite = false);
    }
  }

  Future<void> _startRandomSearch() async {
    if (_searchingRandom || _cancellingMatchmaking) return;
    if (_pendingFriendInviteId != null) {
      NovynAlert.show(
        context,
        'Finish or cancel your pending friend invite before starting public matchmaking.',
        title: 'Invite still active',
        icon: Icons.people_outline_rounded,
      );
      return;
    }
    final socket = _socket ?? context.read<SocketService>();
    if (!socket.isConnected || !socket.isAuthenticated) {
      NovynAlert.show(
        context,
        'Reconnect to Novyn before searching for an opponent.',
        title: 'Connection needed',
        icon: Icons.wifi_off_rounded,
      );
      return;
    }
    setState(() {
      _searchingRandom = true;
      _searchEndedByDisconnect = false;
      _queueCountdown.value = 60;
      _queueDeadline = DateTime.now().add(const Duration(seconds: 60));
    });
    try {
      await socket.joinRandomGame(widget.gameType, playerLevel: widget.playerLevel);
      if (!mounted || !_searchingRandom) return;
      _queueTimer?.cancel();
      _queueTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_searchingRandom) {
          timer.cancel();
          return;
        }
        final deadline = _queueDeadline;
        if (deadline == null) return;
        final remaining = deadline.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          timer.cancel();
          _handleRandomMatchTimeout({
            'gameType': widget.gameType,
            'message': 'No player found right now. Please try again.',
          });
          return;
        }
        _queueCountdown.value = remaining.clamp(0, 60);
      });
      if (!_matchmakingRouteOpen && mounted) {
        _matchmakingRouteOpen = true;
        unawaited(Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => _RandomMatchmakingScreen(
              gameTitle: widget.title,
              countdown: _queueCountdown,
              onCancel: () => _cancelRandomSearch(),
            ),
          ),
        ).whenComplete(() {
          _matchmakingRouteOpen = false;
        }));
      }
    } catch (error) {
      _queueTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _searchingRandom = false;
        _queueDeadline = null;
      });
      NovynAlert.show(
        context,
        error is StateError
            ? error.message.toString()
            : 'Could not start matchmaking. Check your connection and try again.',
        isError: true,
        title: 'Matchmaking unavailable',
        icon: Icons.group_off_rounded,
      );
    }
  }

  Future<void> _reconnect() async {
    if (_reconnecting) return;
    setState(() => _reconnecting = true);
    try {
      await (_socket ?? context.read<SocketService>())
          .reconnectWithCurrentSession();
    } catch (_) {
      if (mounted) {
        NovynAlert.show(
          context,
          'Novyn could not reconnect. Check your network and try again.',
          isError: true,
          title: 'Reconnect failed',
          icon: Icons.wifi_off_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  Future<void> _cancelRandomSearch({bool leaveLobby = false}) async {
    if (!_searchingRandom || _cancellingMatchmaking) {
      if (leaveLobby && mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _cancellingMatchmaking = true);
    try {
      await (_socket ?? context.read<SocketService>()).cancelRandomGame();
      if (!mounted) return;
      _queueTimer?.cancel();
      setState(() {
        _searchingRandom = false;
        _cancellingMatchmaking = false;
        _queueDeadline = null;
      });
      _closeRandomSearchRoutes();
      if (leaveLobby) {
        if (_backgroundRouteOpen) {
          _backgroundRouteOpen = false;
          Navigator.of(context).pop();
        }
        if (mounted) Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _cancellingMatchmaking = false);
      NovynAlert.show(
        context,
        error is StateError
            ? error.message.toString()
            : 'Could not cancel matchmaking. Your search is still active.',
        isError: true,
        title: 'Matchmaking still active',
        icon: Icons.group_off_rounded,
      );
    }
  }

  Future<void> _handleBack() async {
    final friendInvitePending = _pendingFriendInviteId != null;
    if (!_searchingRandom && !friendInvitePending) {
      Navigator.of(context).pop();
      return;
    }
    final isFriendInvite = friendInvitePending && !_searchingRandom;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isFriendInvite ? 'Waiting for your friend' : 'Matchmaking in progress'),
        content: Text(isFriendInvite
            ? 'The invite stays active for ${_friendInviteSecondsRemaining}s. Keep waiting in the background or cancel it.'
            : 'Your search can keep running while you leave this screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('stay'),
            child: const Text('Stay here'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            child: Text(isFriendInvite ? 'Cancel invite' : 'Cancel search'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('background'),
            child: const Text('Keep searching'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'cancel') {
      if (isFriendInvite) {
        await _cancelPendingFriendInvite(leaveLobby: true);
      } else {
        await _cancelRandomSearch(leaveLobby: true);
      }
      return;
    }
    _showBackgroundSearch(isFriendInvite: isFriendInvite);
  }

  void _showBackgroundSearch({bool isFriendInvite = false}) {
    if (_backgroundRouteOpen) return;
    _backgroundRouteOpen = true;
    unawaited(Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MatchmakingBackgroundScreen(
          title: isFriendInvite ? _pendingInviteFriend?.name ?? 'your friend' : widget.title,
          countdown: isFriendInvite ? _friendInviteCountdown : _queueCountdown,
          isFriendInvite: isFriendInvite,
          onReturn: () => Navigator.of(context).pop(),
          onCancel: isFriendInvite
              ? () => _cancelPendingFriendInvite(leaveLobby: true)
              : () => _cancelRandomSearch(leaveLobby: true),
        ),
      ),
    ).whenComplete(() {
      _backgroundRouteOpen = false;
      if (mounted) setState(() {});
    }));
  }

  Future<void> _cancelPendingFriendInvite({bool leaveLobby = false}) async {
    final inviteId = _pendingFriendInviteId;
    if (inviteId == null) return;
    try {
      await (_socket ?? context.read<SocketService>()).cancelGameInvite(inviteId);
      if (!mounted) return;
      final sheetContext = _friendWaitingSheetContext;
      if (sheetContext != null && sheetContext.mounted) Navigator.of(sheetContext).pop();
      _clearPendingFriendInvite();
      if (_backgroundRouteOpen) Navigator.of(context).pop();
      if (leaveLobby && mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      NovynAlert.show(
        context,
        error is StateError ? error.message.toString() : 'Could not cancel the invite. Please try again.',
        isError: true,
        title: 'Invite is still active',
        icon: Icons.sync_problem_rounded,
      );
    }
  }

  void _handleRandomMatchFound(Map data) {
    if (!mounted || !_searchingRandom) return;
    final gameType = data['gameType']?.toString();
    if (gameType != widget.gameType) return;
    _queueTimer?.cancel();
    final sessionId = data['sessionId']?.toString() ?? '';
    final opponent = data['opponent'] is Map
        ? Map<String, dynamic>.from(data['opponent'] as Map)
        : <String, dynamic>{};
    final game = data['game'] is Map
        ? Map<String, dynamic>.from(data['game'] as Map)
        : _socket?.randomGameFor(sessionId);
    setState(() {
      _searchingRandom = false;
      _cancellingMatchmaking = false;
      _queueDeadline = null;
      _searchEndedByDisconnect = false;
    });
    if (sessionId.isEmpty || game == null) {
      _closeRandomSearchRoutes();
      NovynAlert.show(
        context,
        'A player was found, but the game room could not be created. Please try again.',
        isError: true,
        title: 'Could not open game',
        icon: Icons.sync_problem_rounded,
      );
      return;
    }
    _closeRandomSearchRoutes();
    final currentUsername = _socket?.myUsername ?? _auth?.user?.username ?? '';
    final opponentUsername = opponent['username']?.toString() ?? '';
    final opponentName = opponent['displayName']?.toString().trim().isNotEmpty == true
        ? opponent['displayName'].toString()
        : (opponentUsername.isNotEmpty ? opponentUsername : 'Player');
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _RandomMatchFoundScreen(
          gameTitle: widget.title,
          currentName: _auth?.user?.displayName.isNotEmpty == true
              ? _auth!.user!.displayName
              : currentUsername,
          opponentName: opponentName,
          currentLevel: widget.playerLevel,
          opponentLevel: int.tryParse(opponent['level']?.toString() ?? ''),
          onLeave: () {
            _socket?.moveRandomGame(sessionId, const {'action': 'leave_room'});
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
          onStart: () {
            if (!mounted) return;
            Navigator.of(context).pushReplacement<void, void>(
              MaterialPageRoute<void>(
                builder: (_) => GameRoomScreen(
                  currentUsername: currentUsername,
                  initialGame: game,
                  randomSessionId: sessionId,
                  peerUsername: opponentUsername,
                  opponentDisplayName: opponentName,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleRandomMatchTimeout(Map data) {
    if (!mounted || !_searchingRandom || data['gameType']?.toString() != widget.gameType) return;
    _queueTimer?.cancel();
    _closeRandomSearchRoutes();
    setState(() {
      _searchingRandom = false;
      _queueDeadline = null;
    });
    _showMatchTimeoutDialog(
      title: 'No player found',
      message: data['message']?.toString() ?? 'No player joined in 60 seconds.',
      retryLabel: 'Search again',
      onRetry: _startRandomSearch,
    );
  }

  Future<void> _showMatchTimeoutDialog({
    required String title,
    required String message,
    required String retryLabel,
    required VoidCallback onRetry,
  }) async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(retryLabel),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (_backgroundRouteOpen) {
      _backgroundRouteOpen = false;
      Navigator.of(context).pop();
    }
    if (retry == true) {
      onRetry();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _handleGameInviteAccepted(Map data) {
    if (!mounted || data['messageId']?.toString() != _pendingFriendInviteId) return;
    final from = data['from']?.toString().toLowerCase();
    if (from != _pendingInviteFriend?.username.toLowerCase()) return;
    _friendInviteTimer?.cancel();
    _friendInviteSecondsRemaining = 0;
    _friendInviteCountdown.value = 0;
    _friendInviteAccepted.value = true;
    if (_backgroundRouteOpen) {
      _backgroundRouteOpen = false;
      Navigator.of(context).pop();
    }
    if (mounted) setState(() {});
    // Keep the waiting sheet open. The host explicitly starts the match
    // after seeing the friend in the room, rather than being navigated away
    // as soon as the invitation is accepted.
  }

  void _handleGameInviteTimeout(Map data) {
    if (!mounted || data['messageId']?.toString() != _pendingFriendInviteId) return;
    _friendInviteTimer?.cancel();
    final friend = _pendingInviteFriend;
    final sheetContext = _friendWaitingSheetContext;
    if (sheetContext != null && sheetContext.mounted) Navigator.of(sheetContext).pop();
    _friendWaitingSheetContext = null;
    _clearPendingFriendInvite();
    if (friend == null) return;
    _showMatchTimeoutDialog(
      title: 'Invite expired',
      message: '@${friend.username} did not join within 60 seconds.',
      retryLabel: 'Invite again',
      onRetry: () => _playWithFriend(friend),
    );
  }

  void _openPendingFriendGame() {
    final friend = _pendingInviteFriend;
    final game = _pendingInviteGame;
    final messageId = _pendingFriendInviteId;
    if (friend == null || game == null || messageId == null || !mounted) return;
    final peer = friend.username;
    final opponentName = _pendingInviteOpponentName;
    final currentUser = _pendingInviteCurrentUser;
    final sheetContext = _friendWaitingSheetContext;
    if (sheetContext != null && sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
    _clearPendingFriendInvite();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameRoomScreen(
          messageId: messageId,
          peerUsername: peer,
          currentUsername: currentUser,
          initialGame: game,
          opponentDisplayName: opponentName,
          closeChatOnExit: true,
        ),
      ),
    );
  }

  void _clearPendingFriendInvite() {
    _friendInviteTimer?.cancel();
    _friendWaitingSheetContext = null;
    _pendingFriendInviteId = null;
    _pendingInviteFriend = null;
    _pendingInviteGame = null;
    _pendingInviteOpponentName = '';
    _pendingInviteCurrentUser = '';
    _friendInviteSecondsRemaining = 60;
    _friendInviteCountdown.value = 60;
    _friendInviteAccepted.value = false;
  }

  List<UserModel> get _filteredFriends {
    if (_searchQuery.isEmpty) return _friends;
    return _friends.where((friend) {
      final query = _searchQuery;
      final name = friend.name.toLowerCase();
      final username = friend.username.toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final socket = context.watch<SocketService>();
    final connectionReady = socket.isConnected && socket.isAuthenticated;
    final surface = isDark ? const Color(0xFF201B36) : Colors.white;
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);

    return PopScope<void>(
      canPop: !_searchingRandom && !_cancellingMatchmaking && _pendingFriendInviteId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_cancellingMatchmaking) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF5F3FC),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
                child: Row(
                  children: [
                    Material(
                      color: surface,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: _cancellingMatchmaking ? null : _handleBack,
                        icon: Icon(Icons.arrow_back_rounded, color: foreground, size: 26),
                        iconSize: 26,
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                          color: foreground,
                        ),
                      ),
                    ),
                    Icon(widget.icon, color: const Color(0xFFB9B2E9), size: 38),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    if (!connectionReady) ...[
                      _buildConnectionNotice(theme),
                      const SizedBox(height: 18),
                    ] else if (_searchEndedByDisconnect) ...[
                      _buildSearchEndedNotice(theme),
                      const SizedBox(height: 18),
                    ],
                    Text('Quick play', style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    )),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _QuickPlayTile(
                            title: 'Play vs Bot',
                            subtitle: 'Works offline',
                            icon: Icons.smart_toy_outlined,
                            iconBackground: const Color(0xFFDDF3E9),
                            iconColor: const Color(0xFF176B45),
                            background: surface,
                            foreground: foreground,
                            subtitleColor: muted,
                            playColor: const Color(0xFF5E44F3),
                            onTap: _playWithAiBot,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _QuickPlayTile(
                            title: 'Random player',
                            subtitle: 'Find a match online',
                            icon: Icons.public_rounded,
                            iconBackground: const Color(0xFF796CF4),
                            iconColor: Colors.white,
                            background: const Color(0xFF5E4CF2),
                            foreground: Colors.white,
                            subtitleColor: Colors.white.withValues(alpha: .88),
                            playColor: Colors.white,
                            onTap: connectionReady && !_searchingRandom
                                ? _startRandomSearch
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Invite a friend', style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          )),
                        ),
                        Text('${_friends.length} friends', style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFriendPicker(theme),
                  ],
                ),
              ),
              _buildInviteBottomBar(connectionReady),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendPicker(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF201B36) : Colors.white;
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);
    final filtered = _filteredFriends;
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) {
            final query = value.trim().toLowerCase();
            setState(() {
              _searchQuery = query;
              if (_selectedFriend != null && !_friends.any((friend) =>
                  friend.username.toLowerCase() == _selectedFriend &&
                  (friend.name.toLowerCase().contains(query) ||
                      friend.username.toLowerCase().contains(query)))) {
                _selectedFriend = null;
              }
            });
          },
          style: TextStyle(color: foreground, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search by username',
            hintStyle: TextStyle(color: muted, fontSize: 15),
            prefixIcon: Icon(Icons.search_rounded, color: muted, size: 24),
            filled: true,
            fillColor: surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: Color(0xFF5E44F3), width: 1.5),
            ),
            suffixIcon: _searchQuery.isEmpty ? null : IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: Icon(Icons.close_rounded, color: muted),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingFriends)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_friendsLoadFailed)
          TextButton.icon(
            onPressed: () => _subscribeToFriends(force: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Could not load friends · Retry'),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _friends.isEmpty ? 'Add friends in Contacts to play private matches.' : 'No friends found.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          )
        else
          ...filtered.map((friend) {
            final selected = friend.username.toLowerCase() == _selectedFriend;
            final name = friend.name.isEmpty ? friend.username : friend.name;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: selected
                    ? (isDark
                        ? const Color(0xFF332A57)
                        : const Color(0xFFEEEAFE))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _sendingInvite ? null : () => setState(
                    () => _selectedFriend = friend.username.toLowerCase(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        UserAvatar(
                          name: name,
                          photoUrl: friend.photoUrl,
                          radius: 23,
                          isOnline: friend.isOnline,
                          presence: friend.status,
                          showOnlineIndicator: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: foreground,
                                )),
                              const SizedBox(height: 2),
                              Text('@${friend.username} · ${_presence(friend)}',
                                style: TextStyle(fontSize: 12.5, color: muted)),
                            ],
                          ),
                        ),
                        Icon(
                          selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: selected ? const Color(0xFF6250F5) : const Color(0xFF9690B4),
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildInviteBottomBar(bool connectionReady) {
    final friend = _selectedFriendModel;
    final enabled = connectionReady && friend != null && !_sendingInvite;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
        child: SizedBox(
          height: 64,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: enabled ? () => _playWithFriend(friend) : null,
            icon: _sendingInvite
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.person_add_alt_1_rounded, size: 22),
            label: Text(
              _sendingInvite
                  ? 'Sending invite…'
                  : friend == null ? 'Select a friend to invite' : 'Invite @${friend.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5E4CF2),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF5E4CF2).withValues(alpha: .35),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionNotice(ThemeData theme) {
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 10, 13),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.error.withValues(alpha: .2)),
      ),
      child: Row(children: [
        Icon(Icons.wifi_off_rounded, color: colors.error),
        const SizedBox(width: 11),
        Expanded(child: Text(
          'You’re offline. Reconnect to invite a friend or find a player.',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
        )),
        TextButton(
          onPressed: _reconnecting ? null : _reconnect,
          child: _reconnecting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Reconnect'),
        ),
      ]),
    );
  }

  Widget _buildSearchEndedNotice(ThemeData theme) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.tertiary),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Your search ended when the connection dropped. Start a new search when ready.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          )),
        ]),
      );

  void _playWithAiBot() {
    GameRoomScreen.openOfflineBotMatch(
      context: context,
      currentUsername: _auth?.user?.username ?? _account ?? '',
      gameType: widget.gameType,
      title: widget.title,
    );
  }

}

class _MatchmakingBackgroundScreen extends StatelessWidget {
  const _MatchmakingBackgroundScreen({
    required this.title,
    required this.countdown,
    required this.isFriendInvite,
    required this.onReturn,
    required this.onCancel,
  });

  final String title;
  final ValueListenable<int> countdown;
  final bool isFriendInvite;
  final VoidCallback onReturn;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matchmaking'),
        leading: IconButton(
          tooltip: 'Return to game setup',
          onPressed: onReturn,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFriendInvite ? Icons.person_add_alt_1_rounded : Icons.search_rounded,
                  size: 38,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isFriendInvite ? 'Waiting for $title' : 'Finding a player for $title',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                isFriendInvite
                    ? 'Your invite is active while you browse Novyn.'
                    : 'Your search keeps running while you browse Novyn.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              ValueListenableBuilder<int>(
                valueListenable: countdown,
                builder: (context, seconds, _) => Text(
                  '00:${seconds.toString().padLeft(2, '0')}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onReturn,
                  icon: const Icon(Icons.sports_esports_rounded),
                  label: const Text('Return to game setup'),
                ),
              ),
              TextButton(
                onPressed: onCancel,
                child: Text(isFriendInvite ? 'Cancel invite' : 'Cancel search'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPlayTile extends StatelessWidget {
  const _QuickPlayTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.background,
    required this.foreground,
    required this.subtitleColor,
    required this.playColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final Color background;
  final Color foreground;
  final Color subtitleColor;
  final Color playColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 188,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(icon, color: iconColor, size: 29),
                ),
                const Spacer(),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  )),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: subtitleColor)),
                    ),
                    Icon(Icons.play_arrow_rounded, color: playColor, size: 23),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RandomMatchmakingScreen extends StatelessWidget {
  const _RandomMatchmakingScreen({
    required this.gameTitle,
    required this.countdown,
    required this.onCancel,
  });

  final String gameTitle;
  final ValueListenable<int> countdown;
  final VoidCallback onCancel;

  Widget _orbitArtwork(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final factor in [1.0, .77, .54])
            Container(
              width: size * factor,
              height: size * factor,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFBDB5F3).withValues(alpha: .45),
                  width: 1.5,
                ),
              ),
            ),
          for (final dot in const [
            [0.18, 0.28, 13.0, Color(0xFFD5F1E5)],
            [0.82, 0.18, 11.0, Color(0xFFFFDCE7)],
            [0.25, 0.82, 10.0, Color(0xFFE6E0FF)],
            [0.84, 0.78, 14.0, Color(0xFFFFE5D4)],
          ])
            Positioned(
              left: size * (dot[0] as double) - (dot[2] as double) / 2,
              top: size * (dot[1] as double) - (dot[2] as double) / 2,
              child: Container(
                width: dot[2] as double,
                height: dot[2] as double,
                decoration: BoxDecoration(
                  color: dot[3] as Color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Container(
            width: size * .37,
            height: size * .37,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1A43),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6250F5), width: 5),
              boxShadow: const [
                BoxShadow(color: Color(0x336250F5), blurRadius: 18),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * .16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF141026) : const Color(0xFFF5F3FC);
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);
    final surface = isDark ? const Color(0xFF201B36) : Colors.white;

    return PopScope<void>(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: [
                    Material(
                      color: surface,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: onCancel,
                        icon: Icon(Icons.close_rounded, color: foreground, size: 27),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        gameTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Random player',
                        style: TextStyle(
                          color: Color(0xFF403875),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(
                      300.0,
                      math.min(
                        constraints.maxWidth - 48,
                        constraints.maxHeight * .48,
                      ),
                    ).clamp(150.0, 300.0).toDouble();
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _orbitArtwork(size),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Finding a player',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: foreground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Searching for an available opponent',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: muted),
                            ),
                            const SizedBox(height: 20),
                            ValueListenableBuilder<int>(
                              valueListenable: countdown,
                              builder: (context, seconds, _) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time_rounded, color: muted, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      '0:${(60 - seconds).clamp(0, 60).toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: foreground,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onCancel,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF282046)
                          : const Color(0xFFEDE9FC),
                      foregroundColor: const Color(0xFF5141E5),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Cancel search',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RandomMatchFoundScreen extends StatefulWidget {
  const _RandomMatchFoundScreen({
    required this.gameTitle,
    required this.currentName,
    required this.opponentName,
    required this.currentLevel,
    required this.opponentLevel,
    required this.onLeave,
    required this.onStart,
  });

  final String gameTitle;
  final String currentName;
  final String opponentName;
  final int? currentLevel;
  final int? opponentLevel;
  final VoidCallback onLeave;
  final VoidCallback onStart;

  @override
  State<_RandomMatchFoundScreen> createState() => _RandomMatchFoundScreenState();
}

class _RandomMatchFoundScreenState extends State<_RandomMatchFoundScreen> {
  Timer? _timer;
  int _seconds = 3;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_seconds <= 1) {
        timer.cancel();
        widget.onStart();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF141026) : const Color(0xFFF5F3FC);
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);
    final surface = isDark ? const Color(0xFF201B36) : Colors.white;

    return PopScope<void>(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: [
                    Material(
                      color: surface,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: widget.onLeave,
                        icon: Icon(Icons.close_rounded, color: foreground, size: 27),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.gameTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Random player',
                        style: TextStyle(
                          color: Color(0xFF403875),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final badgeWidth = math.min(
                      112.0,
                      (constraints.maxWidth - 52) / 2,
                    );
                    final avatarSize = math.min(100.0, badgeWidth - 12);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDF3E9),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Text(
                                'Match found',
                                style: TextStyle(
                                  color: Color(0xFF176B45),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Get ready!',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: foreground,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _MatchPlayerBadge(
                              name: widget.currentName,
                              level: widget.currentLevel,
                              color: const Color(0xFF6250F5),
                              size: avatarSize,
                            ),
                            Text(
                              'VS',
                              style: TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            _MatchPlayerBadge(
                              name: widget.opponentName,
                              level: widget.opponentLevel,
                              color: const Color(0xFFE32C62),
                              size: avatarSize,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: LinearProgressIndicator(
                                  value: _seconds / 3,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFE3DFF5),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF6250F5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Starting in $_seconds seconds',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onLeave,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF282046)
                          : const Color(0xFFEDE9FC),
                      foregroundColor: const Color(0xFF5141E5),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Leave match',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchPlayerBadge extends StatelessWidget {
  const _MatchPlayerBadge({
    required this.name,
    required this.level,
    required this.color,
    required this.size,
  });

  final String name;
  final int? level;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1E1A43);
    return SizedBox(
      width: math.max(80.0, size + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .15), blurRadius: 0, spreadRadius: 5),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * .38,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          if (level != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Level $level',
                style: const TextStyle(
                  color: Color(0xFF403875),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FriendInviteWaitingSheet extends StatelessWidget {
  const _FriendInviteWaitingSheet({
    required this.friend,
    required this.currentUser,
    required this.accepted,
    required this.onStart,
    required this.onCancel,
  });

  final UserModel friend;
  final NovynUser? currentUser;
  final ValueListenable<bool> accepted;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  Widget _memberRow({
    required String name,
    required String photoUrl,
    required bool isHost,
    required bool isDark,
  }) {
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF28223F) : const Color(0xFFF5F3FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          UserAvatar(name: name, photoUrl: photoUrl, radius: 19, showOnlineIndicator: false),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isHost ? '$name · Host' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: accepted,
            builder: (context, isAccepted, _) {
              final joined = isHost || isAccepted;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: joined ? const Color(0xFFDDF3E9) : const Color(0xFFFFF0C2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 9, color: joined ? const Color(0xFF18A05E) : const Color(0xFFE9A400)),
                    const SizedBox(width: 7),
                    Text(
                      joined ? 'Joined' : 'Joining…',
                      style: TextStyle(
                        color: joined ? const Color(0xFF176B45) : const Color(0xFF8A5B00),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);
    final friendName = friend.name.isEmpty ? friend.username : friend.name;
    final myName = currentUser?.displayName.isNotEmpty == true
        ? currentUser!.displayName
        : (currentUser?.username ?? 'You');

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF201B36) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFD4CEEF),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In this room', style: TextStyle(color: foreground, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      ValueListenableBuilder<bool>(
                        valueListenable: accepted,
                        builder: (context, isAccepted, _) => Text(
                          isAccepted ? '2 of 2 joined' : '1 of 2 joined',
                          style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: Color(0xFFEDE9FC), shape: BoxShape.circle),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF5141E5)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _memberRow(name: myName, photoUrl: currentUser?.avatarId ?? '', isHost: true, isDark: isDark),
            const SizedBox(height: 9),
            _memberRow(name: friendName, photoUrl: friend.photoUrl, isHost: false, isDark: isDark),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: accepted,
              builder: (context, isAccepted, _) => SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton.icon(
                  onPressed: isAccepted ? onStart : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 23),
                  label: Text(
                    isAccepted ? 'Start match' : 'Waiting for friend',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5E4CF2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE7E2F8),
                    disabledForegroundColor: const Color(0xFF625D8C),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Center(
              child: TextButton(
                onPressed: onCancel,
                child: Text('Cancel invite', style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
