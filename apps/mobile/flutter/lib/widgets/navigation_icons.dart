import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Novyn Nav Icons Suite
/// Customized, clean, recognizable, and animated neomorphic icons for Novyn App.
class NovynNavIcons {
  static Widget chats({required bool active, Color? color}) => _AnimatedIconWrapper(
        active: active,
        color: color,
        painterBuilder: (c, f, a) => _InnovationChatsPainter(color: c, isFilled: f, anim: a),
      );

  static Widget calls({required bool active, Color? color}) => _AnimatedIconWrapper(
        active: active,
        color: color,
        painterBuilder: (c, f, a) => _InnovationCallsPainter(color: c, isFilled: f, anim: a),
      );

  static Widget people({required bool active, Color? color}) => _AnimatedIconWrapper(
        active: active,
        color: color,
        painterBuilder: (c, f, a) => _InnovationPeoplePainter(color: c, isFilled: f, anim: a),
      );

  static Widget discover({required bool active, Color? color}) => _AnimatedIconWrapper(
        active: active,
        color: color,
        painterBuilder: (c, f, a) => _InnovationDiscoverPainter(color: c, isFilled: f, anim: a),
      );

  static Widget profile({required bool active, Color? color}) => _AnimatedIconWrapper(
        active: active,
        color: color,
        painterBuilder: (c, f, a) => _InnovationProfilePainter(color: c, isFilled: f, anim: a),
      );
}

// ── Shared Wrapper ───────────────────────────────────────────────────────────

class _AnimatedIconWrapper extends StatefulWidget {
  final bool active;
  final Color? color;
  final CustomPainter Function(Color color, bool isFilled, double anim) painterBuilder;

  const _AnimatedIconWrapper({
    required this.active,
    this.color,
    required this.painterBuilder,
  });

  @override
  State<_AnimatedIconWrapper> createState() => _AnimatedIconWrapperState();
}

class _AnimatedIconWrapperState extends State<_AnimatedIconWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedIconWrapper old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && old.active) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.color ?? IconTheme.of(context).color ?? Colors.black;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: const Size(28, 28),
        painter: widget.painterBuilder(iconColor, widget.active, _controller.value),
      ),
    );
  }
}

// ── Custom Painters (Recognizable + Futuristic Dual-Tone) ───────────────────

/// 1. CHATS: Modern speech bubble with high-tech turquoise details
class _InnovationChatsPainter extends CustomPainter {
  final Color color;
  final bool isFilled;
  final double anim;
  _InnovationChatsPainter({required this.color, required this.isFilled, required this.anim});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    final paint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Rounded speech bubble
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, h * 0.12, w * 0.8, h * 0.62),
      const Radius.circular(10),
    );
    path.addRRect(rrect);
    
    // Bubble pointer (tail) at bottom-left
    final tailPath = Path()
      ..moveTo(w * 0.28, h * 0.74)
      ..lineTo(w * 0.16, h * 0.88)
      ..lineTo(w * 0.16, h * 0.74)
      ..close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(tailPath, paint);

    // Inner detail lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Line 1: white (if filled) or primary color
    canvas.drawLine(
      Offset(w * 0.28, h * 0.35),
      Offset(w * 0.72, h * 0.35),
      linePaint..color = isFilled ? Colors.white : color,
    );

    // Line 2: high-tech turquoise accent line (animates length when active)
    final widthFactor = isFilled ? (0.35 + 0.12 * math.sin(anim * math.pi * 2)) : 0.4;
    canvas.drawLine(
      Offset(w * 0.28, h * 0.50),
      Offset(w * (0.28 + widthFactor), h * 0.50),
      linePaint..color = const Color(0xFF40E0D0),
    );

    // Floating notification dot when active
    if (isFilled) {
      canvas.drawCircle(
        Offset(w * 0.82, h * 0.18),
        w * 0.08,
        Paint()..color = const Color(0xFF40E0D0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InnovationChatsPainter old) => true;
}

/// 2. CALLS: Phone handset that pulses dual-tone soundwaves
class _InnovationCallsPainter extends CustomPainter {
  final Color color;
  final bool isFilled;
  final double anim;
  _InnovationCallsPainter({required this.color, required this.isFilled, required this.anim});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    final paint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw handset shape (angled 45 degrees)
    canvas.save();
    canvas.translate(w * 0.5, h * 0.5);
    canvas.rotate(-math.pi / 4);

    final path = Path()
      ..moveTo(-w * 0.22, -h * 0.08)
      ..quadraticBezierTo(-w * 0.22, -h * 0.26, -w * 0.12, -h * 0.26)
      ..lineTo(-w * 0.04, -h * 0.14)
      ..quadraticBezierTo(-w * 0.08, -h * 0.04, -w * 0.04, 0)
      ..lineTo(w * 0.04, h * 0.08)
      ..quadraticBezierTo(w * 0.08, h * 0.04, w * 0.12, h * 0.14)
      ..lineTo(w * 0.22, h * 0.26)
      ..quadraticBezierTo(w * 0.22, h * 0.36, w * 0.12, h * 0.36)
      ..quadraticBezierTo(-w * 0.22, h * 0.22, -w * 0.22, -h * 0.08)
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();

    // Dual-tone soundwaves
    final wavePaint = Paint()
      ..color = const Color(0xFF40E0D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final baseRadius = w * 0.22;
    final offsetAnim = 5 * anim;

    if (isFilled) {
      // Arc 1 (Turquoise)
      canvas.drawArc(
        Rect.fromCenter(center: Offset(w * 0.68, h * 0.32), width: baseRadius + offsetAnim, height: baseRadius + offsetAnim),
        -math.pi / 4,
        math.pi / 2,
        false,
        wavePaint..color = const Color(0xFF40E0D0).withOpacity(1.0 - anim),
      );
      // Arc 2 (Primary color shadow wave)
      canvas.drawArc(
        Rect.fromCenter(center: Offset(w * 0.68, h * 0.32), width: baseRadius + w * 0.2 + offsetAnim, height: baseRadius + w * 0.2 + offsetAnim),
        -math.pi / 4,
        math.pi / 2,
        false,
        wavePaint..color = color.withOpacity(0.5 * (1.0 - anim)),
      );
    } else {
      // Static single wave
      canvas.drawArc(
        Rect.fromCenter(center: Offset(w * 0.68, h * 0.32), width: baseRadius, height: baseRadius),
        -math.pi / 4,
        math.pi / 2,
        false,
        wavePaint..color = color.withOpacity(0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InnovationCallsPainter old) => true;
}

/// 3. DISCOVER: Compass Dial with cardinal points and rotating turquoise pointer
class _InnovationDiscoverPainter extends CustomPainter {
  final Color color;
  final bool isFilled;
  final double anim;
  _InnovationDiscoverPainter({required this.color, required this.isFilled, required this.anim});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;
    final r = w * 0.36;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    // Draw outer compass ring
    canvas.drawCircle(Offset(cx, cy), r, paint..color = isFilled ? color.withOpacity(0.3) : color);
    
    // Draw cardinal ticks
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy - r + 3), paint..color = color);
    canvas.drawLine(Offset(cx, cy + r), Offset(cx, cy + r - 3), paint..color = color);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx - r + 3, cy), paint..color = color);
    canvas.drawLine(Offset(cx + r, cy), Offset(cx + r - 3, cy), paint..color = color);

    // Radar scan sweep when active
    if (isFilled) {
      final sweepPaint = Paint()
        ..color = const Color(0xFF40E0D0).withOpacity(0.12)
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
        anim * 2 * math.pi - math.pi / 6,
        math.pi / 3,
        true,
        sweepPaint,
      );
    }

    canvas.save();
    canvas.translate(cx, cy);
    // Rotate: spin needle if active, static angle if inactive
    final angle = isFilled ? anim * 2 * math.pi : math.pi / 4;
    canvas.rotate(angle);

    // North needle pointer (Turquoise)
    final needleNorth = Path()
      ..moveTo(0, -r + 5)
      ..lineTo(w * 0.08, 0)
      ..lineTo(-w * 0.08, 0)
      ..close();
    
    canvas.drawPath(
      needleNorth,
      Paint()
        ..color = const Color(0xFF40E0D0)
        ..style = PaintingStyle.fill,
    );

    // South needle pointer (Primary color outline)
    final needleSouth = Path()
      ..moveTo(0, r - 5)
      ..lineTo(w * 0.08, 0)
      ..lineTo(-w * 0.08, 0)
      ..close();
      
    canvas.drawPath(
      needleSouth,
      Paint()
        ..color = color
        ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Pivot dot
    canvas.drawCircle(Offset.zero, 3.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset.zero, 1.8, Paint()..color = const Color(0xFF40E0D0));
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InnovationDiscoverPainter old) => true;
}

/// 4. PEOPLE: Dual users overlapping with high-tech turquoise friend indicator
class _InnovationPeoplePainter extends CustomPainter {
  final Color color;
  final bool isFilled;
  final double anim;
  _InnovationPeoplePainter({required this.color, required this.isFilled, required this.anim});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    final paint = Paint()
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final bounce = isFilled ? math.sin(anim * math.pi * 2) * 1.5 : 0.0;

    // Draw back user in primary color
    _drawUser(
      canvas,
      Offset(w * 0.36, h * 0.58),
      w * 0.14,
      w * 0.28,
      paint..color = isFilled ? color.withOpacity(0.5) : color.withOpacity(0.6),
    );

    // Draw front user in turquoise accent color (with slight bobbing)
    _drawUser(
      canvas,
      Offset(w * 0.62, h * 0.52 + bounce),
      w * 0.16,
      w * 0.32,
      paint..color = const Color(0xFF40E0D0),
    );
  }

  void _drawUser(Canvas canvas, Offset center, double headRadius, double bodyWidth, Paint paint) {
    // Head
    canvas.drawCircle(Offset(center.dx, center.dy - headRadius - 2), headRadius, paint);
    
    // Body (Shoulders)
    final rect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + headRadius),
      width: bodyWidth,
      height: headRadius * 1.6,
    );
    canvas.drawArc(rect, math.pi, math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _InnovationPeoplePainter old) => true;
}

/// 5. PROFILE: User avatar with animated halo ring
class _InnovationProfilePainter extends CustomPainter {
  final Color color;
  final bool isFilled;
  final double anim;
  _InnovationProfilePainter({required this.color, required this.isFilled, required this.anim});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;
    
    final paint = Paint()
      ..color = color
      ..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    // Outer circle container
    if (isFilled) {
      canvas.drawCircle(Offset(cx, cy), w * 0.40, paint..color = color.withOpacity(0.12)..style = PaintingStyle.fill);
    }
    canvas.drawCircle(Offset(cx, cy), w * 0.40, paint..color = color..style = PaintingStyle.stroke);

    final bobY = isFilled ? math.sin(anim * math.pi * 2) * 1.5 : 0.0;
    final userCenter = cy + bobY;

    // Draw user head (Turquoise highlight)
    canvas.drawCircle(
      Offset(cx, userCenter - 4),
      w * 0.15,
      paint..color = const Color(0xFF40E0D0)..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke,
    );

    // Draw shoulders (Primary color)
    final shoulderRect = Rect.fromCenter(
      center: Offset(cx, userCenter + w * 0.22),
      width: w * 0.44,
      height: w * 0.24,
    );
    canvas.drawArc(
      shoulderRect,
      math.pi,
      math.pi,
      false,
      paint..color = color..style = isFilled ? PaintingStyle.fill : PaintingStyle.stroke,
    );

    // Extra Halo Ring around profile when active
    if (isFilled) {
      final haloPaint = Paint()
        ..color = const Color(0xFF40E0D0).withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(Offset(cx, userCenter - 4), w * 0.25, haloPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InnovationProfilePainter old) => true;
}
