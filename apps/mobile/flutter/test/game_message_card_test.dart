import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/socket_service.dart';
import 'package:novyn/widgets/game_message_card.dart';
import 'package:provider/provider.dart';

class _FakeSocketService extends SocketService {
  String? sentGameType;
  String? sentPeer;
  bool? sentToGroup;

  @override
  Future<void> sendGameChallenge(
    String gameType,
    String peerUsername, {
    bool isGroup = false,
  }) async {
    sentGameType = gameType;
    sentPeer = peerUsername;
    sentToGroup = isGroup;
  }
}

Map<String, dynamic> finishedGame() => {
      'gameType': 'tictactoe',
      'title': 'Tic-Tac-Toe',
      'createdBy': 'alice',
      'opponent': 'bob',
      'state': 'finished',
      'turn': '',
      'winner': 'alice',
      'data': {
        'board': ['X', 'X', 'X', 'O', 'O', null, null, null, null],
        'playerX': 'alice',
        'playerO': 'bob',
        'winningLine': [0, 1, 2],
        'movesCount': 5,
      },
    };

Widget gameCardHost(_FakeSocketService socket, {bool isGroup = false}) {
  return ChangeNotifierProvider<SocketService>.value(
    value: socket,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GameMessageCard(
            messageId: 'game-message-1',
            game: finishedGame(),
            currentUsername: 'alice',
            peerUsername: isGroup ? 'group-123' : 'bob',
            isGroup: isGroup,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Tic-Tac-Toe highlights all server-reported winning cells', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket));

    final scheme = Theme.of(tester.element(find.byType(GameMessageCard))).colorScheme;
    for (final index in [0, 1, 2]) {
      final cell = tester.widget<Container>(
        find.byKey(ValueKey('tic-tac-toe-cell-$index')),
      );
      expect((cell.decoration as BoxDecoration).color, scheme.primaryContainer);
    }

    final ordinaryCell = tester.widget<Container>(
      find.byKey(const ValueKey('tic-tac-toe-cell-3')),
    );
    expect(
      (ordinaryCell.decoration as BoxDecoration).color,
      scheme.surfaceContainerHighest,
    );
  });

  testWidgets('Play again sends a new server-backed Tic-Tac-Toe challenge', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket));

    await tester.tap(find.text('Play again'));
    await tester.pump();

    expect(socket.sentGameType, 'tictactoe');
    expect(socket.sentPeer, 'bob');
    expect(socket.sentToGroup, false);
  });

  testWidgets('group rematch targets the existing group conversation', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket, isGroup: true));

    await tester.tap(find.text('Play again'));
    await tester.pump();

    expect(socket.sentGameType, 'tictactoe');
    expect(socket.sentPeer, 'group-123');
    expect(socket.sentToGroup, true);
  });
}
