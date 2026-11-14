import 'package:flutter/material.dart';

/// Adapts Quick Toggles to the selected count:
/// 1 = one full-width tile, 2 = two columns, 3 = two columns + full row,
/// 4 = a balanced 2x2 grid.
class QuickToggleAdaptiveLayout extends StatelessWidget {
  const QuickToggleAdaptiveLayout({
    super.key,
    required this.children,
    this.spacing = 10,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final rowCount = children.length == 1 ? 1 : (children.length + 1) ~/ 2;
    return Column(
      key: const ValueKey('quick-toggle-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List<Widget>.generate(rowCount, (rowIndex) {
        final start = rowIndex * 2;
        final end = (start + 2).clamp(0, children.length).toInt();
        final rowChildren = <Widget>[];
        for (var index = start; index < end; index++) {
          if (rowChildren.isNotEmpty) {
            rowChildren.add(SizedBox(width: spacing));
          }
          rowChildren.add(Expanded(child: children[index]));
        }

        return Padding(
          padding: EdgeInsets.only(top: rowIndex == 0 ? 0 : spacing),
          child: Row(
            key: ValueKey('quick-toggle-row-$rowIndex'),
            children: rowChildren,
          ),
        );
      }),
    );
  }
}
