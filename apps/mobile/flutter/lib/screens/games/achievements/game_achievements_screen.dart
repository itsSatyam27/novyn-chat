import 'package:flutter/material.dart';

import '../../../services/game_achievements_service.dart';
import '../../../services/game_history_service.dart';
import '../../../theme/novyn_theme.dart';

class GameAchievementsScreen extends StatelessWidget {
  const GameAchievementsScreen({
    super.key,
    required this.matches,
  });

  final List<GameHistoryEntry> matches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final page = dark ? const Color(0xFF08090D) : const Color(0xFFFBFAFF);
    final achievements = GameAchievementsService.evaluate(matches);
    final unlocked = achievements.achievements
        .where((item) => item.isUnlocked)
        .toList(growable: false);
    final locked = achievements.achievements
        .where((item) => !item.isUnlocked)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: page,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                child: Row(
                  children: [
                    Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.of(context).pop(),
                        child: SizedBox(
                          width: 54,
                          height: 54,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: colors.onSurface,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Achievements',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NovynTheme.fontFamily,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 54),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _AchievementSummary(
                  unlocked: achievements.unlocked,
                  total: achievements.total,
                  completion: achievements.completion,
                ),
              ),
            ),
            if (unlocked.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _SectionHeading(
                  title: 'Unlocked',
                  count: unlocked.length,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: unlocked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _AchievementTile(
                    achievement: unlocked[index],
                    unlocked: true,
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: _SectionHeading(
                title: 'Keep going',
                count: locked.length,
              ),
            ),
            if (locked.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: const _AllUnlockedCard(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: locked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _AchievementTile(
                    achievement: locked[index],
                    unlocked: false,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _AchievementSummary extends StatelessWidget {
  const _AchievementSummary({
    required this.unlocked,
    required this.total,
    required this.completion,
  });

  final int unlocked;
  final int total;
  final double completion;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.military_tech_rounded,
                  color: colors.primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your game milestones',
                      style: TextStyle(
                        fontFamily: NovynTheme.fontFamily,
                        color: colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$unlocked of $total achievements unlocked',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(completion * 100).round()}%',
                style: TextStyle(
                  fontFamily: NovynTheme.fontFamily,
                  color: accent,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completion,
              minHeight: 8,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 20, 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: NovynTheme.fontFamily,
              color: colors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
  });

  final GameAchievement achievement;
  final bool unlocked;

  IconData _iconFor(String key) => switch (key) {
        'first_match' => Icons.sports_esports_rounded,
        'getting_started' => Icons.play_circle_outline_rounded,
        'game_regular' => Icons.calendar_month_rounded,
        'first_victory' => Icons.emoji_events_outlined,
        'five_wins' => Icons.workspace_premium_rounded,
        'hat_trick' => Icons.local_fire_department_rounded,
        'unstoppable' => Icons.whatshot_rounded,
        _ => Icons.diversity_3_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    final iconColor = unlocked ? accent : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: unlocked
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              _iconFor(achievement.iconKey),
              color: iconColor,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NovynTheme.fontFamily,
                          color: colors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (unlocked)
                      Icon(Icons.check_circle_rounded, color: accent, size: 18)
                    else
                      Icon(Icons.lock_outline_rounded,
                          color: colors.onSurfaceVariant, size: 17),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: achievement.progressFraction,
                          minHeight: 5,
                          backgroundColor: colors.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            unlocked ? accent : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      unlocked
                          ? 'Unlocked'
                          : '${achievement.safeProgress}/${achievement.target}',
                      style: TextStyle(
                        color: unlocked ? accent : colors.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllUnlockedCard extends StatelessWidget {
  const _AllUnlockedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration_rounded, color: colors.primary, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You have unlocked every available achievement.',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
