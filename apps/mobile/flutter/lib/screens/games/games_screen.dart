import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../services/game_history_service.dart';
import 'game_history_screen.dart';
import 'game_lobby_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const _lastPlayedKey = 'games_last_played_v1';
  String _statsUsername = '';
  GameStatsSnapshot _stats = GameStatsSnapshot.empty;
  int _statsLoadGeneration = 0;
  String? _lastPlayedType;

  static const List<_GameOption> _games = <_GameOption>[
    _GameOption('tictactoe', 'Tic-Tac-Toe', 'Quick strategy', Icons.grid_3x3_rounded),
    _GameOption('rps', 'Rock Paper Scissors', 'Fast showdown', Icons.back_hand_rounded),
  ];

  static List<_GameOption> get _featuredGames => _games;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastPlayed());
  }

  Future<void> _loadLastPlayed() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_lastPlayedKey);
      if (!mounted) return;
      setState(() => _lastPlayedType =
          _featuredGames.any((game) => game.type == saved) ? saved : null);
    } catch (_) {
      // Game selection remains available if local preferences cannot be read.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthService?>(context)?.user;
    final username = user?.username.trim() ?? '';
    if (username.toLowerCase() != _statsUsername.toLowerCase()) {
      _statsUsername = username;
      _loadStats(username);
    }
  }

  Future<void> _loadStats(String username) async {
    final generation = ++_statsLoadGeneration;
    if (mounted) setState(() => _stats = GameStatsSnapshot.empty);
    if (username.isEmpty) return;
    final snapshot = await GameHistoryService.load(username);
    if (!mounted || generation != _statsLoadGeneration) return;
    setState(() => _stats = snapshot);
  }

  Future<void> _openGame(_GameOption game) async {
    if (!mounted) return;
    setState(() => _lastPlayedType = game.type);
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastPlayedKey, game.type);
      } catch (_) {}
    }());
    final screen = GameLobbyScreen(
      gameType: game.type,
      title: game.title,
      subtitle: game.subtitle,
      icon: game.icon,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) _loadStats(_statsUsername);
  }

  Future<void> _openHistory(String username) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameHistoryScreen(username: username),
      ),
    );
    if (mounted) _loadStats(_statsUsername);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final user = Provider.of<AuthService?>(context)?.user;
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : (user?.username.trim().isNotEmpty == true ? user!.username : 'Your profile');
    final username = user?.username.trim() ?? '';

    return Scaffold(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF5F1FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
          children: [
            Text(
              'Games',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontFamily: 'PlusJakartaSans',
                fontSize: 36,
                height: 1.12,
                letterSpacing: -1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 17),
            _GameProfileCard(
              displayName: displayName,
              username: username,
              stats: _stats,
              onHistoryTap: () => _openHistory(username),
              isDark: isDark,
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pick a game',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.45,
                    ),
                  ),
                ),
                Text(
                  '${_featuredGames.length} games',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            for (final game in _featuredGames) ...[
              _FeaturedGameCard(
                game: game,
                lastPlayed: _lastPlayedType == game.type,
                onTap: () => _openGame(game),
              ),
              if (game != _featuredGames.last) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _GameProfileCard extends StatelessWidget {
  const _GameProfileCard({
    required this.displayName,
    required this.username,
    required this.stats,
    required this.onHistoryTap,
    required this.isDark,
  });

  final String displayName;
  final String username;
  final GameStatsSnapshot stats;
  final VoidCallback onHistoryTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDark ? scheme.outlineVariant.withValues(alpha: .35) : const Color(0xFFE3DBFF),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6348E8).withValues(alpha: isDark ? .08 : .055),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFECE7FF),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Color(0xFF684BF5),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.25,
                          ),
                    ),
                    Text(
                      username.isEmpty ? 'Game profile' : '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: onHistoryTap,
                tooltip: 'View match history',
                icon: const Icon(Icons.history_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF6548EF),
                  backgroundColor: const Color(0xFFF0ECFF),
                  minimumSize: const Size(46, 46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .35)),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: _StatValue(label: 'MATCHES', value: '${stats.total}')),
              _statDivider(scheme),
              Expanded(child: _StatValue(label: 'WINS', value: '${stats.wins}', color: const Color(0xFF6548EF))),
              _statDivider(scheme),
              Expanded(child: _StatValue(label: 'LOSSES', value: '${stats.losses}', color: const Color(0xFFE34D87))),
              _statDivider(scheme),
              Expanded(child: _StatValue(label: 'DRAWS', value: '${stats.draws}', color: const Color(0xFF817A9B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statDivider(ColorScheme scheme) => Container(
        width: 1,
        height: 31,
        color: scheme.outlineVariant.withValues(alpha: .4),
      );
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: .65,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      );
}

class _FeaturedGameCard extends StatelessWidget {
  const _FeaturedGameCard({
    required this.game,
    required this.lastPlayed,
    required this.onTap,
  });

  final _GameOption game;
  final bool lastPlayed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTicTacToe = game.type == 'tictactoe';
    final gradient = isTicTacToe
        ? const [Color(0xFF8061FF), Color(0xFF6241E7)]
        : const [Color(0xFFEE4C91), Color(0xFFB72A83)];

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(31),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(31),
        child: Container(
          height: 218,
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(31),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: .2),
                blurRadius: 22,
                offset: const Offset(0, 11),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 1,
                child: _GameArtwork(gameType: game.type),
              ),
              if (lastPlayed)
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Last played',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 70,
                bottom: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.08,
                        letterSpacing: -.6,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      game.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .86),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.north_east_rounded, color: Color(0xFF6347EB), size: 25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameArtwork extends StatelessWidget {
  const _GameArtwork({required this.gameType});

  final String gameType;

  @override
  Widget build(BuildContext context) {
    if (gameType == 'tictactoe') {
      return Icon(
        Icons.grid_3x3_rounded,
        size: 105,
        color: Colors.white.withValues(alpha: .5),
      );
    }

    return Row(
      children: [
        _rpsIcon(Icons.back_hand_rounded),
        _rpsIcon(Icons.article_rounded),
        _rpsIcon(Icons.content_cut_rounded),
      ],
    );
  }

  Widget _rpsIcon(IconData icon) => Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      );
}

class _GameOption {
  const _GameOption(this.type, this.title, this.subtitle, this.icon);

  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
}
