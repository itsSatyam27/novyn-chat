import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _scope = 'Friends';
  String _game = 'Overall';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rankings = const [];
  int _totalPlayers = 0;
  Map<String, dynamic>? _myEntry;
  int _loadGeneration = 0;

  static const _games = <String>[
    'Overall',
    'Tic-Tac-Toe',
    'Rock Paper Scissors',
    'Raja Mantri',
  ];

  String get _gameKey => switch (_game) {
        'Tic-Tac-Toe' => 'tictactoe',
        'Rock Paper Scissors' => 'rps',
        'Raja Mantri' => 'rajamantri',
        _ => 'overall',
      };

  @override
  void initState() {
    super.initState();
    unawaited(_loadLeaderboard());
  }

  Future<void> _loadLeaderboard() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final payload = await ApiService.getGameLeaderboard(
        scope: _scope.toLowerCase(),
        game: _gameKey,
      );
      final rawRankings = payload['rankings'];
      final rankings = rawRankings is List
          ? rawRankings
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      final rawMe = payload['myEntry'];
      final myEntry = rawMe is Map ? Map<String, dynamic>.from(rawMe) : null;
      final rawTotalPlayers = payload['totalPlayers'];
      final parsedTotalPlayers = rawTotalPlayers is num
          ? rawTotalPlayers.toInt()
          : int.tryParse('$rawTotalPlayers') ?? rankings.length;
      final totalPlayers = parsedTotalPlayers < rankings.length
          ? rankings.length
          : parsedTotalPlayers;
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _rankings = rankings;
        _totalPlayers = totalPlayers;
        _myEntry = myEntry;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
        _loading = false;
      });
    }
  }

  void _selectScope(String value) {
    if (_scope == value) return;
    setState(() => _scope = value);
    unawaited(_loadLeaderboard());
  }

  void _selectGame(String value) {
    if (_game == value) return;
    setState(() => _game = value);
    unawaited(_loadLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = colors.primary;
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF211B36);
    final muted = isDark ? Colors.white60 : const Color(0xFF77718F);
    final surface = isDark ? const Color(0xFF201B36) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
        foregroundColor: foreground,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLeaderboard,
          color: accent,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      onTap: () => _selectScope('Friends'),
                    ),
                    _ScopeTab(
                      label: 'Global',
                      selected: _scope == 'Global',
                      onTap: () => _selectScope('Global'),
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
                      onSelected: (_) => _selectGame(game),
                      selectedColor: accent,
                      backgroundColor: surface,
                      labelStyle: TextStyle(
                        color: selected ? colors.onPrimary : foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      side: BorderSide.none,
                      showCheckmark: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: accent,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Score: +10 per human match, +25 for a win, +15 for every 3-win streak.',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF625D8C),
                          fontSize: 11,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 72),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: accent,
                          strokeWidth: 2.5,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Loading rankings…',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                _LeaderboardMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load leaderboard',
                  message: _error!,
                  actionLabel: 'Try again',
                  onAction: () => unawaited(_loadLeaderboard()),
                  isDark: isDark,
                )
              else if (_rankings.isEmpty ||
                  (_rankings.length == 1 &&
                      _rankings.first['isSelf'] == true &&
                      _intValue(_rankings.first['matches']) == 0))
                _LeaderboardMessage(
                  icon: Icons.emoji_events_rounded,
                  title: 'No scores yet',
                  message: _scope == 'Friends'
                      ? 'Finish a real match with a friend to start your leaderboard.'
                      : 'The Global leaderboard will fill up as players complete real matches.',
                  isDark: isDark,
                )
              else ...[
                Row(
                  children: [
                    Text(
                      _scope == 'Friends' ? 'FRIENDS RANKING' : 'GLOBAL RANKING',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _totalPlayers > _rankings.length
                          ? 'Top ${_rankings.length} of $_totalPlayers players'
                          : '$_totalPlayers players',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._rankings.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _LeaderboardPlayerTile(
                      entry: entry,
                      isDark: isDark,
                    ),
                  ),
                ),
                if (_myEntry != null &&
                    _intValue(_myEntry!['rank']) > _rankings.length) ...[
                  const SizedBox(height: 12),
                  Text(
                    'YOUR POSITION',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LeaderboardPlayerTile(
                    entry: _myEntry!,
                    isDark: isDark,
                    highlight: true,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  static int _intValue(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

class _LeaderboardPlayerTile extends StatelessWidget {
  const _LeaderboardPlayerTile({
    required this.entry,
    required this.isDark,
    this.highlight = false,
  });

  final Map<String, dynamic> entry;
  final bool isDark;
  final bool highlight;

  int _number(String key) {
    final value = entry[key];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    final foreground = isDark ? Colors.white : const Color(0xFF211B36);
    final muted = isDark ? Colors.white60 : const Color(0xFF77718F);
    final name = (entry['displayName'] ?? entry['username'] ?? 'Player').toString();
    final username = (entry['username'] ?? '').toString();
    final rank = _number('rank');
    final isSelf = entry['isSelf'] == true;
    final score = _number('score');
    final matches = _number('matches');
    final wins = _number('wins');
    final winRate = _number('winRate');
    final rankColor = rank == 1
        ? const Color(0xFFFFC857)
        : rank == 2
            ? const Color(0xFF9BA5B5)
            : rank == 3
                ? const Color(0xFFCD8B55)
                : accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: highlight
            ? Color.alphaBlend(
                accent.withValues(alpha: .12),
                colors.surface,
              )
            : colors.surface,
        borderRadius: BorderRadius.circular(19),
        border: highlight
            ? Border.all(color: accent.withValues(alpha: .65), width: 1.2)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rankColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          CircleAvatar(
            radius: 21,
            backgroundColor: rankColor.withValues(alpha: 0.17),
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '@$username · $matches matches · $wins wins · $winRate% win rate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              Text(
                'PTS',
                style: TextStyle(
                  color: muted,
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardMessage extends StatelessWidget {
  const _LeaderboardMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.isDark,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isDark;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    final foreground = isDark ? Colors.white : const Color(0xFF211B36);
    final muted = isDark ? Colors.white60 : const Color(0xFF77718F);
    return Container(
      margin: const EdgeInsets.only(top: 34),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: foreground,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              height: 1.5,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: colors.onPrimary,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
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
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.onPrimary : colors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
