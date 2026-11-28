import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/games/achievements/game_achievements_screen.dart';
import 'package:novyn/theme/novyn_theme.dart';

void main() {
  testWidgets('achievements screen follows the active light theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NovynTheme.lightTheme(),
        home: const GameAchievementsScreen(matches: []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Your game milestones'), findsOneWidget);
    expect(find.text('0 of 8 achievements unlocked'), findsOneWidget);
    expect(find.text('Keep going'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('achievements screen follows the active dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NovynTheme.darkTheme(),
        home: const GameAchievementsScreen(matches: []),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF08090D));
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Your game milestones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
