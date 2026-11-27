import 'package:flutter/material.dart';

@immutable
class NovynFilterChipItem {
  const NovynFilterChipItem({
    required this.value,
    required this.label,
    this.badgeCount,
  });

  final String value;
  final String label;
  final int? badgeCount;
}

/// Shared, horizontally scrollable filter pills used across Novyn screens.
class NovynFilterChips extends StatelessWidget {
  const NovynFilterChips({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 20, 6),
  });

  final List<NovynFilterChipItem> items;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = colors.primary;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      // 42dp pill + the screen-specific vertical list padding.
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = item.value == selectedValue;
          final count = item.badgeCount ?? 0;
          final showBadge = count > 0;
          final foreground = selected
              ? colors.onPrimary
              : colors.onSurfaceVariant;

          final badgeBackground = selected ? colors.onPrimary : accent;
          final badgeForeground = selected ? accent : colors.onPrimary;

          return Semantics(
            button: true,
            selected: selected,
            label: showBadge ? '${item.label}, $count' : item.label,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onSelected(item.value),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 190),
                    curve: Curves.easeOutCubic,
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? accent
                          : (isDark
                              ? colors.surface.withValues(alpha: 0.18)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? accent
                            : accent.withValues(alpha: isDark ? 0.30 : 0.22),
                        width: selected ? 1.4 : 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14.5,
                            height: 1,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: foreground,
                          ),
                        ),
                        if (showBadge) ...[
                          const SizedBox(width: 7),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: badgeBackground,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11.5,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: badgeForeground,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
