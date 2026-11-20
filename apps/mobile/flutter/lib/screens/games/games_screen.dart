import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../services/socket_service.dart';
import '../../theme/novyn_theme.dart';
import '../../widgets/novyn_alert.dart';
import '../../widgets/user_avatar.dart';
import '../chats/chat_detail_screen.dart';
import '../people/discover_people_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final Set<String> _sendingChallenges = <String>{};

  Future<void> _challengeFriend(UserModel friend) async {
    final key = friend.username.trim().toLowerCase();
    if (key.isEmpty || !_sendingChallenges.add(key)) return;

    setState(() {});
    try {
      final socket = context.read<SocketService>();
      if (!socket.isConnected || !socket.isAuthenticated) {
        throw StateError('Connect to Novyn before sending a game invite.');
      }

      // The challenge is delivered as a game message in the existing private
      // chat. Both players use the established server-validated game rules.
      socket.sendGameChallenge('tictactoe', friend.username);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatDetailScreen(peer: friend),
        ),
      );
    } catch (error) {
      if (mounted) {
        NovynAlert.show(
          context,
          error is StateError
              ? error.message.toString()
              : 'Could not send the game invite. Please try again.',
          isError: true,
          title: 'Invite not sent',
        );
      }
    } finally {
      if (mounted) setState(() => _sendingChallenges.remove(key));
    }
  }

  void _openFindFriends(String username) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DiscoverPeopleScreen(myUid: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = context.watch<AuthService>().user?.username.trim() ?? '';
    final friendService = context.read<FriendService>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;

    if (username.isEmpty) {
      return const Center(child: Text('Sign in to play games.'));
    }

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Games',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 36,
                      height: 1.12,
                      letterSpacing: -1.25,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Take a break and play together.',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 116),
                children: [
                  _buildFeaturedGame(theme, dark),
                  const SizedBox(height: 14),
                  _buildOnlineMatchmakingCard(theme, dark),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PLAY WITH FRIENDS',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            letterSpacing: 1.15,
                            fontWeight: FontWeight.w800,
                            color: muted,
                          ),
                        ),
                      ),
                      Text(
                        'Tic Tac Toe',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<List<UserModel>>(
                    stream: friendService.friendsStream(username),
                    initialData: friendService.cachedFriends,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _messageCard(
                          theme,
                          icon: Icons.cloud_off_rounded,
                          title: 'Could not load friends',
                          subtitle: 'Check your connection and try again.',
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final friends = List<UserModel>.from(
                        snapshot.data ?? const <UserModel>[],
                      )..sort((a, b) {
                          if (a.isOnline != b.isOnline) {
                            return a.isOnline ? -1 : 1;
                          }
                          return a.name.toLowerCase().compareTo(
                                b.name.toLowerCase(),
                              );
                        });

                      if (friends.isEmpty) {
                        return _emptyFriends(theme, username);
                      }

                      return Column(
                        children: [
                          for (final friend in friends) ...[
                            _friendTile(theme, friend),
                            const SizedBox(height: 9),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedGame(ThemeData theme, bool dark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: dark ? .23 : .13),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              Icons.grid_view_rounded,
              size: 30,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tic Tac Toe',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '1 vs 1 · Quick rounds · First game',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: theme.colorScheme.primary, size: 22),
        ],
      ),
    );
  }

  Widget _buildOnlineMatchmakingCard(ThemeData theme, bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.public_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Play online',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Random matchmaking is coming soon.',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'SOON',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _friendTile(ThemeData theme, UserModel friend) {
    final busy = _sendingChallenges.contains(friend.username.toLowerCase());
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: friend.name,
            photoUrl: friend.photoUrl,
            radius: 22,
            showOnlineIndicator: true,
            isOnline: friend.isOnline,
            presence: friend.status,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@${friend.username} · ${friend.isOnline ? 'Online' : 'Invite anytime'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: busy ? null : () => _challengeFriend(friend),
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sports_esports_rounded, size: 16),
            label: Text(busy ? 'Opening' : 'Invite'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyFriends(ThemeData theme, String username) {
    return _messageCard(
      theme,
      icon: Icons.people_outline_rounded,
      title: 'No friends yet',
      subtitle: 'Add a Novyn friend to send your first game invite.',
      action: TextButton.icon(
        onPressed: () => _openFindFriends(username),
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
        label: const Text('Find friends'),
      ),
    );
  }

  Widget _messageCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            action,
          ],
        ],
      ),
    );
  }
}
