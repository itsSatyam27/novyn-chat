import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';

const _brand = Color(0xFF7667F5);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int _current = 0;

  static const _pages = [
    _OnboardingPage(Icons.forum_rounded, 'STAY IN THE LOOP',
        'Conversations,\nwithout limits.',
        'Share moments, exchange ideas and keep every conversation moving in one place.',
        Color(0xFF7667F5)),
    _OnboardingPage(Icons.call_rounded, 'CLOSER, IN REAL TIME',
        'Hear them.\nSee them.',
        'Reach the people who matter with voice and video calling, whenever you need.',
        Color(0xFF2798D5)),
    _OnboardingPage(Icons.shield_moon_rounded, 'YOUR SPACE, YOUR RULES',
        'Your chats.\nYour control.',
        'Thoughtful privacy controls help you shape how and when people reach you.',
        Color(0xFF21A783)),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _openAuth() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const AuthScreen(),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 320),
    ));
  }

  void _next() {
    if (_current == _pages.length - 1) {
      _openAuth();
      return;
    }
    HapticFeedback.selectionClick();
    _page.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9C91FF), _brand],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.forum_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text('novyn', style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  letterSpacing: -0.8, color: colors.onSurface,
                )),
                const Spacer(),
                TextButton(
                  onPressed: _openAuth,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  child: Text('Skip', style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _current = index),
                  itemBuilder: (context, index) =>
                      _PageContent(data: _pages[index]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final active = index == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 26 : 7, height: 7,
                    decoration: BoxDecoration(
                      color: active ? _brand :
                          colors.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 54,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_current == _pages.length - 1
                          ? 'Get started' : 'Continue',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 9),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _openAuth,
                style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant),
                child: Text('Already have an account? Sign in',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String eyebrow, title, subtitle;
  final Color color;
  const _OnboardingPage(
      this.icon, this.eyebrow, this.title, this.subtitle, this.color);
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage data;
  const _PageContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 520;
      final artSize = compact ? 205.0 : 250.0;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: compact ? 8 : 18),
          SizedBox(
            height: artSize, width: double.infinity,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: artSize * .82, height: artSize * .82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.color.withValues(alpha: dark ? .16 : .09),
                ),
              ),
              Container(
                width: artSize * .63, height: artSize * .63,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: data.color.withValues(alpha: .18)),
                ),
              ),
              Container(
                width: 148, height: 154,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: data.color.withValues(alpha: .22)),
                  boxShadow: [BoxShadow(
                    color: data.color.withValues(alpha: dark ? .12 : .16),
                    blurRadius: 32, offset: const Offset(0, 14),
                  )],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 62, height: 62,
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(data.icon, size: 30, color: data.color),
                    ),
                    const SizedBox(height: 14),
                    Container(height: 6, width: 82,
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: .24),
                        borderRadius: BorderRadius.circular(8))),
                    const SizedBox(height: 7),
                    Container(height: 5, width: 54,
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(8))),
                  ],
                ),
              ),
              Positioned(top: artSize * .13, right: artSize * .13,
                  child: _Dot(color: data.color)),
              Positioned(bottom: artSize * .13, left: artSize * .12,
                  child: _Dot(color: data.color, size: 12)),
            ]),
          ),
          SizedBox(height: compact ? 20 : 30),
          Text(data.eyebrow, style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w800,
            letterSpacing: 1.8, color: data.color,
          )),
          const SizedBox(height: 12),
          Text(data.title, textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: compact ? 29 : 34, height: 1.12,
              letterSpacing: -1.2, fontWeight: FontWeight.w800,
              color: colors.onSurface,
            )),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(data.subtitle, textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14, height: 1.65,
                color: colors.onSurfaceVariant,
              )),
          ),
          const Spacer(),
        ],
      );
    });
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, this.size = 17});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: .8),
      boxShadow: [BoxShadow(
          color: color.withValues(alpha: .28), blurRadius: 12)],
    ),
  );
}
