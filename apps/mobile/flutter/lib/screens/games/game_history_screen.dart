import 'package:flutter/material.dart';

import '../../services/game_history_service.dart';

enum _HistoryFilter { all, wins, losses }

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key, required this.username});

  final String username;

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  late Future<GameStatsSnapshot> _history;
  late DateTime _month;
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _history = GameHistoryService.load(widget.username);
  }

  Future<void> _refresh() async {
    final next = GameHistoryService.load(widget.username);
    setState(() => _history = next);
    await next;
  }

  DateTime get _monthStart => DateTime(_month.year, _month.month);
  DateTime get _monthEnd => DateTime(_month.year, _month.month + 1);

  List<GameHistoryEntry> _monthMatches(List<GameHistoryEntry> all) =>
      all.where((match) {
        final date = match.playedAt.toLocal();
        return !date.isBefore(_monthStart) && date.isBefore(_monthEnd);
      }).toList();

  String _title(String type) => switch (type.toLowerCase()) {
        'tictactoe' => 'Tic-Tac-Toe',
        'rps' => 'Rock Paper Scissors',
        'rajamantri' || 'raja_mantri' || 'rmcs' => 'Raja Mantri',
        _ => 'Novyn Game',
      };

  IconData _gameIcon(String type) => switch (type.toLowerCase()) {
        'rajamantri' || 'raja_mantri' || 'rmcs' => Icons.military_tech_rounded,
        'rps' => Icons.emoji_events_rounded,
        _ => Icons.sports_esports_rounded,
      };

  String _monthLabel(DateTime date) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _dayLabel(DateTime date, DateTime now) {
    if (DateUtils.isSameDay(date, now)) return 'TODAY';
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'YESTERDAY';
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1].toUpperCase()}';
  }

  String _time(DateTime value) {
    final date = value.toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF1E1A33);
    final muted = dark ? const Color(0xFFB9B3D0) : const Color(0xFF706B88);
    final page = dark ? const Color(0xFF141026) : const Color(0xFFF5F1FF);

    return Scaffold(
      backgroundColor: page,
      body: SafeArea(
        child: FutureBuilder<GameStatsSnapshot>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final monthMatches = _monthMatches(
              snapshot.data?.matches ?? const <GameHistoryEntry>[],
            );
            final wins = monthMatches.where((m) => m.result == 'win').length;
            final losses = monthMatches.where((m) => m.result == 'loss').length;
            final winRate = wins + losses == 0
                ? 0
                : (wins / (wins + losses) * 100).round();
            final filtered = monthMatches.where((match) {
              switch (_filter) {
                case _HistoryFilter.wins:
                  return match.result == 'win';
                case _HistoryFilter.losses:
                  return match.result == 'loss';
                case _HistoryFilter.all:
                  return true;
              }
            }).toList();

            final groups = <DateTime, List<GameHistoryEntry>>{};
            for (final match in filtered) {
              final local = match.playedAt.toLocal();
              final day = DateTime(local.year, local.month, local.day);
              (groups[day] ??= <GameHistoryEntry>[]).add(match);
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                      child: Row(
                        children: [
                          Material(
                            color: dark ? const Color(0xFF282244) : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => Navigator.of(context).pop(),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: Icon(Icons.arrow_back_rounded,
                                  color: foreground, size: 30),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text('Game history',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 25,
                                fontWeight: FontWeight.w900, color: foreground,
                                letterSpacing: -.5)),
                          ),
                          SizedBox(
                            width: 44,
                            child: IconButton(
                              tooltip: 'Refresh history',
                              onPressed: _refresh,
                              icon: Icon(Icons.refresh_rounded, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF201B36) : Colors.white,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('THIS MONTH',
                                    style: TextStyle(color: muted,
                                      fontSize: 13, fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5)),
                                  const SizedBox(height: 5),
                                  Text('$wins wins · $losses losses',
                                    style: TextStyle(color: foreground,
                                      fontSize: 17, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => setState(() {
                                          _month = DateTime(_month.year, _month.month - 1);
                                        }),
                                        icon: Icon(Icons.chevron_left_rounded, color: muted),
                                      ),
                                      Text(_monthLabel(_month),
                                        style: TextStyle(color: muted,
                                          fontSize: 12, fontWeight: FontWeight.w700)),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: _month.year == DateTime.now().year &&
                                            _month.month == DateTime.now().month
                                            ? null
                                            : () => setState(() {
                                                _month = DateTime(_month.year, _month.month + 1);
                                              }),
                                        icon: Icon(Icons.chevron_right_rounded, color: muted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('$winRate%',
                                  style: const TextStyle(color: Color(0xFF168844),
                                    fontSize: 34, fontWeight: FontWeight.w900,
                                    letterSpacing: -1.5)),
                                Text('win rate',
                                  style: TextStyle(color: muted, fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                      child: Row(
                        children: [
                          _filterChip('All', monthMatches.length, _HistoryFilter.all,
                            dark, foreground),
                          const SizedBox(width: 10),
                          _filterChip('Wins', wins, _HistoryFilter.wins,
                            dark, foreground),
                          const SizedBox(width: 10),
                          _filterChip('Losses', losses, _HistoryFilter.losses,
                            dark, foreground),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_esports_rounded, size: 44, color: muted),
                              const SizedBox(height: 12),
                              Text('No matches this month',
                                style: TextStyle(color: foreground,
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text('Completed games will appear here.',
                                style: TextStyle(color: muted, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...groups.entries.expand((entry) {
                      final dayMatches = entry.value;
                      return [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 10, 20, 10),
                            child: Text(_dayLabel(entry.key, DateTime.now()),
                              style: TextStyle(color: muted, fontSize: 13,
                                fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverToBoxAdapter(
                            child: Container(
                              decoration: BoxDecoration(
                                color: dark ? const Color(0xFF201B36) : Colors.white,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < dayMatches.length; i++) ...[
                                    _matchTile(dayMatches[i], dark, foreground, muted),
                                    if (i != dayMatches.length - 1)
                                      Divider(height: 1, color: dark
                                        ? const Color(0xFF352D50)
                                        : const Color(0xFFF0ECF8)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ];
                    }),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, int count, _HistoryFilter filter,
      bool dark, Color foreground) {
    final selected = _filter == filter;
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFF6948F5)
            : (dark ? const Color(0xFF201B36) : Colors.white),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => setState(() => _filter = filter),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Text('$label  $count', textAlign: TextAlign.center,
              style: TextStyle(color: selected ? Colors.white : foreground,
                fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }

  Widget _matchTile(GameHistoryEntry match, bool dark,
      Color foreground, Color muted) {
    final won = match.result == 'win';
    final lost = match.result == 'loss';
    final result = won ? 'Won' : lost ? 'Lost' : 'Draw';
    final resultColor = won ? const Color(0xFF168844)
        : lost ? const Color(0xFFD12D2D) : const Color(0xFF625D75);
    final tileColor = match.gameType.toLowerCase().contains('raja')
        ? const Color(0xFFFCE4EF) : const Color(0xFFECE5FF);
    final iconColor = match.gameType.toLowerCase().contains('raja')
        ? const Color(0xFFB72B78) : const Color(0xFF6948F5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 62, height: 62,
            decoration: BoxDecoration(
              color: dark ? iconColor.withValues(alpha: .18) : tileColor,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(_gameIcon(match.gameType), color: iconColor, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(match.gameType),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground, fontSize: 16,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('vs ${match.opponent} · ${_time(match.playedAt)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(result, style: TextStyle(color: resultColor,
              fontSize: 13, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
