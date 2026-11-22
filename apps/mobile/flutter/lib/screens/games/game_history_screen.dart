import 'package:flutter/material.dart';

import '../../services/game_history_service.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key, required this.username});

  final String username;

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  late Future<GameStatsSnapshot> _history;

  @override
  void initState() {
    super.initState();
    _history = GameHistoryService.load(widget.username);
  }

  Future<void> _refresh() async {
    final next = GameHistoryService.load(widget.username);
    setState(() => _history = next);
    await next;
  }

  String _title(String type) => switch (type) {
        'tictactoe' => 'Tic-Tac-Toe',
        'rps' => 'Rock Paper Scissors',
        _ => 'Novyn Game',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? theme.scaffoldBackgroundColor : const Color(0xFFF5F1FC),
      appBar: AppBar(
        title: const Text('Match history'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<GameStatsSnapshot>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = snapshot.data?.matches ?? const <GameHistoryEntry>[];
          if (matches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECE7FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sports_esports_rounded,
                        color: Color(0xFF684BF5),
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No matches yet',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completed games will show up here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
              itemCount: matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final match = matches[index];
                final resultColor = switch (match.result) {
                  'win' => const Color(0xFF079B73),
                  'loss' => const Color(0xFFE34D87),
                  _ => const Color(0xFF817A9B),
                };
                final resultLabel = match.result == 'win'
                    ? 'WIN'
                    : match.result == 'loss'
                        ? 'LOSS'
                        : 'DRAW';
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: dark ? scheme.surface : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0ECFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sports_esports_rounded, color: Color(0xFF684BF5)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(match.gameType),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'vs ${match.opponent}  ·  ${_formatDate(match.playedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: resultColor.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          resultLabel,
                          style: TextStyle(fontSize: 11, letterSpacing: .4, fontWeight: FontWeight.w900, color: resultColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} · $hour:$minute $period';
  }
}
