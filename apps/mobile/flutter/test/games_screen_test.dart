import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/screens/games/games_screen.dart';
import 'package:novyn/services/auth_service.dart';
import 'package:novyn/services/friend_service.dart';
import 'package:novyn/services/socket_service.dart';

class _TestAuthService extends ChangeNotifier implements AuthService {
  @override
  NovynUser? get user => const NovynUser(
        username: 'tester',
        displayName: 'Tester',
        email: 'tester@example.test',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Games hub shows the two MVP games, stranger matchmaking, and friend invites',
      (tester) async {
    final socket = SocketService();
    final friends = FriendService(socket);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: _TestAuthService()),
          Provider<FriendService>.value(value: friends),
          ChangeNotifierProvider<SocketService>.value(value: socket),
        ],
        child: const MaterialApp(home: GamesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Tic-Tac-Toe'), findsOneWidget);
    expect(find.text('Rock Paper Scissors'), findsOneWidget);
    expect(find.text('Play with Random'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('Invite a friend'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Invite a friend'), findsOneWidget);
    expect(find.text('No friends to invite yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
