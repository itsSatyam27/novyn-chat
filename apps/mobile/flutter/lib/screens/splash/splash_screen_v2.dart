import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';
import '../main_screen.dart';

/// Animated light aurora splash. Session restoration is resolved by the
/// existing AuthService before routing, so a slow backend never looks like
/// an unexpected sign-out.
class SplashScreenV2 extends StatefulWidget {
  const SplashScreenV2({
    super.key,
    this.minDuration = const Duration(milliseconds: 900),
  });

  final Duration minDuration;

  @override
  State<SplashScreenV2> createState() => _SplashScreenV2State();
}

class _C {
  static const bg = Color(0xFFF7F4FF);
  static const primary = Color(0xFF6C4DF6);
  static const text = Color(0xFF1C1B29);
  static const sub = Color(0xFF5B5873);
}

class _Bubble {
  const _Bubble(
    this.text,
    this.top,
    this.delay,
    this.fontSize, {
    this.left,
    this.right,
  });

  final String text;
  final double top;
  final double delay;
  final double fontSize;
  final double? left;
  final double? right;
}

const _bubbles = [
  _Bubble('hey 👋', .21, 0, 15, left: .07),
  _Bubble('kaisa hai?', .28, 1.4, 15, right: .06),
  _Bubble('😂😂', .62, 2.6, 17, left: .09),
  _Bubble('chal milte hain', .67, .8, 15, right: .05),
  _Bubble('❤️', .13, 3.4, 18, left: .38),
  _Bubble('typing…', .77, 4.2, 14, left: .06),
];

class _SplashScreenV2State extends State<SplashScreenV2>
    with TickerProviderStateMixin {
  static const _loopSeconds = 7.2;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7200),
  );

  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: widget.minDuration,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
      _progress.value = 1;
    } else {
      _intro.forward();
      _loop.repeat();
      _progress.forward();
    }
    _boot();
  }

  Future<void> _waitForSessionResolution(AuthService auth) async {
    // AuthService performs bounded retries and marks authReady only after it
    // can safely determine the current account state.
    while (mounted && !auth.authReady) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _boot() async {
    final auth = context.read<AuthService>();
    await Future.wait<void>([
      _waitForSessionResolution(auth),
      Future<void>.delayed(widget.minDuration),
    ]);

    if (!mounted || !auth.authReady) return;
    final destination =
        auth.isLoggedIn ? const MainScreen() : const AuthScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _C.bg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: AnimatedBuilder(
          animation: Listenable.merge([_intro, _loop, _progress]),
          builder: (context, _) {
            final t = _loop.value * 2 * math.pi;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _blob(
                  left: -90,
                  top: -60,
                  size: 320,
                  color: const Color(0xFFB9A8FF),
                  dx: math.sin(t) * 30,
                  dy: math.cos(t) * 24,
                ),
                _blob(
                  right: -110,
                  top: size.height * .27,
                  size: 300,
                  color: const Color(0xFFFFC6E0),
                  dx: -math.sin(t) * 28,
                  dy: math.cos(t) * 20,
                ),
                _blob(
                  left: -100,
                  top: size.height * .62,
                  size: 300,
                  color: const Color(0xFFBFE2FF),
                  dx: math.cos(t) * 26,
                  dy: -math.sin(t) * 26,
                ),
                _blob(
                  right: -70,
                  bottom: -80,
                  size: 280,
                  color: const Color(0xFFFFDFC4),
                  dx: -math.cos(t) * 24,
                  dy: math.sin(t) * 22,
                ),
                for (final bubble in _bubbles) _bubbleWidget(bubble, size),
                Align(
                  alignment: const Alignment(0, -.1),
                  child: _center(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 58 + bottomInset,
                  child: _bottom(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _blob({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double size,
    required Color color,
    required double dx,
    required double dy,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withAlpha(165), color.withAlpha(0)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubbleWidget(_Bubble bubble, Size size) {
    final gate = const Interval(.4, .7).transform(_intro.value);
    final phase = (_loop.value - bubble.delay / _loopSeconds) % 1.0;
    final opacity = phase < .18
        ? phase / .18
        : (phase < .78 ? 1.0 : (1 - phase) / .22);

    return Positioned(
      left: bubble.left == null ? null : size.width * bubble.left!,
      right: bubble.right == null ? null : size.width * bubble.right!,
      top: size.height * bubble.top,
      child: Opacity(
        opacity: (opacity * gate).clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset(0, 34 - 88 * phase),
          child: Transform.scale(
            scale: .9 + .1 * phase,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(184),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withAlpha(230)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F6C4DF6),
                    blurRadius: 22,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                bubble.text,
                style: TextStyle(
                  fontSize: bubble.fontSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A4670),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _center() {
    final value = _intro.value;
    double segment(double begin, double end) =>
        Interval(begin, end, curve: Curves.easeOut).transform(value);

    final wordmarkOpacity = segment(.22, .6);
    final taglineOpacity = segment(.3, .68);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _logoGroup(),
        const SizedBox(height: 46),
        Opacity(
          opacity: wordmarkOpacity,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - wordmarkOpacity)),
            child: const Text(
              'Novyn',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                color: _C.text,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: taglineOpacity,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - taglineOpacity)),
            child: const Text(
              'Your space, your people',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                color: _C.sub,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _logoGroup() {
    final introValue = _intro.value;
    final pop = Curves.easeOutBack.transform(
      const Interval(0, .5).transform(introValue),
    );
    final scale = .6 + .4 * pop;
    final fade = const Interval(0, .3).transform(introValue);
    final bobGate = const Interval(.6, 1).transform(introValue);
    final bob = (1 + math.sin(_loop.value * 4 * math.pi)) / 2;
    final lift = -9 * bob * bobGate;
    final ringGate = const Interval(.5, .7).transform(introValue);
    final sheenX = -60 +
        240 * const Interval(.55, 1, curve: Curves.easeInOut).transform(introValue);

    Widget ring(double offset) {
      final phase = (_loop.value * 2 + offset) % 1.0;
      final opacity =
          (phase < .25 ? phase / .25 : (1 - phase) / .75) * .28 * ringGate;
      return Transform.scale(
        scale: .8 + 2.2 * phase,
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _C.primary.withAlpha((opacity * 255).round()),
              width: 2,
            ),
          ),
        ),
      );
    }

    final tile = Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8E70FF), Color(0xFF5B3FE0)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x616C4DF6),
            blurRadius: 44,
            offset: Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: Stack(
          children: [
            Center(
              child: CustomPaint(
                size: const Size(68, 68),
                painter: _LogoMark(),
              ),
            ),
            Positioned(
              left: sheenX,
              top: 0,
              bottom: 0,
              width: 46,
              child: Transform(
                transform: Matrix4.skewX(-.35),
                child: const ColoredBox(color: Color(0x61FFFFFF)),
              ),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ring(0),
          ring(.5),
          Positioned(
            left: 16,
            right: 16,
            bottom: -26,
            height: 14,
            child: Transform.scale(
              scaleX: 1 - .18 * bob,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: _C.primary.withAlpha(
                        (110 * (1 - .35 * bob) * fade).round(),
                      ),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, lift),
            child: Transform.scale(
              scale: scale,
              child: Opacity(opacity: fade, child: tile),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottom() {
    final opacity =
        const Interval(.45, .9, curve: Curves.easeOut).transform(_intro.value);
    final progress = Curves.easeInOut.transform(_progress.value);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - opacity)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Loading',
              value: '${(progress * 100).round()}%',
              child: Container(
                width: 176,
                height: 6,
                decoration: BoxDecoration(
                  color: _C.primary.withAlpha(41),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _C.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Getting your chats ready',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _C.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final bubble = Path()
      ..addRRect(
        RRect.fromLTRBR(
          2.5 * scale,
          3.5 * scale,
          21.5 * scale,
          17.5 * scale,
          Radius.circular(2.5 * scale),
        ),
      )
      ..moveTo(7 * scale, 17 * scale)
      ..lineTo(7 * scale, 21 * scale)
      ..lineTo(12.4 * scale, 17.2 * scale)
      ..close();
    canvas.drawPath(bubble, Paint()..color = Colors.white);

    final letter = Path()
      ..moveTo(8.9 * scale, 14 * scale)
      ..lineTo(8.9 * scale, 8 * scale)
      ..lineTo(15.1 * scale, 14 * scale)
      ..lineTo(15.1 * scale, 8 * scale);
    canvas.drawPath(
      letter,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _C.primary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
