import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/presence_dock.dart';

void main() {
  testWidgets(
      'selected status expands into choices and collapses after selection',
      (tester) async {
    String status = 'away';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => Center(
          child: SizedBox(
              width: 280,
              child: PresenceDock(
                status: status,
                onSelected: (mode) => setState(() => status = mode),
              ))),
    ))));
    expect(find.text('Away'), findsOneWidget);
    expect(find.text('Busy'), findsNothing);
    final badgeSize = tester.getSize(find.byType(PresenceDock));
    await tester.tap(find.text('Away'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(4));
    expect(tester.getSize(find.byType(PresenceDock)), badgeSize);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Busy'));
    await tester.pumpAndSettle();
    expect(status, 'busy');
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    expect(find.text('Busy'), findsOneWidget);
    await tester.tap(find.text('Busy'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNothing);
  });
}
