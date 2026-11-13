import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novyn/services/haptic_service.dart';

import 'auth_screen.dart';

/// A single-screen introduction to Novyn. The previous three-page carousel
/// has been replaced with one concise, animated welcome experience.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  late final Animation<double> _heroA = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0, .62, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _textA = CurvedAnimation(
    parent: _enter,
    curve: const Interval(.22, .82, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _ctaA = CurvedAnimation(
    parent: _enter,
    curve: const Interval(.48, 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _enter.dispose();
    _bob.dispose();
    super.dispose();
  }

  void _openAuth() {
    HapticService.vibrate(
      NovynHapticType.light,
      category: HapticCategory.buttons,
    );
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _OnboardingPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 760;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.72, -1.05),
                  radius: 1.25,
                  colors: [p.meshA, p.meshA.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(.95, .85),
                  radius: 1.15,
                  colors: [p.meshB, p.meshB.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      compact ? 8 : 14,
                      24,
                      compact ? 12 : 20,
                    ),
                    child: Column(
                      children: [
                        _buildHeader(p),
                        SizedBox(height: compact ? 4 : 12),
                        _Reveal(
                          animation: _heroA,
                          dy: 26,
                          child: SizedBox(
                            height: compact ? 300 : 370,
                            width: double.infinity,
                            child: _buildHero(p),
                          ),
                        ),
                        _Reveal(
                          animation: _textA,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Messaging,',
                                style: _textStyle(
                                  34,
                                  FontWeight.w800,
                                  p.ink,
                                  spacing: -1.1,
                                  height: 1.08,
                                ),
                              ),
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (rect) => LinearGradient(
                                  colors: [p.accent, p.teal],
                                ).createShader(rect),
                                child: Text(
                                  'made personal.',
                                  style: _textStyle(
                                    34,
                                    FontWeight.w800,
                                    Colors.white,
                                    spacing: -1.1,
                                    height: 1.08,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Fast, private chats and clear calls with the people who matter.',
                                style: _textStyle(
                                  14,
                                  FontWeight.w400,
                                  p.muted,
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _FeaturePill(
                                    p: p,
                                    icon: Icons.bolt_rounded,
                                    label: 'Real-time',
                                  ),
                                  _FeaturePill(
                                    p: p,
                                    icon: Icons.videocam_outlined,
                                    label: 'Voice & video',
                                  ),
                                  _FeaturePill(
                                    p: p,
                                    icon: Icons.verified_user_outlined,
                                    label: 'Private',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 24),
                        _Reveal(
                          animation: _ctaA,
                          dy: 18,
                          child: Column(
                            children: [
                              _GetStartedButton(onTap: _openAuth, p: p),
                              const SizedBox(height: 5),
                              TextButton(
                                onPressed: _openAuth,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  foregroundColor: p.muted,
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    style: _textStyle(
                                      13,
                                      FontWeight.w500,
                                      p.muted,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Already have an account? ',
                                      ),
                                      TextSpan(
                                        text: 'Log in',
                                        style: _textStyle(
                                          13,
                                          FontWeight.w800,
                                          p.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'By continuing you agree to our Terms and Privacy Policy.',
                                textAlign: TextAlign.center,
                                style: _textStyle(10, FontWeight.w500, p.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildHeader(_OnboardingPalette p) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [p.accent.withValues(alpha: .78), p.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: .25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.forum_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'novyn',
          style: _textStyle(22, FontWeight.w800, p.ink, spacing: -.8),
        ),
      ],
    );
  }

  Widget _float(double phase, double amplitude, Widget child) {
    return AnimatedBuilder(
      animation: _bob,
      child: child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          math.sin((_bob.value + phase) * 2 * math.pi) * amplitude,
        ),
        child: child,
      ),
    );
  }

  Widget _buildHero(_OnboardingPalette p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = (width / 342).clamp(.82, 1.0);
        final phoneWidth = 174.0 * scale;
        final phoneHeight = 278.0 * scale;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 50 * scale,
              child: Container(
                width: 230 * scale,
                height: 230 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: p.accent.withValues(alpha: .20),
                      blurRadius: 75,
                      spreadRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 28 * scale,
              child: Container(
                width: 245 * scale,
                height: 245 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: p.accent.withValues(alpha: .12),
                    width: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 46 * scale,
              child: _float(
                .35,
                5,
                Container(
                  width: phoneWidth,
                  height: phoneHeight,
                  decoration: BoxDecoration(
                    color: p.phone,
                    borderRadius: BorderRadius.circular(31),
                    border: Border.all(color: p.outline, width: 1.3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: p.isDark ? .34 : .12,
                        ),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                      BoxShadow(
                        color: p.accent.withValues(alpha: .10),
                        blurRadius: 30,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(29),
                    child: _PhonePreview(p: p),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 112 * scale,
              child: _float(
                .65,
                8,
                _GlassCard(
                  p: p,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: p.teal.withValues(alpha: .15),
                        child: Icon(
                          Icons.call_rounded,
                          size: 17,
                          color: p.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voice call',
                            style: _textStyle(10, FontWeight.w800, p.ink),
                          ),
                          Text(
                            'Connected',
                            style: _textStyle(9, FontWeight.w500, p.teal),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 196 * scale,
              child: _float(
                .85,
                7,
                _GlassCard(
                  p: p,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: p.accent.withValues(alpha: .14),
                        child: Icon(
                          Icons.videocam_rounded,
                          size: 17,
                          color: p.accent,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Video call',
                            style: _textStyle(10, FontWeight.w800, p.ink),
                          ),
                          Text(
                            'HD quality',
                            style: _textStyle(9, FontWeight.w500, p.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10 * scale,
              right: 45 * scale,
              child: _float(
                .1,
                6,
                _GlassCard(
                  p: p,
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.lock_rounded,
                    color: p.teal,
                    size: 21,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 45 * scale,
              bottom: 3,
              child: _float(
                .2,
                5,
                _GlassCard(
                  p: p,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: p.teal,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'End-to-end secure',
                        style: _textStyle(9, FontWeight.w700, p.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.p});
  final _OnboardingPalette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 11),
        Container(
          width: 47,
          height: 5,
          decoration: BoxDecoration(
            color: p.muted.withValues(alpha: .30),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 17),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: p.accent,
                child: const Icon(Icons.person, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alex Morgan',
                      style: _textStyle(10, FontWeight.w800, p.ink),
                    ),
                    Text(
                      'Online now',
                      style: _textStyle(8, FontWeight.w500, p.teal),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz_rounded, color: p.muted, size: 19),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _ChatBubble(text: 'Hey! How are you?', isMe: false),
        const _ChatBubble(text: 'Doing great! 😊', isMe: true),
        const _ChatBubble(text: 'Want to catch up?', isMe: false),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(9, 0, 9, 11),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: p.input,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, color: p.muted, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Message...',
                    style: _textStyle(8, FontWeight.w500, p.muted),
                  ),
                ),
                Icon(Icons.send_rounded, color: p.accent, size: 15),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isMe});
  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final p = _OnboardingPalette.of(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? p.accent : p.input,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 12),
          ),
        ),
        child: Text(
          text,
          style: _textStyle(
            8,
            FontWeight.w500,
            isMe ? Colors.white : p.ink,
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.p, required this.child, this.padding});
  final _OnboardingPalette p;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.glass,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: p.outline.withValues(alpha: .8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? .14 : .045),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.p,
    required this.icon,
    required this.label,
  });
  final _OnboardingPalette p;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: p.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.teal),
          const SizedBox(width: 6),
          Text(label, style: _textStyle(11, FontWeight.w600, p.muted)),
        ],
      ),
    );
  }
}

class _GetStartedButton extends StatelessWidget {
  const _GetStartedButton({required this.onTap, required this.p});
  final VoidCallback onTap;
  final _OnboardingPalette p;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [p.accent, Color.lerp(p.accent, p.teal, .28)!],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: p.accent.withValues(alpha: .28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get started',
                  style: _textStyle(15, FontWeight.w800, Colors.white),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.child,
    this.dy = 0,
  });
  final Animation<double> animation;
  final Widget child;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, dy * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}

class _OnboardingPalette {
  const _OnboardingPalette({
    required this.bg,
    required this.meshA,
    required this.meshB,
    required this.phone,
    required this.input,
    required this.glass,
    required this.outline,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.teal,
    required this.isDark,
  });

  final Color bg;
  final Color meshA;
  final Color meshB;
  final Color phone;
  final Color input;
  final Color glass;
  final Color outline;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color teal;
  final bool isDark;

  factory _OnboardingPalette.of(BuildContext context) {
    // Onboarding intentionally stays light, independent of the app theme.
    const accent = Color(0xFF6D5DFC);
    return const _OnboardingPalette(
      bg: Color(0xFFFAFAFF),
      meshA: Color(0x226D5DFC),
      meshB: Color(0x1918B99A),
      phone: Colors.white,
      input: Color(0xFFF0EFF8),
      glass: Color(0xF2FFFFFF),
      outline: Color(0x33716B91),
      ink: Color(0xFF17152B),
      muted: Color(0xFF77748B),
      accent: accent,
      teal: Color(0xFF17A98B),
      isDark: false,
    );
  }
}

TextStyle _textStyle(
  double size,
  FontWeight weight,
  Color color, {
  double spacing = 0,
  double height = 1.2,
}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );
}
