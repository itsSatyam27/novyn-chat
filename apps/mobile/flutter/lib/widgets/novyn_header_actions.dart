import 'package:flutter/material.dart';

/// Joined search and overflow controls used by the Messages and Buddy headers.
class NovynHeaderActions extends StatelessWidget {
  const NovynHeaderActions({
    super.key,
    required this.searchVisible,
    required this.onSearchTap,
    this.trailingAction,
  });

  final bool searchVisible;
  final VoidCallback onSearchTap;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface
            : accent.withValues(alpha: .085),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 46,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onSearchTap,
                  child: Icon(
                    searchVisible ? Icons.close_rounded : Icons.search_rounded,
                    color: accent,
                    size: 23,
                  ),
                ),
              ),
            ),
            if (trailingAction != null) ...[
              Container(
                width: 1,
                height: 27,
                color: accent.withValues(alpha: isDark ? .28 : .22),
              ),
              SizedBox(
                width: 48,
                height: 46,
                child: trailingAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
