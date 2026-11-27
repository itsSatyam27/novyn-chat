import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/novyn_filter_chips.dart';

void main() => registerNovynFilterChipTests();

void registerNovynFilterChipTests() {
  testWidgets('renders the shared pill style and unread count badge',
      (tester) async {
    var selected = 'all';

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6D4CF5),
          ),
        ),
        home: Scaffold(
          body: NovynFilterChips(
            items: const [
              NovynFilterChipItem(value: 'all', label: 'All'),
              NovynFilterChipItem(
                value: 'unread',
                label: 'Unread',
                badgeCount: 3,
              ),
            ],
            selectedValue: selected,
            onSelected: (value) => selected = value,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();

    expect(selected, 'unread');
  });

  testWidgets('does not show an empty count badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NovynFilterChips(
            items: [
              NovynFilterChipItem(
                value: 'missed',
                label: 'Missed',
                badgeCount: 0,
              ),
            ],
            selectedValue: 'missed',
            onSelected: _ignoreSelection,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );

    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}

void _ignoreSelection(String value) {}
