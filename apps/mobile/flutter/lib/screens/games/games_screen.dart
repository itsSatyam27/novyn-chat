import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../services/socket_service.dart';
import '../../utils/game_matchmaking.dart';
import '../../widgets/novyn_alert.dart';
import '../../widgets/novyn_page_route.dart';
import '../../widgets/user_avatar.dart';
import '../chats/chat_detail_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const _games = <_GameOption>[
    _GameOption('tictactoe', 'Tic-Tac-Toe', 'Three in a row', Icons.grid_3x3_rounded),
    _GameOption('connect4', 'Connect 4', 'Line up four chips', Icons.circle_rounded),
    _GameOption('rps', 'Rock Paper Scissors', 'Choose your move', Icons.back_hand_rounded),
    _GameOption('doodle', 'Doodle Duel', 'Draw and guess', Icons.draw_rounded),
    _GameOption('numberclash', 'Number Clash', 'Pick a number', Icons.pin_rounded),
    _GameOption('updown', 'Up or Down', 'Predict the next card', Icons.trending_up_rounded),
  ];

  AuthService? _auth;
  StreamSubscription<List<UserModel>>? _friendsSubscription;
  String? _account;
  List<UserModel> _friends = const [];
  String? _selectedOpponent;
  String _selectedGameType = 'tictactoe';
  bool _loadingFriends = true;
  bool _sendingChallenge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _auth = context.read<AuthService>();
      _auth!.addListener(_handleAuthChanged);
      _subscribeToFriends();
    });
  }

  @override
  void dispose() {
    _auth?.removeListener(_handleAuthChanged);
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
    _friends = const [];
    _selectedOpponent = null;

    if (username.isEmpty) {
      setState(() => _loadingFriends = false);
      return;
    }

    setState(() => _loadingFriends = true);
    _friendsSubscription = context.read<FriendService>().friendsStream(username).listen(
      (friends) {
        if (!mounted || _account != owner) return;
        final sorted = List<UserModel>.from(friends)
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        setState(() {
          _friends = sorted;
          final stillExists = sorted.any(
            (friend) => friend.username.toLowerCase() == _selectedOpponent,
          );
          if (!stillExists) {
            final online = GameMatchmaking.availableOnlineFriends(sorted);
            _selectedOpponent = online.isNotEmpty
                ? online.first.username.toLowerCase()
                : sorted.isNotEmpty
                    ? sorted.first.username.toLowerCase()
                    : null;
          }
          _loadingFriends = false;
        });
      },
      onError: (Object error) {
        if (!mounted || _account != owner) return;
        setState(() => _loadingFriends = false);
      },
    );
  }

  UserModel? get _selectedFriend {
    final selected = _selectedOpponent;
    if (selected == null) return null;
    for (final friend in _friends) {
      if (friend.username.toLowerCase() == selected) return friend;
    }
    return null;
  }

  List<UserModel> get _onlineFriends =>
      GameMatchmaking.availableOnlineFriends(_friends);

  Future<void> _quickMatch() async {
    final opponent = GameMatchmaking.pickRandomOnlineFriend(_friends);
    if (opponent == null) {
      NovynAlert.show(
        context,
        'No friends are available for a quick match right now. You can still invite someone from your friends list.',
        title: 'No players online',
        icon: Icons.group_off_rounded,
      );
      return;
    }
    await _sendChallenge(opponent);
  }

  Future<void> _sendChallenge(UserModel opponent) async {
    if (_sendingChallenge) return;
    setState(() => _sendingChallenge = true);
    try {
      await context.read<SocketService>().sendGameChallenge(
            _selectedGameType,
            opponent.username,
          );
      if (!mounted) return;
      Navigator.of(context).push<void>(
        NovynPageRoute<void>(child: ChatDetailScreen(peer: opponent)),
      );
    } catch (error) {
      if (!mounted) return;
      NovynAlert.show(
        context,
        error is StateError
            ? error.message.toString()
            : 'Could not send the game invitation. Check your connection and try again.',
        isError: true,
        title: 'Could not start game',
        icon: Icons.sports_esports_rounded,
      );
    } finally {
      if (mounted) setState(() => _sendingChallenge = false);
    }
  }

  String _presenceLabel(UserModel friend) {
    final presence = friend.status.trim().toLowerCase();
    if (!friend.isOnline || presence == 'offline' || presence == 'invisible') {
      return 'Offline';
    }
    if (presence == 'busy' || presence == 'dnd') return 'Busy';
    if (presence == 'away' || presence == 'idle') return 'Away';
    return 'Online';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final username = context.watch<AuthService>().user?.username;
    final selectedGame = _games.firstWhere(
      (game) => game.type == _selectedGameType,
      orElse: () => _games.first,
    );
    final selectedFriend = _selectedFriend;

    if (username == null || username.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Sign in to play Novyn Games.')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 112),
          children: [
            Text(
              'Games',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontFamily: 'PlusJakartaSans',
                fontSize: 36,
                height: 1.12,
                letterSpacing: -1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Play together, wherever you are.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            _buildQuickMatchCard(theme, selectedGame),
            const SizedBox(height: 26),
            _sectionTitle(theme, 'Choose a game'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _games.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
              itemBuilder: (context, index) {
                final game = _games[index];
                return _buildGameTile(theme, game, game.type == _selectedGameType);
              },
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(child: _sectionTitle(theme, 'Invite a friend')),
                Text(
                  _onlineFriends.length.toString() + ' online',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Choose someone to challenge in ' + selectedGame.title + '.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildFriendsSection(theme),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedFriend == null || _sendingChallenge
                    ? null
                    : () => _sendChallenge(selectedFriend),
                icon: _sendingChallenge
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sports_esports_rounded),
                label: Text(
                  selectedFriend == null
                      ? 'Choose a friend'
                      : 'Challenge @' + selectedFriend.username,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'You can also start a game from any one-to-one or group chat using the attachment menu.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMatchCard(ThemeData theme, _GameOption selectedGame) {
    final colors = theme.colorScheme;
    final canMatch = _onlineFriends.isNotEmpty && !_sendingChallenge;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(
          alpha: theme.brightness == Brightness.dark ? .42 : .72,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.primary.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.bolt_rounded, size: 26, color: colors.primary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _loadingFriends
                      ? 'Checking players…'
                      : _onlineFriends.length.toString() + ' online',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Quick match',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Get paired with a random online friend for ' + selectedGame.title + '.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canMatch ? _quickMatch : null,
              icon: _sendingChallenge
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shuffle_rounded),
              label: const Text('Find a quick match'),
            ),
          ),
          if (!_loadingFriends && _onlineFriends.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Your online friends will appear here. You can still invite someone below.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String value) => Text(
        value,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      );

  Widget _buildGameTile(ThemeData theme, _GameOption game, bool selected) {
    final colors = theme.colorScheme;
    return Material(
      color: selected ? colors.primary.withValues(alpha: .10) : colors.surface,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: _sendingChallenge
            ? null
            : () => setState(() => _selectedGameType = game.type),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected
                  ? colors.primary
                  : colors.outlineVariant.withValues(alpha: .55),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: selected ? .17 : .09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(game.icon, color: colors.primary, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      game.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 17, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsSection(ThemeData theme) {
    final colors = theme.colorScheme;
    if (_loadingFriends) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
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
            Icon(Icons.people_outline_rounded, size: 28, color: colors.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              'No friends to invite yet',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Add friends in Contacts and they will show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final selected = friend.username.toLowerCase() == _selectedOpponent;
          final presence = _presenceLabel(friend);
          return Material(
            color: selected ? colors.primary.withValues(alpha: .09) : colors.surface,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _sendingChallenge
                  ? null
                  : () => setState(
                        () => _selectedOpponent = friend.username.toLowerCase(),
                      ),
              child: Container(
                width: 142,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: .55),
                    width: selected ? 1.5 : 1,
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.name.isEmpty ? friend.username : friend.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            presence,
                            maxLines: 1,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: presence == 'Online'
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GameOption {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;

  const _GameOption(this.type, this.title, this.subtitle, this.icon);
}
