import 'dart:async';

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
  });

  final String gameType;
  final String title;
  final String subtitle;
  final IconData icon;

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
  int _secondsRemaining = 60;
  int _friendInviteSecondsRemaining = 60;
  final ValueNotifier<int> _friendInviteCountdown = ValueNotifier<int>(60);
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

  void _handleSocketStateChanged() {
    if (!mounted || !_searchingRandom || _connectionReady) return;
    _queueTimer?.cancel();
    setState(() {
      _searchingRandom = false;
      _cancellingMatchmaking = false;
      _queueDeadline = null;
      _secondsRemaining = 60;
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
    if (_sendingInvite) return;
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
            gameTitle: widget.title,
            friend: friend,
            currentUser: _auth?.user,
            countdown: _friendInviteCountdown,
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
      _secondsRemaining = 60;
      _queueCountdown.value = 60;
      // Give the server timeout event a short delivery grace period before
      // showing a local fallback in case the event was lost during reconnect.
      _queueDeadline = DateTime.now().add(const Duration(seconds: 60));
    });
    try {
      await socket.joinRandomGame(widget.gameType);
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
        setState(() => _secondsRemaining = remaining.clamp(0, 60));
        _queueCountdown.value = remaining.clamp(0, 60);
      });
    } catch (error) {
      _queueTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _searchingRandom = false;
        _queueDeadline = null;
        _secondsRemaining = 60;
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
        _secondsRemaining = 60;
        _queueDeadline = null;
      });
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
      _secondsRemaining = 60;
      _searchEndedByDisconnect = false;
    });
    if (sessionId.isEmpty || game == null) {
      NovynAlert.show(
        context,
        'A player was found, but the game room could not be created. Please try again.',
        isError: true,
        title: 'Could not open game',
        icon: Icons.sync_problem_rounded,
      );
      return;
    }
    if (_backgroundRouteOpen) {
      _backgroundRouteOpen = false;
      Navigator.of(context).pop();
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameRoomScreen(
          currentUsername: _socket?.myUsername ?? _auth?.user?.username ?? '',
          initialGame: game,
          randomSessionId: sessionId,
          peerUsername: opponent['username']?.toString() ?? '',
          opponentDisplayName: opponent['displayName']?.toString() ??
              opponent['username']?.toString() ??
              'Player',
        ),
      ),
    );
  }

  void _handleRandomMatchTimeout(Map data) {
    if (!mounted || !_searchingRandom || data['gameType']?.toString() != widget.gameType) return;
    _queueTimer?.cancel();
    setState(() {
      _searchingRandom = false;
      _queueDeadline = null;
      _secondsRemaining = 60;
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
    final sheetContext = _friendWaitingSheetContext;
    if (sheetContext != null && sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
    _friendWaitingSheetContext = null;
    if (_backgroundRouteOpen) {
      _backgroundRouteOpen = false;
      Navigator.of(context).pop();
    }
    _openPendingFriendGame();
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
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final socket = context.watch<SocketService>();
    final connectionReady = socket.isConnected && socket.isAuthenticated;

    return PopScope<void>(
      canPop: !_searchingRandom && !_cancellingMatchmaking && _pendingFriendInviteId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_cancellingMatchmaking) {
          unawaited(_handleBack());
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF3F1F9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _cancellingMatchmaking ? null : _handleBack,
            icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
          ),
          title: Text(
            widget.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -.3,
              color: colors.onSurface,
            ),
          ),
          centerTitle: false,
          titleSpacing: 0,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              if (!connectionReady) ...[
                _buildConnectionNotice(theme),
                const SizedBox(height: 18),
              ] else if (_searchEndedByDisconnect) ...[
                _buildSearchEndedNotice(theme),
                const SizedBox(height: 18),
              ],
              _buildRandomCard(theme, connectionReady),
              const SizedBox(height: 16),
              _buildFriendCard(theme, connectionReady),
            ],
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

  Widget _buildRandomCard(ThemeData theme, bool connectionReady) {
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final canStart = !_sendingInvite && !_cancellingMatchmaking && connectionReady;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0xFF5E44F3).withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark
              ? colors.outlineVariant.withValues(alpha: .25)
              : const Color(0xFFEEEAF8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF5E44F3),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              _buildGameBadge(widget.gameType),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Random player',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1C2A),
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: !canStart
                  ? null
                  : _searchingRandom
                      ? () => _cancelRandomSearch()
                      : _startRandomSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E44F3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _cancellingMatchmaking
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Cancelling…',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : _searchingRandom
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Cancel search · 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded, size: 21, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Find a player',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
          if (_searchingRandom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _secondsRemaining == 0
                        ? 'Waiting for match confirmation…'
                        : 'Searching for an opponent…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5E44F3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendCard(ThemeData theme, bool connectionReady) {
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedFriend = _selectedFriendModel;
    final filtered = _filteredFriends;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0xFF5E44F3).withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark
              ? colors.outlineVariant.withValues(alpha: .25)
              : const Color(0xFFEEEAF8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF28253A)
                      : const Color(0xFFEEECFD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: Color(0xFF5E44F3),
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  'Invite a friend',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1C2A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (val) {
              final query = val.trim().toLowerCase();
              setState(() {
                _searchQuery = query;
                if (_selectedFriend != null &&
                    !_friends.any((friend) =>
                        friend.username.toLowerCase() == _selectedFriend &&
                        (friend.name.toLowerCase().contains(query) ||
                            friend.username.toLowerCase().contains(query)))) {
                  _selectedFriend = null;
                }
              });
            },
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E1C2A),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF221F33) : const Color(0xFFFAF9FD),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
              ),
              hintText: 'Search by username',
              hintStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8C87A6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? colors.outlineVariant.withValues(alpha: .3)
                      : const Color(0xFFE2DDF5),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? colors.outlineVariant.withValues(alpha: .3)
                      : const Color(0xFFE2DDF5),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF5E44F3),
                  width: 1.8,
                ),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          if (_loadingFriends) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ] else if (_friendsLoadFailed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => _subscribeToFriends(force: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Could not load friends - Retry'),
                ),
              ),
            ),
          ] else if (filtered.isNotEmpty) ...[
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final friend = filtered[index];
                  final isSelected = friend.username.toLowerCase() == _selectedFriend;
                  final presence = _presence(friend);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: isSelected
                          ? const Color(0xFF5E44F3).withValues(alpha: .08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _sendingInvite
                            ? null
                            : () => setState(
                                  () => _selectedFriend = friend.username.toLowerCase(),
                                ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF5E44F3)
                                  : (isDark
                                      ? colors.outlineVariant.withValues(alpha: .2)
                                      : const Color(0xFFEEEAF8)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                name: friend.name,
                                photoUrl: friend.photoUrl,
                                radius: 18,
                                isOnline: friend.isOnline,
                                presence: friend.status,
                                showOnlineIndicator: true,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.name.isEmpty ? friend.username : friend.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF1E1C2A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${friend.username} · $presence',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: presence == 'Online'
                                            ? const Color(0xFF5E44F3)
                                            : colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? const Color(0xFF5E44F3)
                                    : (isDark ? Colors.white54 : const Color(0xFF8C87A6)),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else if (_friends.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Add friends in Contacts to play private matches.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(children: [
                Icon(Icons.person_search_rounded,
                    color: colors.onSurfaceVariant.withValues(alpha: .75), size: 25),
                const SizedBox(height: 6),
                Text(
                  'No friends match "${_searchController.text.trim()}".',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedFriend = null;
                    });
                  },
                  child: const Text('Clear search'),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _sendingInvite || !connectionReady
                  ? null
                  : () {
                      if (selectedFriend != null) {
                        _playWithFriend(selectedFriend);
                      } else if (filtered.isNotEmpty) {
                        final target = filtered.first;
                        setState(() => _selectedFriend = target.username.toLowerCase());
                        _playWithFriend(target);
                      } else {
                        NovynAlert.show(
                          context,
                          'Select or search a friend first to send an invite.',
                          icon: Icons.people_outline_rounded,
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF28253A)
                    : const Color(0xFFECE8FD),
                foregroundColor: const Color(0xFF5E44F3),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _sendingInvite
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF5E44F3),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Sending invite…',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5E44F3),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 20,
                          color: Color(0xFF5E44F3),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedFriend != null
                              ? 'Invite @${selectedFriend.username} to play'
                              : 'Invite to play',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5E44F3),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBadge(String gameType) {
    switch (gameType) {
      case 'tictactoe':
        return const SizedBox(
          width: 72,
          height: 64,
          child: CustomPaint(
            painter: _TicTacToeBadgePainter(),
          ),
        );
      case 'rps':
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.back_hand_rounded, size: 20, color: Color(0xFF5E44F3)),
              SizedBox(width: 4),
              Icon(Icons.content_cut_rounded, size: 18, color: Color(0xFF8B70F8)),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            widget.icon,
            size: 28,
            color: const Color(0xFF5E44F3),
          ),
        );
    }
  }
}

class _TicTacToeBadgePainter extends CustomPainter {
  const _TicTacToeBadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFDDD6FE)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final cellW = size.width / 3;
    final cellH = size.height / 3;

    // Vertical lines
    canvas.drawLine(Offset(cellW, 4), Offset(cellW, size.height - 4), linePaint);
    canvas.drawLine(Offset(cellW * 2, 4), Offset(cellW * 2, size.height - 4), linePaint);

    // Horizontal lines
    canvas.drawLine(Offset(4, cellH), Offset(size.width - 4, cellH), linePaint);
    canvas.drawLine(Offset(4, cellH * 2), Offset(size.width - 4, cellH * 2), linePaint);

    // Top-left: X (purple #5E44F3)
    _drawX(canvas, Offset(cellW * 0.5, cellH * 0.5), 7, const Color(0xFF5E44F3));

    // Top-right: O (light purple #C4B5FD)
    _drawO(canvas, Offset(cellW * 2.5, cellH * 0.5), 7.5, const Color(0xFFC4B5FD));

    // Center: O (purple #5E44F3)
    _drawO(canvas, Offset(cellW * 1.5, cellH * 1.5), 8, const Color(0xFF5E44F3));

    // Bottom-right: X (purple #5E44F3)
    _drawX(canvas, Offset(cellW * 2.5, cellH * 2.5), 7, const Color(0xFF5E44F3));
  }

  void _drawX(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center + Offset(-radius, -radius), center + Offset(radius, radius), paint);
    canvas.drawLine(center + Offset(radius, -radius), center + Offset(-radius, radius), paint);
  }

  void _drawO(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class _FriendInviteWaitingSheet extends StatefulWidget {
  const _FriendInviteWaitingSheet({
    required this.gameTitle,
    required this.friend,
    required this.currentUser,
    required this.countdown,
  });

  final String gameTitle;
  final UserModel friend;
  final NovynUser? currentUser;
  final ValueListenable<int> countdown;

  @override
  State<_FriendInviteWaitingSheet> createState() => _FriendInviteWaitingSheetState();
}

class _FriendInviteWaitingSheetState extends State<_FriendInviteWaitingSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final friendName = widget.friend.name.isEmpty ? widget.friend.username : widget.friend.name;
    final myName = widget.currentUser?.displayName.isNotEmpty == true
        ? widget.currentUser!.displayName
        : (widget.currentUser?.username ?? 'You');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161522) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFDDD9E8),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Waiting for ${widget.friend.name.isEmpty ? widget.friend.username : widget.friend.name}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1C2A),
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.gameTitle} invitation sent to @${widget.friend.username}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF7E7A9C),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF5E44F3), width: 2.5),
                    ),
                    child: UserAvatar(
                      name: myName,
                      photoUrl: widget.currentUser?.avatarId ?? '',
                      radius: 28,
                      showOnlineIndicator: false,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E1C2A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E44F3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5E44F3).withValues(alpha: .38),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.friend.isOnline ? const Color(0xFF22C55E) : const Color(0xFF8C87A6),
                        width: 2.5,
                      ),
                    ),
                    child: UserAvatar(
                      name: friendName,
                      photoUrl: widget.friend.photoUrl,
                      radius: 28,
                      isOnline: widget.friend.isOnline,
                      presence: widget.friend.status,
                      showOnlineIndicator: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 80,
                    child: Text(
                      friendName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E1C2A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF221F33) : const Color(0xFFF4F2FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF5E44F3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: widget.countdown,
                    builder: (context, seconds, _) => Text(
                      'Invite sent to @${widget.friend.username}. They can join from this chat within $seconds seconds.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF58527A),
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Keep browsing lobby',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
