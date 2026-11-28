import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/screens/games/home/games_screen.dart';
import 'package:novyn/screens/games/shared/room/game_room_screen.dart';
import 'package:novyn/screens/games/invitations/game_invitation_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('game invitation expiry guard rejects stale entries safely', () {
    const now = 1_800_000_000_000;
    expect(
      isGameInvitationExpired(
        <String, dynamic>{'expiresAt': now - 1},
        nowMilliseconds: now,
      ),
      isTrue,
    );
    expect(
      isGameInvitationExpired(
        <String, dynamic>{'expiresAt': now + 1},
        nowMilliseconds: now,
      ),
      isFalse,
    );
    expect(
      isGameInvitationExpired(
        <String, dynamic>{},
        nowMilliseconds: now,
      ),
      isFalse,
    );
    expect(
      gameInvitationExpiryTimestamp(
        <String, dynamic>{'expiresAt': '1800000000000'},
      ),
      now,
    );
  });
  test('game room status reflects match and connection state', () {
    expect(
      resolveGameRoomStatusLabel(
        isFinished: true,
        isOfflineBot: true,
        isConnected: false,
      ),
      'Finished',
    );
    expect(
      resolveGameRoomStatusLabel(
        isFinished: false,
        isOfflineBot: true,
        isConnected: false,
      ),
      'Practice',
    );
    expect(
      resolveGameRoomStatusLabel(
        isFinished: false,
        isOfflineBot: false,
        isConnected: false,
      ),
      'Offline',
    );
    expect(
      resolveGameRoomStatusLabel(
        isFinished: false,
        isOfflineBot: false,
        isConnected: true,
      ),
      'Live',
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Games hub lists each game as its own entry point', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: GamesScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Games'), findsOneWidget);
    expect(find.text('2 Player'), findsOneWidget);
    expect(find.text('3 P / 4 P'), findsOneWidget);
    expect(find.text('Tic-Tac-Toe'), findsOneWidget);
    expect(find.text('Rock Paper'), findsOneWidget);
    expect(find.text('Raja Mantri'), findsOneWidget);
    expect(find.text('Connect 4'), findsNothing);
    expect(find.text('Doodle Duel'), findsNothing);
    expect(find.text('Number Clash'), findsNothing);
    expect(find.text('Up or Down'), findsNothing);

    // The profile summary is intentionally collapsed by default.
    expect(find.text('PvP'), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.text('PvP'), findsOneWidget);
    expect(find.text('Wins'), findsOneWidget);
    expect(find.text('Losses'), findsOneWidget);
    // The compact level badge and progress label are the visible XP UI.
    expect(find.text('Lv1'), findsOneWidget);
    expect(find.textContaining('0 / 500 XP'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-streak-tictactoe')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-streak-rps')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-streak-rajamantri')), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsNWidgets(3));
    expect(find.text('Game History'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Game invitations'), findsOneWidget);
    expect(find.text('Match history'), findsOneWidget);
    expect(find.text('Leaderboard'), findsNWidgets(2));
    expect(find.text('Play with Random'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('games hub highlights the last selected featured game', (tester) async {
    SharedPreferences.setMockInitialValues({'games_last_played_v1': 'rps'});
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: GamesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Tic-Tac-Toe'), findsOneWidget);
    expect(find.text('Rock Paper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
