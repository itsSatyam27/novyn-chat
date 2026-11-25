import 'package:flutter/material.dart';

class NovynEmptyState extends StatefulWidget {
  final IconData? icon;
  final Widget? illustration;
  final String title;
  final String description;
  final String? buttonLabel;
  final IconData? buttonIcon;
  final VoidCallback? onButtonTap;
  final bool isSecondaryButton;

  const NovynEmptyState({
    super.key,
    this.icon,
    this.illustration,
    required this.title,
    required this.description,
    this.buttonLabel,
    this.buttonIcon,
    this.onButtonTap,
    this.isSecondaryButton = false,
  });

  @override
  State<NovynEmptyState> createState() => _NovynEmptyStateState();
}

class _NovynEmptyStateState extends State<NovynEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.illustration != null)
              widget.illustration!
            else if (widget.icon != null)
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E1A33),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                  height: 1.45,
                ),
              ),
            ),
            if (widget.buttonLabel != null && widget.onButtonTap != null) ...[
              const SizedBox(height: 24),
              Material(
                color: widget.isSecondaryButton
                    ? Color.alphaBlend(
                        primary.withValues(alpha: .11),
                        theme.colorScheme.surface,
                      )
                    : primary,
                borderRadius: BorderRadius.circular(26),
                child: InkWell(
                  onTap: widget.onButtonTap,
                  borderRadius: BorderRadius.circular(26),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.buttonIcon != null) ...[
                          Icon(
                            widget.buttonIcon,
                            size: 19,
                            color: widget.isSecondaryButton ? primary : Colors.white,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.buttonLabel!,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: widget.isSecondaryButton ? primary : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NovynEmptyIllustrations {
  const NovynEmptyIllustrations._();

  static Widget speechBubblesDots({bool isDark = false, Color? accent}) {
    return Builder(
      builder: (context) => _SpeechBubblesBase(
        accent: accent ?? Theme.of(context).colorScheme.primary,
        isDark: isDark,
        badge: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget speechBubblesCheck({bool isDark = false, Color? accent}) {
    return Builder(
      builder: (context) => _SpeechBubblesBase(
        accent: accent ?? Theme.of(context).colorScheme.primary,
        isDark: isDark,
        badge: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
      ),
    );
  }

  static Widget speechBubblesStar({bool isDark = false, Color? accent}) {
    return Builder(
      builder: (context) => _SpeechBubblesBase(
        accent: accent ?? Theme.of(context).colorScheme.primary,
        isDark: isDark,
        badge: const Icon(Icons.star_rounded, color: Colors.white, size: 38),
      ),
    );
  }

  static Widget peopleGroupPlus({bool isDark = false, Color? accent}) {
    return Builder(
      builder: (context) {
        final primary = accent ?? Theme.of(context).colorScheme.primary;
        return _PeopleGroupBase(
          accent: primary,
          isDark: isDark,
          badge: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.add_rounded, color: primary, size: 22),
          ),
        );
      },
    );
  }

  static Widget peopleGroupHeart({bool isDark = false, Color? accent}) {
    return Builder(
      builder: (context) => _PeopleGroupBase(
        accent: accent ?? Theme.of(context).colorScheme.primary,
        isDark: isDark,
        badge: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // The heart remains red because it communicates the favourite state.
          child: const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFE53935),
            size: 19,
          ),
        ),
      ),
    );
  }

  static Widget personOffline({bool isDark = false, Color? accent}) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final primary = accent ?? theme.colorScheme.primary;
        final soft = Color.lerp(
          primary,
          theme.brightness == Brightness.dark ? Colors.white : Colors.white,
          theme.brightness == Brightness.dark ? .28 : .78,
        )!;
        final sparkle = Color.lerp(
          primary,
          theme.colorScheme.surface,
          .42,
        )!;
        return SizedBox(
          width: 170,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 18,
                top: 10,
                child: CustomPaint(
                  size: const Size(11, 11),
                  painter: _SparklePainter(color: sparkle),
                ),
              ),
              Positioned(
                right: 22,
                top: 18,
                child: CustomPaint(
                  size: const Size(11, 11),
                  painter: _SparklePainter(color: sparkle),
                ),
              ),
              Positioned(
                bottom: 2,
                child: Container(
                  width: 86,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(86, 14),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _PersonSilhouette(
                      headRadius: 20,
                      bodyWidth: 76,
                      bodyHeight: 38,
                      color: primary,
                    ),
                    Positioned(
                      right: -6,
                      bottom: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: soft.withValues(alpha: .2),
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colorScheme.outline),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeechBubblesBase extends StatelessWidget {
  final Widget badge;
  final bool isDark;
  final Color accent;

  const _SpeechBubblesBase({
    required this.badge,
    required this.accent,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = Color.lerp(accent, Colors.white, isDark ? .24 : .78)!;
    final muted = Color.lerp(accent, theme.colorScheme.surface, .64)!;
    return SizedBox(
      width: 170,
      height: 146,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 14,
            top: 12,
            child: CustomPaint(
              size: const Size(11, 11),
              painter: _SparklePainter(color: muted),
            ),
          ),
          Positioned(
            right: 18,
            top: 24,
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _SparklePainter(color: muted),
            ),
          ),
          Positioned(
            bottom: 2,
            child: Container(
              width: 86,
              height: 14,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.all(
                  Radius.elliptical(86, 14),
                ),
              ),
            ),
          ),
          Positioned(
            left: 28,
            top: 14,
            child: CustomPaint(
              size: const Size(72, 70),
              painter: _SpeechBubblePainter(
                color: soft,
                tailOnRight: false,
              ),
            ),
          ),
          Positioned(
            left: 56,
            top: 32,
            child: CustomPaint(
              size: const Size(84, 82),
              painter: _SpeechBubblePainter(
                color: accent,
                tailOnRight: true,
              ),
              child: SizedBox(
                width: 84,
                height: 72,
                child: Center(child: badge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleGroupBase extends StatelessWidget {
  final Widget badge;
  final bool isDark;
  final Color accent;

  const _PeopleGroupBase({
    required this.badge,
    required this.accent,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = Color.lerp(accent, Colors.white, isDark ? .22 : .78)!;
    final sparkle = Color.lerp(accent, theme.colorScheme.surface, .64)!;
    return SizedBox(
      width: 170,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 14,
            top: 12,
            child: CustomPaint(
              size: const Size(11, 11),
              painter: _SparklePainter(color: sparkle),
            ),
          ),
          Positioned(
            right: 18,
            top: 16,
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _SparklePainter(color: sparkle),
            ),
          ),
          Positioned(
            bottom: 2,
            child: Container(
              width: 90,
              height: 14,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.all(
                  Radius.elliptical(90, 14),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 12,
            child: _PersonSilhouette(
              headRadius: 13,
              bodyWidth: 48,
              bodyHeight: 28,
              color: soft,
            ),
          ),
          Positioned(
            right: 20,
            bottom: 12,
            child: _PersonSilhouette(
              headRadius: 13,
              bodyWidth: 48,
              bodyHeight: 28,
              color: soft,
            ),
          ),
          Positioned(
            bottom: 8,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _PersonSilhouette(
                  headRadius: 18,
                  bodyWidth: 70,
                  bodyHeight: 36,
                  color: accent,
                ),
                Positioned(
                  right: -8,
                  bottom: 2,
                  child: badge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonSilhouette extends StatelessWidget {
  final double headRadius;
  final double bodyWidth;
  final double bodyHeight;
  final Color color;

  const _PersonSilhouette({
    required this.headRadius,
    required this.bodyWidth,
    required this.bodyHeight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: headRadius * 2,
          height: headRadius * 2,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(bodyHeight)),
          child: Container(
            width: bodyWidth,
            height: bodyHeight,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  final Color color;
  final bool tailOnRight;

  const _SpeechBubblePainter({required this.color, this.tailOnRight = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 10),
      const Radius.circular(22),
    );
    canvas.drawRRect(r, paint);

    final tail = Path();
    if (tailOnRight) {
      tail.moveTo(size.width - 38, size.height - 11);
      tail.lineTo(size.width - 24, size.height);
      tail.lineTo(size.width - 16, size.height - 11);
    } else {
      tail.moveTo(16, size.height - 11);
      tail.lineTo(24, size.height);
      tail.lineTo(38, size.height - 11);
    }
    tail.close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.tailOnRight != tailOnRight;
}

class _SparklePainter extends CustomPainter {
  final Color color;

  const _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w / 2, h / 2, w, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, h)
      ..quadraticBezierTo(w / 2, h / 2, 0, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}
