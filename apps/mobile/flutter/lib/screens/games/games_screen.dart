import 'package:flutter/material.dart';

/// Landing page for Novyn's integrated games area.
///
/// Individual games and matchmaking flows will be added incrementally.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Games',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 36,
                  height: 1.12,
                  letterSpacing: -1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Play together, wherever you are.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.sports_esports_rounded,
                        color: colors.primary,
                        size: 27,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Your game room is getting ready',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Novyn Games will bring quick multiplayer games, '
                      'friend invites and online matchmaking into one place. '
                      'We’ll add and test each game one at a time.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
