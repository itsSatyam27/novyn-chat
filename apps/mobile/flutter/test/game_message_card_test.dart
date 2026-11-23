import 'package:flutter/material.dart';
import 'package:novyn/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/socket_service.dart';
import 'package:novyn/widgets/game_message_card.dart';
import 'package:novyn/screens/games/game_room_screen.dart';
import 'package:provider/provider.dart';

class _FakeSocketService extends SocketService {
  String? sentGameType;
  int openChatCalls = 0;
  String? sentMessageId;
  String? sentPeer;
  Map<String, dynamic>? sentMoveData;
  bool? sentToGroup;

  @override
  Future<Map<String, dynamic>> makeGameMove(
    String messageId,
    String peerUsername,
    Map<String, dynamic> moveData, {
    bool isGroup = false,
  }) async {
    sentMessageId = messageId;
    sentPeer = peerUsername;
    sentMoveData = Map<String, dynamic>.from(moveData);
    sentToGroup = isGroup;
    return <String, dynamic>{'ok': true};
  }

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
    openChatCalls++;
    return <Message>[
      Message(
        id: 'new-game-message',
        text: 'Started a new game',
        isFromMe: true,
        game: <String, dynamic>{
          'gameType': sentGameType ?? 'tictactoe',
          'title': sentGameType == 'rps' ? 'Rock Paper Scissors' : 'Tic-Tac-Toe',
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

Map<String, dynamic> finishedGame({String gameType = 'tictactoe'}) => {
      'gameType': gameType,
      'title': gameType == 'rps' ? 'Rock Paper Scissors' : 'Tic-Tac-Toe',
      'createdBy': 'alice',
      'opponent': 'bob',
      'state': 'finished',
      'turn': '',
      'winner': 'alice',
      'data': gameType == 'rps'
          ? {
              'player1': 'alice',
              'player2': 'bob',
              'p1Move': 'rock',
              'p2Move': 'scissors',
            }
          : {
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
  String gameType = 'tictactoe',
}) {
  return ChangeNotifierProvider<SocketService>.value(
    value: socket,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GameMessageCard(
            messageId: 'game-message-1',
            game: finishedGame(gameType: gameType),
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

    expect(find.text('Details'), findsOneWidget);
    expect(find.bySemanticsLabel('Empty cell'), findsNothing);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('Playing with bob'), findsOneWidget);
    expect(find.byKey(const ValueKey('tic-tac-toe-cell-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tic-Tac-Toe marks all server-reported winning cells', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket));

    for (final index in [0, 1, 2, 3, 4]) {
      expect(find.byKey(ValueKey('tic-tac-toe-cell-$index')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tic-Tac-Toe rematch uses the existing match conversation', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket));
    await tester.pumpAndSettle();

    final playAgain = find.widgetWithText(FilledButton, 'Play again');
    expect(playAgain, findsOneWidget);
    await tester.tap(playAgain);
    await tester.pumpAndSettle();

    expect(socket.sentMessageId, 'game-message-1');
    expect(socket.sentMoveData, {'action': 'rematch_request'});
    expect(socket.sentPeer, 'bob');
    expect(socket.sentToGroup, false);
  });

  testWidgets('group rematch targets the existing group conversation', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket, isGroup: true));
    await tester.pumpAndSettle();

    final playAgain = find.widgetWithText(FilledButton, 'Play again');
    expect(playAgain, findsOneWidget);
    await tester.tap(playAgain);
    await tester.pumpAndSettle();

    expect(socket.sentMessageId, 'game-message-1');
    expect(socket.sentMoveData, {'action': 'rematch_request'});
    expect(socket.sentPeer, 'group-123');
    expect(socket.sentToGroup, true);
  });

  testWidgets('Play vs Bot opens the correct local Tic-Tac-Toe board', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(
      ChangeNotifierProvider<SocketService>.value(
        value: socket,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => GameRoomScreen.openOfflineBotMatch(
                    context: context,
                    currentUsername: 'alice',
                    gameType: 'tictactoe',
                    title: 'Tic-Tac-Toe',
                  ),
                  child: const Text('Play vs Bot'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Play vs Bot'));
    await tester.pumpAndSettle();

    expect(find.text('Tic-Tac-Toe'), findsOneWidget);
    expect(find.text('Playing with AI Bot'), findsOneWidget);
    expect(find.byKey(const ValueKey('tic-tac-toe-cell-0')), findsOneWidget);
    expect(socket.openChatCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline Tic-Tac-Toe bot replies and its move stays visible', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(
      ChangeNotifierProvider<SocketService>.value(
        value: socket,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => GameRoomScreen.openOfflineBotMatch(
                    context: context,
                    currentUsername: 'alice',
                    gameType: 'tictactoe',
                    title: 'Tic-Tac-Toe',
                  ),
                  child: const Text('Play vs Bot'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Play vs Bot'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tic-tac-toe-cell-0')));
    await tester.pump();
    expect(find.text('AI Bot is thinking…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tic-tac-toe-cell-0')),
        matching: find.text('X'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tic-tac-toe-cell-4')),
        matching: find.text('O'),
      ),
      findsOneWidget,
    );
    expect(find.text('Your move'), findsOneWidget);
    expect(socket.openChatCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rock Paper Scissors rematch uses the existing match', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket, gameType: 'rps'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final playAgain = find.widgetWithText(FilledButton, 'Play again');
    expect(playAgain, findsOneWidget);
    await tester.tap(playAgain);
    await tester.pumpAndSettle();

    expect(socket.sentMessageId, 'game-message-1');
    expect(socket.sentMoveData, {'action': 'rematch_request'});
    expect(socket.sentPeer, 'bob');
    expect(socket.sentToGroup, false);
  });
}
