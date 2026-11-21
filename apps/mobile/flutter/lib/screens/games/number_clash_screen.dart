import 'package:flutter/material.dart';
import 'game_lobby_screen.dart';

class NumberClashScreen extends StatelessWidget {
  const NumberClashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameLobbyScreen(
      gameType: 'numberclash',
      title: 'Number Clash',
      subtitle: 'Pick the closest number strategy',
      icon: Icons.pin_rounded,
    );
  }
}
