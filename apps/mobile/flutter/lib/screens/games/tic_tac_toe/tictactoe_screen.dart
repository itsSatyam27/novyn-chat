import 'package:flutter/material.dart';
import '../shared/lobby/game_lobby_screen.dart';

class TicTacToeScreen extends StatelessWidget {
  const TicTacToeScreen({super.key});

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
