import 'package:flutter/material.dart';
import 'game_lobby_screen.dart';

class Connect4Screen extends StatelessWidget {
  const Connect4Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameLobbyScreen(
      gameType: 'connect4',
      title: 'Connect 4',
      subtitle: 'Line up four chips in a row',
      icon: Icons.circle_rounded,
    );
  }
}
