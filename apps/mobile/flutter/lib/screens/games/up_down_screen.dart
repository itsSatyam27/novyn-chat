import 'package:flutter/material.dart';
import 'game_lobby_screen.dart';

class UpDownScreen extends StatelessWidget {
  const UpDownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameLobbyScreen(
      gameType: 'updown',
      title: 'Up or Down',
      subtitle: 'Predict whether the next card goes higher or lower',
      icon: Icons.trending_up_rounded,
    );
  }
}
