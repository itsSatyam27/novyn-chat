import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rps_screen.dart';
import 'tictactoe_screen.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const _lastPlayedKey = 'games_last_played_v1';
  String? _lastPlayedType;

  @override
  void initState() {
    super.initState();
    _loadLastPlayed();
  }

  Future<void> _loadLastPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_lastPlayedKey);
      if (!mounted) return;
      setState(() => _lastPlayedType =
          saved == 'tictactoe' || saved == 'rps' ? saved : null);
    } catch (_) {}
  }

  void _openGame(String type) {
    setState(() => _lastPlayedType = type);
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastPlayedKey, type);
      } catch (_) {}
    }());
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => type == 'tictactoe'
            ? const TicTacToeScreen()
            : const RpsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 112),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 22),
              child: Text(
                'Games',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 36,
                  height: 1.12,
                  letterSpacing: -1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _FeaturedGameCard(
              title: 'Tic-Tac-Toe',
              subtitle: 'Quick strategy',
              isLastPlayed: _lastPlayedType == 'tictactoe',
              colors: const [Color(0xFF8060FA), Color(0xFF5C3FE4)],
              onTap: () => _openGame('tictactoe'),
              art: const _TicTacToeArt(),
            ),
            const SizedBox(height: 14),
            _FeaturedGameCard(
              title: 'Rock Paper Scissors',
              subtitle: 'Fast showdown',
              isLastPlayed: _lastPlayedType == 'rps',
              colors: const [Color(0xFFEB4784), Color(0xFFB9297C)],
              onTap: () => _openGame('rps'),
              art: const _RpsArt(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedGameCard extends StatelessWidget {
  const _FeaturedGameCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.art,
    required this.onTap,
    required this.isLastPlayed,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final Widget art;
  final VoidCallback onTap;
  final bool isLastPlayed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          height: 252,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: .24),
                blurRadius: 26,
                offset: const Offset(0, 13),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 2,
                right: 2,
                child: SizedBox(width: 150, height: 150, child: art),
              ),
              if (isLastPlayed)
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .23),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Last played',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 25,
                              height: 1.1,
                              letterSpacing: -.6,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .9),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.north_east_rounded,
                        color: colors.last,
                        size: 28,
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
  }
}

class _TicTacToeArt extends StatelessWidget {
  const _TicTacToeArt();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TicTacToePainter());
  }
}

class _TicTacToePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .42)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final x = size.width * .28;
    final y = size.height * .28;
    for (final offset in [x, x + size.width * .34]) {
      canvas.drawLine(Offset(offset, 4), Offset(offset, size.height - 4), line);
    }
    for (final offset in [y, y + size.height * .34]) {
      canvas.drawLine(Offset(4, offset), Offset(size.width - 4, offset), line);
    }
    final mark = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(12, 12), Offset(43, 43), mark);
    canvas.drawLine(Offset(43, 12), Offset(12, 43), mark);
    canvas.drawCircle(Offset(size.width * .83, size.height * .18), 17,
        Paint()..color = const Color(0xFFFFD6E7)..style = PaintingStyle.stroke..strokeWidth = 8);
    canvas.drawCircle(Offset(size.width * .5, size.height * .5), 18,
        Paint()..color = const Color(0xFFFFD6E7)..style = PaintingStyle.stroke..strokeWidth = 8);
    canvas.drawLine(Offset(size.width * .65, size.height * .72),
        Offset(size.width * .88, size.height * .94), mark);
    canvas.drawLine(Offset(size.width * .88, size.height * .72),
        Offset(size.width * .65, size.height * .94), mark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RpsArt extends StatelessWidget {
  const _RpsArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 2,
          top: 8,
          child: _RpsSymbol(icon: Icons.back_hand_rounded, angle: -.18),
        ),
        Positioned(
          right: 2,
          top: 8,
          child: _RpsSymbol(icon: Icons.description_rounded, angle: .05),
        ),
        Positioned(
          right: 36,
          bottom: 0,
          child: _RpsSymbol(icon: Icons.content_cut_rounded, angle: .12),
        ),
      ],
    );
  }
}

class _RpsSymbol extends StatelessWidget {
  const _RpsSymbol({required this.icon, required this.angle});
  final IconData icon;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: Container(
          width: 61,
          height: 61,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .22),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 35),
        ),
      );
}
