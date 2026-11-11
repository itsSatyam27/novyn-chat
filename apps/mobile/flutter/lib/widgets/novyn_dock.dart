import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Persistent bottom navigation. Its outer footprint stays constant across
/// styles so changing a dock never shifts the page or causes a size jump.
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
  static const icons = [
    LucideIcons.messageCircle,
    LucideIcons.phone,
    LucideIcons.compass,
    LucideIcons.users,
    LucideIcons.sun,
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final selected = selectedIndex.clamp(0, 4);
    final full = style == 'full_width';
    final compact = style == 'minimal' || style == 'sliding';
    final glass = style == 'glass';
    final duration = Duration(milliseconds: reduceMotion ? 0 : 320);
    final radius = style == 'rounded_bar' ? 22.0 : (style == 'glow' ? 30.0 : 26.0);
    final background = dark ? const Color(0xE923172F) : const Color(0xF7FFFFFF);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: duration,
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.fromLTRB(full ? 0 : 14, 0, full ? 0 : 14, full ? 0 : 14),
        child: SizedBox(
          height: 82,
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeInOutCubic,
              width: double.infinity,
              height: full ? 72 : (compact ? 68 : 82),
              padding: EdgeInsets.symmetric(horizontal: full ? 4 : 8, vertical: 7),
              decoration: BoxDecoration(
                color: style == 'minimal'
                    ? Colors.transparent
                    : (glass ? background.withValues(alpha: .68) : background),
                borderRadius: BorderRadius.circular(full ? 0 : radius),
                border: style == 'minimal' || full
                    ? null
                    : Border.all(
                        color: dark ? const Color(0x35C8B8F5) : const Color(0xFFDCD4FA),
                      ),
                boxShadow: style == 'minimal' || full
                    ? null
                    : [
                        BoxShadow(
                          color: dark
                              ? Colors.black.withValues(alpha: .28)
                              : accent.withValues(alpha: .09),
                          blurRadius: glass ? 26 : 20,
                          offset: const Offset(0, 8),
                          spreadRadius: style == 'glow' ? 1 : 0,
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(full ? 0 : radius),
                child: glass
                    ? BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: _items(context, selected, accent, dark, compact, reduceMotion),
                      )
                    : _items(context, selected, accent, dark, compact, reduceMotion),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _items(
    BuildContext context,
    int selected,
    Color accent,
    bool dark,
    bool compact,
    bool reduceMotion,
  ) {
    final full = style == 'full_width';
    final elevated = style == 'elevated';
    final sliding = style == 'sliding';
    final duration = Duration(milliseconds: reduceMotion ? 0 : 300);

    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / 5;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (sliding)
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeInOutCubic,
                left: segmentWidth * selected + (segmentWidth - 42) / 2,
                top: 4,
                width: 42,
                height: 42,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: dark ? .25 : .12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            Row(
              children: List.generate(5, (index) {
                final active = index == selected;
                final isPrimary = elevated && index == 2;
                final filledActive = active &&
                    style != 'minimal' &&
                    style != 'full_width' &&
                    !sliding &&
                    style != 'glow';
                final activeColor = (style == 'minimal' || full || sliding || style == 'glow')
                    ? accent
                    : Colors.white;
                final inactiveColor = dark
                    ? const Color(0xFFD4C9F2)
                    : const Color(0xFF514477);

                return Expanded(
                  child: Semantics(
                    label: labels[index],
                    button: true,
                    selected: active,
                    child: GestureDetector(
                      key: ValueKey('dock-tab-$index'),
                      behavior: HitTestBehavior.opaque,
                      onTap: active
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              onSelected(index);
                            },
                      child: Center(
                        child: AnimatedContainer(
                          duration: duration,
                          curve: Curves.easeInOutCubic,
                          height: 58,
                          margin: EdgeInsets.symmetric(horizontal: full ? 1 : 2, vertical: 1),
                          padding: EdgeInsets.symmetric(
                            horizontal: active && !compact ? 8 : 4,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPrimary
                                ? accent
                                : (filledActive
                                    ? accent
                                    : (active && style == 'glow'
                                        ? accent.withValues(alpha: .16)
                                        : Colors.transparent)),
                            borderRadius: BorderRadius.circular(style == 'rounded_bar' ? 16 : 22),
                            boxShadow: active && style == 'glow'
                                ? [BoxShadow(color: accent.withValues(alpha: .35), blurRadius: 16)]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedScale(
                                    scale: active || isPrimary ? 1.08 : 1,
                                    duration: duration,
                                    child: Icon(
                                      icons[index],
                                      size: isPrimary ? 25 : 22,
                                      color: isPrimary
                                          ? Colors.white
                                          : (active ? activeColor : inactiveColor),
                                    ),
                                  ),
                                  if (index == 0 && unreadCount > 0)
                                    Positioned(
                                      top: -8,
                                      right: -13,
                                      child: PositionedBadge(
                                        value: unreadCount > 99 ? '99+' : '$unreadCount',
                                      ),
                                    ),
                                  if (index == 3 && requestCount > 0)
                                    const Positioned(
                                      top: -5,
                                      right: -8,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Color(0xFFFF5C85),
                                          shape: BoxShape.circle,
                                        ),
                                        child: SizedBox(width: 8, height: 8),
                                      ),
                                    ),
                                ],
                              ),
                              if (!compact) ...[
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: duration,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    height: 1.1,
                                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                    color: active
                                        ? (filledActive ? Colors.white : accent)
                                        : inactiveColor,
                                  ),
                                  child: Text(
                                    labels[index],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (compact && style == 'minimal' && active)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class PositionedBadge extends StatelessWidget {
  const PositionedBadge({super.key, required this.value});
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFE34D73),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF171325)
                : Colors.white,
            width: 1.5,
          ),
        ),
        child: Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
        ),
      );
}
