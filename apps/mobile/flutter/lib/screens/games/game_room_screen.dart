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
      if (widget.randomSessionId == null &&
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
    if (widget.closeChatOnExit) _socket?.closeChat();
    super.dispose();
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )),
            Text(
              widget.randomSessionId == null
                  ? 'Playing with $opponent'
                  : 'Random match · $opponent',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primaryContainer.withValues(alpha: .9),
                          colors.surfaceContainerLow,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: .13),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Icon(
                            Icons.sports_esports_rounded,
                            color: colors.primary,
                            size: 29,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game['state']?.toString() == 'finished'
                                    ? 'Game completed'
                                    : 'Game in progress',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Moves sync live with everyone in this match.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 14),
                  Text(
                    widget.randomSessionId == null
                        ? 'Stay on this screen while you play. Your game result will also be saved in chat.'
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
