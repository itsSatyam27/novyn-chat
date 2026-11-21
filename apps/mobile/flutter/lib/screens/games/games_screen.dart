import 'package:flutter/material.dart';

import 'game_lobby_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  static const List<_GameOption> _games = <_GameOption>[
    _GameOption(
      'tictactoe',
      'Tic-Tac-Toe',
      'Make a line of three',
      Icons.grid_3x3_rounded,
      'Quick strategy',
    ),
    _GameOption(
      'rps',
      'Rock Paper Scissors',
      'Rock beats scissors',
      Icons.back_hand_rounded,
      'Fast showdown',
    ),
    _GameOption(
      'connect4',
      'Connect 4',
      'Line up four chips',
      Icons.circle_rounded,
      'Think ahead',
    ),
    _GameOption(
      'doodle',
      'Doodle Duel',
      'Draw and guess',
      Icons.draw_rounded,
      'Creative challenge',
    ),
    _GameOption(
      'numberclash',
      'Number Clash',
      'Pick the closest number',
      Icons.pin_rounded,
      'Number strategy',
    ),
    _GameOption(
      'updown',
      'Up or Down',
      'Predict the next card',
      Icons.trending_up_rounded,
      'Card prediction',
    ),
  ];

  void _openGame(BuildContext context, _GameOption game) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameLobbyScreen(
          gameType: game.type,
          title: game.title,
          subtitle: game.subtitle,
          icon: game.icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
          children: [
            Text(
              'Games',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontFamily: 'PlusJakartaSans',
                fontSize: 36,
                height: 1.12,
                letterSpacing: -1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Pick a game. Choose your opponent. Play.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 21),
            Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer.withValues(alpha: .95),
                    colors.surfaceContainerLow,
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: colors.primary.withValues(alpha: .13),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      Icons.sports_esports_rounded,
                      size: 29,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your game room awaits',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Challenge friends or get matched with a stranger playing the same game.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose a game',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_games.length} games',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _games.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final game = _games[index];
                return _GameTile(
                  game: game,
                  onTap: () => _openGame(context, game),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, required this.onTap});

  final _GameOption game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(game.icon, color: colors.primary, size: 23),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded,
                      size: 18, color: colors.onSurfaceVariant),
                ],
              ),
              const Spacer(),
              Text(
                game.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                game.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                game.tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameOption {
  const _GameOption(
    this.type,
    this.title,
    this.subtitle,
    this.icon,
    this.tag,
  );

  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final String tag;
}
