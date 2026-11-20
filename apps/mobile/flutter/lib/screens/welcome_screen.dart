import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../theme/novyn_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.account, required this.onContinue, required this.onSignOut});
  final NovynAccount account;
  final VoidCallback onContinue;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151B31), NovynTheme.background, Color(0xFF0A1D20)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104, height: 104,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: const LinearGradient(colors: [NovynTheme.accent, NovynTheme.teal]),
                      boxShadow: const [BoxShadow(color: Color(0x558B7CFF), blurRadius: 46, offset: Offset(0, 18))],
                    ),
                    child: const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 38),
                  const Text('WELCOME TO NOVYN', style: TextStyle(color: NovynTheme.teal, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
                  const SizedBox(height: 15),
                  const Text('You’re in.', textAlign: TextAlign.center, style: TextStyle(fontSize: 42, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1.8)),
                  const SizedBox(height: 12),
                  Text(account.displayName, textAlign: TextAlign.center, style: const TextStyle(color: NovynTheme.text, fontSize: 22, fontWeight: FontWeight.w700)),
                  if (account.username.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('@${account.username}', style: const TextStyle(color: NovynTheme.muted, fontSize: 14)),
                  ],
                  const SizedBox(height: 22),
                  const Text('Your Novyn space is ready. Make yourself at home.', textAlign: TextAlign.center, style: TextStyle(color: NovynTheme.muted, fontSize: 14, height: 1.6)),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onContinue,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text('Continue'), SizedBox(width: 10), Icon(Icons.arrow_forward_rounded, size: 18)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: onSignOut, child: const Text('Sign out')),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
