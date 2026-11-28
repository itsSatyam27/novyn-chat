import 'game_history_service.dart';

class GameAchievement {
  const GameAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.progress,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final String iconKey;
  final int progress;
  final int target;

  bool get isUnlocked => progress >= target;
  double get progressFraction =>
      target <= 0 ? 1.0 : (progress / target).clamp(0.0, 1.0).toDouble();
  int get safeProgress => progress.clamp(0, target).toInt();
}

class GameAchievementsSnapshot {
  const GameAchievementsSnapshot(this.achievements);

  final List<GameAchievement> achievements;

  int get total => achievements.length;
  int get unlocked => achievements.where((item) => item.isUnlocked).length;
  int get remaining => total - unlocked;
  double get completion => total == 0 ? 0 : unlocked / total;
}

class GameAchievementsService {
  GameAchievementsService._();

  static const _catalog = <_AchievementRule>[
    _AchievementRule(
      id: 'first_match',
      title: 'First Match',
      description: 'Complete your first human match.',
      iconKey: 'first_match',
      target: 1,
      metric: _AchievementMetric.matches,
    ),
    _AchievementRule(
      id: 'getting_started',
      title: 'Getting Started',
      description: 'Complete 5 human matches.',
      iconKey: 'getting_started',
      target: 5,
      metric: _AchievementMetric.matches,
    ),
    _AchievementRule(
      id: 'game_regular',
      title: 'Game Regular',
      description: 'Complete 25 human matches.',
      iconKey: 'game_regular',
      target: 25,
      metric: _AchievementMetric.matches,
    ),
    _AchievementRule(
      id: 'first_victory',
      title: 'First Victory',
      description: 'Win your first human match.',
      iconKey: 'first_victory',
      target: 1,
      metric: _AchievementMetric.wins,
    ),
    _AchievementRule(
      id: 'five_wins',
      title: 'On the Board',
      description: 'Win 5 human matches.',
      iconKey: 'five_wins',
      target: 5,
      metric: _AchievementMetric.wins,
    ),
    _AchievementRule(
      id: 'hat_trick',
      title: 'Hat Trick',
      description: 'Win 3 matches in a row in the same game.',
      iconKey: 'hat_trick',
      target: 3,
      metric: _AchievementMetric.bestStreak,
    ),
    _AchievementRule(
      id: 'unstoppable',
      title: 'Unstoppable',
      description: 'Win 5 matches in a row in the same game.',
      iconKey: 'unstoppable',
      target: 5,
      metric: _AchievementMetric.bestStreak,
    ),
    _AchievementRule(
      id: 'all_rounder',
      title: 'All-Rounder',
      description: 'Complete a human match in all 3 available games.',
      iconKey: 'all_rounder',
      target: 3,
      metric: _AchievementMetric.gameVariety,
    ),
  ];

  static GameAchievementsSnapshot evaluate(List<GameHistoryEntry> matches) {
    // Achievements are competitive milestones: bot matches do not count.
    final humanMatches = matches.where((match) => !match.isBotMatch).toList()
      ..sort((a, b) {
        final byDate = a.playedAt.compareTo(b.playedAt);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    var wins = 0;
    final seenGames = <String>{};
    final currentStreakByGame = <String, int>{};
    var bestStreak = 0;

    for (final match in humanMatches) {
      final game = _normalizeGameType(match.gameType);
      if (game == null) continue;
      seenGames.add(game);

      if (match.result == 'win') {
        wins++;
        final streak = (currentStreakByGame[game] ?? 0) + 1;
        currentStreakByGame[game] = streak;
        if (streak > bestStreak) bestStreak = streak;
      } else if (match.result == 'loss' || match.result == 'draw') {
        currentStreakByGame[game] = 0;
      }
    }

    final achievements = _catalog.map((rule) {
      final progress = switch (rule.metric) {
        _AchievementMetric.matches => humanMatches.length,
        _AchievementMetric.wins => wins,
        _AchievementMetric.bestStreak => bestStreak,
        _AchievementMetric.gameVariety => seenGames.length,
      };
      return GameAchievement(
        id: rule.id,
        title: rule.title,
        description: rule.description,
        iconKey: rule.iconKey,
        progress: progress,
        target: rule.target,
      );
    }).toList(growable: false);

    return GameAchievementsSnapshot(
      List<GameAchievement>.unmodifiable(achievements),
    );
  }

  static String? _normalizeGameType(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return switch (normalized) {
      'tictactoe' => 'tictactoe',
      'rps' || 'rockpaperscissors' => 'rps',
      'rajamantri' || 'rmcs' => 'rajamantri',
      _ => null,
    };
  }
}

enum _AchievementMetric { matches, wins, bestStreak, gameVariety }

class _AchievementRule {
  const _AchievementRule({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.target,
    required this.metric,
  });

  final String id;
  final String title;
  final String description;
  final String iconKey;
  final int target;
  final _AchievementMetric metric;
}
