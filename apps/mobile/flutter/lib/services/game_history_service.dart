import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

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

  int get practiceMatches => matches.where((match) => match.isBotMatch).length;
  int get competitiveTotal =>
      matches.where((match) => !match.isBotMatch).length;
  int get competitiveWins => matches
      .where((match) => !match.isBotMatch && match.result == 'win')
      .length;
  int get competitiveLosses => matches
      .where((match) => !match.isBotMatch && match.result == 'loss')
      .length;
  int get competitiveDraws => matches
      .where((match) => !match.isBotMatch && match.result == 'draw')
      .length;
  double get competitiveWinRate => competitiveTotal == 0
      ? 0
      : competitiveWins / competitiveTotal * 100;

  /// Per-game competitive statistics exclude local bot/practice matches.
  List<GameTypeStats> get gameBreakdown {
    final grouped = <String, List<GameHistoryEntry>>{};
    for (final match in matches) {
      if (match.isBotMatch) continue;
      final game = _normaliseGameType(match.gameType);
      (grouped[game] ??= <GameHistoryEntry>[]).add(match);
    }
    final result = grouped.entries.map((entry) {
      final gameMatches = entry.value;
      final ordered = List<GameHistoryEntry>.from(gameMatches)
        ..sort((a, b) => a.playedAt.compareTo(b.playedAt));
      var current = 0;
      var best = 0;
      for (final match in ordered) {
        if (match.result == 'win') {
          current++;
          if (current > best) best = current;
        } else {
          current = 0;
        }
      }
      return GameTypeStats(
        gameType: entry.key,
        total: gameMatches.length,
        wins: gameMatches.where((match) => match.result == 'win').length,
        losses: gameMatches.where((match) => match.result == 'loss').length,
        draws: gameMatches.where((match) => match.result == 'draw').length,
        currentWinStreak: currentWinStreak(entry.key),
        longestWinStreak: best,
      );
    }).toList()
      ..sort((a, b) {
        final byTotal = b.total.compareTo(a.total);
        return byTotal != 0 ? byTotal : a.gameType.compareTo(b.gameType);
      });
    return List<GameTypeStats>.unmodifiable(result);
  }

  /// XP is derived from completed, de-duplicated competitive match history.
  /// Human matches: +10 completion, +25 win, +10 first human win each day.
  /// Every third consecutive human win in the same game grants +15 XP.
  /// Bot matches remain in history but award no XP or competitive streak credit.
  int get totalXp {
    final chronological = List<GameHistoryEntry>.from(matches)
      ..sort((a, b) => a.playedAt.compareTo(b.playedAt));
    final competitiveStreaks = <String, int>{};
    final firstHumanWinDays = <DateTime>{};
    var xp = 0;

    for (final match in chronological) {
      if (match.isBotMatch) continue;
      final game = _normaliseGameType(match.gameType);
      final isWin = match.result == 'win';
      xp += 10;
      if (isWin) xp += 25;

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
      if (match.isBotMatch) continue;
      if (_normaliseGameType(match.gameType) != target) continue;
      if (match.result != 'win') break;
      streak++;
    }
    return streak;
  }

  static String _normaliseGameType(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class GameTypeStats {
  const GameTypeStats({
    required this.gameType,
    required this.total,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.currentWinStreak,
    required this.longestWinStreak,
  });

  final String gameType;
  final int total;
  final int wins;
  final int losses;
  final int draws;
  final int currentWinStreak;
  final int longestWinStreak;

  double get winRate => total == 0 ? 0 : wins / total * 100;
}

class GameHistoryService {
  GameHistoryService._();

  static const _keyPrefix = 'novyn_game_history_v1_';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static Future<void> _writeQueue = Future<void>.value();

  static String _key(String username) =>
      '$_keyPrefix${Uri.encodeComponent(username.trim().toLowerCase())}';

  @visibleForTesting
  static Future<List<Map<String, dynamic>>?> Function()?
      cloudHistoryLoaderForTesting;

  static List<GameHistoryEntry> _decodeEntries(Object? decoded) {
    if (decoded is! List) return <GameHistoryEntry>[];
    final unique = <String, GameHistoryEntry>{};
    for (final raw in decoded) {
      if (raw is! Map) continue;
      try {
        final entry = GameHistoryEntry.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (entry.id.isEmpty ||
            entry.gameType.trim().isEmpty ||
            !const {'win', 'loss', 'draw'}.contains(entry.result) ||
            entry.playedAt.millisecondsSinceEpoch <= 0) {
          continue;
        }
        unique[entry.id] = entry;
      } catch (_) {
        // A malformed row must not hide the rest of the match history.
      }
    }
    final matches = unique.values.toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return matches;
  }

  static Future<List<GameHistoryEntry>> _loadLocalMatches(
    String username, {
    SharedPreferences? preferences,
  }) async {
    if (username.trim().isEmpty) return <GameHistoryEntry>[];
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(username));
      if (raw == null || raw.isEmpty) return <GameHistoryEntry>[];
      return _decodeEntries(jsonDecode(raw));
    } catch (_) {
      return <GameHistoryEntry>[];
    }
  }

  static Future<GameStatsSnapshot> load(String username) async {
    if (username.trim().isEmpty) return GameStatsSnapshot.empty;

    // The local cache is read first so the history remains usable offline.
    // A missing cache is not an empty account: always try the cloud source too.
    SharedPreferences? prefs;
    var localMatches = <GameHistoryEntry>[];
    try {
      prefs = await SharedPreferences.getInstance();
      localMatches = await _loadLocalMatches(username, preferences: prefs);
    } catch (_) {
      // Continue with the cloud read even when local storage is unavailable.
    }

    List<Map<String, dynamic>>? cloud;
    try {
      final loader = cloudHistoryLoaderForTesting;
      cloud = loader == null
          ? await ApiService.getGameHistory()
          : await loader();
    } catch (_) {
      cloud = null;
    }

    if (cloud == null) {
      return GameStatsSnapshot(List<GameHistoryEntry>.unmodifiable(localMatches));
    }

    // Server records are authoritative for matching IDs. Local-only entries
    // stay visible as an offline/legacy fallback, but clients never upload
    // unverified results into competitive history.
    final merged = <String, GameHistoryEntry>{
      for (final match in localMatches) match.id: match,
      for (final match in _decodeEntries(cloud)) match.id: match,
    };
    final synced = merged.values.toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

    if (prefs != null) {
      try {
        await prefs.setString(
          _key(username),
          jsonEncode(synced.map((match) => match.toJson()).toList()),
        );
      } catch (_) {
        // A cache write failure must not discard the loaded cloud history.
      }
    }
    return GameStatsSnapshot(List<GameHistoryEntry>.unmodifiable(synced));
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
      final existing = await _loadLocalMatches(username, preferences: prefs);
      if (existing.any((match) => match.id == matchId)) return;
      final matches = <GameHistoryEntry>[
        GameHistoryEntry(
          id: matchId,
          gameType: gameType,
          opponent: opponent.trim().isEmpty ? 'Opponent' : opponent.trim(),
          result: normalizedResult,
          playedAt: playedAt,
          isBotMatch: isBotMatch,
        ),
        ...existing,
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
