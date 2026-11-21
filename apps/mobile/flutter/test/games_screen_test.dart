import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/games/games_screen.dart';

void main() {
  testWidgets('Games hub lists each game as its own entry point', (tester) async {
    await tester.view.setPhysicalSize(const Size(900, 1200));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: GamesScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Choose a game'), findsOneWidget);
    expect(find.text('Tic-Tac-Toe'), findsOneWidget);
    expect(find.text('Rock Paper Scissors'), findsOneWidget);
    expect(find.text('Connect 4'), findsOneWidget);
    expect(find.text('Doodle Duel'), findsOneWidget);
    expect(find.text('Number Clash'), findsOneWidget);
    expect(find.text('Up or Down'), findsOneWidget);
    expect(find.text('Play with Random'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
