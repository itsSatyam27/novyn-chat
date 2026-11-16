import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Semantic tone used by every in-app status and action alert.
enum NovynAlertTone { success, danger, violet, neutral, warning }

class NovynAlertEvent {
  const NovynAlertEvent({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.tone = NovynAlertTone.neutral,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final NovynAlertTone tone;

  // Safety
  static NovynAlertEvent userBlocked(String name) => NovynAlertEvent(
        title: 'User blocked',
        subtitle: '$name can’t message or call you',
        icon: Icons.block_rounded,
        tone: NovynAlertTone.danger,
      );
  static NovynAlertEvent userUnblocked(String name) => NovynAlertEvent(
        title: 'User unblocked',
        subtitle: '$name can reach you again',
        icon: Icons.check_circle_outline_rounded,
        tone: NovynAlertTone.success,
      );
  static const stealthOn = NovynAlertEvent(
    title: 'Stealth Mode on',
    subtitle: 'Your privacy settings were updated',
    icon: Icons.visibility_off_rounded,
    tone: NovynAlertTone.violet,
  );
  static const reportSent = NovynAlertEvent(
    title: 'Report sent',
    subtitle: 'Thanks for letting us know',
    icon: Icons.flag_rounded,
    tone: NovynAlertTone.neutral,
  );

  // Chat
  static const messageDeleted = NovynAlertEvent(
    title: 'Message deleted',
    subtitle: 'Deleted for everyone',
    icon: Icons.delete_outline_rounded,
    tone: NovynAlertTone.danger,
  );
  static const chatCleared = NovynAlertEvent(
    title: 'Chat cleared',
    subtitle: 'All messages were removed',
    icon: Icons.cleaning_services_rounded,
    tone: NovynAlertTone.neutral,
  );
  static const messagePinned = NovynAlertEvent(
    title: 'Message pinned',
    subtitle: 'Pinned to the top of this chat',
    icon: Icons.push_pin_rounded,
    tone: NovynAlertTone.violet,
  );
  static const textCopied = NovynAlertEvent(
    title: 'Text copied',
    subtitle: 'Copied to your clipboard',
    icon: Icons.content_copy_rounded,
    tone: NovynAlertTone.neutral,
  );

  // Friends
  static NovynAlertEvent requestSent(String name) => NovynAlertEvent(
        title: 'Request sent',
        subtitle: 'Waiting for $name to accept',
        icon: Icons.send_rounded,
        tone: NovynAlertTone.violet,
      );
  static NovynAlertEvent requestAccepted(String name) => NovynAlertEvent(
        title: 'Request accepted',
        subtitle: 'You and $name are now friends',
        icon: Icons.how_to_reg_rounded,
        tone: NovynAlertTone.success,
      );
  static NovynAlertEvent contactRemoved(String name) => NovynAlertEvent(
        title: 'Contact removed',
        subtitle: '$name was removed from friends',
        icon: Icons.person_remove_rounded,
        tone: NovynAlertTone.danger,
      );

  // System
  static const noInternet = NovynAlertEvent(
    title: 'No internet',
    subtitle: 'Check your connection and try again',
    icon: Icons.wifi_off_rounded,
    tone: NovynAlertTone.warning,
  );
  static const profileSaved = NovynAlertEvent(
    title: 'Profile saved',
    subtitle: 'Your changes were saved',
    icon: Icons.check_circle_outline_rounded,
    tone: NovynAlertTone.success,
  );
  static const loggedOut = NovynAlertEvent(
    title: 'Logged out',
    subtitle: 'See you soon',
    icon: Icons.logout_rounded,
    tone: NovynAlertTone.neutral,
  );
}

class _AlertStyle {
  const _AlertStyle(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

const _alertStyles = <NovynAlertTone, _AlertStyle>{
  NovynAlertTone.success: _AlertStyle(Color(0xFFDDF3E8), Color(0xFF15803D)),
  NovynAlertTone.danger: _AlertStyle(Color(0xFFFDECEC), Color(0xFFC62828)),
  NovynAlertTone.violet: _AlertStyle(Color(0xFFEAE4FF), Color(0xFF6C4DF6)),
  NovynAlertTone.neutral: _AlertStyle(Color(0xFFECE8F8), Color(0xFF57546B)),
  NovynAlertTone.warning: _AlertStyle(Color(0xFFFDEBD3), Color(0xFFB45309)),
};

/// Reusable, animated top-positioned alert for the entire Novyn app.
///
/// The original string API remains supported so existing screens can migrate
/// without changing their copy all at once.
class NovynAlert {
  NovynAlert._();

  static _AlertSession? _active;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 3000),
    String? title,
    IconData? icon,
    NovynAlertTone? tone,
    bool haptic = true,
  }) {
    showEvent(
      context,
      NovynAlertEvent(
        title: title ?? (isError ? 'Something went wrong' : 'Done'),
        subtitle: message,
        icon: icon ?? (isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded),
        tone: tone ?? (isError ? NovynAlertTone.danger : NovynAlertTone.success),
      ),
      duration: duration,
      haptic: haptic,
    );
  }

  static void showEvent(
    BuildContext context,
    NovynAlertEvent event, {
    Duration duration = const Duration(milliseconds: 2800),
    bool haptic = true,
  }) {
    _active?.removeImmediately();

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    final session = _AlertSession();
    entry = OverlayEntry(
      builder: (_) => _NovynToast(
        event: event,
        duration: duration,
        onRemove: () {
          if (identical(_active, session)) _active = null;
          session.removeImmediately();
        },
      ),
    );
    session.entry = entry;
    _active = session;
    overlay.insert(entry);

    if (haptic) {
      if (event.tone == NovynAlertTone.danger) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  static void hide() => _active?.dismiss();
}

class _AlertSession {
  OverlayEntry? entry;
  void removeImmediately() {
    final current = entry;
    entry = null;
    if (current?.mounted ?? false) current!.remove();
  }
  void dismiss() {
    // The toast owns its exit animation and timer. Replacing an alert removes
    // the previous entry immediately; explicit dismissal is handled in-card.
    removeImmediately();
  }
}

class _NovynToast extends StatefulWidget {
  const _NovynToast({
    required this.event,
    required this.duration,
    required this.onRemove,
  });

  final NovynAlertEvent event;
  final Duration duration;
  final VoidCallback onRemove;

  @override
  State<_NovynToast> createState() => _NovynToastState();
}

class _NovynToastState extends State<_NovynToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.55),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  late final Animation<double> _scale = Tween<double>(begin: .94, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    try {
      await _controller.reverse();
    } catch (_) {
      // The overlay may have been replaced while the exit animation ran.
    }
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
    final event = widget.event;
    final style = _alertStyles[event.tone]!;
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          label: '${event.title}. ${event.subtitle}',
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _controller,
              child: ScaleTransition(
                scale: _scale,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Material(
                      color: colors.surface,
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 11, 7, 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: style.background,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Icon(event.icon, color: style.foreground, size: 22),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.3,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Dismiss',
                              visualDensity: VisualDensity.compact,
                              onPressed: _dismiss,
                              icon: Icon(Icons.close_rounded, size: 18, color: colors.onSurfaceVariant),
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
        ),
      ),
    );
  }
}
