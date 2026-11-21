import 'package:flutter/material.dart';

import 'connect4_screen.dart';
import 'doodle_duel_screen.dart';
import 'game_lobby_screen.dart';
import 'number_clash_screen.dart';
import 'rps_screen.dart';
import 'tictactoe_screen.dart';
import 'up_down_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  static const List<_GameOption> _games = <_GameOption>[
    _GameOption('tictactoe', 'Tic-Tac-Toe', 'Make a line of three',
        Icons.grid_3x3_rounded, 'QUICK STRATEGY'),
    _GameOption('rps', 'Rock Paper Scissors', 'Rock beats scissors',
        Icons.back_hand_rounded, 'FAST SHOWDOWN'),
    _GameOption('connect4', 'Connect 4', 'Line up four chips',
        Icons.circle_rounded, 'THINK AHEAD'),
    _GameOption('doodle', 'Doodle Duel', 'Draw and guess',
        Icons.draw_rounded, 'CREATIVE CHALLENGE'),
    _GameOption('numberclash', 'Number Clash', 'Pick the closest number',
        Icons.pin_rounded, 'NUMBER STRATEGY'),
    _GameOption('updown', 'Up or Down', 'Predict the next card',
        Icons.trending_up_rounded, 'CARD PREDICTION'),
  ];

  void _openGame(BuildContext context, _GameOption game) {
    final Widget screen;
    switch (game.type) {
      case 'tictactoe':
        screen = const TicTacToeScreen();
        break;
      case 'rps':
        screen = const RpsScreen();
        break;
      case 'connect4':
        screen = const Connect4Screen();
        break;
      case 'doodle':
        screen = const DoodleDuelScreen();
        break;
      case 'numberclash':
        screen = const NumberClashScreen();
        break;
      case 'updown':
        screen = const UpDownScreen();
        break;
      default:
        screen = GameLobbyScreen(
          gameType: game.type,
          title: game.title,
          subtitle: game.subtitle,
          icon: game.icon,
        );
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accents = <Color>[
      colors.primary,
      colors.tertiary,
      colors.secondary,
      colors.primary,
      colors.tertiary,
      colors.secondary,
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Games',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 35,
                          height: 1.12,
                          letterSpacing: -1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A little friendly competition?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: .16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sports_esports_rounded,
                          size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${_games.length} games',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _GameHeroCard(),
            const SizedBox(height: 27),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose a game',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.35,
                    ),
                  ),
                ),
                Text(
                  'LET’S PLAY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _games.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 15,
                crossAxisSpacing: 13,
                childAspectRatio: .91,
              ),
              itemBuilder: (context, index) {
                final game = _games[index];
                return _GameTile(
                  game: game,
                  accent: accents[index],
                  onTap: () => _openGame(context, game),
                );
              },
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'Play with friends or meet a new rival',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameHeroCard extends StatelessWidget {
  const _GameHeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .19),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: colors.shadow.withValues(alpha: .07),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(19, 19, 14, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primaryContainer,
              Color.lerp(colors.primaryContainer, colors.surface, .42)!,
              colors.surfaceContainerLow,
            ],
          ),
          borderRadius: BorderRadius.circular(27),
          border: Border.all(
            color: colors.primary.withValues(alpha: .18),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'NOVYN ARCADE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your next\nfriendly rivalry.',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                      letterSpacing: -.55,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Challenge a friend or find a new opponent.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 105,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -.16,
                    child: Container(
                      width: 73,
                      height: 86,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(3, -3),
                    child: Transform.rotate(
                      angle: .12,
                      child: Container(
                        width: 72,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.surface,
                              colors.primaryContainer,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: .2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: .22),
                              blurRadius: 17,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.sports_esports_rounded,
                          size: 39,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 8,
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 20, color: colors.tertiary),
                  ),
                  Positioned(
                    left: 1,
                    bottom: 8,
                    child: Icon(Icons.bolt_rounded,
                        size: 22, color: colors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTile extends StatefulWidget {
  const _GameTile({
    required this.game,
    required this.accent,
    required this.onTap,
  });

  final _GameOption game;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = widget.accent;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? .975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: _pressed ? .09 : .17),
                blurRadius: _pressed ? 9 : 17,
                offset: Offset(0, _pressed ? 3 : 9),
              ),
              BoxShadow(
                color: colors.shadow.withValues(alpha: .045),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: accent.withValues(alpha: .22),
                width: 1.1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.game.tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontSize: 9,
                          letterSpacing: .65,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 17,
                      color: colors.onSurfaceVariant.withValues(alpha: .8),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 69,
                    height: 65,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: .20),
                          accent.withValues(alpha: .07),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: accent.withValues(alpha: .2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: .13),
                          blurRadius: 13,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.game.icon,
                      color: accent,
                      size: 34,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  widget.game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.game.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
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
