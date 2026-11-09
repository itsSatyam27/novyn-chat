import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    LucideIcons.messageSquare,
    LucideIcons.phone,
    LucideIcons.compass,
    LucideIcons.users,
    LucideIcons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = Duration(milliseconds: reduceMotion ? 0 : 220);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: dark ? const Color(0xEB18142C) : const Color(0xF2FFFFFF),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: dark ? const Color(0x24FFFFFF) : const Color(0xFFE8E4F4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .34 : .12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Row(
                children: List.generate(_icons.length, (index) {
                  final active = index == selectedIndex;
                  final label = _labels[index];
                  final width = active ? 118.0 : null;
                  return Expanded(
                    flex: active ? 2 : 1,
                    child: Semantics(
                      label: label,
                      button: true,
                      selected: active,
                      child: GestureDetector(
                        key: ValueKey('dock-tab-$index'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelected(index),
                        child: Center(
                          child: AnimatedContainer(
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            width: width,
                            height: 46,
                            padding: EdgeInsets.symmetric(
                              horizontal: active ? 14 : 0,
                            ),
                            decoration: BoxDecoration(
                              gradient: active
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFA173FF),
                                        Color(0xFF7A3EF0),
                                      ],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF8F5BFF)
                                            .withValues(alpha: .32),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _icons[index],
                                  size: 20,
                                  color: active
                                      ? Colors.white
                                      : (dark
                                          ? const Color(0xFFB9B2D6)
                                          : const Color(0xFF77718E)),
                                ),
                                if (active) ...[
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                if (index == 0 && unreadCount > 0 && !active)
                                  _dotBadge(unreadCount > 99 ? '99+' : '$unreadCount'),
                                if (index == 3 && requestCount > 0 && !active)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(left: 3, bottom: 12),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF5C85),
                                      shape: BoxShape.circle,
                                    ),
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
