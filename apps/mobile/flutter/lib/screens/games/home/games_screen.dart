import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';
import '../../../services/game_history_service.dart';
import '../../../widgets/user_avatar.dart';
import '../shared/history/game_history_screen.dart';
import '../shared/lobby/game_lobby_screen.dart';
import '../raja_mantri/raja_mantri_lobby_screen.dart';
import '../leaderboard/leaderboard_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const _lastPlayedKey = 'games_last_played_v1';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  bool _showSearch = false;
  String _activeCategory = 'All';
  String _statsUsername = '';
  GameStatsSnapshot _stats = GameStatsSnapshot.empty;
  int _statsLoadGeneration = 0;
  Future<void>? _statsLoadFuture;
  double _prevBottomInset = 0;

  static const List<_GameOption> _games = <_GameOption>[
    _GameOption(
      type: 'tictactoe',
      title: 'Tic-Tac-Toe',
      subtitle: 'Quick strategy · 2P',
      icon: Icons.tag_rounded,
      gradient: [Color(0xFF6341ED), Color(0xFF5B3DE6)],
    ),
    _GameOption(
      type: 'rps',
      title: 'Rock Paper',
      subtitle: 'Fast showdown · 2P',
      icon: Icons.content_cut_rounded,
      gradient: [Color(0xFFE53468), Color(0xFFD61E53)],
    ),
  ];

  static const _GameOption _rajaMantriGame = _GameOption(
    type: 'rajamantri',
    title: 'Raja Mantri',
    subtitle: 'Chor Sipahi · 4P',
    icon: Icons.military_tech_rounded,
    gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastPlayed());
    GameHistoryService.revision.addListener(_onGameHistoryChanged);
  }

  @override
  void dispose() {
    GameHistoryService.revision.removeListener(_onGameHistoryChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onGameHistoryChanged() {
    if (mounted && _statsUsername.isNotEmpty) {
      _statsLoadFuture = _loadStats(_statsUsername);
    }
  }

  Future<void> _loadLastPlayed() async {
    try {
      await SharedPreferences.getInstance();
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthService?>(context)?.user;
    final username = user?.username.trim() ?? '';
    if (username.toLowerCase() != _statsUsername.toLowerCase()) {
      _statsUsername = username;
      _statsLoadFuture = _loadStats(username);
    }
  }

  Future<void> _loadStats(String username) async {
    final generation = ++_statsLoadGeneration;
    if (mounted) setState(() => _stats = GameStatsSnapshot.empty);
    if (username.isEmpty) return;
    final snapshot = await GameHistoryService.load(username);
    if (!mounted || generation != _statsLoadGeneration) return;
    setState(() {
      _stats = snapshot;
    });
  }

  Future<void> _openGame(_GameOption game) async {
    if (!mounted) return;
    // The game lobby displays the same XP level shown on the Games profile.
    // Wait for the initial history/cloud refresh so a quick tap cannot send a
    // temporary default Level 1 into random matchmaking.
    final pendingStatsLoad = _statsLoadFuture;
    if (pendingStatsLoad != null) await pendingStatsLoad;
    if (!mounted) return;
    _searchFocusNode.unfocus();
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastPlayedKey, game.type);
      } catch (_) {}
    }());
    if (game.type == 'rajamantri') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const RajaMantriLobbyScreen(),
        ),
      );
      if (mounted) _statsLoadFuture = _loadStats(_statsUsername);
      return;
    }
    final screen = GameLobbyScreen(
      gameType: game.type,
      title: game.title == 'Rock Paper' ? 'Rock Paper Scissors' : game.title,
      subtitle: game.subtitle,
      icon: game.icon,
      playerLevel: _stats.level,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) _statsLoadFuture = _loadStats(_statsUsername);
  }

  Future<void> _openHistory(String username) async {
    _searchFocusNode.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameHistoryScreen(username: username),
      ),
    );
    if (mounted) _statsLoadFuture = _loadStats(_statsUsername);
  }

  List<_GameOption> get _filteredGames {
    final categoryGames = switch (_activeCategory) {
      '2 Player' => _games,
      '3 P / 4 P' => <_GameOption>[_rajaMantriGame],
      _ => <_GameOption>[..._games, _rajaMantriGame],
    };
    if (_searchQuery.isEmpty) return categoryGames;
    return categoryGames.where((g) {
      final q = _searchQuery.toLowerCase();
      return g.title.toLowerCase().contains(q) ||
          g.subtitle.toLowerCase().contains(q) ||
          (g.type == 'rps' && 'rock paper scissors'.contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (_prevBottomInset > 0 && bottomInset == 0 && _searchFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      });
    }
    _prevBottomInset = bottomInset;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = Provider.of<AuthService?>(context)?.user;
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : (user?.username.trim().isNotEmpty == true ? user!.username : 'Harsh');
    final username = user?.username.trim() ?? 'harsh';

    final filtered = _filteredGames;

    return PopScope(
      canPop: !_searchFocusNode.hasFocus,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
        },
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 16, bottom: 116),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Games',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: isDark ? Colors.white : const Color(0xFF1E1A33),
                          ),
                        ),
                      ),
                      _GamesHeaderAction(
                        icon: _showSearch ? Icons.close_rounded : Icons.search_rounded,
                        tooltip: _showSearch ? 'Close search' : 'Search games',
                        onTap: () {
                          setState(() {
                            _showSearch = !_showSearch;
                            if (!_showSearch) {
                              _searchController.clear();
                              _searchQuery = '';
                              _searchFocusNode.unfocus();
                            }
                          });
                          if (_showSearch) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _searchFocusNode.requestFocus();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      _GamesHeaderAction(
                        icon: Icons.emoji_events_rounded,
                        tooltip: 'Leaderboard',
                        onTap: () {
                          _searchFocusNode.unfocus();
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const LeaderboardScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Hero Profile & Stats Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _GameProfileHeroCard(
                    displayName: displayName,
                    username: username,
                    photoUrl: user?.photoUrl ?? '',
                    stats: _stats,
                    onHistoryTap: () => _openHistory(username),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 20),

                if (_showSearch) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF201B36) : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5E44F3).withValues(alpha: isDark ? 0.08 : 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchFocusNode.unfocus(),
                        cursorColor: const Color(0xFF5E44F3),
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E1A33),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          prefixIcon: Icon(Icons.search_rounded, size: 22, color: Color(0xFF7E7A9C)),
                          hintText: 'Search games',
                          hintStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF7E7A9C)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _GamesCategoryPill(
                        label: 'All',
                        selected: _activeCategory == 'All',
                        onTap: () => setState(() => _activeCategory = 'All'),
                      ),
                      const SizedBox(width: 9),
                      _GamesCategoryPill(
                        label: '2 Player',
                        selected: _activeCategory == '2 Player',
                        onTap: () => setState(() => _activeCategory = '2 Player'),
                      ),
                      const SizedBox(width: 9),
                      _GamesCategoryPill(
                        label: '3 P / 4 P',
                        selected: _activeCategory == '3 P / 4 P',
                        onTap: () => setState(() => _activeCategory = '3 P / 4 P'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty && _searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                    child: Center(
                      child: Text(
                        'No games found for "$_searchQuery"',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length + (_searchQuery.isEmpty ? 1 : 0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return _GameComingSoonGridCard(isDark: isDark);
                        }
                        final game = filtered[index];
                        return _GameGridCard(
                          game: game,
                          streakCount: _stats.currentWinStreak(game.type),
                          onPlay: () => _openGame(game),
                        );
                      },
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

class _GamesHeaderAction extends StatelessWidget {
  const _GamesHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? const Color(0xFF292241) : Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 21, color: const Color(0xFF6848F5)),
          ),
        ),
      ),
    );
  }
}

class _GameProfileHeroCard extends StatefulWidget {
  const _GameProfileHeroCard({
    required this.displayName,
    required this.username,
    required this.photoUrl,
    required this.stats,
    required this.onHistoryTap,
    required this.isDark,
  });

  final String displayName;
  final String username;
  final String photoUrl;
  final GameStatsSnapshot stats;
  final VoidCallback onHistoryTap;
  final bool isDark;

  @override
  State<_GameProfileHeroCard> createState() => _GameProfileHeroCardState();
}

class _GameProfileHeroCardState extends State<_GameProfileHeroCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final isDark = widget.isDark;
    final total = stats.total;
    final wins = stats.wins;
    final losses = stats.losses;
    final draws = stats.draws;
    final winRate = total > 0 ? (wins / total * 100).round() : 0;
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A33);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);
    final surface = isDark ? const Color(0xFF201B36) : Colors.white;
    final softSurface = isDark ? const Color(0xFF2A2347) : const Color(0xFFF1EEFC);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5E44F3).withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                SizedBox(
                  width: 66,
                  height: 66,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: stats.levelProgress,
                          strokeWidth: 4,
                          strokeCap: StrokeCap.round,
                          backgroundColor: isDark
                              ? const Color(0xFF453B68)
                              : const Color(0xFFE3DDFB),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6250F5),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: UserAvatar(
                          name: widget.displayName.isNotEmpty
                              ? widget.displayName
                              : widget.username,
                          photoUrl: widget.photoUrl,
                          radius: 27,
                          fallbackColor: const Color(0xFF5E44F3),
                        ),
                      ),
                      Positioned(
                        right: -5,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6250F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: surface, width: 2),
                          ),
                          child: Text(
                            'Lv${stats.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayName.isNotEmpty ? widget.displayName : 'Player',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: stats.levelProgress,
                          minHeight: 7,
                          backgroundColor: isDark
                              ? const Color(0xFF453B68)
                              : const Color(0xFFE3DDFB),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6250F5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${stats.xpIntoCurrentLevel} / ${GameStatsSnapshot.xpPerLevel} XP · ${stats.xpToNextLevel} to Level ${stats.level + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: softSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF5E44F3),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF3A3158) : const Color(0xFFE9E5F6),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStatBox(
                              value: '$total',
                              label: 'Matches',
                              bgColor: softSurface,
                              textColor: foreground,
                              labelColor: muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HeroStatBox(
                              value: '$wins',
                              label: 'Wins',
                              bgColor: isDark ? const Color(0xFF1C332A) : const Color(0xFFE0F4E9),
                              textColor: const Color(0xFF16834A),
                              labelColor: const Color(0xFF388E57),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HeroStatBox(
                              value: '$losses',
                              label: 'Losses',
                              bgColor: isDark ? const Color(0xFF381F28) : const Color(0xFFFDE2E2),
                              textColor: const Color(0xFFD92D2D),
                              labelColor: const Color(0xFFB42318),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HeroStatBox(
                              value: '$draws',
                              label: 'Draws',
                              bgColor: softSurface,
                              textColor: foreground,
                              labelColor: muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            'Win rate',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                height: 7,
                                child: total == 0
                                    ? Container(color: softSurface)
                                    : Row(
                                        children: [
                                          if (wins > 0)
                                            Expanded(
                                              flex: wins,
                                              child: Container(color: const Color(0xFF16A34A)),
                                            ),
                                          if (draws > 0)
                                            Expanded(
                                              flex: draws,
                                              child: Container(color: const Color(0xFFB8ACE8)),
                                            ),
                                          if (losses > 0)
                                            Expanded(
                                              flex: losses,
                                              child: Container(color: const Color(0xFFEF4444)),
                                            ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$winRate%',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16834A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: widget.onHistoryTap,
                          icon: const Icon(Icons.history_rounded, size: 20),
                          label: const Text('Match history'),
                          style: FilledButton.styleFrom(
                            foregroundColor: const Color(0xFF5E44F3),
                            backgroundColor: softSurface,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(48),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HeroStatBox extends StatelessWidget {
  const _HeroStatBox({
    required this.value,
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.labelColor,
  });

  final String value;
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _GamesCategoryPill extends StatelessWidget {
  const _GamesCategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? const Color(0xFF6848F5)
          : (isDark ? const Color(0xFF201B36) : Colors.white),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? const Color(0xFF6848F5)
                  : (isDark ? const Color(0xFF382F57) : const Color(0xFFE7E1FA)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF625D7D)),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameGridCard extends StatelessWidget {
  const _GameGridCard({
    required this.game,
    required this.streakCount,
    required this.onPlay,
  });

  final _GameOption game;
  final int streakCount;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: game.gradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: game.gradient.first.withValues(alpha: isDark ? 0.24 : 0.2),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(game.icon, color: Colors.white, size: 22),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFFFD166), size: 15),
                    const SizedBox(width: 3),
                    Text(
                      '$streakCount',
                      key: ValueKey('game-streak-${game.type}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            game.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            game.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: double.infinity,
                height: 38,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFF5E44F3),
                      size: 19,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Play',
                      style: TextStyle(
                        color: Color(0xFF5E44F3),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameComingSoonGridCard extends StatelessWidget {
  const _GameComingSoonGridCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: isDark ? const Color(0xFF453B6D) : const Color(0xFFD6CEF8),
        strokeWidth: 1.5,
        dashWidth: 6,
        dashSpace: 5,
        radius: 22,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1833).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2449) : const Color(0xFFEEEAFB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF5E44F3),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Coming soon',
              style: TextStyle(
                color: Color(0xFF5E44F3),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashSpace = 5.0,
    this.radius = 24.0,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashSpace != dashSpace ||
      oldDelegate.radius != radius;
}

class _GameOption {
  const _GameOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
}
