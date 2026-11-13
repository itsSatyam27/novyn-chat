import 'package:flutter/material.dart';

/// Crisp, resolution-independent Novyn circular mark used on splash/auth surfaces.
class NovynBrandMark extends StatelessWidget {
  final double size;
  const NovynBrandMark({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _NovynBrandPainter()),
  );
}

class _NovynBrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);
    final circle = Rect.fromCircle(center: const Offset(50, 50), radius: 49);
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF806FFF), Color(0xFF5141CD)],
      ).createShader(circle);
    canvas.drawCircle(const Offset(50, 50), 49, bg);

    final wingPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final left = Path()
      ..moveTo(47, 31)
      ..cubicTo(38, 25, 25, 25, 17, 32)
      ..cubicTo(9, 39, 10, 51, 17, 57)
      ..cubicTo(14, 66, 20, 76, 30, 77)
      ..cubicTo(39, 78, 44, 68, 45, 57)
      ..cubicTo(46, 48, 45, 39, 47, 31)
      ..close();
    canvas.drawPath(left, wingPaint);
    final right = Path()
      ..moveTo(53, 31)
      ..cubicTo(62, 25, 75, 25, 83, 32)
      ..cubicTo(91, 39, 90, 51, 83, 57)
      ..cubicTo(86, 66, 80, 76, 70, 77)
      ..cubicTo(61, 78, 56, 68, 55, 57)
      ..cubicTo(54, 48, 55, 39, 53, 31)
      ..close();
    canvas.drawPath(right, wingPaint);

    final feather = Paint()
      ..color = const Color(0xFF6A58E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final leftFeather = Path()
      ..moveTo(22, 39)
      ..cubicTo(21, 48, 25, 54, 32, 58)
      ..moveTo(20, 53)
      ..cubicTo(19, 62, 24, 68, 31, 70);
    canvas.drawPath(leftFeather, feather);
    final rightFeather = Path()
      ..moveTo(78, 39)
      ..cubicTo(79, 48, 75, 54, 68, 58)
      ..moveTo(80, 53)
      ..cubicTo(81, 62, 76, 68, 69, 70);
    canvas.drawPath(rightFeather, feather);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
