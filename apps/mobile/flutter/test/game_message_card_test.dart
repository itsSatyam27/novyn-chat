import 'package:flutter/material.dart';
import 'package:novyn/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/socket_service.dart';
import 'package:novyn/widgets/game_message_card.dart';
import 'package:provider/provider.dart';

class _FakeSocketService extends SocketService {
  String? sentGameType;
  String? sentPeer;
  bool? sentToGroup;

  @override
  Future<String> sendGameChallenge(
    String gameType,
    String peerUsername, {
    bool isGroup = false,
  }) async {
    sentGameType = gameType;
    sentPeer = peerUsername;
    sentToGroup = isGroup;
    return 'new-game-message';
  }

  @override
  Future<List<Message>> openChat(
    String peerUsername,
    List<Message> cachedHistory, {
    bool isGroup = false,
  }) async {
    return <Message>[
      Message(
        id: 'new-game-message',
        text: 'Started a new game',
        isFromMe: true,
        game: <String, dynamic>{
          'gameType': 'tictactoe',
          'title': 'Tic-Tac-Toe',
          'createdBy': 'alice',
          'opponent': peerUsername,
          'state': 'in_progress',
          'turn': 'alice',
          'data': <String, dynamic>{
            'board': List<dynamic>.filled(9, null),
            'playerX': 'alice',
          },
        },
      ),
    ];
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

Widget gameCardHost(
  _FakeSocketService socket, {
  bool isGroup = false,
  bool compact = false,
}) {
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
            compact: compact,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('chat game bubble is a summary and opens a dedicated game room', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket, compact: true));

    expect(find.text('Open'), findsOneWidget);
    expect(find.byKey(const ValueKey('tic-tac-toe-cell-0')), findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Playing with bob'), findsOneWidget);
    expect(find.byKey(const ValueKey('tic-tac-toe-cell-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tic-Tac-Toe highlights all server-reported winning cells', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket));

    final scheme = Theme.of(tester.element(find.byType(GameMessageCard))).colorScheme;
    for (final index in [0, 1, 2]) {
      final cell = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('tic-tac-toe-cell-$index')),
      );
      final gradient = (cell.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors.first, scheme.primaryContainer);
    }

    final ordinaryCell = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('tic-tac-toe-cell-3')),
    );
    expect(
      ((ordinaryCell.decoration as BoxDecoration).gradient as LinearGradient).colors.first,
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
