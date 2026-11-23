import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/game_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('awards global XP once and reduces rewards for bot matches', () async {
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
    await record('rps-bot', 'rps', 'win', base.add(const Duration(days: 1)),
        bot: true);

    final stats = await GameHistoryService.load('alice');
    expect(stats.total, 4);
    expect(stats.totalXp, 145);
    expect(stats.level, 1);
    expect(stats.xpIntoCurrentLevel, 145);
    expect(stats.xpToNextLevel, 355);
    expect(stats.currentWinStreak('tictactoe'), 3);
    expect(stats.currentWinStreak('rps'), 1);
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
}
