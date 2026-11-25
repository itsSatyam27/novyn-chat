import 'package:flutter/material.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _scope = 'Friends';
  String _game = 'Overall';

  static const _games = <String>[
    'Overall',
    'Tic-Tac-Toe',
    'Rock Paper Scissors',
    'Raja Mantri',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF211B36);
    final muted = isDark ? Colors.white60 : const Color(0xFF77718F);
    final surface = isDark ? const Color(0xFF201B36) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
        foregroundColor: foreground,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _ScopeTab(
                    label: 'Friends',
                    selected: _scope == 'Friends',
                    onTap: () => setState(() => _scope = 'Friends'),
                  ),
                  _ScopeTab(
                    label: 'Global',
                    selected: _scope == 'Global',
                    onTap: () => setState(() => _scope = 'Global'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'RANK BY GAME',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _games.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final game = _games[index];
                  final selected = _game == game;
                  return ChoiceChip(
                    label: Text(game),
                    selected: selected,
                    onSelected: (_) => setState(() => _game = game),
                    selectedColor: const Color(0xFF6848F5),
                    backgroundColor: surface,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    side: BorderSide.none,
                    showCheckmark: false,
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEE9FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFF6848F5),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Leaderboard is coming',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_scope rankings for $_game will appear here once verified match scores are aggregated on Novyn servers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      height: 1.5,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6848F5) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
