import 'dart:async';
import 'package:flutter/material.dart';

/// Compact top notification matching Novyn web's settings toast.
class NovynAlert {
  NovynAlert._();

  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NovynToast(
        message: message,
        isError: isError,
        duration: duration,
        onRemove: () {
          if (_activeEntry == entry) _activeEntry = null;
          entry.remove();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _NovynToast extends StatefulWidget {
  const _NovynToast({
    required this.message,
    required this.isError,
    required this.duration,
    required this.onRemove,
  });

  final String message;
  final bool isError;
  final Duration duration;
  final VoidCallback onRemove;

  @override
  State<_NovynToast> createState() => _NovynToastState();
}

class _NovynToastState extends State<_NovynToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.7),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onRemove();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = widget.isError ? const Color(0xFFE24465) : const Color(0xFF00A982);

    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _controller,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  color: colors.surface,
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.fromLTRB(15, 9, 8, 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.isError
                              ? Icons.error_rounded
                              : Icons.check_circle_rounded,
                          color: tone,
                          size: 21,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Dismiss',
                          visualDensity: VisualDensity.compact,
                          onPressed: _dismiss,
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
