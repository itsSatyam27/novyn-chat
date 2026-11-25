
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/widgets/novyn_empty_state.dart';

void main() {
  const accent = Color(0xFF008577);

  testWidgets('generic empty-state icons use the active theme accent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(primary: accent),
        ),
        home: const Scaffold(
          body: NovynEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Nothing here',
            description: 'Try again later.',
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.search_off_rounded));
    expect(icon.color, accent);
  });

  testWidgets('people-group illustration badge follows the active accent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(primary: accent),
        ),
        home: const Scaffold(
          body: Center(
            child: NovynEmptyIllustrations.peopleGroupPlus(),
          ),
        ),
      ),
    );

    final add = tester.widget<Icon>(find.byIcon(Icons.add_rounded));
    expect(add.color, accent);
  });

  testWidgets('speech-bubble illustration can be built with a custom accent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(primary: accent),
        ),
        home: const Scaffold(
          body: Center(
            child: NovynEmptyIllustrations.speechBubblesCheck(),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
