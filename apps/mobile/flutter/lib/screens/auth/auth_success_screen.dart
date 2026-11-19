import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import 'auth_screen.dart';
import '../main_screen.dart';

class AuthSuccessScreen extends StatefulWidget {
  const AuthSuccessScreen({super.key, this.isNewAccount = false});
  final bool isNewAccount;

  @override
  State<AuthSuccessScreen> createState() => _AuthSuccessScreenState();
}

class _AuthSuccessScreenState extends State<AuthSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();
  bool _busy = false;

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const AuthScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (_) => false,
    );
  }

  void _continue() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 450),
      ),
      (_) => false,
    );
  }

  Widget _glow(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: .24), color.withValues(alpha: 0)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final name = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : (user?.username ?? 'there');
    final username = user?.username ?? '';
    final email = user?.email ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF080B18),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF080B18),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10132B), Color(0xFF080B18), Color(0xFF111026)],
                  ),
                ),
              ),
            ),
            Positioned(top: -150, left: -140, child: _glow(const Color(0xFF806BFF), 370)),
            Positioned(right: -160, bottom: -180, child: _glow(const Color(0xFF4268B8), 410)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FadeTransition(
                      opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero)
                            .animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFA696FF), Color(0xFF6047E8)],
                                ),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x668C78FF), blurRadius: 42, offset: Offset(0, 18)),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Image.asset('assets/icons/novyn-badge.png', fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2440),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFF8C78FF).withValues(alpha: .35)),
                              ),
                              child: Text(
                                widget.isNewAccount ? 'ACCOUNT CREATED' : 'YOU’RE SIGNED IN',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFBBAEFF), fontSize: 10,
                                  fontWeight: FontWeight.w800, letterSpacing: 1.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.isNewAccount ? 'Welcome to Novyn,' : 'Welcome back,',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: const Color(0xFFAAA8C7), fontSize: 17, fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: const Color(0xFFF6F3FF), fontSize: 34,
                                height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -1.2,
                              ),
                            ),
                            if (username.isNotEmpty) ...[
                              const SizedBox(height: 9),
                              Text('@$username', style: GoogleFonts.inter(
                                color: const Color(0xFFA99AFF), fontSize: 14, fontWeight: FontWeight.w600,
                              )),
                            ],
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(email, style: GoogleFonts.inter(
                                color: const Color(0xFF8585A8), fontSize: 12,
                              )),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              'Your conversations are waiting. Pick up right where you left off.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: const Color(0xFFAAA8C7), fontSize: 14, height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 34),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFA393FF), Color(0xFF654BE8)],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x558C78FF), blurRadius: 24, offset: Offset(0, 9)),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _busy ? null : _continue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                  child: Text('Continue to Novyn', style: GoogleFonts.inter(
                                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
                                  )),
                                ),
                              ),
                            ),
                            const SizedBox(height: 13),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _signOut,
                                icon: _busy
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFA1B1)))
                                    : const Icon(Icons.logout_rounded, size: 18),
                                label: Text(_busy ? 'Signing out…' : 'Sign out', style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                )),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFFA1B1),
                                  side: const BorderSide(color: Color(0x66FF718E)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'YOUR CONVERSATIONS. YOUR SPACE. YOUR CONTROL.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF656783), fontSize: 9,
                                fontWeight: FontWeight.w700, letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
