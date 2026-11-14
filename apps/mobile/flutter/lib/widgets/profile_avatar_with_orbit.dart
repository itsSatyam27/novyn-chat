import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'user_avatar.dart';

class ProfileAvatarWithOrbit extends StatefulWidget {
  final String? photoUrl;
  final String displayName;
  final String status;
  final File? localFile;

  const ProfileAvatarWithOrbit({
    super.key,
    required this.photoUrl,
    required this.displayName,
    required this.status,
    this.localFile,
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

  String _resolvedPhotoSource() {
    final source = widget.photoUrl?.trim() ?? '';
    if (source.isEmpty ||
        source.startsWith('https://') ||
        source.startsWith('http://')) {
      return source;
    }

    // UserAvatar handles legacy Base64 values; strip a data-URI prefix and
    // normalize padding so both avatar widgets decode the same source.
    final comma = source.indexOf(',');
    final payload = source.startsWith('data:image/') && comma >= 0
        ? source.substring(comma + 1)
        : source;
    try {
      return base64.normalize(payload);
    } catch (_) {
      return payload;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbitColor = _getStatusColor(widget.status);
    final initial = widget.displayName.isNotEmpty
        ? widget.displayName.substring(0, 1).toUpperCase()
        : '?';

    Widget fallback() => Center(
          child: Text(
            initial,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
        );

    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating orbit is constrained to the same 92px footprint.
          AnimatedBuilder(
            animation: _controller,
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(92, 92),
                painter: _OrbitCometPainter(color: orbitColor),
              ),
            ),
            builder: (context, child) => Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: child,
            ),
          ),
          Container(
            width: 70,
            height: 70,
            clipBehavior: Clip.antiAlias,
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
            ),
            child: widget.localFile != null
                ? Image.file(
                    widget.localFile!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => fallback(),
                  )
                : UserAvatar(
                    name: widget.displayName,
                    photoUrl: _resolvedPhotoSource(),
                    radius: 35,
                    fallbackColor: theme.colorScheme.primary,
                  ),
          ),
        ],
      ),
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
