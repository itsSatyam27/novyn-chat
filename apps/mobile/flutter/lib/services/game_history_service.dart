import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GameHistoryEntry {
  const GameHistoryEntry({
    required this.id,
    required this.gameType,
    required this.opponent,
    required this.result,
    required this.playedAt,
  });

  final String id;
  final String gameType;
  final String opponent;
  final String result;
  final DateTime playedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameType': gameType,
        'opponent': opponent,
        'result': result,
        'playedAt': playedAt.toIso8601String(),
      };

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) =>
      GameHistoryEntry(
        id: json['id']?.toString() ?? '',
        gameType: json['gameType']?.toString() ?? '',
        opponent: json['opponent']?.toString() ?? 'Opponent',
        result: json['result']?.toString() ?? 'draw',
        playedAt: DateTime.tryParse(json['playedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class GameStatsSnapshot {
  const GameStatsSnapshot(this.matches);

  static const empty = GameStatsSnapshot(<GameHistoryEntry>[]);
  final List<GameHistoryEntry> matches;

  int get total => matches.length;
  int get wins => matches.where((match) => match.result == 'win').length;
  int get losses => matches.where((match) => match.result == 'loss').length;
  int get draws => matches.where((match) => match.result == 'draw').length;
}

class GameHistoryService {
  GameHistoryService._();

  static const _keyPrefix = 'novyn_game_history_v1_';
  static const _maxEntries = 250;
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
        ),
        ...existing.matches,
      ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
      await prefs.setString(
        key,
        jsonEncode(matches.take(_maxEntries).map((match) => match.toJson()).toList()),
      );
    } catch (_) {
      // A failed local write must never interrupt a finished match.
    }
  }
}
