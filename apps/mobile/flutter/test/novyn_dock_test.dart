import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/novyn_dock.dart';

void main() {
  const styles = [
    'floating_pill',
    'rounded_bar',
    'minimal',
    'glass',
    'sliding',
    'elevated',
    'full_width',
    'glow',
  ];

  testWidgets('dock keeps a stable footprint across all styles',
      (tester) async {
    var selectedStyle = styles.first;
    await tester.view.setPhysicalSize(const Size(390, 844));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: StatefulBuilder(
          builder: (context, setState) => NovynDock(
            selectedIndex: 0,
            onSelected: (_) {},
            style: selectedStyle,
          ),
        ),
      ),
    ));

    final shell = find.byKey(const ValueKey('novyn-dock-shell'));
    expect(tester.getSize(shell).height, 96);

    for (final style in styles.skip(1)) {
      selectedStyle = style;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: NovynDock(
            selectedIndex: 0,
            onSelected: (_) {},
            style: selectedStyle,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.getSize(shell).height, 96, reason: style);
      expect(tester.takeException(), isNull, reason: style);
    }
  });

  testWidgets('dock tabs remain tappable and badges stay visible',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: StatefulBuilder(
          builder: (context, setState) => NovynDock(
            selectedIndex: selected,
            unreadCount: 3,
            requestCount: 1,
            onSelected: (index) => setState(() => selected = index),
            style: 'sliding',
          ),
        ),
      ),
    ));

    final contacts = find.byKey(const ValueKey('dock-tab-3'));
    expect(contacts, findsOneWidget);
    await tester.tap(contacts);
    await tester.pumpAndSettle();
    expect(selected, 3);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
