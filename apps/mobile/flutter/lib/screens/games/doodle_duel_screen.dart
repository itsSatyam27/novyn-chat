import 'package:flutter/material.dart';
import 'game_lobby_screen.dart';

class DoodleDuelScreen extends StatelessWidget {
  const DoodleDuelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameLobbyScreen(
      gameType: 'doodle',
      title: 'Doodle Duel',
      subtitle: 'Draw and guess with your friends',
      icon: Icons.draw_rounded,
    );
  }
}
