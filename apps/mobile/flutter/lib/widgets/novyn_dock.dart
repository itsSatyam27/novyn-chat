import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NovynDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadCount;
  final int requestCount;
  final String style;

  const NovynDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.unreadCount = 0,
    this.requestCount = 0,
    this.style = 'floating_pill',
  });

  static const labels = ['Messages', 'Calls', 'Discover', 'Contacts', 'Settings'];
  static const icons = [LucideIcons.messageCircle, LucideIcons.phone, LucideIcons.compass, LucideIcons.users, LucideIcons.sun];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final selected = selectedIndex.clamp(0, 4);
    final full = style == 'full_width';
    final compact = style == 'minimal' || style == 'sliding';
    final glass = style == 'glass';
    final radius = style == 'rounded_bar' ? 22.0 : (style == 'glow' ? 30.0 : 44.0);
    final background = dark ? const Color(0xE923172F) : const Color(0xF7FFFFFF);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(full ? 0 : 14, 0, full ? 0 : 14, full ? 0 : 14),
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: reduceMotion ? 0 : 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero).animate(animation), child: child),
          ),
          child: Container(
            key: ValueKey(style),
            height: full ? 72 : (compact ? 68 : 82),
            padding: EdgeInsets.symmetric(horizontal: full ? 4 : 8, vertical: 7),
            decoration: BoxDecoration(
              color: style == 'minimal' ? Colors.transparent : (glass ? background.withValues(alpha: .68) : background),
              borderRadius: BorderRadius.circular(full ? 0 : radius),
              border: style == 'minimal' || full ? null : Border.all(color: dark ? const Color(0x35C8B8F5) : const Color(0xFFDCD4FA)),
              boxShadow: style == 'minimal' || full ? null : [BoxShadow(color: dark ? Colors.black.withValues(alpha:.32) : accent.withValues(alpha:.10), blurRadius: glass ? 28 : 22, offset: const Offset(0, 9), spreadRadius: style == 'glow' ? 1 : 0)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(full ? 0 : radius),
              child: glass ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: _items(context, selected, accent, dark, compact, reduceMotion)) : _items(context, selected, accent, dark, compact, reduceMotion),
            ),
          ),
        ),
      ),
    );
  }

  Widget _items(BuildContext context, int selected, Color accent, bool dark, bool compact, bool reduceMotion) {
    final full = style == 'full_width';
    final elevated = style == 'elevated';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(5, (index) {
        final active = index == selected;
        final isPrimary = elevated && index == 2;
        final duration = Duration(milliseconds: reduceMotion ? 0 : 300);
        final color = active ? (style == 'minimal' ? accent : Colors.white) : (dark ? const Color(0xFFD4C9F2) : const Color(0xFF514477));
        return Expanded(
          child: Semantics(
            label: labels[index], button: true, selected: active,
            child: GestureDetector(
              key: ValueKey('dock-tab-$index'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!active) { HapticFeedback.selectionClick(); onSelected(index); }
              },
              child: Center(
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  height: isPrimary ? 58 : 58,
                  margin: EdgeInsets.symmetric(horizontal: full ? 1 : 2, vertical: isPrimary ? 0 : 2),
                  padding: EdgeInsets.symmetric(horizontal: active && !compact ? 9 : 4, vertical: 5),
                  decoration: BoxDecoration(
                    color: active && style != 'minimal' && style != 'full_width' && style != 'sliding'
                        ? (style == 'glow' ? accent.withValues(alpha:.22) : accent)
                        : (isPrimary ? accent : Colors.transparent),
                    borderRadius: BorderRadius.circular(style == 'rounded_bar' ? 16 : 28),
                    boxShadow: active && style == 'glow' ? [BoxShadow(color: accent.withValues(alpha:.42), blurRadius: 18)] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: active || isPrimary ? 1.08 : 1,
                        duration: duration,
                        child: Icon(icons[index], size: isPrimary ? 25 : 22, color: isPrimary ? Colors.white : color),
                      ),
                      if (!compact && style != 'minimal') ...[
                        const SizedBox(height: 3),
                        Text(labels[index], maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 9.5, height: 1.1, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color)),
                      ],
                      if (compact && active)
                        Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                      if (index == 0 && unreadCount > 0)
                        PositionedBadge(value: unreadCount > 99 ? '99+' : '$unreadCount'),
                      if (index == 3 && requestCount > 0)
                        Container(width: 6,height: 6,margin: const EdgeInsets.only(top: 2),decoration: const BoxDecoration(color: Color(0xFFFF5C85),shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class PositionedBadge extends StatelessWidget {
  const PositionedBadge({super.key, required this.value});
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 2),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: const Color(0xFFE34D73), borderRadius: BorderRadius.circular(10)),
    child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
  );
}
