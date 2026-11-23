import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_models.dart';
import '../../services/socket_service.dart';
import '../../widgets/game_message_card.dart';

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
  }) {
    final account = currentUsername.trim();
    if (account.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to start a practice game.')),
      );
      return;
    }

    final initialGame = <String, dynamic>{
      'gameType': gameType,
      'title': title,
      'state': 'in_progress',
      'createdBy': account,
      'turn': account,
      'isOfflineBot': true,
      'data': gameType == 'tictactoe'
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
        ),
      ),
    );
  }

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  SocketService? _socket;

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
    if (widget.initialGame['isOfflineBot'] == true ||
        widget.peerUsername == 'AI Bot') {
      return;
    }
    final s = _socket;
    if (s == null || !s.isConnected) return;
    final rId = widget.randomSessionId;
    if (rId != null && rId.isNotEmpty) {
      s.moveRandomGame(rId, const {'action': 'leave_room'});
      return;
    }
    final mId = widget.messageId;
    if (mId != null && mId.isNotEmpty && widget.peerUsername.isNotEmpty) {
      s.makeGameMove(mId, widget.peerUsername, const {'action': 'leave_room'}, isGroup: widget.isGroup);
    }
  }

  String _gameTitle(Map<String, dynamic> game) {
    final title = game['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
    const names = <String, String>{
      'tictactoe': 'Tic-Tac-Toe',
      'rps': 'Rock Paper Scissors',
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
    final title = _gameTitle(game ?? widget.initialGame);
    final opponent = widget.opponentDisplayName?.trim().isNotEmpty == true
        ? widget.opponentDisplayName!
        : (game?['opponent']?.toString() ?? widget.peerUsername);

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF282046) : const Color(0xFFEEE9FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5E44F3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Live',
                      style: TextStyle(
                        color: Color(0xFF5E44F3),
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
    );
  }
}
