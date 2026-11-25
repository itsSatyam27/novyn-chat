import 'package:flutter/material.dart';

import '../../shared/lobby/game_lobby_screen.dart';

/// Tic-Tac-Toe-specific lobby entry point.
/// Shared matchmaking mechanics stay in the shared lobby engine.
class TicTacToeLobbyScreen extends StatelessWidget {
  const TicTacToeLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameLobbyScreen(
      gameType: 'tictactoe',
      title: 'Tic-Tac-Toe',
      subtitle: 'Make a line of three',
      icon: Icons.grid_3x3_rounded,
    );
  }
}
