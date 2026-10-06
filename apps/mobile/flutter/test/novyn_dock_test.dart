import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/novyn_dock.dart';

void main() {
  testWidgets('dock changes selection and stays visible after idle',
      (tester) async {
    var selection = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => Align(
        alignment: Alignment.bottomCenter,
        child: NovynDock(
            selectedIndex: selection,
            unreadCount: 3,
            onSelected: (index) => setState(() => selection = index)),
      ),
    ))));
    final target = find.byKey(const ValueKey('dock-tab-3'));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    await tester.pump();
    final highlight = tester
        .widget<AnimatedSlide>(find.byKey(const ValueKey('dock-highlight')));
    expect(selection, 3);
    expect(highlight.offset.dx, closeTo(3 * 57 / 54, 0.001));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(target.hitTestable(), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
