import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../theme/novyn_theme.dart';

class NovynHomeScreen extends StatelessWidget {
  const NovynHomeScreen({super.key, required this.account, required this.onSignOut});
  final NovynAccount account;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('novyn', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1)),
      actions: [
        IconButton(tooltip: 'Sign out', onPressed: onSignOut, icon: const Icon(Icons.logout_rounded)),
        const SizedBox(width: 6),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [NovynTheme.background, Color(0xFF101B28)])),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good to have you here, ${account.displayName}.', style: const TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(height: 10),
              const Text('This is your new Novyn space.', style: TextStyle(color: NovynTheme.muted, fontSize: 14)),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: NovynTheme.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: NovynTheme.line)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: NovynTheme.teal, size: 24),
                    SizedBox(height: 16),
                    Text('A fresh start.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('The new messaging and play experience will be built here. No old chat screens are loaded in this Phase 2 client.', style: TextStyle(color: NovynTheme.muted, fontSize: 13, height: 1.55)),
                  ],
                ),
              ),
              const Spacer(),
              Text('@${account.username}', style: const TextStyle(color: NovynTheme.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ),
  );
}
