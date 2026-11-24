import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/games/raja_mantri_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpMatch(WidgetTester tester, {required int playerCount}) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RajaMantriScreen(
          currentUsername: 'tester',
          customOpponents: List<String>.generate(
            playerCount - 1,
            (index) => 'Bot ${index + 1}',
          ),
          playerCount: playerCount,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('three-player Raja Mantri mode builds exactly three player cards', (tester) async {
    await pumpMatch(tester, playerCount: 3);

    expect(find.text('Round 1/5'), findsOneWidget);
    expect(find.text('Bot 1'), findsOneWidget);
    expect(find.text('Bot 2'), findsOneWidget);
    expect(find.text('Bot 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('four-player Raja Mantri mode keeps the classic four roles roster', (tester) async {
    await pumpMatch(tester, playerCount: 4);

    expect(find.text('Round 1/5'), findsOneWidget);
    expect(find.text('Bot 1'), findsOneWidget);
    expect(find.text('Bot 2'), findsOneWidget);
    expect(find.text('Bot 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
