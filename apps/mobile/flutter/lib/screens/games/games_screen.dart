import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../services/game_history_service.dart';
import '../../widgets/user_avatar.dart';
import 'game_history_screen.dart';
import 'game_lobby_screen.dart';
import 'raja_mantri_lobby_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const _lastPlayedKey = 'games_last_played_v1';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _carouselController = ScrollController();

  String _searchQuery = '';
  int _activeCarouselIndex = 0;
  String _statsUsername = '';
  GameStatsSnapshot _stats = GameStatsSnapshot.empty;
  int _statsLoadGeneration = 0;
  String? _lastPlayedType;
  double _prevBottomInset = 0;

  static const List<_GameOption> _games = <_GameOption>[
    _GameOption(
      type: 'tictactoe',
      title: 'Tic-Tac-Toe',
      subtitle: 'Quick strategy',
      icon: Icons.tag_rounded,
      gradient: [Color(0xFF6341ED), Color(0xFF5B3DE6)],
    ),
    _GameOption(
      type: 'rps',
      title: 'Rock Paper',
      subtitle: 'Fast showdown',
      icon: Icons.content_cut_rounded,
      gradient: [Color(0xFFE53468), Color(0xFFD61E53)],
    ),
  ];

  static const _GameOption _rajaMantriGame = _GameOption(
    type: 'rajamantri',
    title: 'Raja Mantri',
    subtitle: 'Chor Sipahi (4P)',
    icon: Icons.military_tech_rounded,
    gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastPlayed());
    _carouselController.addListener(_onCarouselScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _carouselController.removeListener(_onCarouselScroll);
    _carouselController.dispose();
    super.dispose();
  }

  void _onCarouselScroll() {
    if (!_carouselController.hasClients) return;
    const itemExtent = 238.0; // card width (224) + separator (14)
    final index = (_carouselController.offset / itemExtent).round().clamp(0, 2);
    if (index != _activeCarouselIndex) {
      setState(() => _activeCarouselIndex = index);
    }
  }

  Future<void> _loadLastPlayed() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_lastPlayedKey);
      if (!mounted) return;
      setState(() => _lastPlayedType =
          _games.any((game) => game.type == saved) ? saved : null);
    } catch (_) {}
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
    _searchFocusNode.unfocus();
    setState(() => _lastPlayedType = game.type);
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
      if (mounted) _loadStats(_statsUsername);
      return;
    }
    final screen = GameLobbyScreen(
      gameType: game.type,
      title: game.title == 'Rock Paper' ? 'Rock Paper Scissors' : game.title,
      subtitle: game.subtitle,
      icon: game.icon,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) _loadStats(_statsUsername);
  }

  Future<void> _openHistory(String username) async {
    _searchFocusNode.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameHistoryScreen(username: username),
      ),
    );
    if (mounted) _loadStats(_statsUsername);
  }

  List<_GameOption> get _filteredGames {
    final list = <_GameOption>[..._games];
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    final res = list.where((g) {
      return g.title.toLowerCase().contains(q) ||
          g.subtitle.toLowerCase().contains(q) ||
          (g.type == 'rps' && 'rock paper scissors'.contains(q));
    }).toList();
    if ('raja mantri chor sipahi rmcs'.contains(q) ||
        _rajaMantriGame.title.toLowerCase().contains(q) ||
        _rajaMantriGame.subtitle.toLowerCase().contains(q)) {
      res.add(_rajaMantriGame);
    }
    return res;
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
                // Title Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Games',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E1A33),
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

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

                // Search Bar
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
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 22,
                          color: Color(0xFF7E7A9C),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF7E7A9C)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _searchFocusNode.unfocus();
                                },
                              )
                            : null,
                        hintText: 'Search games',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF7E7A9C),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

            // 2 Player Section Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '2 Player',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5E44F3),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2 Player Games Carousel
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: Text(
                    'No games found matching "$_searchQuery"',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 236,
                child: ListView.separated(
                  controller: _carouselController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final game = filtered[index];
                    return _GameCarouselCard(
                      game: game,
                      onPlay: () => _openGame(game),
                    );
                  },
                ),
              ),

            if (filtered.isNotEmpty) ...[
              const SizedBox(height: 14),
              // Dots Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    math.max(3, filtered.length),
                    (index) {
                      final isActive = index == _activeCarouselIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF5E44F3)
                              : (isDark ? const Color(0xFF382F57) : const Color(0xFFD8D1F7)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 3 P / 4 P Section Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '3 P / 4 P',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5E44F3),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3 P / 4 P Games Carousel
            SizedBox(
              height: 236,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                children: [
                  _GameCarouselCard(
                    game: _rajaMantriGame,
                    onPlay: () => _openGame(_rajaMantriGame),
                  ),
                  const SizedBox(width: 14),
                  CustomPaint(
                    painter: _DashedBorderPainter(
                      color: isDark ? const Color(0xFF453B6D) : const Color(0xFFD6CEF8),
                      strokeWidth: 1.5,
                      dashWidth: 6,
                      dashSpace: 5,
                      radius: 24,
                    ),
                    child: Container(
                      width: 210,
                      height: 216,
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
                            width: 44,
                            height: 44,
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
                  ),
                ],
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

class _GameProfileHeroCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final total = stats.total;
    final wins = stats.wins;
    final losses = stats.losses;
    final draws = stats.draws;
    final winRate = total > 0 ? (wins / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(26),
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
          // Header Row: Avatar, Name & Handle, History Button
          Row(
            children: [
              UserAvatar(
                name: displayName.isNotEmpty ? displayName : username,
                photoUrl: photoUrl,
                radius: 24,
                fallbackColor: const Color(0xFF5E44F3),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty ? displayName : 'Player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E1A33),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      username.isNotEmpty ? '@$username' : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onHistoryTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2649) : const Color(0xFFEDE9FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Color(0xFF5E44F3),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 4 Stats Badges
          Row(
            children: [
              Expanded(
                child: _HeroStatBox(
                  value: '$total',
                  label: 'Matches',
                  bgColor: isDark ? const Color(0xFF282244) : const Color(0xFFF1EFFF),
                  textColor: isDark ? Colors.white : const Color(0xFF1E1A33),
                  labelColor: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStatBox(
                  value: '$wins',
                  label: 'Wins',
                  bgColor: isDark ? const Color(0xFF1C332A) : const Color(0xFFE8F7EE),
                  textColor: const Color(0xFF16A34A),
                  labelColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF388E57),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStatBox(
                  value: '$losses',
                  label: 'Losses',
                  bgColor: isDark ? const Color(0xFF381F28) : const Color(0xFFFDE8EC),
                  textColor: const Color(0xFFEF4444),
                  labelColor: isDark ? const Color(0xFFF87171) : const Color(0xFF9E4B57),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStatBox(
                  value: '$draws',
                  label: 'Draws',
                  bgColor: isDark ? const Color(0xFF282244) : const Color(0xFFF1EFFF),
                  textColor: isDark ? Colors.white : const Color(0xFF1E1A33),
                  labelColor: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Win rate label & value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Win rate',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                ),
              ),
              Text(
                '$winRate%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: total == 0
                  ? Container(color: isDark ? const Color(0xFF2C2649) : const Color(0xFFE8E5F4))
                  : Row(
                      children: [
                        if (wins > 0)
                          Expanded(
                            flex: wins,
                            child: Container(color: const Color(0xFF16A34A)),
                          ),
                        if (wins > 0 && (draws > 0 || losses > 0))
                          Container(width: 2, color: Colors.transparent),
                        if (draws > 0)
                          Expanded(
                            flex: draws,
                            child: Container(color: const Color(0xFFB8ACE8)),
                          ),
                        if (draws > 0 && losses > 0)
                          Container(width: 2, color: Colors.transparent),
                        if (losses > 0)
                          Expanded(
                            flex: losses,
                            child: Container(color: const Color(0xFFEF4444)),
                          ),
                      ],
                    ),
            ),
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

class _GameCarouselCard extends StatelessWidget {
  const _GameCarouselCard({
    required this.game,
    required this.onPlay,
  });

  final _GameOption game;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 224,
      height: 216,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: game.gradient,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: game.gradient.first.withValues(alpha: isDark ? 0.22 : 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              game.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const Spacer(),
          // Title
          Text(
            game.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          // Subtitle
          Text(
            game.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Play Button
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: double.infinity,
                height: 42,
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Color(0xFF1E1A33),
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Play',
                      style: TextStyle(
                        color: Color(0xFF1E1A33),
                        fontSize: 14,
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
