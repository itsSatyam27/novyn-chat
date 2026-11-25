import 'package:flutter/material.dart';
import '../shared/lobby/game_lobby_screen.dart';

class RpsScreen extends StatelessWidget {
  const RpsScreen({super.key});

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
