import 'package:flutter/material.dart';

import '../../shared/lobby/game_lobby_screen.dart';

/// Rock Paper Scissors-specific lobby entry point.
/// Shared matchmaking mechanics stay in the shared lobby engine.
class RockPaperScissorsLobbyScreen extends StatelessWidget {
  const RockPaperScissorsLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameLobbyScreen(
      gameType: 'rps',
      title: 'Rock Paper Scissors',
      subtitle: 'Rock beats scissors, scissors beats paper',
      icon: Icons.back_hand_rounded,
    );
  }
}
