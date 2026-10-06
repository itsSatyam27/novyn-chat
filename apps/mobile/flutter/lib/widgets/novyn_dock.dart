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

  static const _labels = ['Chats', 'Calls', 'Discover', 'People', 'Settings'];
  static const _icons = [
    LucideIcons.messageSquare,
    LucideIcons.phone,
    LucideIcons.compass,
    LucideIcons.users,
    LucideIcons.settings
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = Duration(milliseconds: reduceMotion ? 0 : 240);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Center(
          child: RepaintBoundary(
            child: Container(
              width: 304,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: dark
                        ? const Color(0x40000000)
                        : const Color(0x184B5E85),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xF011111B)
                          : const Color(0xE6FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: dark ? const Color(0x2BC9C1FF) : Colors.white),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 285,
                          height: 54,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 1.5,
                                top: 0,
                                child: AnimatedSlide(
                                  key: const ValueKey('dock-highlight'),
                                  offset: Offset(selectedIndex * 57 / 54, 0),
                                  duration: duration,
                                  curve: Curves.easeOutCubic,
                                  child: const RepaintBoundary(
                                    child: SizedBox(
                                      width: 54,
                                      height: 54,
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                        color: Color(0xFF6D5DFC),
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(999)),
                                      )),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                  children:
                                      List.generate(_icons.length, (index) {
                                final active = index == selectedIndex;
                                return Semantics(
                                  label: _labels[index],
                                  button: true,
                                  selected: active,
                                  child: GestureDetector(
                                    key: ValueKey('dock-tab-$index'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => onSelected(index),
                                    child: SizedBox(
                                      width: 57,
                                      height: 54,
                                      child: Stack(children: [
                                        Center(
                                            child: AnimatedScale(
                                          scale: active ? 1.05 : 1,
                                          duration: duration,
                                          curve: Curves.easeOutCubic,
                                          child: Icon(_icons[index],
                                              size: 22,
                                              color: active
                                                  ? Colors.white
                                                  : dark
                                                      ? const Color(0xFFEDF8F3)
                                                      : const Color(
                                                          0xFF587985)),
                                        )),
                                        if (index == 0 && unreadCount > 0)
                                          Positioned(
                                              top: 1,
                                              right: 1,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4),
                                                constraints:
                                                    const BoxConstraints(
                                                        minWidth: 16,
                                                        minHeight: 16),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFD94762),
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                ),
                                                child: Text(
                                                    unreadCount > 99
                                                        ? '99+'
                                                        : '$unreadCount',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10)),
                                              )),
                                        if (index == 3 && requestCount > 0)
                                          const Positioned(
                                              top: 3,
                                              right: 5,
                                              child: SizedBox(
                                                  width: 8,
                                                  height: 8,
                                                  child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                          color:
                                                              Color(0xFFD94762),
                                                          shape: BoxShape
                                                              .circle)))),
                                      ]),
                                    ),
                                  ),
                                );
                              })),
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
      ),
    );
  }
}
