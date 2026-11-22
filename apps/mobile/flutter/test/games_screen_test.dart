import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/games/games_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Games hub shows only Tic-Tac-Toe and Rock Paper Scissors', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: GamesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Tic-Tac-Toe'), findsOneWidget);
    expect(find.text('Rock Paper Scissors'), findsOneWidget);
    expect(find.text('Quick strategy'), findsOneWidget);
    expect(find.text('Fast showdown'), findsOneWidget);
    expect(find.text('Connect 4'), findsNothing);
    expect(find.text('Doodle Duel'), findsNothing);
    expect(find.text('Number Clash'), findsNothing);
    expect(find.text('Up or Down'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('last played marker is limited to the two available games', (tester) async {
    SharedPreferences.setMockInitialValues({'games_last_played_v1': 'rps'});
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: GamesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Last played'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
