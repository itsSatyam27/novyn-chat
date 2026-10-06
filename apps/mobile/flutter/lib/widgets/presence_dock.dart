import 'package:flutter/material.dart';

class PresenceDock extends StatelessWidget {
  final String status;
  final ValueChanged<String> onSelected;
  final bool busy;
  const PresenceDock(
      {super.key,
      required this.status,
      required this.onSelected,
      this.busy = false});

  static const modes = ['online', 'away', 'busy', 'invisible'];
  static const labels = ['Online', 'Away', 'Busy', 'Invisible'];
  static const colors = [
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF64748B)
  ];

  @override
  Widget build(BuildContext context) {
    final selected = modes.indexOf(status.trim().toLowerCase());
    final current = selected < 0 ? 0 : selected;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String>(
      enabled: !busy,
      tooltip: 'Change status',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: dark ? const Color(0xFF202236) : const Color(0xFFF8FAFF),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 220),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (var index = 0; index < modes.length; index++)
          PopupMenuItem<String>(
            value: modes[index],
            child: Semantics(
                selected: current == index,
                child: Row(children: [
                  _dot(index),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(labels[index],
                          style: TextStyle(
                            fontWeight: current == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: current == index
                                ? colors[index]
                                : (dark ? Colors.white70 : Colors.black87),
                          ))),
                  if (current == index)
                    Icon(Icons.check_rounded, color: colors[index], size: 18),
                ])),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colors[current].withValues(alpha: .1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors[current].withValues(alpha: .18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(current),
          const SizedBox(width: 9),
          Text(labels[current],
              style: TextStyle(
                  color: colors[current], fontWeight: FontWeight.w700)),
          const SizedBox(width: 5),
          Icon(Icons.expand_more_rounded, size: 18, color: colors[current]),
        ]),
      ),
    );
  }

  Widget _dot(int index) => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: colors[index],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: colors[index].withValues(alpha: .3), blurRadius: 7)
        ],
      ));
}
