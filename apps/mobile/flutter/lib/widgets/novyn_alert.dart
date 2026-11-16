import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

/// Semantic tone used by every in-app status and action alert.
enum NovynAlertTone { success, danger, violet, neutral, warning }

class NovynAlertEvent {
  const NovynAlertEvent({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.tone = NovynAlertTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final NovynAlertTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

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
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showEvent(
      context,
      NovynAlertEvent(
        title: title ?? (isError ? 'Something went wrong' : 'Done'),
        subtitle: message,
        icon: icon ?? (isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded),
        tone: tone ?? (isError ? NovynAlertTone.danger : NovynAlertTone.success),
        actionLabel: actionLabel,
        onAction: onAction,
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

    String styleId = 'snackbar';
    try { styleId = Provider.of<SettingsService>(context, listen: false).alertStyle; } catch (_) {}
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    final session = _AlertSession();
    entry = OverlayEntry(
      builder: (_) => _NovynToast(
        event: event,
        duration: duration,
        styleId: styleId,
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
    required this.styleId,
  });

  final NovynAlertEvent event;
  final Duration duration;
  final String styleId;
  final VoidCallback onRemove;
  final String styleId;

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
    final tone = _alertStyles[event.tone]!;
    final colors = Theme.of(context).colorScheme;
    final styleId = widget.styleId;
    final isCentre = styleId == 'centre_hud';
    final isBottom = styleId == 'snackbar' || styleId == 'switch_card' || styleId == 'countdown_card';
    final isCapsule = styleId == 'capsule';
    final bg = styleId == 'snackbar' ? const Color(0xFF1C1B29) : colors.surface;
    final fg = styleId == 'snackbar' ? Colors.white : colors.onSurface;
    final subtitleColor = styleId == 'snackbar' ? Colors.white70 : colors.onSurfaceVariant;
    final radius = styleId == 'capsule' ? 28.0 : (styleId == 'centre_hud' ? 34.0 : 22.0);
    final content = _buildAlertContent(event, tone, colors, styleId, fg, subtitleColor);
    return Positioned(
      top: isBottom ? null : 0,
      bottom: isBottom ? 14 : null,
      left: styleId == 'capsule' ? null : 12,
      right: styleId == 'capsule' ? null : 12,
      child: SafeArea(
        top: !isBottom,
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
                child: isCentre
                    ? Center(
                        child: Material(
                          color: Colors.white.withValues(alpha: .96),
                          elevation: 20,
                          borderRadius: BorderRadius.circular(radius),
                          child: SizedBox(
                            width: 166,
                            height: 166,
                            child: content,
                          ),
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 520, minWidth: isCapsule ? 46 : 0),
                          child: Material(
                            color: bg,
                            elevation: 12,
                            shadowColor: Colors.black.withValues(alpha: .20),
                            borderRadius: BorderRadius.circular(radius),
                            child: Container(
                              padding: EdgeInsets.fromLTRB(isCapsule ? 0 : 12, 10, 8, 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(radius),
                                border: styleId == 'snackbar' || isCapsule
                                    ? null
                                    : Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
                              ),
                              child: content,
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

  Widget _buildAlertContent(
    NovynAlertEvent event,
    _AlertStyle tone,
    ColorScheme colors,
    String styleId,
    Color foreground,
    Color subtitleColor,
  ) {
    final iconColor = styleId == 'snackbar' ? Colors.white : tone.foreground;
    final iconBg = styleId == 'snackbar'
        ? Colors.white.withValues(alpha: .14)
        : tone.background;
    final iconSize = styleId == 'centre_hud' ? 36.0 : 22.0;
    final iconTile = Container(
      width: styleId == 'centre_hud' ? 66 : 42,
      height: styleId == 'centre_hud' ? 66 : 42,
      decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(styleId == 'centre_hud' ? 22 : 14)),
      alignment: Alignment.center,
      child: Icon(event.icon, color: iconColor, size: iconSize),
    );
    final titleAndSubtitle = Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: styleId == 'centre_hud' ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: styleId == 'centre_hud' ? 15 : 13.5, fontWeight: FontWeight.w800, color: foreground)),
          if (styleId != 'capsule') ...[
            const SizedBox(height: 2),
            Text(event.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.3, color: subtitleColor)),
          ] else
            Text(event.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: subtitleColor)),
        ],
      ),
    );
    Widget? action;
    if (event.actionLabel != null && event.onAction != null) {
      action = TextButton(
        onPressed: () { event.onAction!(); _dismiss(); },
        child: Text(event.actionLabel!, style: TextStyle(fontSize: 12, color: tone.foreground)),
      );
    }
    if (styleId == 'centre_hud') {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        iconTile, const SizedBox(height: 8),
        Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: foreground)),
        const SizedBox(height: 3),
        Text(event.subtitle, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: subtitleColor)),
      ]);
    }
    if (styleId == 'capsule') {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 46, height: 46, child: Center(child: Icon(event.icon, color: Colors.white, size: 21))),
        Padding(padding: const EdgeInsets.only(right: 16), child: Text(
          '${event.title} · ${event.subtitle}', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
      ]);
    }
    if (styleId == 'switch_card') {
      return Row(children: [
        iconTile, const SizedBox(width: 11), titleAndSubtitle,
        Container(width: 46, height: 28, decoration: BoxDecoration(
          color: tone.foreground, borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.all(3),
          child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
      ]);
    }
    if (styleId == 'countdown_card') {
      return Row(children: [
        SizedBox(width: 46, height: 46, child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(value: 1, strokeWidth: 3, color: colors.outlineVariant)),
          SizedBox.expand(child: TweenAnimationBuilder<double>(tween: Tween(begin: 1, end: 0), duration: widget.duration,
            builder: (_, value, __) => CircularProgressIndicator(value: value, strokeWidth: 3, color: tone.foreground))),
          Icon(event.icon, size: 20, color: tone.foreground),
        ])),
        const SizedBox(width: 11), titleAndSubtitle,
        if (action != null) action,
      ]);
    }
    return Row(children: [
      iconTile, const SizedBox(width: 11), titleAndSubtitle,
      if (styleId == 'top_banner')
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(14)),
          child: Text('OK', style: TextStyle(color: tone.foreground, fontSize: 10, fontWeight: FontWeight.w800)),
        )
      else if (action != null) action
      else IconButton(tooltip: 'Dismiss', visualDensity: VisualDensity.compact, onPressed: _dismiss,
        icon: Icon(Icons.close_rounded, size: 18, color: subtitleColor)),
    ]);
  }
}
}
