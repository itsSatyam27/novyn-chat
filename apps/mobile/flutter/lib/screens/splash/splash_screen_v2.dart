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

  Future<void> _completeStartup() async {
    final auth = context.read<AuthService>();

    // The visual splash can finish before the network-backed session restore.
    // If a saved session exists, AuthService keeps retrying transient backend
    // failures. Do not route to onboarding until it confirms signed-in or
    // signed-out state; otherwise a Render cold start looks like a logout.
    while (mounted && !auth.authReady) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;

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
  }

  @override
  void dispose() {
    _mainController.dispose();
    _loadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const scheme = ColorScheme.light(
      primary: Color(0xFF6D5DFC),
      onSurface: Color(0xFF17152B),
      onSurfaceVariant: Color(0xFF77748B),
    );
    const background = Color(0xFFFAFAFF);
    const accent = Color(0xFF6D5DFC);
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 700;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.85, -1),
                  radius: 1.25,
                  colors: [accent.withValues(alpha: .13), background],
                ),
              ),
            ),
          ),
          Positioned(
            right: -95,
            bottom: -110,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x147C6CFF),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: compact ? 12 : 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: compact ? 8 : 18),
                              _buildLogoSection(),
                              SizedBox(height: compact ? 16 : 24),
                              _buildWordmark(),
                              const SizedBox(height: 8),
                              _buildTagline(),
                              SizedBox(height: compact ? 28 : 42),
                              _buildLoadingBar(),
                              SizedBox(height: compact ? 16 : 26),
                              Text(
                                'A little more connected.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: .4,
                                  color: scheme.onSurfaceVariant.withValues(alpha: .68),
                                ),
                              ),
                              SizedBox(height: compact ? 8 : 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Animated Novyn brand mark ─────────────────────────────────────────────
  Widget _buildLogoSection() {
    const scheme = ColorScheme.light(primary: Color(0xFF6D5DFC), onSurface: Color(0xFF17152B), onSurfaceVariant: Color(0xFF77748B));
    const dark = false;
    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _loadController]),
      builder: (context, _) {
        final pulse = 1 + (sin(_loadController.value * pi * 5) * .018);
        return Transform.scale(
          scale: _logoScale.value * pulse,
          child: Opacity(
            opacity: _logoFade.value,
            child: SizedBox(
              width: 178,
              height: 178,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 174,
                    height: 174,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: dark ? .20 : .14),
                        width: 1,
                      ),
                    ),
                  ),
                  Container(
                    width: 146,
                    height: 146,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(38),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C6CFF), Color(0xFF5141CD)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5141CD).withValues(alpha: .30),
                          blurRadius: 38,
                          spreadRadius: 2,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icons/app_icon_foreground.png',
                      fit: BoxFit.contain,
                    ),
                  ),
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

  // ── Wordmark ──────────────────────────────────────────────────────────────
  Widget _buildWordmark() {
    const scheme = ColorScheme.light(primary: Color(0xFF6D5DFC), onSurface: Color(0xFF17152B), onSurfaceVariant: Color(0xFF77748B));
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, _wordmarkSlide.value),
        child: Opacity(
          opacity: _wordmarkFade.value,
          child: Text(
            'novyn',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -2.2,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  // ── Tagline ───────────────────────────────────────────────────────────────
  Widget _buildTagline() {
    const scheme = ColorScheme.light(primary: Color(0xFF6D5DFC), onSurface: Color(0xFF17152B), onSurfaceVariant: Color(0xFF77748B));
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) => Opacity(
        opacity: _taglineFade.value,
        child: Text(
          'Connect. Chat. Vibe.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: .7,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
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
              onComplete: _completeStartup,
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: const Color(0xFF6D5DFC).withValues(alpha: 0.7),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: const Color(0xFF6D5DFC).withValues(alpha: 0.5),
              ),
            ),
          ],
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
//  _NovynWingsPainter — clean white wings on the Novyn purple mark
// ═══════════════════════════════════════════════════════════════════════════
class _NovynWingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 100;
    canvas.save();
    canvas.scale(sx, sy);

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final leftWing = Path()
      ..moveTo(49, 57)
      ..cubicTo(42, 48, 31, 30, 13, 17)
      ..cubicTo(14, 32, 20, 43, 31, 51)
      ..cubicTo(23, 47, 15, 46, 9, 49)
      ..cubicTo(15, 62, 26, 68, 38, 64)
      ..cubicTo(42, 62, 46, 59, 49, 57)
      ..close();

    final rightWing = Path()
      ..moveTo(51, 57)
      ..cubicTo(58, 48, 69, 30, 87, 17)
      ..cubicTo(86, 32, 80, 43, 69, 51)
      ..cubicTo(77, 47, 85, 46, 91, 49)
      ..cubicTo(85, 62, 74, 68, 62, 64)
      ..cubicTo(58, 62, 54, 59, 51, 57)
      ..close();

    canvas.drawPath(leftWing, paint);
    canvas.drawPath(rightWing, paint);

    // Inner feather cuts give the mark its distinctive wing silhouette.
    final cut = Paint()
      ..color = const Color(0xFF6848ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final leftFeather = Path()
      ..moveTo(25, 34)
      ..cubicTo(31, 43, 36, 49, 42, 53);
    final rightFeather = Path()
      ..moveTo(75, 34)
      ..cubicTo(69, 43, 64, 49, 58, 53);
    canvas.drawPath(leftFeather, cut);
    canvas.drawPath(rightFeather, cut);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      ..color = const Color(0xFF6D5DFC)
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
      ..color = const Color(0xFF6D5DFC)
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
      ..color = const Color(0xFF6D5DFC).withValues(alpha: 0.5)
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
