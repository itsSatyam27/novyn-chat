import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:novyn/services/haptic_service.dart';

/// Persistent bottom navigation. Its outer footprint stays constant across
/// styles so changing a dock never shifts the page or causes a size jump.
class NovynDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadCount;
  final int requestCount;
  final String style;
  final bool preview;

  const NovynDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.unreadCount = 0,
    this.requestCount = 0,
    this.style = 'floating_pill',
    this.preview = false,
  });

  static const labels = ['Messages', 'Calls', 'Discover', 'Contacts', 'Settings'];
  static const icons = [
    LucideIcons.messageCircle,
    LucideIcons.phone,
    LucideIcons.compass,
    LucideIcons.users,
    LucideIcons.userRound,
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final selected = selectedIndex.clamp(0, 4);
    final full = style == 'full_width';
    final compact = style == 'minimal';
    final glass = style == 'glass';
    final duration = Duration(milliseconds: reduceMotion ? 0 : 320);
    final radius = style == 'rounded_bar' ? 22.0 : (style == 'glow' ? 30.0 : 26.0);
    final scheme = Theme.of(context).colorScheme;
    final background = scheme.surface;

    final dockSurface = SizedBox(
      key: const ValueKey('novyn-dock-shell'),
      height: 96,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedPadding(
          duration: duration,
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.fromLTRB(
            full ? 0 : 14,
            0,
            full ? 0 : 14,
            full ? 0 : 14,
          ),
          child: SizedBox(
            height: 82,
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeInOutCubic,
                width: double.infinity,
                height: full || compact ? 72 : 82,
                padding: EdgeInsets.symmetric(
                  horizontal: full ? 4 : 8,
                  // Compact and edge-to-edge styles need extra vertical room:
                  // the tab's 58px body plus its vertical margins is 60px.
                  vertical: full || compact ? 4 : 7,
                ),
                decoration: BoxDecoration(
                  color: style == 'minimal'
                      ? background.withValues(alpha: dark ? .78 : .86)
                      : (glass ? background.withValues(alpha: .88) : background),
                  borderRadius: BorderRadius.circular(full ? 0 : radius),
                  border: style == 'minimal' || full
                      ? null
                      : Border.all(
                          color: accent.withValues(alpha: dark ? .22 : .16),
                        ),
                  boxShadow: style == 'minimal' || full
                      ? null
                      : [
                          BoxShadow(
                            color: style == 'glow'
                                ? accent.withValues(alpha: dark ? .30 : .24)
                                : (dark
                                    ? Colors.black.withValues(alpha: .28)
                                    : accent.withValues(alpha: .09)),
                            blurRadius: style == 'glow' ? 30 : (glass ? 26 : 20),
                            offset: const Offset(0, 8),
                            spreadRadius: style == 'glow' ? 3 : 0,
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(full ? 0 : radius),
                  child: glass
                      ? BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                          child: _items(
                            context, selected, accent, dark, compact, reduceMotion,
                          ),
                        )
                      : _items(
                          context, selected, accent, dark, compact, reduceMotion,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return preview
        ? dockSurface
        : ColoredBox(
            // Paint the system-navigation inset too; transparent dock styles
            // must never expose a few pixels of the page beneath the dock.
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(top: false, child: dockSurface),
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
                top: 13,
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
                // Elevated style follows the selected tab; the Discover tab must
                // not remain highlighted just because it occupies the center slot.
                final isPrimary = elevated && active;
                final filledActive = active &&
                    style != 'minimal' &&
                    style != 'full_width' &&
                    !sliding &&
                    style != 'glow';
                final activeColor = (style == 'minimal' || full || sliding || style == 'glow')
                    ? accent
                    : Colors.white;
                final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

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
                              HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.navigation);
                              onSelected(index);
                            },
                      child: Center(
                        child: AnimatedContainer(
                          duration: duration,
                          curve: Curves.easeInOutCubic,
                          height: 58,
                          width: double.infinity,
                          margin: EdgeInsets.symmetric(horizontal: full ? 1 : 2, vertical: 1),
                          padding: EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isPrimary
                                ? accent
                                : (filledActive
                                    ? accent
                                    : (active && style == 'glow'
                                        ? accent.withValues(alpha: .24)
                                        : Colors.transparent)),
                            borderRadius: BorderRadius.circular(style == 'rounded_bar' ? 16 : 22),
                            boxShadow: active && style == 'glow'
                                ? [
                                    BoxShadow(color: accent.withValues(alpha: dark ? .68 : .58), blurRadius: 30, spreadRadius: 4),
                                    BoxShadow(color: accent.withValues(alpha: dark ? .34 : .28), blurRadius: 12, spreadRadius: 1),
                                  ]
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
                                  if (index == 2 && requestCount > 0)
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
