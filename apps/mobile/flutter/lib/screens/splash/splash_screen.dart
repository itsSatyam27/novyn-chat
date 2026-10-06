import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../main_screen.dart';
import '../auth/onboarding_screen.dart';
import '../auth/auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  SplashScreen
// ═══════════════════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Main sequenced animation — 4.2s total
  late AnimationController _mainController;
  // Continuous particle drift
  late AnimationController _particleController;
  // Loading bar fill — starts after main sequence completes
  late AnimationController _loadController;
  // Shimmer glint that loops across the bar
  late AnimationController _barShimmerController;

  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _catDraw;
  late Animation<double> _dotsBurst;
  late Animation<double> _wordmarkReveal;
  late Animation<double> _shimmer;
  late Animation<double> _dividerGrow;
  late Animation<double> _taglineFade;
  late Animation<double> _taglineSlide;
  late Animation<double> _ctaFade;
  late Animation<double> _ctaSlide;

  final List<_Particle> _particles = [];
  final Random _random = Random();

  static const int _ringCount = 3;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Loading bar fills over 2.4s; shimmer glint loops every 1.1s
    _loadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _barShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _setupAnimations();
    _initParticles();

    // Start main sequence, then kick off the loading bar
    _mainController.forward().whenComplete(() {
      _loadController.forward();
      _barShimmerController.repeat();
    });
  }

  void _setupAnimations() {
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.44, curve: Curves.elasticOut),
      ),
    );
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.36, curve: Curves.easeOut),
      ),
    );
    _catDraw = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.27, 0.56, curve: Curves.easeInOutCubic),
      ),
    );
    _dotsBurst = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.50, 0.68, curve: Curves.easeOutBack),
      ),
    );
    _wordmarkReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.37, 0.64, curve: Curves.easeOutCubic),
      ),
    );
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.66, 0.84, curve: Curves.easeInOut),
      ),
    );
    _dividerGrow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.58, 0.78, curve: Curves.easeInOutCubic),
      ),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.68, 0.84, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.66, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _ctaFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.78, 0.96, curve: Curves.easeOut),
      ),
    );
    _ctaSlide = Tween<double>(begin: 28.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.76, 0.94, curve: Curves.easeOutCubic),
      ),
    );
  }

  void _initParticles() {
    for (int i = 0; i < 80; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        vx: (_random.nextDouble() - 0.5) * 0.00055,
        vy: (_random.nextDouble() - 0.5) * 0.00055,
        radius: _random.nextDouble() * 1.3 + 0.4,
        opacity: _random.nextDouble() * 0.5 + 0.08,
        color: [
          const Color(0xFF4A8FFF),
          const Color(0xFF00D4A0),
          const Color(0xFF8B6FF5),
        ][_random.nextInt(3)],
      ));
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    _loadController.dispose();
    _barShimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060C1A),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              painter: _ParticlePainter(_particles),
              size: Size.infinite,
            ),
          ),
          const _GridOverlay(),
          const Center(child: _GlowHalo()),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogoSection(),
                const SizedBox(height: 24),
                _buildWordmark(),
                const SizedBox(height: 12),
                _buildDivider(),
                const SizedBox(height: 22),
                _buildTagline(),
                const SizedBox(height: 44),
                _buildLoadingBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo + pulse rings ────────────────────────────────────────────────────
  Widget _buildLogoSection() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(_ringCount, (i) {
            return AnimatedBuilder(
              animation: _mainController,
              builder: (context, _) {
                final start = i * 0.08;
                final raw =
                    (_mainController.value - start).clamp(0.0, 1.0);
                final t = Curves.easeOut.transform(raw);
                if (t <= 0) return const SizedBox.shrink();
                final scale = 0.2 + t * 2.8;
                final opacity = (1.0 - t) * 0.45;
                final ringColor = i == 2
                    ? const Color(0xFF00D4A0)
                    : const Color(0xFF4A8FFF);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor.withValues(alpha: opacity),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, _) {
              return Transform.scale(
                scale: _iconScale.value,
                child: Opacity(
                  opacity: _iconFade.value.clamp(0.0, 1.0),
                  child: CustomPaint(
                    size: const Size(60, 60),
                    painter: _CatPainter(
                      drawProgress: _catDraw.value,
                      featuresProgress: _dotsBurst.value,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Wordmark with shimmer ─────────────────────────────────────────────────
  Widget _buildWordmark() {
    const word = 'Novyn';
    const letterCount = word.length;

    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final shimmerX = _shimmer.value * bounds.width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Colors.white,
                Colors.white,
                Color(0xFFCCE4FF),
                Colors.white,
                Colors.white,
              ],
              stops: [
                0.0,
                (shimmerX / bounds.width - 0.12).clamp(0.0, 1.0),
                (shimmerX / bounds.width).clamp(0.0, 1.0),
                (shimmerX / bounds.width + 0.12).clamp(0.0, 1.0),
                1.0,
              ],
            ).createShader(bounds);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: word.split('').asMap().entries.map((entry) {
              final i = entry.key;
              final char = entry.value;
              final stagger = i / letterCount * 0.28;
              final raw =
                  (_wordmarkReveal.value - stagger).clamp(0.0, 1.0);
              final t = Curves.easeOutCubic.transform(raw);
              final isAccent = char == 'v';
              return Transform.translate(
                offset: Offset(0, 60 * (1.0 - t)),
                child: Opacity(
                  opacity: t,
                  child: Text(
                    char,
                    style: GoogleFonts.syne(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: isAccent
                          ? const Color(0xFF00D4A0)
                          : Colors.white,
                      letterSpacing: -2,
                      shadows: isAccent
                          ? [
                              Shadow(
                                color: const Color(0xFF00D4A0)
                                    .withValues(alpha: 0.55),
                                blurRadius: 20,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Divider ───────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return AnimatedBuilder(
      animation: _dividerGrow,
      builder: (context, _) {
        final w = 260.0 * _dividerGrow.value;
        return SizedBox(
          width: w,
          height: 4,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0x664A8FFF)],
                    ),
                  ),
                ),
              ),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A8FFF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF4A8FFF).withValues(alpha: 0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x664A8FFF), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ],
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
        return Transform.translate(
          offset: Offset(0, _taglineSlide.value),
          child: Opacity(
            opacity: _taglineFade.value,
            child: Text(
              'WHERE CONVERSATIONS CONNECT',
              style: GoogleFonts.syne(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.5,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Loading bar ───────────────────────────────────────────────────────────
  Widget _buildLoadingBar() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _ctaSlide.value),
          child: Opacity(
            opacity: _ctaFade.value,
            child: _LoadingBar(
              loadController: _loadController,
              shimmerController: _barShimmerController,
              onComplete: () async {
                if (!mounted) return;
                final auth = context.read<AuthService>();

                // Wait for Firebase Auth to restore session (max 2s)
                if (!auth.authReady) {
                  await Future.any([
                    Future.doWhile(() async {
                      await Future.delayed(const Duration(milliseconds: 50));
                      return !auth.authReady;
                    }),
                    Future.delayed(const Duration(seconds: 2)),
                  ]);
                }

                if (!mounted) return;

                Widget destination;
                if (auth.isLoggedIn) {
                  destination = const MainScreen();
                } else {
                  // Show onboarding only on first launch
                  final prefs = await SharedPreferences.getInstance();
                  final seen = prefs.getBool('onboarding_seen') ?? false;
                  if (!seen) {
                    await prefs.setBool('onboarding_seen', true);
                    destination = const OnboardingScreen();
                  } else {
                    destination = const AuthScreen();
                  }
                }

                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => destination,
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 500),
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
//  _LoadingBar
// ═══════════════════════════════════════════════════════════════════════════
class _LoadingBar extends StatefulWidget {
  final AnimationController loadController;
  final AnimationController shimmerController;
  final VoidCallback onComplete;

  const _LoadingBar({
    required this.loadController,
    required this.shimmerController,
    required this.onComplete,
  });

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar> {
  bool _navigated = false;

  static const _messages = [
    'warming up...',
    'fetching vibes...',
    'almost there...',
    'ready to chat!',
  ];

  @override
  void initState() {
    super.initState();
    widget.loadController.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_navigated) {
      _navigated = true;
      Future.delayed(const Duration(milliseconds: 340), widget.onComplete);
    }
  }

  @override
  void dispose() {
    widget.loadController.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const barWidth = 220.0;
    const barHeight = 6.0;
    const radius = barHeight / 2;

    return AnimatedBuilder(
      animation: Listenable.merge(
          [widget.loadController, widget.shimmerController]),
      builder: (context, _) {
        final fill = widget.loadController.value;
        final shimmer = widget.shimmerController.value;

        final msgIndex =
            (fill * (_messages.length - 0.01)).floor().clamp(0, _messages.length - 1);

        // Paw bobs up and down as it walks
        final pawBounce = sin(shimmer * pi * 2) * 3.5;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Paw + label ───────────────────────────────────────────────
            SizedBox(
              width: barWidth,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Status label
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _messages[msgIndex],
                      style: GoogleFonts.syne(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.40),
                      ),
                    ),
                  ),
                  // Walking paw icon above the fill head
                  Positioned(
                    left: (fill * barWidth - 7).clamp(0.0, barWidth - 14),
                    top: -pawBounce - 4,
                    child: Transform.rotate(
                      angle: 0.15,
                      child: CustomPaint(
                        size: const Size(14, 14),
                        painter: _PawPainter(
                          color: fill >= 1.0
                              ? const Color(0xFF00D4A0)
                              : const Color(0xFF4A8FFF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Bar track ─────────────────────────────────────────────────
            SizedBox(
              width: barWidth,
              height: barHeight,
              child: Stack(
                children: [
                  // Track
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A8FFF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: const Color(0xFF4A8FFF).withValues(alpha: 0.18),
                        width: 0.5,
                      ),
                    ),
                  ),

                  // Fill
                  if (fill > 0)
                    FractionallySizedBox(
                      widthFactor: fill,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: LinearGradient(
                            colors: fill >= 1.0
                                ? const [Color(0xFF00D4A0), Color(0xFF4A8FFF)]
                                : const [Color(0xFF4A8FFF), Color(0xFF8B6FF5)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (fill >= 1.0
                                      ? const Color(0xFF00D4A0)
                                      : const Color(0xFF4A8FFF))
                                  .withValues(alpha: 0.55),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Shimmer glint sweeping across the filled area
                  if (fill > 0.05)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: FractionallySizedBox(
                        widthFactor: fill,
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) {
                            final gx = shimmer * bounds.width * 1.4 -
                                bounds.width * 0.2;
                            final cx =
                                (gx / bounds.width).clamp(0.0, 1.0);
                            return LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.55),
                                Colors.transparent,
                              ],
                              stops: [
                                (cx - 0.2).clamp(0.0, 1.0),
                                cx,
                                (cx + 0.2).clamp(0.0, 1.0),
                              ],
                            ).createShader(bounds);
                          },
                          child: Container(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Percentage ────────────────────────────────────────────────
            Text(
              '${(fill * 100).round()}%',
              style: GoogleFonts.syne(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _PawPainter — central pad + 4 toe beans
// ═══════════════════════════════════════════════════════════════════════════
class _PawPainter extends CustomPainter {
  final Color color;
  const _PawPainter({required this.color});

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
          center: Offset(w * 0.5, h * 0.65),
          width: w * 0.52,
          height: h * 0.44),
      paint,
    );

    // Toe beans
    for (final pos in [
      Offset(w * 0.18, h * 0.32),
      Offset(w * 0.40, h * 0.20),
      Offset(w * 0.62, h * 0.20),
      Offset(w * 0.82, h * 0.32),
    ]) {
      canvas.drawCircle(pos, w * 0.13, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PawPainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════
//  _GlowHalo
// ═══════════════════════════════════════════════════════════════════════════
class _GlowHalo extends StatelessWidget {
  const _GlowHalo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      height: 140,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.75,
            colors: [
              const Color(0xFF00D4A0).withValues(alpha: 0.07),
              const Color(0xFF4A8FFF).withValues(alpha: 0.08),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _Particle
// ═══════════════════════════════════════════════════════════════════════════
class _Particle {
  double x, y, vx, vy, radius, opacity;
  Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.opacity,
    required this.color,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  _ParticlePainter
// ═══════════════════════════════════════════════════════════════════════════
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      p.x = (p.x + p.vx) % 1.0;
      p.y = (p.y + p.vy) % 1.0;
      if (p.x < 0) p.x += 1.0;
      if (p.y < 0) p.y += 1.0;

      final pos1 = Offset(p.x * size.width, p.y * size.height);

      for (int j = i + 1; j < particles.length; j++) {
        final q = particles[j];
        final pos2 = Offset(q.x * size.width, q.y * size.height);
        final dist = (pos1 - pos2).distance;
        if (dist < 100) {
          linePaint.color = const Color(0xFF4A8FFF)
              .withValues(alpha: (1 - dist / 100) * 0.055);
          canvas.drawLine(pos1, pos2, linePaint);
        }
      }

      dotPaint.color = p.color.withValues(alpha: p.opacity);
      canvas.drawCircle(pos1, p.radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  _GridOverlay
// ═══════════════════════════════════════════════════════════════════════════
class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GridPainter(),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A8FFF).withValues(alpha: 0.028)
      ..strokeWidth = 1.0;
    const spacing = 60.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  _CatPainter — draws a cute cat face stroke-by-stroke
//
//  Coordinate space: 0–56 × 0–56 (scaled to canvas size)
//  Stroke order:
//    0  Head circle
//    1  Left ear outer
//    2  Right ear outer
//    3  Left ear inner  (purple)
//    4  Right ear inner (purple)
//  Then featuresProgress pops in: eyes, nose, mouth, whiskers
// ═══════════════════════════════════════════════════════════════════════════
class _CatPainter extends CustomPainter {
  final double drawProgress;
  final double featuresProgress;

  _CatPainter({required this.drawProgress, required this.featuresProgress});

  static Path _headPath() =>
      Path()..addOval(const Rect.fromLTWH(10, 12, 36, 36));

  static Path _leftEarOuter() => Path()
    ..moveTo(14, 22)
    ..lineTo(10, 8)
    ..lineTo(22, 16);

  static Path _rightEarOuter() => Path()
    ..moveTo(42, 22)
    ..lineTo(46, 8)
    ..lineTo(34, 16);

  static Path _leftEarInner() => Path()
    ..moveTo(14.5, 20)
    ..lineTo(12, 10)
    ..lineTo(20.5, 17);

  static Path _rightEarInner() => Path()
    ..moveTo(41.5, 20)
    ..lineTo(44, 10)
    ..lineTo(35.5, 17);

  double _strokeT(int index, int total) {
    final seg = 1.0 / total;
    return ((drawProgress - index * seg) / seg).clamp(0.0, 1.0);
  }

  Path _partial(Path full, double t) {
    if (t <= 0) return Path();
    if (t >= 1) return full;
    final result = Path();
    for (final m in full.computeMetrics()) {
      result.addPath(m.extractPath(0, m.length * t), Offset.zero);
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 56, size.height / 56);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.0;

    // 0 — head (blue)
    stroke.color = const Color(0xFF4A8FFF);
    canvas.drawPath(_partial(_headPath(), _strokeT(0, 5)), stroke);

    // 1 — left ear outer
    canvas.drawPath(_partial(_leftEarOuter(), _strokeT(1, 5)), stroke);

    // 2 — right ear outer
    canvas.drawPath(_partial(_rightEarOuter(), _strokeT(2, 5)), stroke);

    // 3 — left ear inner (purple)
    stroke.color = const Color(0xFF8B6FF5);
    canvas.drawPath(_partial(_leftEarInner(), _strokeT(3, 5)), stroke);

    // 4 — right ear inner
    canvas.drawPath(_partial(_rightEarInner(), _strokeT(4, 5)), stroke);

    if (featuresProgress <= 0) return;

    final fill = Paint()..style = PaintingStyle.fill;
    final fstroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;

    // Staggered eased t per feature
    double ft(double offset) => Curves.easeOutBack.transform(
        ((featuresProgress - offset) / (1.0 - offset + 0.001))
            .clamp(0.0, 1.0));

    // Left eye
    final t0 = ft(0.0);
    if (t0 > 0) {
      fill.color = const Color(0xFF4A8FFF).withValues(alpha: t0 * 0.25);
      canvas.drawCircle(const Offset(22, 28), 4.5 * t0, fill);
      fill.color = const Color(0xFF4A8FFF).withValues(alpha: t0);
      canvas.drawCircle(const Offset(22, 28), 2.8 * t0, fill);
      fill.color = Colors.white.withValues(alpha: t0 * 0.9);
      canvas.drawCircle(const Offset(23.2, 26.8), 0.9 * t0, fill);
    }

    // Right eye
    final t1 = ft(0.08);
    if (t1 > 0) {
      fill.color = const Color(0xFF4A8FFF).withValues(alpha: t1 * 0.25);
      canvas.drawCircle(const Offset(34, 28), 4.5 * t1, fill);
      fill.color = const Color(0xFF4A8FFF).withValues(alpha: t1);
      canvas.drawCircle(const Offset(34, 28), 2.8 * t1, fill);
      fill.color = Colors.white.withValues(alpha: t1 * 0.9);
      canvas.drawCircle(const Offset(35.2, 26.8), 0.9 * t1, fill);
    }

    // Nose (teal triangle)
    final t2 = ft(0.18);
    if (t2 > 0) {
      fill.color = const Color(0xFF00D4A0).withValues(alpha: t2);
      canvas.save();
      canvas.translate(28, 35.75);
      canvas.scale(t2, t2);
      canvas.translate(-28, -35.75);
      canvas.drawPath(
        Path()
          ..moveTo(28, 34.5)
          ..lineTo(25.8, 37.0)
          ..lineTo(30.2, 37.0)
          ..close(),
        fill,
      );
      canvas.restore();
    }

    // Mouth
    final t3 = ft(0.26);
    if (t3 > 0) {
      fstroke.color =
          const Color(0xFF4A8FFF).withValues(alpha: t3 * 0.7);
      canvas.drawPath(
        _partial(
            Path()
              ..moveTo(28, 37)
              ..quadraticBezierTo(25, 39.5, 23, 38.5),
            t3),
        fstroke,
      );
      canvas.drawPath(
        _partial(
            Path()
              ..moveTo(28, 37)
              ..quadraticBezierTo(31, 39.5, 33, 38.5),
            t3),
        fstroke,
      );
    }

    // Whiskers
    final t4 = ft(0.34);
    if (t4 > 0) {
      fstroke
        ..color = const Color(0xFF4A8FFF).withValues(alpha: t4 * 0.45)
        ..strokeWidth = 1.0;
      for (final w in [
        [const Offset(24, 35), const Offset(6, 33)],
        [const Offset(24, 36.5), const Offset(6, 36.5)],
        [const Offset(24, 38), const Offset(6, 40)],
        [const Offset(32, 35), const Offset(50, 33)],
        [const Offset(32, 36.5), const Offset(50, 36.5)],
        [const Offset(32, 38), const Offset(50, 40)],
      ]) {
        canvas.drawPath(
          Path()
            ..moveTo(w[0].dx, w[0].dy)
            ..lineTo(
              w[0].dx + (w[1].dx - w[0].dx) * t4,
              w[0].dy + (w[1].dy - w[0].dy) * t4,
            ),
          fstroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) =>
      old.drawProgress != drawProgress ||
      old.featuresProgress != featuresProgress;
}
