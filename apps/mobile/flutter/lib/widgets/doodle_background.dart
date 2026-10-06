import 'package:flutter/material.dart';
import 'dart:math' as math;

class DoodleBackground extends StatelessWidget {
  final bool isDark;
  final int seed;
  const DoodleBackground({
    super.key, 
    required this.isDark,
    this.seed = 7, // Default seed
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0D0F1A), const Color(0xFF111320)]
              : [const Color(0xFFF5F3FF), const Color(0xFFEEF2FF)],
        ),
      ),
      child: CustomPaint(
        painter: _DoodlePainter(isDark: isDark, seed: seed),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final bool isDark;
  final int seed;
  _DoodlePainter({required this.isDark, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);

    // Two layers — subtle fill + stroke outline
    final strokeColor = isDark
        ? const Color(0xFF7C6FF7).withValues(alpha: 0.12)
        : const Color(0xFF7C6FF7).withValues(alpha: 0.10);

    final fillColor = isDark
        ? const Color(0xFF7C6FF7).withValues(alpha: 0.04)
        : const Color(0xFF7C6FF7).withValues(alpha: 0.05);

    final accentColor = isDark
        ? const Color(0xFFEC4899).withValues(alpha: 0.07)
        : const Color(0xFFEC4899).withValues(alpha: 0.07);

    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final accent = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final shapes = [
      // Large shapes spread across screen
      const _Shape(0.08, 0.12, 38, 0),
      const _Shape(0.85, 0.08, 28, 1),
      const _Shape(0.15, 0.35, 22, 2),
      const _Shape(0.78, 0.28, 32, 3),
      const _Shape(0.05, 0.55, 26, 4),
      const _Shape(0.92, 0.50, 20, 0),
      const _Shape(0.45, 0.18, 18, 1),
      const _Shape(0.60, 0.42, 30, 2),
      const _Shape(0.25, 0.70, 24, 3),
      const _Shape(0.80, 0.72, 22, 4),
      const _Shape(0.50, 0.85, 28, 0),
      const _Shape(0.12, 0.88, 20, 1),
      const _Shape(0.70, 0.90, 18, 2),
      const _Shape(0.35, 0.50, 16, 3),
      const _Shape(0.90, 0.35, 14, 4),
      // Small accent shapes
      const _Shape(0.22, 0.22, 10, 5),
      const _Shape(0.65, 0.15, 8, 5),
      const _Shape(0.40, 0.78, 10, 5),
      const _Shape(0.55, 0.62, 8, 6),
      const _Shape(0.18, 0.60, 12, 6),
      const _Shape(0.75, 0.55, 10, 6),
      const _Shape(0.30, 0.92, 8, 5),
      const _Shape(0.88, 0.82, 12, 6),
    ];

    for (final s in shapes) {
      final x = s.rx * size.width;
      final y = s.ry * size.height;
      final r = s.radius;
      final angle = random.nextDouble() * math.pi;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      final p = s.type < 5 ? stroke : accent;
      final f = fill;

      switch (s.type % 7) {
        case 0: // Circle with fill
          canvas.drawCircle(Offset.zero, r, f);
          canvas.drawCircle(Offset.zero, r, p);
          break;

        case 1: // Rounded square
          final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 1.6),
            Radius.circular(r * 0.35),
          );
          canvas.drawRRect(rect, f);
          canvas.drawRRect(rect, p);
          break;

        case 2: // Triangle
          final path = Path()
            ..moveTo(0, -r)
            ..lineTo(r * 0.87, r * 0.5)
            ..lineTo(-r * 0.87, r * 0.5)
            ..close();
          canvas.drawPath(path, f);
          canvas.drawPath(path, p);
          break;

        case 3: // Wavy line
          final path = Path()
            ..moveTo(-r, 0)
            ..cubicTo(-r * 0.5, -r * 0.5, r * 0.5, r * 0.5, r, 0);
          canvas.drawPath(path, p);
          break;

        case 4: // Star / asterisk
          for (int i = 0; i < 3; i++) {
            final a = i * math.pi / 3;
            canvas.drawLine(
              Offset(math.cos(a) * r, math.sin(a) * r),
              Offset(-math.cos(a) * r, -math.sin(a) * r),
              p,
            );
          }
          break;

        case 5: // Small dot
          canvas.drawCircle(Offset.zero, r * 0.5, Paint()..color = strokeColor..style = PaintingStyle.fill);
          break;

        case 6: // Diamond
          final path = Path()
            ..moveTo(0, -r)
            ..lineTo(r * 0.6, 0)
            ..lineTo(0, r)
            ..lineTo(-r * 0.6, 0)
            ..close();
          canvas.drawPath(path, f);
          canvas.drawPath(path, accent);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) => old.isDark != isDark;
}

class _Shape {
  final double rx, ry, radius;
  final int type;
  const _Shape(this.rx, this.ry, this.radius, this.type);
}
