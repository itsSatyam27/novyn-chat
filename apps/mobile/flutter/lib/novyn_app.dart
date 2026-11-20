import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_api.dart';
import 'theme/novyn_theme.dart';

class NovynApp extends StatelessWidget {
  const NovynApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Novyn',
    debugShowCheckedModeBanner: false,
    theme: NovynTheme.dark(),
    home: const _BootstrapScreen(),
  );
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();
  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  late final Future<NovynAccount?> _session = AuthApi.restoreSession();

  void _openWelcome(NovynAccount account) {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => _welcomePage(account)));
  }

  Widget _welcomePage(NovynAccount account) => WelcomeScreen(
    account: account,
    onContinue: () => _openHome(account),
    onSignOut: _signOut,
  );

  void _openHome(NovynAccount account) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => NovynHomeScreen(account: account, onSignOut: _signOut)),
    );
  }

  Future<void> _signOut() async {
    await AuthApi.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => AuthScreen(onAuthenticated: _openWelcome)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NovynAccount?>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const _StartupScreen();
      final account = snapshot.data;
      if (account != null) return NovynHomeScreen(account: account, onSignOut: _signOut);
      return AuthScreen(onAuthenticated: _openWelcome);
    },
  );
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10152A), Color(0xFF080B13), Color(0xFF111B25)])),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandMark(),
            SizedBox(height: 18),
            Text('novyn', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.5)),
            SizedBox(height: 24),
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 68, height: 68,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [NovynTheme.accent, NovynTheme.teal])),
    child: const Icon(Icons.forum_rounded, color: Colors.white, size: 31),
  );
}
