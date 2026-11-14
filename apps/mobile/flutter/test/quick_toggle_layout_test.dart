import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/profile/widgets/quick_toggle_layout.dart';

void main() {
  Widget tile(int index) => LayoutBuilder(
        builder: (context, constraints) => Container(
          key: ValueKey('tile-$index'),
          height: 64,
          width: constraints.maxWidth,
        ),
      );

  Future<void> pumpCount(WidgetTester tester, int count) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: QuickToggleAdaptiveLayout(
              children: List<Widget>.generate(count, tile),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Quick toggle adaptive layout', () {
    testWidgets('one selected toggle uses the full row', (tester) async {
      await pumpCount(tester, 1);
      expect(find.byKey(const ValueKey('quick-toggle-row-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-toggle-row-1')), findsNothing);
      expect(tester.getSize(find.byKey(const ValueKey('tile-0'))).width, closeTo(328, 1));
    });

    testWidgets('two selected toggles split into equal columns', (tester) async {
      await pumpCount(tester, 2);
      expect(find.byKey(const ValueKey('quick-toggle-row-0')), findsOneWidget);
      final first = tester.getSize(find.byKey(const ValueKey('tile-0'))).width;
      final second = tester.getSize(find.byKey(const ValueKey('tile-1'))).width;
      expect(first, closeTo(second, 1));
      expect(first, lessThan(200));
    });

    testWidgets('three selected toggles use two small and one full row', (tester) async {
      await pumpCount(tester, 3);
      expect(find.byKey(const ValueKey('quick-toggle-row-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-toggle-row-1')), findsOneWidget);
      final first = tester.getSize(find.byKey(const ValueKey('tile-0'))).width;
      final second = tester.getSize(find.byKey(const ValueKey('tile-1'))).width;
      final third = tester.getSize(find.byKey(const ValueKey('tile-2'))).width;
      expect(first, closeTo(second, 1));
      expect(third, greaterThan(first * 1.8));
      expect(third, closeTo(328, 1));
    });

    testWidgets('four selected toggles use a balanced 2x2 grid', (tester) async {
      await pumpCount(tester, 4);
      expect(find.byKey(const ValueKey('quick-toggle-row-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-toggle-row-1')), findsOneWidget);
      final widths = List<double>.generate(
        4,
        (index) => tester.getSize(find.byKey(ValueKey('tile-$index'))).width,
      );
      expect(widths[0], closeTo(widths[1], 1));
      expect(widths[2], closeTo(widths[3], 1));
      expect(widths[0], closeTo(widths[2], 1));
    });

    testWidgets('empty selection renders no toggle rows', (tester) async {
      await pumpCount(tester, 0);
      expect(find.byKey(const ValueKey('quick-toggle-layout')), findsNothing);
    });
  });
}
