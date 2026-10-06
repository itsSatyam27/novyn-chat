import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProfileAvatarWithOrbit extends StatefulWidget {
  final String? photoUrl;
  final String displayName;
  final String status;

  const ProfileAvatarWithOrbit({
    super.key,
    required this.photoUrl,
    required this.displayName,
    required this.status,
  });

  @override
  State<ProfileAvatarWithOrbit> createState() => ProfileAvatarWithOrbitState();
}

class ProfileAvatarWithOrbitState extends State<ProfileAvatarWithOrbit>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbitColor = _getStatusColor(widget.status);

    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Glowing Orbit ───────────────────────────────────────────
        AnimatedBuilder(
          animation: _controller,
          child: RepaintBoundary(
            child: CustomPaint(
              size: const Size(92, 92),
              painter: _OrbitCometPainter(color: orbitColor),
            ),
          ),
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: child,
            );
          },
        ),

        // ── Avatar with Outer Glow ──────────────────────────────────
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF1A1D2E)
                : Colors.white,
            boxShadow: [
              BoxShadow(
                color: orbitColor.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
            image: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                ? DecorationImage(
                    image: MemoryImage(base64Decode(widget.photoUrl!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: widget.photoUrl == null || widget.photoUrl!.isEmpty
              ? Center(
                  child: Text(
                    widget.displayName.isNotEmpty
                        ? widget.displayName.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'online':
        return const Color(0xFF10B981);
      case 'away':
        return const Color(0xFFF59E0B);
      case 'busy':
        return const Color(0xFFEC4899);
      case 'invisible':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF10B981);
    }
  }
}

// ── Custom Painter for the Comet Orbit ───────────────────────────────────────
class _OrbitCometPainter extends CustomPainter {
  final Color color;
  _OrbitCometPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw the base faint orbit line
    final orbitPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, orbitPaint);

    // 2. Draw the Comet Trail (a fading arc)
    final trailPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.transparent, color],
        stops: const [0.8, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0,
        math.pi * 0.4, false, trailPaint);

    // 3. Draw the Satellite Head (Glowing Dot)
    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    // Position at the end of the arc
    final headOffset = Offset(
      center.dx + radius * math.cos(math.pi * 0.4),
      center.dy + radius * math.sin(math.pi * 0.4),
    );
    canvas.drawCircle(headOffset, 4.5, headPaint);
    canvas.drawCircle(headOffset, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _OrbitCometPainter oldDelegate) =>
      oldDelegate.color != color;
}
