import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/novyn_theme.dart';
import '../main_screen.dart';
import '../auth/onboarding_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  SplashScreenV2 — Redesigned with pastel gradient & simplified animations
// ═══════════════════════════════════════════════════════════════════════════
class SplashScreenV2 extends StatefulWidget {
  const SplashScreenV2({super.key});

  @override
  State<SplashScreenV2> createState() => _SplashScreenV2State();
}

class _SplashScreenV2State extends State<SplashScreenV2>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _loadController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _wordmarkSlide;
  late Animation<double> _wordmarkFade;
  late Animation<double> _taglineFade;
  late Animation<double> _loadingBarSlide;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _loadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _setupAnimations();

    _mainController.forward().whenComplete(() {
      _loadController.forward();
    });
  }

  void _setupAnimations() {
    // Logo bounces in with elastic curve
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // Wordmark slides up with fade
    _wordmarkSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _wordmarkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.45, curve: Curves.easeOut),
      ),
    );

    // Tagline fades in
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.5, 0.7, curve: Curves.easeOut),
      ),
    );

    // Loading bar slides up from below
    _loadingBarSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 0.85, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _loadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF5E6FF), // Light lavender
              Color(0xFFFFE8F0), // Light pink
              Color(0xFFE8F6F8), // Light teal
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Floating decorative bubbles
            Positioned(
              top: 80,
              left: 20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NovynTheme.pastelPurple.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              bottom: 150,
              right: 30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NovynTheme.pastelPink.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              top: 200,
              right: 50,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NovynTheme.pastelTeal.withValues(alpha: 0.15),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with cat
                  _buildLogoSection(),
                  const SizedBox(height: 32),

                  // Wordmark
                  _buildWordmark(),
                  const SizedBox(height: 12),

                  // Tagline
                  _buildTagline(),
                  const SizedBox(height: 60),

                  // Loading bar
                  _buildLoadingBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logo section with animated cat ─────────────────────────────────────────
  Widget _buildLogoSection() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        return Transform.scale(
          scale: _logoScale.value,
          child: Opacity(
            opacity: _logoFade.value,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    NovynTheme.pastelLavender,
                    NovynTheme.pastelPurple,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: NovynTheme.pastelPurple.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cat icon/emoji
                  Transform.scale(
                    scale: 0.7,
                    child: CustomPaint(
                      size: const Size(100, 100),
                      painter: _CatPainterV2(),
                    ),
                  ),

                  // Paw prints animation around the circle
                  _buildPawPrints(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Paw prints circling around logo ───────────────────────────────────────
  Widget _buildPawPrints() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        const radius = 80.0;
        final angle = _mainController.value * 2 * pi;
        final positions = <Offset>[
          Offset(radius * cos(angle), radius * sin(angle)),
          Offset(radius * cos(angle + pi / 2), radius * sin(angle + pi / 2)),
          Offset(radius * cos(angle + pi), radius * sin(angle + pi)),
          Offset(radius * cos(angle + 3 * pi / 2), radius * sin(angle + 3 * pi / 2)),
        ];

        return Stack(
          children: List.generate(
            4,
            (i) => Transform.translate(
              offset: positions[i] * (_mainController.value * 2).clamp(0, 1),
              child: Opacity(
                opacity: (1 - _mainController.value * 2).clamp(0, 1),
                child: CustomPaint(
                  size: const Size(20, 20),
                  painter: _SmallPawPainter(
                    color: [
                      NovynTheme.pastelPurple,
                      NovynTheme.pastelPink,
                      NovynTheme.pastelTeal,
                      NovynTheme.pastelPeach,
                    ][i],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Wordmark "Novyn" ───────────────────────────────────────────────────────
  Widget _buildWordmark() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _wordmarkSlide.value),
          child: Opacity(
            opacity: _wordmarkFade.value,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [
                    NovynTheme.pastelPurple,
                    Color(0xFF7C6FF7),
                    NovynTheme.pastelPurple,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              child: Text(
                'Novyn',
                style: GoogleFonts.syne(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tagline ───────────────────────────────────────────────────────────────
  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        return Opacity(
          opacity: _taglineFade.value,
          child: Text(
            'Connect. Chat. Vibe.',
            style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: const Color(0xFF7C6FF7),
            ),
          ),
        );
      },
    );
  }

  // ── Loading bar ────────────────────────────────────────────────────────────
  Widget _buildLoadingBar() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _loadingBarSlide.value),
          child: Opacity(
            opacity: (_mainController.value * 2).clamp(0, 1),
            child: _AnimatedLoadingBar(
              loadController: _loadController,
              onComplete: () {
                if (!mounted) return;
                final auth = context.read<AuthService>();
                final destination = auth.isLoggedIn
                    ? const MainScreen()
                    : const OnboardingScreen();
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => destination,
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 600),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _AnimatedLoadingBar
// ═══════════════════════════════════════════════════════════════════════════
class _AnimatedLoadingBar extends StatefulWidget {
  final AnimationController loadController;
  final VoidCallback onComplete;

  const _AnimatedLoadingBar({
    required this.loadController,
    required this.onComplete,
  });

  @override
  State<_AnimatedLoadingBar> createState() => _AnimatedLoadingBarState();
}

class _AnimatedLoadingBarState extends State<_AnimatedLoadingBar> {
  bool _navigated = false;

  static const _messages = [
    'settling in...',
    'finding your vibe...',
    'almost there...',
  ];

  @override
  void initState() {
    super.initState();
    widget.loadController.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_navigated) {
      _navigated = true;
      Future.delayed(const Duration(milliseconds: 400), widget.onComplete);
    }
  }

  @override
  void dispose() {
    widget.loadController.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const barWidth = 200.0;
    const barHeight = 8.0;
    const radius = barHeight / 2;

    return AnimatedBuilder(
      animation: widget.loadController,
      builder: (context, _) {
        final fill = widget.loadController.value;
        final msgIndex = (fill * (_messages.length - 0.01))
            .floor()
            .clamp(0, _messages.length - 1);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Message
            Text(
              _messages[msgIndex],
              style: GoogleFonts.syne(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: const Color(0xFF7C6FF7).withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),

            // Progress bar
            SizedBox(
              width: barWidth,
              height: barHeight,
              child: Stack(
                children: [
                  // Track
                  Container(
                    decoration: BoxDecoration(
                      color: NovynTheme.pastelPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),

                  // Fill with gradient
                  if (fill > 0)
                    FractionallySizedBox(
                      widthFactor: fill,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: const LinearGradient(
                            colors: [
                              NovynTheme.pastelPurple,
                              NovynTheme.pastelPink,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: NovynTheme.pastelPurple
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Percentage
            Text(
              '${(fill * 100).round()}%',
              style: GoogleFonts.syne(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: const Color(0xFF7C6FF7).withValues(alpha: 0.5),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _CatPainterV2 — Cute cat face
// ═══════════════════════════════════════════════════════════════════════════
class _CatPainterV2 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Head
    final headPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h / 2.2),
        width: w * 0.6,
        height: h * 0.5,
      ),
      headPaint,
    );

    // Ears
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.35, h * 0.25),
        width: w * 0.25,
        height: h * 0.3,
      ),
      headPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.65, h * 0.25),
        width: w * 0.25,
        height: h * 0.3,
      ),
      headPaint,
    );

    // Inner ears (pink)
    final innerEarPaint = Paint()
      ..color = NovynTheme.pastelPink.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.35, h * 0.28),
        width: w * 0.12,
        height: h * 0.15,
      ),
      innerEarPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.65, h * 0.28),
        width: w * 0.12,
        height: h * 0.15,
      ),
      innerEarPaint,
    );

    // Eyes
    final eyePaint = Paint()
      ..color = const Color(0xFF7C6FF7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.4, h * 0.45), w * 0.08, eyePaint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.45), w * 0.08, eyePaint);

    // Eye shine
    final shinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.42, h * 0.42), w * 0.03, shinePaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.42), w * 0.03, shinePaint);

    // Nose (peach)
    final nosePaint = Paint()
      ..color = NovynTheme.pastelPeach
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.6),
        width: w * 0.1,
        height: w * 0.08,
      ),
      nosePaint,
    );

    // Mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF7C6FF7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(w / 2, h * 0.65)
      ..quadraticBezierTo(w * 0.35, h * 0.75, w * 0.3, h * 0.7)
      ..moveTo(w / 2, h * 0.65)
      ..quadraticBezierTo(w * 0.65, h * 0.75, w * 0.7, h * 0.7);
    canvas.drawPath(path, mouthPaint);

    // Whiskers
    final whiskerPaint = Paint()
      ..color = const Color(0xFF7C6FF7).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.15, h * 0.5), Offset(w * 0.05, h * 0.48),
        whiskerPaint);
    canvas.drawLine(Offset(w * 0.15, h * 0.58), Offset(w * 0.05, h * 0.6),
        whiskerPaint);
    canvas.drawLine(Offset(w * 0.85, h * 0.5), Offset(w * 0.95, h * 0.48),
        whiskerPaint);
    canvas.drawLine(Offset(w * 0.85, h * 0.58), Offset(w * 0.95, h * 0.6),
        whiskerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  _SmallPawPainter
// ═══════════════════════════════════════════════════════════════════════════
class _SmallPawPainter extends CustomPainter {
  final Color color;
  const _SmallPawPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Central pad
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.65),
        width: w * 0.5,
        height: h * 0.4,
      ),
      paint,
    );

    // Toe beans
    canvas.drawCircle(Offset(w * 0.2, h * 0.3), w * 0.12, paint);
    canvas.drawCircle(Offset(w * 0.4, h * 0.15), w * 0.12, paint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.15), w * 0.12, paint);
    canvas.drawCircle(Offset(w * 0.8, h * 0.3), w * 0.12, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
