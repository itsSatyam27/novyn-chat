import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/chat_models.dart';
import '../../../../services/chess_engine.dart';
import '../../../../services/socket_service.dart';
import '../../../../widgets/game_message_card.dart';
import '../../chess/chess_game_screen.dart';

String resolveGameRoomStatusLabel({
  required bool isFinished,
  required bool isOfflineBot,
  required bool isConnected,
}) {
  if (isFinished) return 'Finished';
  if (isOfflineBot) return 'Practice';
  return isConnected ? 'Live' : 'Offline';
}

class GameRoomScreen extends StatefulWidget {
  const GameRoomScreen({
    super.key,
    required this.currentUsername,
    required this.initialGame,
    this.messageId,
    this.peerUsername = '',
    this.randomSessionId,
    this.opponentDisplayName,
    this.isGroup = false,
    this.closeChatOnExit = false,
  });

  final String currentUsername;
  final Map<String, dynamic> initialGame;
  final String? messageId;
  final String peerUsername;
  final String? randomSessionId;
  final String? opponentDisplayName;
  final bool isGroup;
  final bool closeChatOnExit;

  static void openOfflineBotMatch({
    required BuildContext context,
    required String currentUsername,
    required String gameType,
    required String title,
    String botDifficulty = 'medium',
  }) {
    final account = currentUsername.trim();
    if (account.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to start a practice game.')),
      );
      return;
    }

    final isChess = gameType == 'chess';
    final initialGame = <String, dynamic>{
      'gameType': gameType,
      'title': title,
      'state': 'in_progress',
      'createdBy': account,
      'turn': account,
      'isOfflineBot': true,
      'botDifficulty': botDifficulty,
      'data': isChess
          ? <String, dynamic>{
              'white': account,
              'black': 'novyn_chess_bot',
              'whiteName': account,
              'blackName': 'Chess Bot',
              'player1': account,
              'player2': 'novyn_chess_bot',
              'fen': ChessEngine.startFen,
              'legalMoves': ChessEngine.legalMoves(ChessEngine.startFen),
              'moves': <String>[],
              'lastMove': '',
              'lastMoveAt': 0,
              'whiteTimeMs': 300000,
              'blackTimeMs': 300000,
              'check': false,
              'canClaimDraw': false,
            }
          : gameType == 'tictactoe'
          ? <String, dynamic>{
              'playerX': account,
              'playerO': 'AI Bot',
              'board': List<dynamic>.filled(9, null),
              'winsX': 0,
              'winsO': 0,
            }
          : <String, dynamic>{
              'player1': account,
              'player2': 'AI Bot',
              'round': 1,
              'target': 3,
              'p1Score': 0,
              'p2Score': 0,
              'p1Move': null,
              'p2Move': null,
            },
    };

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameRoomScreen(
          messageId: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          peerUsername: 'AI Bot',
          currentUsername: account,
          initialGame: initialGame,
          opponentDisplayName: isChess ? 'Chess Bot' : null,
        ),
      ),
    );
  }

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  SocketService? _socket;
  bool _leaving = false;
  bool _leftRoom = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _socket = context.read<SocketService>();
      if (widget.initialGame['isOfflineBot'] != true &&
          widget.peerUsername != 'AI Bot' &&
          widget.randomSessionId == null &&
          widget.peerUsername.trim().isNotEmpty &&
          _socket!.currentChatWith?.toLowerCase() !=
              widget.peerUsername.toLowerCase()) {
        _socket!.openChat(
          widget.peerUsername,
          const <Message>[],
          isGroup: widget.isGroup,
        );
      }
    });
  }

  @override
  void dispose() {
    _notifyLeaveRoom();
    if (widget.closeChatOnExit) _socket?.closeChat();
    super.dispose();
  }

  void _notifyLeaveRoom() {
    if (_leftRoom || widget.initialGame['isOfflineBot'] == true ||
        widget.peerUsername == 'AI Bot') {
      return;
    }
    final s = _socket;
    if (s == null || !s.isConnected) return;
    final rId = widget.randomSessionId;
    if (rId != null && rId.isNotEmpty) {
      unawaited(
        s.moveRandomGame(rId, const {'action': 'leave_room'})
            .then<void>((_) {}, onError: (_) {}),
      );
      return;
    }
    final mId = widget.messageId;
    if (mId != null && mId.isNotEmpty && widget.peerUsername.isNotEmpty) {
      unawaited(
        s.makeGameMove(
          mId,
          widget.peerUsername,
          const {'action': 'leave_room'},
          isGroup: widget.isGroup,
        ).then<void>((_) {}, onError: (_) {}),
      );
    }
  }

  Future<void> _confirmAndLeave() async {
    if (_leaving || _leftRoom) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Leave match?'),
            content: const Text('Leaving now will end the match and award the win to the other player.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Leave match'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _leaving = true);
    try {
      final socket = _socket ?? context.read<SocketService>();
      final current = _currentGame(socket) ?? widget.initialGame;
      if (current['state']?.toString() != 'finished') {
        final randomId = widget.randomSessionId;
        if (randomId != null && randomId.isNotEmpty) {
          await socket.moveRandomGame(randomId, const {'action': 'leave_room'});
        } else {
          final messageId = widget.messageId;
          if (messageId == null || messageId.isEmpty || widget.peerUsername.isEmpty) {
            throw StateError('This game room cannot be forfeited right now.');
          }
          await socket.makeGameMove(
            messageId,
            widget.peerUsername,
            const {'action': 'leave_room'},
            isGroup: widget.isGroup,
          );
        }
      }
      _leftRoom = true;
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _leaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Could not leave the match. Check your connection and retry.',
            ),
          ),
        );
      }
    }
  }

  String _gameTitle(Map<String, dynamic> game) {
    final title = game['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
    const names = <String, String>{
      'tictactoe': 'Tic-Tac-Toe',
      'rps': 'Rock Paper Scissors',
      'rajamantri': 'Raja Mantri',
    };
    return names[game['gameType']?.toString()] ?? 'Novyn Game';
  }

  Map<String, dynamic>? _currentGame(SocketService socket) {
    final randomSessionId = widget.randomSessionId;
    if (randomSessionId != null) {
      return socket.randomGameFor(randomSessionId) ?? widget.initialGame;
    }
    final messageId = widget.messageId;
    if (messageId == null) return widget.initialGame;
    for (final message in socket.messages) {
      if (message.id == messageId && message.game != null) {
        return Map<String, dynamic>.from(message.game!);
      }
    }
    return widget.initialGame.isEmpty ? null : widget.initialGame;
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final game = _currentGame(socket);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = colors.primary;
    final title = _gameTitle(game ?? widget.initialGame);
    final opponentCandidate = widget.opponentDisplayName?.trim().isNotEmpty == true
        ? widget.opponentDisplayName!.trim()
        : (game?['opponent']?.toString().trim() ?? widget.peerUsername.trim());
    final opponent = opponentCandidate.isNotEmpty
        ? opponentCandidate
        : (widget.randomSessionId != null ? 'Opponent' : 'Player');
    final isOfflineBot = game?['isOfflineBot'] == true ||
        widget.initialGame['isOfflineBot'] == true;
    final isFinished = game?['state']?.toString() == 'finished';
    final statusLabel = resolveGameRoomStatusLabel(
      isFinished: isFinished,
      isOfflineBot: isOfflineBot,
      isConnected: socket.isConnected,
    );
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = isFinished
        ? const Color(0xFF16834A)
        : isOfflineBot || socket.isConnected
            ? accent
            : colors.onSurfaceVariant;

    if ((game ?? widget.initialGame)['gameType']?.toString() == 'chess') {
      return ChessGameScreen(
        currentUsername: widget.currentUsername,
        initialGame: game ?? widget.initialGame,
        messageId: widget.messageId,
        peerUsername: widget.peerUsername,
        randomSessionId: widget.randomSessionId,
        opponentDisplayName: widget.opponentDisplayName,
        isOfflineBot: isOfflineBot,
      );
    }

    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmAndLeave();
      },
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
      appBar: AppBar(
        titleSpacing: 4,
        backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              widget.randomSessionId == null
                  ? 'Playing with $opponent'
                  : 'Random match · $opponent',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Leave match',
            onPressed: _leaving ? null : _confirmAndLeave,
            icon: _leaving
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.exit_to_app_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: game == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Loading game room…'),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  GameMessageCard(
                    messageId: widget.messageId ??
                        'random:${widget.randomSessionId ?? ''}',
                    game: game,
                    currentUsername: widget.currentUsername,
                    peerUsername: widget.peerUsername.isNotEmpty
                        ? widget.peerUsername
                        : opponent,
                    opponentDisplayName: widget.opponentDisplayName,
                    isGroup: widget.isGroup,
                    compact: false,
                    randomSessionId: widget.randomSessionId,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    widget.randomSessionId == null
                        ? 'Stay on this screen while you play. Your result is saved in chat.'
                        : 'Stay on this screen while you play. Your random match is synced live with your opponent.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
      ),
      ),
    );
  }
}
