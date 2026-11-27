import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/novyn_dock.dart';
import 'widgets/novyn_filter_chips_test.dart' as filter_chip_tests;

void _ignoreDockSelection(int _) {}

void main() {
  filter_chip_tests.registerNovynFilterChipTests();
  const styles = [
    'slide_pill',
    'expand_capsule',
    'edge_to_edge',
    'dot_minimal',
    'soft_glow_glass',
    'liquid_stretch',
    'flip_tiles',
    'draw_ring',
  ];

  testWidgets('dock keeps a stable footprint across all styles',
      (tester) async {
    var selectedStyle = styles.first;
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

  testWidgets('update badge appears on Settings avatar when a build is available',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        bottomNavigationBar: NovynDock(
          selectedIndex: 4,
          onSelected: _ignoreDockSelection,
          updateAvailable: true,
          style: 'slide_pill',
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('dock-update-badge')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
            style: 'slide_pill',
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
