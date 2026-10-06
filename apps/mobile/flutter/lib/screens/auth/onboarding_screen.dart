import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const _kPurple  = Color(0xFF7C6FF7);
const _kPurple2 = Color(0xFF9B8FFF);
const _kPink    = Color(0xFFEC4899);
const _kGreen   = Color(0xFF10B981);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _page = PageController();
  int _current = 0;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  static const _pages = [
    _PageData(
      emoji: '✦',
      title: 'Real-time\nMessaging',
      subtitle: 'Send messages instantly.\nNo delays, no limits.',
      color: _kPurple,
    ),
    _PageData(
      emoji: '📞',
      title: 'Voice & Video\nCalls',
      subtitle: 'Crystal-clear calls with\npeople who matter.',
      color: Color(0xFF0EA5E9),
    ),
    _PageData(
      emoji: '🔒',
      title: 'Private &\nSecure',
      subtitle: 'Your conversations stay\nbetween you and them.',
      color: _kGreen,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _page.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < _pages.length - 1) {
      _page.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goToAuth() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Light pastel gradient background (always light, regardless of theme)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF5E6FF),
                    Color(0xFFFFE8F0),
                    Color(0xFFE8F6F8),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Decorative blobs
          Positioned(
            top: 40, left: 20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C6FF7).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 120, right: 30,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEC4899).withValues(alpha: 0.07),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  // ── Skip button ──────────────────────────────────
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 20, 0),
                      child: _current < _pages.length - 1
                          ? GestureDetector(
                              onTap: _goToAuth,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _kPurple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _kPurple.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Text(
                                  'Skip',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _kPurple,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(height: 36),
                    ),
                  ),

                  // ── Logo ─────────────────────────────────────────
                  const SizedBox(height: 24),
                  _buildLogo(),

                  const SizedBox(height: 8),

                  // App name
                  Text(
                    'Novyn',
                    style: GoogleFonts.syne(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1D2E),
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Page content ──────────────────────────────────
                  Expanded(
                    child: PageView.builder(
                      controller: _page,
                      onPageChanged: (i) => setState(() => _current = i),
                      itemCount: _pages.length,
                      itemBuilder: (_, i) => _PageContent(
                        data: _pages[i],
                        isDark: false, // always light
                      ),
                    ),
                  ),

                  // ── Dots ──────────────────────────────────────────
                  _buildDots(false),

                  const SizedBox(height: 32),

                  // ── Button ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _current < _pages.length - 1
                        ? _NextButton(onTap: _next)
                        : _GetStartedButton(onTap: _goToAuth),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _kPurple.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Orb
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_kPurple, _kPurple2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _kPurple.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.pets_rounded, color: Colors.white, size: 30),
        ),
      ],
    );
  }

  Widget _buildDots(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final isActive = i == _current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? _pages[_current].color
                : (isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Page data ──────────────────────────────────────────────────────────────
class _PageData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  const _PageData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

// ── Page content ───────────────────────────────────────────────────────────
class _PageContent extends StatelessWidget {
  final _PageData data;
  final bool isDark;
  const _PageContent({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big emoji in a colored circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.color.withValues(alpha: 0.12),
              border: Border.all(
                color: data.color.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                data.emoji,
                style: const TextStyle(fontSize: 52),
              ),
            ),
          ),

          const SizedBox(height: 36),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.syne(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1D2E),
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : const Color(0xFF64748B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Next button ────────────────────────────────────────────────────────────
class _NextButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NextButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPurple, _kPurple2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _kPurple.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Next',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Get Started button ─────────────────────────────────────────────────────
class _GetStartedButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GetStartedButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPurple, _kPink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _kPurple.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Get Started',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
