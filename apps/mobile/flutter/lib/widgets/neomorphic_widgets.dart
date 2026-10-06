import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/novyn_theme.dart';

/// A custom neomorphic container that supports outer shadows (convex/extruded)
/// and inner shadows (concave/sunken) without external library dependencies.
class NeoContainer extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final double distance;
  final double blur;
  final Color? color;
  final bool isSunken;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxBorder? border;

  const NeoContainer({
    super.key,
    this.child,
    this.borderRadius = 20,
    this.distance = 6,
    this.blur = 12,
    this.color,
    this.isSunken = false,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final themeBg = NovynTheme.pageBg(context);
    final containerColor = color ?? themeBg;
    
    final lightShadow = NovynTheme.neoLightShadow(context);
    final darkShadow = NovynTheme.neoDarkShadow(context);

    if (isSunken) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Sunken Light Inner Shadow (from top-left)
            Positioned.fill(
              child: CustomPaint(
                painter: InnerShadowPainter(
                  borderRadius: borderRadius,
                  shadowColor: lightShadow,
                  offset: Offset(distance, distance),
                  blurRadius: blur,
                ),
              ),
            ),
            // Sunken Dark Inner Shadow (from bottom-right)
            Positioned.fill(
              child: CustomPaint(
                painter: InnerShadowPainter(
                  borderRadius: borderRadius,
                  shadowColor: darkShadow,
                  offset: Offset(-distance, -distance),
                  blurRadius: blur,
                ),
              ),
            ),
            // Content
            if (child != null)
              Padding(
                padding: padding ?? const EdgeInsets.all(12),
                child: child!,
              ),
          ],
        ),
      );
    } else {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
          boxShadow: [
            // Light source shadow on top-left
            BoxShadow(
              color: lightShadow,
              offset: Offset(-distance, -distance),
              blurRadius: blur,
            ),
            // Occlusion shadow on bottom-right
            BoxShadow(
              color: darkShadow,
              offset: Offset(distance, distance),
              blurRadius: blur,
            ),
          ],
        ),
        child: child,
      );
    }
  }
}

/// Custom painter to render soft inner shadows for neomorphic widgets.
class InnerShadowPainter extends CustomPainter {
  final double borderRadius;
  final Color shadowColor;
  final Offset offset;
  final double blurRadius;

  InnerShadowPainter({
    required this.borderRadius,
    required this.shadowColor,
    required this.offset,
    required this.blurRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    
    canvas.clipRRect(rrect);
    
    // Draw a wide stroke path along the boundaries that bleeds inward due to blur
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius)
      ..style = PaintingStyle.stroke
      ..strokeWidth = blurRadius * 2;
      
    // Offset path to draw shadows along one direction
    final shadowPath = Path()
      ..addRRect(rrect)
      ..transform(Matrix4.translationValues(offset.dx, offset.dy, 0).storage);
      
    canvas.drawPath(shadowPath, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! InnerShadowPainter ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.offset != offset ||
        oldDelegate.blurRadius != blurRadius;
  }
}

/// A neomorphic stateful button that visually clicks down (becomes sunken)
/// and triggers a haptic feedback click when touched.
class NeoButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final double distance;
  final double blur;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const NeoButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.distance = 5,
    this.blur = 10,
    this.color,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;

  void _onPressDown() {
    if (widget.onTap != null) {
      HapticFeedback.lightImpact();
      setState(() => _isPressed = true);
    }
  }

  void _onPressUp() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      widget.onTap?.call();
    }
  }

  void _onPressCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onPressDown(),
      onTapUp: (_) => _onPressUp(),
      onTapCancel: () => _onPressCancel(),
      child: Transform.scale(
        scale: _isPressed ? 0.98 : 1.0,
        child: NeoContainer(
          borderRadius: widget.borderRadius,
          distance: widget.distance,
          blur: widget.blur,
          color: widget.color,
          isSunken: _isPressed,
          padding: widget.padding,
          margin: widget.margin,
          width: widget.width,
          height: widget.height,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A neomorphic soft input text field that renders as a recessed container.
class NeoTextField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final VoidCallback? onEditingComplete;

  const NeoTextField({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return NeoContainer(
      isSunken: true,
      borderRadius: 16,
      distance: 3,
      blur: 6,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: onSurface.withOpacity(0.4),
              size: 20,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              focusNode: focusNode,
              onEditingComplete: onEditingComplete,
              style: TextStyle(
                color: onSurface,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: onSurface.withOpacity(0.4),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
