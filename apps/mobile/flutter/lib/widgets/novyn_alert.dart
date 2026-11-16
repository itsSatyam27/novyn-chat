import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';

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

class NovynAlertStyleOption {
  const NovynAlertStyleOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
}

class NovynAlertStyles {
  NovynAlertStyles._();

  static const all = <NovynAlertStyleOption>[
    NovynAlertStyleOption(
      id: 'snackbar',
      name: 'Snackbar',
      description: 'A dark bottom snackbar with an icon, message and optional action',
      icon: Icons.vertical_align_bottom_rounded,
    ),
    NovynAlertStyleOption(
      id: 'top_banner',
      name: 'Top Banner',
      description: 'A white top card with a status badge and a short progress line',
      icon: Icons.vertical_align_top_rounded,
    ),
    NovynAlertStyleOption(
      id: 'capsule',
      name: 'Capsule',
      description: 'A compact pill that pops in, expands to show the message, then fades',
      icon: Icons.horizontal_rule_rounded,
    ),
    NovynAlertStyleOption(
      id: 'switch_card',
      name: 'Switch Card',
      description: 'A bottom card with a switch-like state indicator',
      icon: Icons.toggle_on_rounded,
    ),
    NovynAlertStyleOption(
      id: 'centre_hud',
      name: 'Centre HUD',
      description: 'A floating glass tile in the centre, like a volume HUD',
      icon: Icons.center_focus_strong_rounded,
    ),
    NovynAlertStyleOption(
      id: 'countdown_card',
      name: 'Countdown Card',
      description: 'A bottom card with a circular timer and optional action',
      icon: Icons.timer_outlined,
    ),
  ];

  static NovynAlertStyleOption byId(String id) =>
      all.firstWhere((style) => style.id == id, orElse: () => all.first);
}

class _AlertToneColors {
  const _AlertToneColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

const _alertToneColors = <NovynAlertTone, _AlertToneColors>{
  NovynAlertTone.success: _AlertToneColors(Color(0xFFDDF3E8), Color(0xFF15803D)),
  NovynAlertTone.danger: _AlertToneColors(Color(0xFFFDECEC), Color(0xFFC62828)),
  NovynAlertTone.violet: _AlertToneColors(Color(0xFFEAE4FF), Color(0xFF6C4DF6)),
  NovynAlertTone.neutral: _AlertToneColors(Color(0xFFECE8F8), Color(0xFF57546B)),
  NovynAlertTone.warning: _AlertToneColors(Color(0xFFFDEBD3), Color(0xFFB45309)),
};

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
    String? styleOverride,
  }) {
    _active?.removeImmediately();

    var styleId = styleOverride ?? 'snackbar';
    if (styleOverride == null) {
      try {
        styleId = Provider.of<SettingsService>(context, listen: false).alertStyle;
      } catch (_) {
        // Keep the default when used in an isolated widget or test.
      }
    }

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

  static void hide() {
    _active?.removeImmediately();
    _active = null;
  }

  static void preview(BuildContext context, String styleId) {
    showEvent(
      context,
      NovynAlertEvent.profileSaved,
      styleOverride: styleId,
      duration: const Duration(milliseconds: 2400),
      haptic: false,
    );
  }
}

class _AlertSession {
  OverlayEntry? entry;

  void removeImmediately() {
    final current = entry;
    entry = null;
    if (current?.mounted ?? false) current!.remove();
  }
}

class _NovynToast extends StatefulWidget {
  const _NovynToast({
    required this.event,
    required this.duration,
    required this.styleId,
    required this.onRemove,
  });

  final NovynAlertEvent event;
  final Duration duration;
  final String styleId;
  final VoidCallback onRemove;

  @override
  State<_NovynToast> createState() => _NovynToastState();
}

class _NovynToastState extends State<_NovynToast>
    with TickerProviderStateMixin {
  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final AnimationController _progressController = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: _isBottomStyle ? const Offset(0, .35) : const Offset(0, -.35),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _entryController,
    curve: widget.styleId == 'capsule' ? Curves.easeOutBack : Curves.easeOutCubic,
  ));
  late final Animation<double> _scale = Tween<double>(
    begin: widget.styleId == 'centre_hud' || widget.styleId == 'capsule' ? .72 : .96,
    end: 1,
  ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack));

  Timer? _timer;
  bool _closing = false;

  bool get _isBottomStyle =>
      widget.styleId == 'snackbar' ||
      widget.styleId == 'switch_card' ||
      widget.styleId == 'countdown_card';

  @override
  void initState() {
    super.initState();
    _entryController.forward();
    _progressController.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    try {
      await _entryController.reverse();
    } catch (_) {
      // The overlay may have been replaced while the exit animation ran.
    }
    if (mounted) widget.onRemove();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entryController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styleId = widget.styleId;
    final isCentre = styleId == 'centre_hud';
    final tone = _alertToneColors[widget.event.tone]!;
    final content = _buildStyleContent(context, tone);
    final animated = SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _entryController,
        child: ScaleTransition(scale: _scale, child: content),
      ),
    );

    if (isCentre) {
      return Positioned.fill(
        child: SafeArea(child: Center(child: animated)),
      );
    }

    return Positioned(
      top: _isBottomStyle ? null : 0,
      bottom: _isBottomStyle ? 14 : null,
      left: 12,
      right: 12,
      child: SafeArea(
        top: !_isBottomStyle,
        bottom: false,
        child: Center(child: animated),
      ),
    );
  }

  Widget _buildStyleContent(BuildContext context, _AlertToneColors tone) {
    final styleId = widget.styleId;
    final event = widget.event;
    final colors = Theme.of(context).colorScheme;
    final darkSnack = styleId == 'snackbar';
    final foreground = darkSnack ? Colors.white : colors.onSurface;
    final secondary = darkSnack ? Colors.white70 : colors.onSurfaceVariant;
    final iconBackground = darkSnack
        ? Colors.white.withValues(alpha: .14)
        : tone.background;
    final iconForeground = darkSnack ? Colors.white : tone.foreground;

    Widget iconTile({double size = 42, double iconSize = 22}) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(size == 64 ? 22 : 14),
          ),
          alignment: Alignment.center,
          child: Icon(event.icon, color: iconForeground, size: iconSize),
        );

    Widget textBlock({bool centered = false}) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: foreground),
            ),
            const SizedBox(height: 2),
            Text(
              event.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: TextStyle(fontSize: 12, height: 1.3, color: secondary),
            ),
          ],
        );

    Widget actionButton({Color? color}) {
      if (event.actionLabel == null || event.onAction == null) {
        return IconButton(
          tooltip: 'Dismiss',
          visualDensity: VisualDensity.compact,
          onPressed: _dismiss,
          icon: Icon(Icons.close_rounded, size: 18, color: color ?? secondary),
        );
      }
      return TextButton(
        onPressed: () {
          event.onAction!();
          _dismiss();
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: color ?? tone.foreground,
        ),
        child: Text(event.actionLabel!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      );
    }

    switch (styleId) {
      case 'snackbar':
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: const Color(0xFF1C1B29),
            elevation: 14,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(event.icon, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${event.title} · ${event.subtitle}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  actionButton(color: const Color(0xFFC4B9FF)),
                ],
              ),
            ),
          ),
        );

      case 'top_banner':
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: colors.surface,
            elevation: 14,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    children: [
                      iconTile(),
                      const SizedBox(width: 11),
                      Expanded(child: textBlock()),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(14)),
                        child: Text(
                          _statusLabel(event.tone),
                          style: TextStyle(color: tone.foreground, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .35),
                        ),
                      ),
                      if (event.actionLabel != null && event.onAction != null)
                        actionButton(color: tone.foreground),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (_, __) => LinearProgressIndicator(
                    value: 1 - _progressController.value,
                    minHeight: 3,
                    backgroundColor: colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(tone.foreground),
                  ),
                ),
              ],
            ),
          ),
        );

      case 'capsule':
        return AnimatedBuilder(
          animation: _entryController,
          builder: (context, child) {
            final expansion = Curves.easeOutCubic.transform(_entryController.value);
            return Material(
              color: event.tone == NovynAlertTone.danger || event.tone == NovynAlertTone.neutral
                  ? const Color(0xFF57546B)
                  : const Color(0xFF6C4DF6),
              elevation: 13,
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                height: 46,
                width: 46 + (210 * expansion) +
                    (event.actionLabel != null && event.onAction != null ? 54 : 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: Center(child: Icon(event.icon, color: Colors.white, size: 20)),
                    ),
                    if (expansion > .08)
                      Expanded(
                        child: Opacity(
                          opacity: expansion.clamp(0, 1).toDouble(),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '${event.title} · ${event.subtitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    if (event.actionLabel != null && event.onAction != null && expansion > .5)
                      GestureDetector(
                        onTap: () {
                          event.onAction!();
                          _dismiss();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(event.actionLabel!,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );

      case 'switch_card':
        final isOn = event.tone == NovynAlertTone.success || event.tone == NovynAlertTone.violet;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: colors.surface,
            elevation: 15,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  iconTile(),
                  const SizedBox(width: 11),
                  Expanded(child: textBlock()),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.elasticOut,
                    width: 48,
                    height: 28,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isOn ? tone.foreground : const Color(0xFF9C96B8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                  if (event.actionLabel != null && event.onAction != null)
                    actionButton(color: tone.foreground),
                ],
              ),
            ),
          ),
        );

      case 'centre_hud':
        return Material(
          color: Colors.white.withValues(alpha: .96),
          elevation: 22,
          borderRadius: BorderRadius.circular(36),
          child: SizedBox(
            width: 166,
            height: 166,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconTile(size: event.actionLabel != null ? 50 : 64, iconSize: event.actionLabel != null ? 27 : 34),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1C1B29)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.subtitle,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, height: 1.2, color: Color(0xFF6B6880)),
                  ),
                  if (event.actionLabel != null && event.onAction != null)
                    SizedBox(
                      height: 25,
                      child: TextButton(
                        onPressed: () {
                          event.onAction!();
                          _dismiss();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: tone.foreground,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(event.actionLabel!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

      case 'countdown_card':
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: colors.surface,
            elevation: 15,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(value: 1, strokeWidth: 3, color: colors.outlineVariant),
                        ),
                        SizedBox.expand(
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (_, __) => CircularProgressIndicator(
                              value: 1 - _progressController.value,
                              strokeWidth: 3,
                              color: tone.foreground,
                            ),
                          ),
                        ),
                        Icon(event.icon, size: 20, color: tone.foreground),
                      ],
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: textBlock()),
                  actionButton(color: tone.foreground),
                ],
              ),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _statusLabel(NovynAlertTone tone) => switch (tone) {
        NovynAlertTone.success => 'ON',
        NovynAlertTone.danger => 'OFF',
        NovynAlertTone.violet => 'ACTIVE',
        NovynAlertTone.warning => 'WARNING',
        NovynAlertTone.neutral => 'INFO',
      };
}
