import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameHistoryEntry {
  const GameHistoryEntry({
    required this.id,
    required this.gameType,
    required this.opponent,
    required this.result,
    required this.playedAt,
    this.isBotMatch = false,
  });

  final String id;
  final String gameType;
  final String opponent;
  final String result;
  final DateTime playedAt;
  final bool isBotMatch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameType': gameType,
        'opponent': opponent,
        'result': result,
        'playedAt': playedAt.toIso8601String(),
        'isBotMatch': isBotMatch,
      };

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) =>
      GameHistoryEntry(
        id: json['id']?.toString() ?? '',
        gameType: json['gameType']?.toString() ?? '',
        opponent: json['opponent']?.toString() ?? 'Opponent',
        result: json['result']?.toString() ?? 'draw',
        playedAt: DateTime.tryParse(json['playedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        isBotMatch: json['isBotMatch'] == true,
      );
}

class GameStatsSnapshot {
  const GameStatsSnapshot(this.matches);

  static const empty = GameStatsSnapshot(<GameHistoryEntry>[]);
  static const xpPerLevel = 500;

  final List<GameHistoryEntry> matches;

  int get total => matches.length;
  int get wins => matches.where((match) => match.result == 'win').length;
  int get losses => matches.where((match) => match.result == 'loss').length;
  int get draws => matches.where((match) => match.result == 'draw').length;

  /// XP is derived from completed, de-duplicated match history.
  /// Human matches: +10 completion, +25 win, +10 first human win each day.
  /// Bot matches: +5 completion and +10 win, with no daily/milestone bonus.
  /// Every third consecutive human win in the same game grants +15 XP.
  int get totalXp {
    final chronological = List<GameHistoryEntry>.from(matches)
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));
    final competitiveStreaks = <String, int>{};
    final firstHumanWinDays = <DateTime>{};
    var xp = 0;

    for (final match in chronological) {
      final game = _normaliseGameType(match.gameType);
      final isWin = match.result == 'win';
      xp += match.isBotMatch ? 5 : 10;

      if (isWin) {
        xp += match.isBotMatch ? 10 : 25;
      }

      if (match.isBotMatch) {
        competitiveStreaks[game] = 0;
        continue;
      }

      if (!isWin) {
        competitiveStreaks[game] = 0;
        continue;
      }

      final streak = (competitiveStreaks[game] ?? 0) + 1;
      competitiveStreaks[game] = streak;
      if (streak % 3 == 0) xp += 15;

      final local = match.playedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (firstHumanWinDays.add(day)) xp += 10;
    }
    return xp;
  }

  int get level => (totalXp ~/ xpPerLevel) + 1;
  int get xpIntoCurrentLevel => totalXp % xpPerLevel;
  int get xpToNextLevel => xpPerLevel - xpIntoCurrentLevel;
  double get levelProgress => xpIntoCurrentLevel / xpPerLevel;

  int currentWinStreak(String gameType) {
    final target = _normaliseGameType(gameType);
    final chronological = List<GameHistoryEntry>.from(matches)
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    var streak = 0;
    for (final match in chronological) {
      if (_normaliseGameType(match.gameType) != target) continue;
      if (match.result != 'win') break;
      streak++;
    }
    return streak;
  }

  static String _normaliseGameType(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class GameHistoryService {
  GameHistoryService._();

  static const _keyPrefix = 'novyn_game_history_v1_';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static Future<void> _writeQueue = Future<void>.value();

  static String _key(String username) =>
      '$_keyPrefix${Uri.encodeComponent(username.trim().toLowerCase())}';

  static Future<GameStatsSnapshot> load(String username) async {
    if (username.trim().isEmpty) return GameStatsSnapshot.empty;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(username));
      if (raw == null || raw.isEmpty) return GameStatsSnapshot.empty;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return GameStatsSnapshot.empty;
      final matches = decoded
          .whereType<Map>()
          .map((entry) => GameHistoryEntry.fromJson(
                Map<String, dynamic>.from(entry),
              ))
          .where((entry) => entry.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
      return GameStatsSnapshot(List<GameHistoryEntry>.unmodifiable(matches));
    } catch (_) {
      return GameStatsSnapshot.empty;
    }
  }

  static Future<void> recordFinishedMatch({
    required String username,
    required String matchId,
    required String gameType,
    required String opponent,
    required String result,
    required DateTime playedAt,
    bool isBotMatch = false,
  }) {
    if (username.trim().isEmpty || matchId.trim().isEmpty) {
      return Future<void>.value();
    }
    final pending = _writeQueue.then((_) => _recordFinishedMatch(
          username: username,
          matchId: matchId,
          gameType: gameType,
          opponent: opponent,
          result: result,
          playedAt: playedAt,
          isBotMatch: isBotMatch,
        ));
    _writeQueue = pending.catchError((_) {});
    return pending;
  }

  static Future<void> _recordFinishedMatch({
    required String username,
    required String matchId,
    required String gameType,
    required String opponent,
    required String result,
    required DateTime playedAt,
    required bool isBotMatch,
  }) async {
    final normalizedResult = const {'win', 'loss', 'draw'}.contains(result)
        ? result
        : 'draw';
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(username);
      final existing = await load(username);
      if (existing.matches.any((match) => match.id == matchId)) return;
      final matches = <GameHistoryEntry>[
        GameHistoryEntry(
          id: matchId,
          gameType: gameType,
          opponent: opponent.trim().isEmpty ? 'Opponent' : opponent.trim(),
          result: normalizedResult,
          playedAt: playedAt,
          isBotMatch: isBotMatch,
        ),
        ...existing.matches,
      ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
      await prefs.setString(
        key,
        jsonEncode(matches.map((match) => match.toJson()).toList()),
      );
      revision.value++;
    } catch (_) {
      // A failed local write must never interrupt a finished match.
    }
  }
}
