import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Floating, theme-aware bottom navigation used across the mobile app.
class NovynDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadCount;
  final int requestCount;

  const NovynDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.unreadCount = 0,
    this.requestCount = 0,
  });

  static const _labels = ['Messages', 'Calls', 'Discover', 'Contacts', 'Settings'];
  static const _icons = [
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
    final dockFill = dark
        ? const Color(0xE923172F)
        : const Color(0xF7FFFFFF);
    final dockBorder = dark
        ? const Color(0x35C8B8F5)
        : const Color(0xFFDCD4FA);
    final idleIcon = dark
        ? const Color(0xFFD4C9F2)
        : const Color(0xFF514477);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: dockFill,
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: dockBorder),
            boxShadow: [
              BoxShadow(
                color: dark
                    ? const Color(0x70000000)
                    : const Color(0x1C5B3C9A),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Keep the total width constant while the active capsule
                  // smoothly expands and the inactive tabs gently contract.
                  final unit = constraints.maxWidth / 5;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_icons.length, (index) {
                      final active = index == selectedIndex;
                      final label = _labels[index];
                      return Semantics(
                        label: label,
                        button: true,
                        selected: active,
                        child: GestureDetector(
                          key: ValueKey('dock-tab-$index'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (index != selectedIndex) {
                              HapticFeedback.selectionClick();
                              onSelected(index);
                            }
                          },
                          child: AnimatedContainer(
                            duration: Duration(
                              milliseconds: reduceMotion ? 0 : 320,
                            ),
                            curve: Curves.easeInOutCubic,
                            width: unit * (active ? 1.75 : .8125),
                            height: 64,
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            padding: EdgeInsets.symmetric(
                              horizontal: active ? 8 : 0,
                            ),
                            decoration: BoxDecoration(
                              gradient: active
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF853CF2),
                                        Color(0xFF7138E8),
                                      ],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(36),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF793CEB)
                                            .withValues(alpha: dark ? .32 : .25),
                                        blurRadius: 20,
                                        offset: const Offset(0, 7),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                AnimatedScale(
                                  scale: active ? 1.04 : 1,
                                  duration: Duration(
                                    milliseconds: reduceMotion ? 0 : 260,
                                  ),
                                  curve: Curves.easeOutBack,
                                  child: Icon(
                                    _icons[index],
                                    size: 23,
                                    color: active ? Colors.white : idleIcon,
                                  ),
                                ),
                                ClipRect(
                                  child: AnimatedSize(
                                    duration: Duration(
                                      milliseconds: reduceMotion ? 0 : 280,
                                    ),
                                    curve: Curves.easeInOutCubic,
                                    alignment: Alignment.centerLeft,
                                    child: active
                                        ? Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: AnimatedOpacity(
                                              opacity: 1,
                                              duration: Duration(
                                                milliseconds:
                                                    reduceMotion ? 0 : 180,
                                              ),
                                              child: Text(
                                                label,
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.clip,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -.2,
                                                ),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                if (index == 0 &&
                                    unreadCount > 0 &&
                                    !active)
                                  _dotBadge(unreadCount > 99
                                      ? '99+'
                                      : '$unreadCount'),
                                if (index == 3 &&
                                    requestCount > 0 &&
                                    !active)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(
                                        left: 3, bottom: 12),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF5C85),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              )
            ),
          ),
        ),
      ),
    );
  }

  Widget _dotBadge(String value) => Container(
        margin: const EdgeInsets.only(left: 3, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE34D73),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
