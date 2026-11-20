import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/screens/games/games_screen.dart';
import 'package:novyn/services/auth_service.dart';
import 'package:novyn/services/friend_service.dart';
import 'package:novyn/services/socket_service.dart';

class _TestAuthService extends Fake implements AuthService {
  @override
  NovynUser? get user => const NovynUser(
        username: 'tester',
        displayName: 'Tester',
        email: 'tester@example.test',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Games hub shows the first game and keeps matchmaking unavailable',
      (tester) async {
    final socket = SocketService();
    final friends = FriendService(socket);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: _TestAuthService()),
          Provider<FriendService>.value(value: friends),
          ChangeNotifierProvider<SocketService>.value(value: socket),
        ],
        child: const MaterialApp(home: GamesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Tic Tac Toe'), findsOneWidget);
    expect(find.text('Play online'), findsOneWidget);
    expect(find.text('Random matchmaking is coming soon.'), findsOneWidget);
    expect(find.text('No friends yet'), findsOneWidget);
    expect(find.text('Find friends'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
