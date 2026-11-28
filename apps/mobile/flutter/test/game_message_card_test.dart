import 'package:flutter/material.dart';
import 'package:novyn/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/socket_service.dart';
import 'package:novyn/widgets/game_message_card.dart';
import 'package:novyn/screens/games/shared/room/game_room_screen.dart';
import 'package:provider/provider.dart';

class _FakeSocketService extends SocketService {
  String? sentGameType;
  int openChatCalls = 0;
  String? sentMessageId;
  String? sentPeer;
  Map<String, dynamic>? sentMoveData;
  bool? sentToGroup;
  String? sentRandomSessionId;

  @override
  Future<Map<String, dynamic>> moveRandomGame(
    String sessionId,
    Map<String, dynamic> moveData,
  ) async {
    sentRandomSessionId = sessionId;
    sentMoveData = Map<String, dynamic>.from(moveData);
    return <String, dynamic>{'ok': true};
  }

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
  String? randomSessionId,
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
            randomSessionId: randomSessionId,
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

  testWidgets('offline Tic-Tac-Toe shows the shared game-over bottom sheet', (tester) async {
    final socket = _FakeSocketService();
    final game = <String, dynamic>{
      'gameType': 'tictactoe',
      'title': 'Tic-Tac-Toe',
      'createdBy': 'alice',
      'opponent': 'AI Bot',
      'isOfflineBot': true,
      'state': 'finished',
      'winner': 'alice',
      'turn': '',
      'data': <String, dynamic>{
        'board': ['X', 'X', 'X', 'O', 'O', null, null, null, null],
        'playerX': 'alice',
        'playerO': 'AI Bot',
        'winningLine': [0, 1, 2],
        'movesCount': 5,
      },
    };
    await tester.pumpWidget(
      ChangeNotifierProvider<SocketService>.value(
        value: socket,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GameMessageCard(
                messageId: 'bot_finished_test',
                game: game,
                currentUsername: 'alice',
                peerUsername: 'AI Bot',
                compact: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You win!'), findsOneWidget);
    expect(find.text('Great match! Want a rematch?'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('1 : 0')),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Play again'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Close room'), findsOneWidget);

    final playAgainButton = find.widgetWithText(FilledButton, 'Play again');
    await tester.ensureVisible(playAgainButton);
    await tester.pumpAndSettle();
    await tester.tap(playAgainButton);
    await tester.pumpAndSettle();

    expect(game['state'], 'in_progress');
    expect(game['winner'], isNull);
    expect((game['data'] as Map<String, dynamic>)['board'], List<dynamic>.filled(9, null));
    expect(socket.sentMoveData, isNull);
    expect(find.text('Great match! Want a rematch?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline Tic-Tac-Toe opens the result sheet when a bot match finishes', (tester) async {
    final socket = _FakeSocketService();
    final game = <String, dynamic>{
      'gameType': 'tictactoe',
      'title': 'Tic-Tac-Toe',
      'createdBy': 'alice',
      'opponent': 'AI Bot',
      'isOfflineBot': true,
      'state': 'in_progress',
      'winner': null,
      'turn': 'alice',
      'data': <String, dynamic>{
        'board': ['X', 'X', null, 'O', 'O', null, null, null, null],
        'playerX': 'alice',
        'playerO': 'AI Bot',
        'winsX': 0,
        'winsO': 0,
      },
    };
    await tester.pumpWidget(
      ChangeNotifierProvider<SocketService>.value(
        value: socket,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GameMessageCard(
                messageId: 'bot_finish_transition_test',
                game: game,
                currentUsername: 'alice',
                peerUsername: 'AI Bot',
                compact: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tic-tac-toe-cell-2')));
    await tester.pumpAndSettle();

    expect(game['state'], 'finished');
    expect(game['winner'], 'alice');
    expect(find.text('Great match! Want a rematch?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Play again'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Close room'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline Rock Paper Scissors bot move is revealed', (tester) async {
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
                    gameType: 'rps',
                    title: 'Rock Paper Scissors',
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
    expect(find.text('Playing with AI Bot'), findsOneWidget);
    expect(find.text('?'), findsNWidgets(2));

    final rockChoice = find.text('Rock').last;
    await tester.ensureVisible(rockChoice);
    await tester.pumpAndSettle();
    await tester.tap(rockChoice);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1800));

    expect(find.text('?'), findsNothing);
    expect(find.text('Pick your move'), findsNothing);
    expect(socket.openChatCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incoming rematch request updates an open result sheet', (tester) async {
    final socket = _FakeSocketService();
    final game = finishedGame();
    late StateSetter updateGame;

    await tester.pumpWidget(
      ChangeNotifierProvider<SocketService>.value(
        value: socket,
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                updateGame = setState;
                return GameMessageCard(
                  messageId: 'game-message-1',
                  game: game,
                  currentUsername: 'alice',
                  peerUsername: 'bob',
                  compact: false,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Great match! Want a rematch?'), findsOneWidget);
    updateGame(() {
      (game['data'] as Map<String, dynamic>)['rematch'] = {
        'status': 'pending',
        'requestedBy': 'bob',
        'requestedAt': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': DateTime.now().millisecondsSinceEpoch + 15000,
      };
    });
    await tester.pumpAndSettle();

    expect(find.text('Rematch Challenge!'), findsOneWidget);
    expect(find.textContaining('Accept ('), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requester cancels a rematch with the dedicated cancel action', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(gameCardHost(socket));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Play again'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel request'), findsOneWidget);

    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();

    expect(socket.sentMessageId, 'game-message-1');
    expect(socket.sentMoveData, {'action': 'rematch_cancel'});
    expect(find.text('Rematch request cancelled'), findsOneWidget);
  });

  testWidgets('random-match rematch uses the random session socket route', (tester) async {
    final socket = _FakeSocketService();
    await tester.pumpWidget(
      gameCardHost(
        socket,
        gameType: 'rps',
        randomSessionId: 'random-session-1',
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Play again'));
    await tester.pumpAndSettle();

    expect(socket.sentRandomSessionId, 'random-session-1');
    expect(socket.sentMessageId, isNull);
    expect(socket.sentMoveData, {'action': 'rematch_request'});
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