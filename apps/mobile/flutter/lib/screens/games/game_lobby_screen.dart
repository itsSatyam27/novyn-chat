import 'dart:async';

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
  int _secondsRemaining = 60;
  DateTime? _queueDeadline;
  Timer? _queueTimer;

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
      _subscribeToFriends();
    });
  }

  @override
  void dispose() {
    _auth?.removeListener(_handleAuthChanged);
    _queueTimer?.cancel();
    if (_socket != null) {
      _socket!.onRandomMatchFound = null;
      _socket!.onRandomMatchTimeout = null;
      if (_searchingRandom) {
        unawaited(_socket!.cancelRandomGame().catchError((_) {}));
      }
    }
    unawaited(_friendsSubscription?.cancel());
    super.dispose();
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    final username = _auth?.user?.username.trim().toLowerCase();
    if (username != _account) _subscribeToFriends();
  }

  void _subscribeToFriends() {
    final username = _auth?.user?.username.trim() ?? '';
    final owner = username.toLowerCase();
    if (owner == _account) return;
    _account = owner;
    unawaited(_friendsSubscription?.cancel());
    _friendsSubscription = null;
    _friends = const <UserModel>[];
    _selectedFriend = null;
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
          setState(() => _loadingFriends = false);
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
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => GameRoomScreen(
            messageId: messageId,
            peerUsername: friend.username,
            currentUsername: socket.myUsername ?? _auth?.user?.username ?? '',
            initialGame: Map<String, dynamic>.from(gameMessage!.game!),
            opponentDisplayName:
                friend.name.isEmpty ? friend.username : friend.name,
            closeChatOnExit: true,
          ),
        ),
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
    setState(() {
      _searchingRandom = true;
      _secondsRemaining = 60;
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
        final remaining = deadline.difference(DateTime.now()).inSeconds.clamp(0, 60);
        setState(() => _secondsRemaining = remaining);
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
      if (leaveLobby) Navigator.of(context).pop();
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
    if (!_searchingRandom) {
      Navigator.of(context).pop();
      return;
    }
    final cancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave matchmaking?'),
        content: const Text(
          'You are currently searching for a player. Cancel the search before leaving this game lobby.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep searching'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel and leave'),
          ),
        ],
      ),
    );
    if (!mounted || cancel != true) return;
    await _cancelRandomSearch(leaveLobby: true);
  }

  void _handleRandomMatchFound(Map data) {
    if (!mounted) return;
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
    if (!mounted || data['gameType']?.toString() != widget.gameType) return;
    _queueTimer?.cancel();
    setState(() {
      _searchingRandom = false;
      _queueDeadline = null;
      _secondsRemaining = 60;
    });
    NovynAlert.show(
      context,
      data['message']?.toString() ??
          'No player available right now. Please try again.',
      title: 'No player available',
      icon: Icons.group_off_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedFriend = _selectedFriendModel;
    final onlineCount = _friends.where((friend) => _presence(friend) == 'Online').length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _cancellingMatchmaking ? null : _handleBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(widget.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            )),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(21),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer.withValues(alpha: .95),
                    colors.surfaceContainerLow,
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: colors.primary.withValues(alpha: .15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: .85),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(widget.icon, color: colors.primary, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      )),
                  const SizedBox(height: 5),
                  Text(widget.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      )),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.people_alt_rounded,
                          size: 17, color: colors.primary),
                      const SizedBox(width: 7),
                      Text('Two-player match',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                      const Spacer(),
                      Text('Friends or strangers',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text('Choose how to play',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                )),
            const SizedBox(height: 12),
            _buildRandomCard(theme),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text('Play with a friend',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                ),
                Text('$onlineCount online',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a friend and invite them into a private match.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildFriends(theme),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedFriend == null || _sendingInvite
                    ? null
                    : () => _playWithFriend(selectedFriend),
                icon: _sendingInvite
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sports_esports_rounded),
                label: Text(selectedFriend == null
                    ? 'Choose a friend'
                    : 'Play with @${selectedFriend.username}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRandomCard(ThemeData theme) {
    final colors = theme.colorScheme;
    final canStart = !_sendingInvite && !_cancellingMatchmaking;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.public_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Play with Random',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 2),
                    Text('Match with a stranger playing the same game.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: !canStart
                  ? null
                  : _searchingRandom
                      ? () => _cancelRandomSearch()
                      : _startRandomSearch,
              icon: _cancellingMatchmaking
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_searchingRandom
                      ? Icons.close_rounded
                      : Icons.search_rounded),
              label: Text(_cancellingMatchmaking
                  ? 'Cancelling…'
                  : _searchingRandom
                      ? 'Cancel search · 00:${_secondsRemaining.toString().padLeft(2, '0')}'
                      : 'Find a player'),
            ),
          ),
          if (_searchingRandom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('Searching for a stranger…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      )),
                ),
                Text(
                  '00:${_secondsRemaining.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 9),
            Text(
              'The search lasts up to 60 seconds. Only players looking for ${widget.title} are matched.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFriends(ThemeData theme) {
    final colors = theme.colorScheme;
    if (_loadingFriends) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_friends.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: .5)),
        ),
        child: Column(
          children: [
            Icon(Icons.person_add_alt_1_rounded,
                size: 28, color: colors.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('No friends to invite yet',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 4),
            Text(
              'Add friends in Contacts and they will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: _friends.map((friend) {
        final selected =
            friend.username.toLowerCase() == _selectedFriend;
        final presence = _presence(friend);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected
                ? colors.primary.withValues(alpha: .08)
                : colors.surface,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: _sendingInvite
                  ? null
                  : () => setState(
                        () => _selectedFriend = friend.username.toLowerCase(),
                      ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: .45),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      name: friend.name,
                      photoUrl: friend.photoUrl,
                      radius: 21,
                      isOnline: friend.isOnline,
                      presence: friend.status,
                      showOnlineIndicator: true,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.name.isEmpty ? friend.username : friend.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text('@${friend.username} · $presence',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: presence == 'Online'
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              )),
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
