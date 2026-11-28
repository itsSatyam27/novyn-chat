import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/game_achievements_service.dart';
import 'package:novyn/services/game_history_service.dart';

GameHistoryEntry match(
  String id,
  String game,
  String result,
  int minute, {
  bool bot = false,
}) {
  return GameHistoryEntry(
    id: id,
    gameType: game,
    opponent: 'opponent',
    result: result,
    playedAt: DateTime(2026, 1, 1, 0, minute),
    isBotMatch: bot,
  );
}

void main() {
  group('GameAchievementsService', () {
    test('starts with all achievements locked and zero progress', () {
      final snapshot = GameAchievementsService.evaluate(const []);

      expect(snapshot.total, 8);
      expect(snapshot.unlocked, 0);
      expect(snapshot.remaining, 8);
      expect(snapshot.completion, 0);
      expect(snapshot.achievements.every((item) => !item.isUnlocked), isTrue);
    });

    test('bot matches do not count toward competitive achievements', () {
      final snapshot = GameAchievementsService.evaluate([
        match('bot-1', 'tictactoe', 'win', 1, bot: true),
        match('bot-2', 'rps', 'win', 2, bot: true),
        match('bot-3', 'rajamantri', 'win', 3, bot: true),
      ]);

      expect(snapshot.unlocked, 0);
      expect(snapshot.achievements.first.progress, 0);
      expect(snapshot.achievements[3].progress, 0);
      expect(snapshot.achievements.last.progress, 0);
    });

    test('tracks match and win milestones from human matches', () {
      final snapshot = GameAchievementsService.evaluate([
        match('m1', 'tictactoe', 'win', 1),
        match('m2', 'tictactoe', 'win', 2),
        match('m3', 'tictactoe', 'loss', 3),
        match('m4', 'rps', 'win', 4),
        match('m5', 'rps', 'win', 5),
      ]);

      final byId = {for (final item in snapshot.achievements) item.id: item};
      expect(byId['first_match']!.isUnlocked, isTrue);
      expect(byId['getting_started']!.isUnlocked, isTrue);
      expect(byId['game_regular']!.progress, 5);
      expect(byId['first_victory']!.isUnlocked, isTrue);
      expect(byId['five_wins']!.progress, 4);
      expect(byId['all_rounder']!.progress, 2);
    });

    test('streak achievements require consecutive wins in the same game', () {
      final mixed = GameAchievementsService.evaluate([
        match('m1', 'tictactoe', 'win', 1),
        match('m2', 'rps', 'win', 2),
        match('m3', 'tictactoe', 'win', 3),
        match('m4', 'rps', 'win', 4),
        match('m5', 'tictactoe', 'win', 5),
        match('m6', 'rps', 'win', 6),
      ]);
      final mixedHatTrick = mixed.achievements.firstWhere(
        (item) => item.id == 'hat_trick',
      );
      expect(mixedHatTrick.progress, 3);
      expect(mixedHatTrick.isUnlocked, isFalse);

      final sameGame = GameAchievementsService.evaluate([
        match('s1', 'rps', 'win', 1),
        match('s2', 'rps', 'win', 2),
        match('s3', 'rps', 'win', 3),
        match('s4', 'rps', 'win', 4),
        match('s5', 'rps', 'win', 5),
      ]);
      final byId = {for (final item in sameGame.achievements) item.id: item};
      expect(byId['hat_trick']!.isUnlocked, isTrue);
      expect(byId['unstoppable']!.isUnlocked, isTrue);
    });

    test('losses and draws reset the streak for that game only', () {
      final snapshot = GameAchievementsService.evaluate([
        match('m1', 'tictactoe', 'win', 1),
        match('m2', 'tictactoe', 'win', 2),
        match('m3', 'tictactoe', 'draw', 3),
        match('m4', 'tictactoe', 'win', 4),
        match('m5', 'rps', 'win', 5),
        match('m6', 'rps', 'win', 6),
        match('m7', 'rps', 'win', 7),
      ]);

      final hatTrick = snapshot.achievements.firstWhere(
        (item) => item.id == 'hat_trick',
      );
      expect(hatTrick.progress, 3);
      expect(hatTrick.isUnlocked, isTrue);
    });

    test('all-rounder counts the three available games only', () {
      final snapshot = GameAchievementsService.evaluate([
        match('m1', 'tictactoe', 'loss', 1),
        match('m2', 'rps', 'draw', 2),
        match('m3', 'Raja Mantri', 'loss', 3),
        match('m4', 'uno', 'win', 4),
      ]);

      final allRounder = snapshot.achievements.firstWhere(
        (item) => item.id == 'all_rounder',
      );
      expect(allRounder.progress, 3);
      expect(allRounder.isUnlocked, isTrue);
    });
  });
}
