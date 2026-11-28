import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/game_history_service.dart';
import 'package:novyn/screens/games/shared/history/game_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameHistoryService.cloudHistoryLoaderForTesting = null;
  });

  test('bot matches award no XP and do not affect human streaks', () async {
    final base = DateTime(2026, 11, 1, 9);
    Future<void> record(String id, String type, String result, DateTime at,
        {bool bot = false}) {
      return GameHistoryService.recordFinishedMatch(
        username: 'alice',
        matchId: id,
        gameType: type,
        opponent: bot ? 'AI Bot' : 'bob',
        result: result,
        playedAt: at,
        isBotMatch: bot,
      );
    }

    await record('ttt-1', 'tictactoe', 'win', base);
    await record('ttt-2', 'tictactoe', 'win', base.add(const Duration(hours: 1)));
    await record('ttt-3', 'tictactoe', 'win', base.add(const Duration(hours: 2)));
    // A repeated finish event for the same match must not award XP twice.
    await record('ttt-3', 'tictactoe', 'win', base.add(const Duration(hours: 2)));
    await record('rps-human-1', 'rps', 'win', base.add(const Duration(days: 1)));
    await record('rps-bot', 'rps', 'loss', base.add(const Duration(days: 1, hours: 1)),
        bot: true);
    await record('rps-human-2', 'rps', 'win', base.add(const Duration(days: 1, hours: 2)));

    final stats = await GameHistoryService.load('alice');
    // History still shows bot matches locally, but they contribute no XP.
    expect(stats.total, 6);
    expect(stats.totalXp, 210);
    expect(stats.level, 1);
    expect(stats.xpIntoCurrentLevel, 210);
    expect(stats.xpToNextLevel, 290);
    expect(stats.currentWinStreak('tictactoe'), 3);
    expect(stats.currentWinStreak('rps'), 2);
    expect(stats.matches.firstWhere((match) => match.id == 'rps-bot').isBotMatch,
        isTrue);
  });

  test('a loss resets only that game’s current win streak', () async {
    final base = DateTime(2026, 11, 10, 12);
    Future<void> record(String id, String type, String result, int hour) {
      return GameHistoryService.recordFinishedMatch(
        username: 'alice',
        matchId: id,
        gameType: type,
        opponent: 'bob',
        result: result,
        playedAt: base.add(Duration(hours: hour)),
      );
    }

    await record('ttt-1', 'tictactoe', 'win', 0);
    await record('ttt-2', 'tictactoe', 'loss', 1);
    await record('ttt-3', 'tictactoe', 'win', 2);
    await record('rps-1', 'rps', 'win', 3);

    final stats = await GameHistoryService.load('alice');
    expect(stats.currentWinStreak('tictactoe'), 1);
    expect(stats.currentWinStreak('rps'), 1);
  });
  test('loads cloud history when a fresh install has no local cache', () async {
    var cloudReads = 0;
    GameHistoryService.cloudHistoryLoaderForTesting = () async {
      cloudReads++;
      return [
        GameHistoryEntry(
          id: 'cloud-match-1',
          gameType: 'tictactoe',
          opponent: 'bob',
          result: 'win',
          playedAt: DateTime(2026, 11, 20, 12),
        ).toJson(),
      ];
    };

    final snapshot = await GameHistoryService.load('alice');

    expect(cloudReads, 1);
    expect(snapshot.total, 1);
    expect(snapshot.matches.single.id, 'cloud-match-1');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('novyn_game_history_v1_alice'),
      contains('cloud-match-1'),
    );
  });

  test('cloud records override stale cache rows and merge new records', () async {
    SharedPreferences.setMockInitialValues({
      'novyn_game_history_v1_alice': jsonEncode([
        GameHistoryEntry(
          id: 'shared-match',
          gameType: 'rps',
          opponent: 'old-name',
          result: 'loss',
          playedAt: DateTime(2026, 11, 19, 10),
        ).toJson(),
        GameHistoryEntry(
          id: 'local-only-match',
          gameType: 'tictactoe',
          opponent: 'carol',
          result: 'draw',
          playedAt: DateTime(2026, 11, 18, 10),
        ).toJson(),
      ]),
    });
    GameHistoryService.cloudHistoryLoaderForTesting = () async => [
      GameHistoryEntry(
        id: 'shared-match',
        gameType: 'rps',
        opponent: 'bob',
        result: 'win',
        playedAt: DateTime(2026, 11, 19, 10),
      ).toJson(),
      GameHistoryEntry(
        id: 'cloud-only-match',
        gameType: 'rajamantri',
        opponent: 'dave, erin, frank',
        result: 'loss',
        playedAt: DateTime(2026, 11, 17, 10),
      ).toJson(),
    ];

    final snapshot = await GameHistoryService.load('alice');

    expect(snapshot.total, 3);
    expect(
      snapshot.matches.firstWhere((match) => match.id == 'shared-match').result,
      'win',
    );
    expect(
      snapshot.matches.firstWhere((match) => match.id == 'shared-match').opponent,
      'bob',
    );
    expect(snapshot.matches.map((match) => match.id),
        containsAll(['shared-match', 'local-only-match', 'cloud-only-match']));
  });

  test('offline cloud failure keeps the local history cache available', () async {
    SharedPreferences.setMockInitialValues({
      'novyn_game_history_v1_alice': jsonEncode([
        GameHistoryEntry(
          id: 'offline-match',
          gameType: 'tictactoe',
          opponent: 'bob',
          result: 'draw',
          playedAt: DateTime(2026, 11, 15, 10),
        ).toJson(),
      ]),
    });
    GameHistoryService.cloudHistoryLoaderForTesting = () async {
      throw StateError('network unavailable');
    };

    final snapshot = await GameHistoryService.load('alice');

    expect(snapshot.total, 1);
    expect(snapshot.matches.single.id, 'offline-match');
  });

  test('corrupt local cache does not block cloud history recovery', () async {
    SharedPreferences.setMockInitialValues({
      'novyn_game_history_v1_alice': '{not-json',
    });
    GameHistoryService.cloudHistoryLoaderForTesting = () async => [
      GameHistoryEntry(
        id: 'recovered-cloud-match',
        gameType: 'rps',
        opponent: 'bob',
        result: 'draw',
        playedAt: DateTime(2026, 11, 12, 10),
      ).toJson(),
    ];

    final snapshot = await GameHistoryService.load('alice');

    expect(snapshot.total, 1);
    expect(snapshot.matches.single.id, 'recovered-cloud-match');
  });

  test('recording a finished match writes locally without a network round-trip', () async {
    var cloudReads = 0;
    GameHistoryService.cloudHistoryLoaderForTesting = () async {
      cloudReads++;
      return null;
    };

    await GameHistoryService.recordFinishedMatch(
      username: 'alice',
      matchId: 'local-finish',
      gameType: 'tictactoe',
      opponent: 'bob',
      result: 'win',
      playedAt: DateTime(2026, 11, 21, 12),
    );

    expect(cloudReads, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('novyn_game_history_v1_alice'),
      contains('local-finish'),
    );
  });

  test('player statistics separate practice and report each game streak', () async {
    final base = DateTime(2026, 11, 23, 9);
    Future<void> record(
      String id,
      String type,
      String result,
      int hour, {
      bool bot = false,
    }) {
      return GameHistoryService.recordFinishedMatch(
        username: 'alice',
        matchId: id,
        gameType: type,
        opponent: bot ? 'AI Bot' : 'bob',
        result: result,
        playedAt: base.add(Duration(hours: hour)),
        isBotMatch: bot,
      );
    }

    await record('ttt-1', 'tictactoe', 'win', 0);
    await record('ttt-2', 'tictactoe', 'win', 1);
    await record('ttt-3', 'tictactoe', 'win', 2);
    await record('ttt-4', 'tictactoe', 'loss', 3);
    await record('ttt-5', 'tictactoe', 'win', 4);
    await record('rps-1', 'rps', 'win', 5);
    await record('rps-2', 'rps', 'win', 6);
    await record('bot-1', 'tictactoe', 'win', 7, bot: true);

    final stats = await GameHistoryService.load('alice');
    final ttt = stats.gameBreakdown.firstWhere(
      (game) => game.gameType == 'tictactoe',
    );
    final rps = stats.gameBreakdown.firstWhere(
      (game) => game.gameType == 'rps',
    );

    expect(stats.total, 8);
    expect(stats.practiceMatches, 1);
    expect(stats.competitiveTotal, 7);
    expect(stats.competitiveWins, 6);
    expect(stats.competitiveLosses, 1);
    expect(stats.competitiveDraws, 0);
    expect(stats.competitiveWinRate, closeTo(85.714, 0.01));
    expect(stats.gameBreakdown.map((game) => game.gameType),
        ['tictactoe', 'rps']);
    expect(ttt.total, 5);
    expect(ttt.currentWinStreak, 1);
    expect(ttt.longestWinStreak, 3);
    expect(rps.total, 2);
    expect(rps.currentWinStreak, 2);
    expect(rps.longestWinStreak, 2);
  });

  testWidgets('history screen filters draws and labels local bot matches',
      (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'novyn_game_history_v1_alice': jsonEncode([
        GameHistoryEntry(
          id: 'bot-win',
          gameType: 'tictactoe',
          opponent: 'Practice opponent',
          result: 'win',
          playedAt: now,
          isBotMatch: true,
        ).toJson(),
      ]),
    });
    GameHistoryService.cloudHistoryLoaderForTesting = () async => [
      GameHistoryEntry(
        id: 'human-win',
        gameType: 'tictactoe',
        opponent: 'bob',
        result: 'win',
        playedAt: now.subtract(const Duration(minutes: 2)),
      ).toJson(),
      GameHistoryEntry(
        id: 'human-loss',
        gameType: 'rps',
        opponent: 'carol',
        result: 'loss',
        playedAt: now.subtract(const Duration(minutes: 3)),
      ).toJson(),
      GameHistoryEntry(
        id: 'human-draw',
        gameType: 'rajamantri',
        opponent: 'dave, erin, frank',
        result: 'draw',
        playedAt: now.subtract(const Duration(minutes: 4)),
      ).toJson(),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: GameHistoryScreen(username: 'alice'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('vs AI Bot · '), findsOneWidget);
    expect(find.text('Won'), findsNWidgets(2));
    expect(find.text('Lost'), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);

    await tester.tap(find.textContaining('Draws'));
    await tester.pumpAndSettle();

    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('Won'), findsNothing);
    expect(find.text('Lost'), findsNothing);
    expect(find.text('Raja Mantri'), findsOneWidget);
    expect(find.text('No draws this month'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
