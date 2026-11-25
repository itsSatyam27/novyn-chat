import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'novyn_alert.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../services/game_history_service.dart';
import '../screens/games/shared/room/game_room_screen.dart';
import '../screens/games/raja_mantri/raja_mantri_online_game_screen.dart';

class GameMessageCard extends StatefulWidget {
  final String messageId;
  final Map<String, dynamic> game;
  final String currentUsername;
  final String peerUsername;
  final String? opponentDisplayName;
  final bool isGroup;
  final bool compact;
  final String? randomSessionId;

  const GameMessageCard({
    super.key,
    required this.messageId,
    required this.game,
    required this.currentUsername,
    required this.peerUsername,
    this.opponentDisplayName,
    this.isGroup = false,
    this.compact = true,
    this.randomSessionId,
  });

  @override
  State<GameMessageCard> createState() => _GameMessageCardState();
}

class _GameMessageCardState extends State<GameMessageCard> {
  Map<String, dynamic>? _optimisticData;
  bool _sendingMove = false;
  bool _startingRematch = false;
  bool _recordedFinishedGame = false;

  @override
  void initState() {
    super.initState();
    _recordFinishedGame(widget.game);
  }

  @override
  void didUpdateWidget(covariant GameMessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game['data'] != widget.game['data']) {
      _optimisticData = null;
    }
    if (_recordedFinishedGame &&
        widget.game['state']?.toString() != 'finished') {
      _recordedFinishedGame = false;
    }
    _recordFinishedGame(widget.game);
  }

  void _recordFinishedGame(Map<String, dynamic> game) {
    if (_recordedFinishedGame || game['state']?.toString() != 'finished') return;
    final username = widget.currentUsername.trim();
    final rawUpdatedAt = game['updatedAt'];
    final playedAt = rawUpdatedAt is num
        ? DateTime.fromMillisecondsSinceEpoch(rawUpdatedAt.toInt())
        : DateTime.tryParse(rawUpdatedAt?.toString() ?? '') ?? DateTime.now();
    final baseMatchId = game['id']?.toString().trim().isNotEmpty == true
        ? game['id'].toString()
        : widget.messageId.trim();
    final matchId = rawUpdatedAt == null
        ? baseMatchId
        : '$baseMatchId-${playedAt.microsecondsSinceEpoch}';
    if (username.isEmpty || matchId.isEmpty) return;
    _recordedFinishedGame = true;
    final winner = game['winner']?.toString().trim().toLowerCase() ?? '';
    final result = winner.isEmpty || winner == 'draw'
        ? 'draw'
        : winner == username.toLowerCase()
            ? 'win'
            : 'loss';
    if (_isOfflineBot && rawUpdatedAt == null) {
      game['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    }
    unawaited(GameHistoryService.recordFinishedMatch(
      username: username,
      matchId: matchId,
      gameType: game['gameType']?.toString() ?? 'unknown',
      opponent: widget.peerUsername,
      result: result,
      playedAt: playedAt,
      isBotMatch: _isOfflineBot,
    ));
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _type => widget.game['gameType']?.toString() ?? '';
  String get _title => widget.game['title']?.toString() ?? 'Game';
  String get _creator => widget.game['createdBy']?.toString() ?? '';
  String get _opponent => (_data['player2'] ?? _data['playerO'] ?? widget.game['opponent'])?.toString() ?? (widget.isGroup ? 'Waiting for player' : widget.peerUsername);
  String get _turn => widget.game['turn']?.toString() ?? '';
  String get _state => widget.game['state']?.toString() ?? 'in_progress';
  String get _winner => widget.game['winner']?.toString() ?? '';
  Map<String, dynamic> get _data => _optimisticData ??
      (widget.game['data'] is Map
          ? Map<String, dynamic>.from(widget.game['data'])
          : <String, dynamic>{});
  bool get _myTurn => _turn.toLowerCase() == widget.currentUsername.toLowerCase();
  bool get _finished => _state == 'finished';
  bool get _canJoinGroup => widget.isGroup &&
      _opponent == 'Waiting for player' &&
      widget.currentUsername.toLowerCase() != _creator.toLowerCase();

  bool get _isOfflineBot =>
      widget.peerUsername == 'AI Bot' ||
      widget.messageId.startsWith('bot_') ||
      widget.game['isOfflineBot'] == true;

  Future<bool> _move(Map<String, dynamic> data) async {
    if (_sendingMove || _finished) return false;
    if (_isOfflineBot) {
      _handleOfflineBotMove(data);
      return true;
    }
    final previousData = _optimisticData;
    setState(() {
      _sendingMove = true;
      _optimisticData = _type == 'rps' ? null : Map<String, dynamic>.from(data);
    });
    try {
      final socket = context.read<SocketService>();
      if (widget.randomSessionId != null) {
        await socket.moveRandomGame(widget.randomSessionId!, data);
      } else {
        await socket.makeGameMove(
          widget.messageId,
          widget.peerUsername,
          data,
          isGroup: widget.isGroup,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _optimisticData = previousData);
        NovynAlert.show(
          context,
          error is StateError
              ? error.message.toString()
              : 'Move could not be sent. Check your connection and try again.',
          isError: true,
          title: 'Move not sent',
          icon: Icons.sync_problem_rounded,
          tone: NovynAlertTone.warning,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _sendingMove = false);
    }
    return true;
  }

  void _handleOfflineBotMove(Map<String, dynamic> data) {
    if (_type == 'tictactoe') {
      final board = List<dynamic>.from(data['board'] as List);
      final gData = widget.game['data'] as Map<String, dynamic>;
      gData['board'] = board;

      const winLines = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6]
      ];

      String? checkWinner(List<dynamic> b) {
        for (final line in winLines) {
          final s = b[line[0]];
          if (s != null && s == b[line[1]] && s == b[line[2]]) {
            return s.toString();
          }
        }
        return null;
      }

      final winnerSymbol = checkWinner(board);
      if (winnerSymbol != null) {
        widget.game['state'] = 'finished';
        widget.game['winner'] = widget.currentUsername;
        gData['winsX'] = ((gData['winsX'] as int?) ?? 0) + 1;
        HapticFeedback.heavyImpact();
        setState(() {});
        _recordFinishedGame(widget.game);
        return;
      } else if (!board.contains(null)) {
        widget.game['state'] = 'finished';
        widget.game['winner'] = 'draw';
        setState(() {});
        _recordFinishedGame(widget.game);
        return;
      }

      widget.game['turn'] = 'AI Bot';
      setState(() {});

      Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        final currentBoard = List<dynamic>.from(gData['board'] as List);
        final emptyIndices = <int>[];
        for (int i = 0; i < 9; i++) {
          if (currentBoard[i] == null) emptyIndices.add(i);
        }
        if (emptyIndices.isEmpty) return;

        int chosen = -1;
        for (final idx in emptyIndices) {
          final test = List<dynamic>.from(currentBoard)..[idx] = 'O';
          if (checkWinner(test) == 'O') {
            chosen = idx;
            break;
          }
        }
        if (chosen == -1) {
          for (final idx in emptyIndices) {
            final test = List<dynamic>.from(currentBoard)..[idx] = 'X';
            if (checkWinner(test) == 'X') {
              chosen = idx;
              break;
            }
          }
        }
        if (chosen == -1 && emptyIndices.contains(4)) {
          chosen = 4;
        }
        if (chosen == -1) {
          chosen = emptyIndices[math.Random().nextInt(emptyIndices.length)];
        }

        currentBoard[chosen] = 'O';
        gData['board'] = currentBoard;
        final botWin = checkWinner(currentBoard);
        if (botWin != null) {
          widget.game['state'] = 'finished';
          widget.game['winner'] = 'AI Bot';
          gData['winsO'] = ((gData['winsO'] as int?) ?? 0) + 1;
          HapticFeedback.mediumImpact();
        } else if (!currentBoard.contains(null)) {
          widget.game['state'] = 'finished';
          widget.game['winner'] = 'draw';
        } else {
          widget.game['turn'] = widget.currentUsername;
        }
        setState(() {});
        _recordFinishedGame(widget.game);
      });
    } else if (_type == 'rps') {
      final userMove = data['move']?.toString() ?? 'rock';
      final gData = Map<String, dynamic>.from(
        widget.game['data'] as Map<String, dynamic>,
      );
      gData['p1Move'] = userMove;
      gData['p2Move'] = null;
      gData['roundResolved'] = false;
      widget.game['data'] = gData;
      setState(() {});

      Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        const botChoices = ['rock', 'paper', 'scissors'];
        final botMove = botChoices[math.Random().nextInt(botChoices.length)];
        int p1Score = (gData['p1Score'] as int?) ?? 0;
        int p2Score = (gData['p2Score'] as int?) ?? 0;
        final round = (gData['round'] as int?) ?? 1;
        final target = (gData['target'] as int?) ?? 3;
        String roundWinner = 'draw';

        if (userMove != botMove) {
          if ((userMove == 'rock' && botMove == 'scissors') ||
              (userMove == 'paper' && botMove == 'rock') ||
              (userMove == 'scissors' && botMove == 'paper')) {
            p1Score++;
            roundWinner = widget.currentUsername;
          } else {
            p2Score++;
            roundWinner = 'AI Bot';
          }
        }

        gData['p2Move'] = botMove;
        gData['roundWinner'] = roundWinner;
        gData['p1Score'] = p1Score;
        gData['p2Score'] = p2Score;
        gData['round'] = round + 1;
        gData['roundResolved'] = true;
        gData['roundResolvedAt'] = DateTime.now().millisecondsSinceEpoch;

        if (p1Score >= target) {
          widget.game['state'] = 'finished';
          widget.game['winner'] = widget.currentUsername;
          HapticFeedback.heavyImpact();
        } else if (p2Score >= target) {
          widget.game['state'] = 'finished';
          widget.game['winner'] = 'AI Bot';
          HapticFeedback.mediumImpact();
        }
        widget.game['data'] = Map<String, dynamic>.from(gData);
        setState(() {});
        _recordFinishedGame(widget.game);
      });
    }
  }

  void _resetOfflineGame() {
    final gData = widget.game['data'] as Map<String, dynamic>? ?? {};
    widget.game['id'] = 'bot_${DateTime.now().microsecondsSinceEpoch}';
    widget.game.remove('updatedAt');
    _recordedFinishedGame = false;
    widget.game['state'] = 'in_progress';
    widget.game['winner'] = null;
    widget.game['turn'] = widget.currentUsername;
    gData['rematch'] = null;
    gData['playerLeft'] = null;

    if (_type == 'tictactoe') {
      gData['board'] = List.filled(9, null);
    } else if (_type == 'rps') {
      gData['p1Score'] = 0;
      gData['p2Score'] = 0;
      gData['round'] = 1;
      gData['p1Move'] = null;
      gData['p2Move'] = null;
    }
    setState(() {});
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = _finished
        ? (_winner == 'draw'
            ? 'Draw'
            : _winner.toLowerCase() == widget.currentUsername.toLowerCase()
                ? 'You won'
                : '$_winner won')
        : !_isInviteOwner
            ? 'Game invite · Tap to join'
        : _myTurn
            ? 'Your turn'
            : 'Waiting for opponent';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.sports_esports_rounded, color: colors.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 3),
                Text(
                  status + (_finished ? ' · Completed' : ' · Live game'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _openGameRoom,
            child: Text(_finished ? 'Details' : _isInviteOwner ? 'Open' : 'Join'),
          ),
        ],
      ),
    );
  }

  bool get _isInviteOwner =>
      _creator.toLowerCase() == widget.currentUsername.toLowerCase();

  Future<void> _openGameRoom() async {
    if (!widget.isGroup && !_isInviteOwner && !_finished) {
      try {
        await context.read<SocketService>().acceptGameInvite(widget.messageId);
      } catch (error) {
        if (!mounted) return;
        NovynAlert.show(
          context,
          error is StateError
              ? error.message.toString()
              : 'This game invite could not be accepted. Check your connection and try again.',
          isError: true,
          title: 'Could not join game',
          icon: Icons.sports_esports_rounded,
        );
        return;
      }
    }
    if (!mounted) return;
    if (_type == 'rajamantri' && !widget.isGroup && !_isInviteOwner && !_finished) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RajaMantriInviteWaitingScreen(
            messageId: widget.messageId,
            hostName: widget.opponentDisplayName ?? widget.peerUsername,
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GameRoomScreen(
          messageId: widget.messageId,
          peerUsername: widget.peerUsername,
          currentUsername: widget.currentUsername,
          initialGame: widget.game,
          isGroup: widget.isGroup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildSummary(context);
    if (_type == 'tictactoe') {
      return _TicTacToeMatchPanel(
        game: widget.game,
        currentUsername: widget.currentUsername,
        opponentUsername: widget.peerUsername,
        opponentName: widget.opponentDisplayName ?? widget.peerUsername,
        canJoinGroup: _canJoinGroup,
        sendingMove: _sendingMove,
        startingRematch: _startingRematch,
        isOfflineBot: _isOfflineBot,
        onSendBoard: (board, playerX, playerO) => _move({
          'board': board,
          'playerX': playerX,
          'playerO': playerO,
        }),
        onPlayAgain: _startRematch,
        onRematchAction: _sendRematchAction,
      );
    }
    if (_type == 'rps') {
      return _RockPaperScissorsPanel(
        game: widget.game,
        currentUsername: widget.currentUsername,
        opponentUsername: widget.peerUsername,
        opponentName: widget.opponentDisplayName ?? widget.peerUsername,
        sendingMove: _sendingMove,
        startingRematch: _startingRematch,
        onSendMove: (move) => _move({'move': move}),
        onPlayAgain: _startRematch,
        onRematchAction: _sendRematchAction,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports_rounded, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(_title, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _finished
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _finished ? 'FINISHED' : 'LIVE',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _finished ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _finished
                ? (_winner == 'draw' ? 'It\'s a draw!' : _winner.toLowerCase() == widget.currentUsername.toLowerCase() ? 'You won!' : '$_winner won')
                : _myTurn ? 'Your turn' : _canJoinGroup ? 'Join the game' : 'Waiting for opponent',
            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (_finished && _type != 'rps' &&
              widget.randomSessionId == null &&
              widget.peerUsername.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startingRematch ? null : _startRematch,
                icon: _startingRematch
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.replay_rounded, size: 18),
                label: Text(_startingRematch ? 'Starting rematch…' : 'Play again'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startRematch() async {
    if (_isOfflineBot) {
      _resetOfflineGame();
      return;
    }
    if (_startingRematch) return;
    setState(() => _startingRematch = true);
    try {
      final socket = context.read<SocketService>();
      await socket.makeGameMove(
        widget.messageId,
        widget.peerUsername,
        {'action': 'rematch_accept'},
        isGroup: widget.isGroup,
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _startingRematch = false);
    }
  }

  Future<void> _sendRematchAction(String action) async {
    if (_isOfflineBot) {
      if (action == 'rematch_request' || action == 'rematch_accept') {
        _resetOfflineGame();
      }
      return;
    }
    try {
      final socket = context.read<SocketService>();
      await socket.makeGameMove(
        widget.messageId,
        widget.peerUsername,
        {'action': action},
        isGroup: widget.isGroup,
      );
    } catch (_) {}
  }
}

void _showGameOverModal(
  BuildContext context, {
  required String emoji,
  required String title,
  required String subtitle,
  required String score,
  required Future<void> Function() onPlayAgain,
  required VoidCallback onClose,
  Future<void> Function(String action)? onRematchAction,
  bool isOpponentRequest = false,
  String? playerLeft,
  String? opponentName,
  bool isOfflineBot = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _GameOverModalContent(
        emoji: emoji,
        title: title,
        subtitle: subtitle,
        score: score,
        onPlayAgain: onPlayAgain,
        onClose: onClose,
        onRematchAction: onRematchAction,
        isOpponentRequest: isOpponentRequest,
        playerLeft: playerLeft,
        opponentName: opponentName,
        isOfflineBot: isOfflineBot,
      );
    },
  );
}

class _GameOverModalContent extends StatefulWidget {
  const _GameOverModalContent({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.onPlayAgain,
    required this.onClose,
    this.onRematchAction,
    this.isOpponentRequest = false,
    this.playerLeft,
    this.opponentName,
    this.isOfflineBot = false,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String score;
  final Future<void> Function() onPlayAgain;
  final VoidCallback onClose;
  final Future<void> Function(String action)? onRematchAction;
  final bool isOpponentRequest;
  final String? playerLeft;
  final String? opponentName;
  final bool isOfflineBot;

  @override
  State<_GameOverModalContent> createState() => _GameOverModalContentState();
}

class _GameOverModalContentState extends State<_GameOverModalContent> {
  bool _rematchRequested = false;
  bool _opponentWantsRematch = false;
  int _secondsRemaining = 15;
  Timer? _timer;
  bool _loading = false;
  String? _statusNote;

  @override
  void initState() {
    super.initState();
    if (widget.playerLeft != null && widget.playerLeft!.isNotEmpty) {
      _statusNote = '${widget.opponentName ?? "Player 2"} left the room';
    } else if (widget.isOpponentRequest) {
      _opponentWantsRematch = true;
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _GameOverModalContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerLeft != null && widget.playerLeft != oldWidget.playerLeft) {
      _timer?.cancel();
      setState(() {
        _rematchRequested = false;
        _opponentWantsRematch = false;
        _statusNote = '${widget.opponentName ?? "Player 2"} left the room';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 15;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _rematchRequested = false;
          _opponentWantsRematch = false;
          _statusNote = 'Rematch request timed out';
        });
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _handlePlayAgain() async {
    final opponent = widget.opponentName ?? 'Player 2';
    if (widget.playerLeft != null && widget.playerLeft!.isNotEmpty) {
      setState(() {
        _statusNote = '$opponent left the room';
        _rematchRequested = false;
      });
      return;
    }
    if (widget.isOfflineBot) {
      if (_loading) return;
      setState(() => _loading = true);
      try {
        await widget.onPlayAgain();
        if (mounted) Navigator.of(context).pop();
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }
    setState(() {
      _rematchRequested = true;
      _statusNote = null;
      _loading = false;
    });
    _startTimer();
    if (widget.onRematchAction != null) {
      try {
        await widget.onRematchAction!('rematch_request');
      } catch (err) {
        if (!mounted) return;
        _timer?.cancel();
        setState(() {
          _rematchRequested = false;
          final msg = err.toString();
          if (msg.contains('left the room')) {
            _statusNote = '$opponent left the room';
          } else {
            _statusNote = 'Could not request rematch';
          }
        });
      }
    }
  }

  Future<void> _handleAccept() async {
    _timer?.cancel();
    setState(() => _loading = true);
    try {
      if (widget.onRematchAction != null) {
        // The rematch action already starts the accepted rematch. Calling
        // onPlayAgain as well would send a duplicate rematch_accept event.
        await widget.onRematchAction!('rematch_accept');
      } else {
        await widget.onPlayAgain();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusNote = 'Could not accept rematch. Try again.';
        });
      }
    }
  }

  Future<void> _handleDecline() async {
    _timer?.cancel();
    if (widget.onRematchAction != null) {
      try {
        await widget.onRematchAction!('rematch_decline');
      } catch (_) {}
    }
    setState(() {
      _opponentWantsRematch = false;
      _rematchRequested = false;
      _statusNote = 'Rematch declined';
    });
  }

  void _handleCancelRequest() {
    _timer?.cancel();
    if (widget.onRematchAction != null) {
      try {
        widget.onRematchAction!('rematch_decline');
      } catch (_) {}
    }
    setState(() {
      _rematchRequested = false;
      _statusNote = 'Rematch request cancelled';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _opponentWantsRematch ? '🤝' : (_rematchRequested ? '⏱' : widget.emoji),
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 14),
          Text(
            _opponentWantsRematch
                ? 'Rematch Challenge!'
                : (_rematchRequested ? 'Rematch Requested' : widget.title),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E1A33),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _statusNote ??
                (_opponentWantsRematch
                    ? 'Opponent wants to play again! Accept within 15s'
                    : (_rematchRequested
                        ? 'Waiting for opponent to accept...'
                        : widget.subtitle)),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF7E7A9C),
            ),
          ),
          const SizedBox(height: 18),
          if (_opponentWantsRematch || _rematchRequested) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    '${_secondsRemaining}s remaining',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2649) : const Color(0xFFF3F0FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.score,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1E1A33),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_opponentWantsRematch) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _handleAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Accept (${_secondsRemaining}s)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _handleDecline,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF2C2649) : const Color(0xFFF3F0FA),
                      foregroundColor: const Color(0xFFD81E5B),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD81E5B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_rematchRequested) ...[
            FilledButton(
              onPressed: _handleCancelRequest,
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2C2649) : const Color(0xFFF3F0FA),
                foregroundColor: isDark ? Colors.white70 : const Color(0xFF5A5579),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Cancel request',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ] else ...[
            FilledButton(
              onPressed: _handlePlayAgain,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Play again',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                widget.onRematchAction?.call('leave_room');
                Navigator.of(context).pop();
                widget.onClose();
              },
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2C2649) : const Color(0xFFF3F0FA),
                foregroundColor: const Color(0xFFD81E5B),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Close room',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD81E5B),
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }
}

class _RpsPlayerCard extends StatelessWidget {
  const _RpsPlayerCard({
    required this.name,
    required this.username,
    required this.mark,
    required this.accent,
    required this.status,
    required this.active,
    this.isSolidPill = false,
  });

  final String name;
  final String username;
  final String mark;
  final Color accent;
  final String status;
  final bool active;
  final bool isSolidPill;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active ? accent : (dark ? const Color(0xFF382F57) : const Color(0xFFEAE6F8)),
          width: active ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: active ? accent.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              mark,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : const Color(0xFF1E1A33),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: dark ? Colors.white60 : const Color(0xFF7E7A9C),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSolidPill ? accent : (dark ? const Color(0xFF2C2649) : const Color(0xFFF3F0FA)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              status,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSolidPill ? Colors.white : (dark ? Colors.white70 : const Color(0xFF7E7A9C)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RpsVsBadge extends StatelessWidget {
  const _RpsVsBadge();
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF282046) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: dark ? const Color(0xFF382F57) : const Color(0xFFEAE6F8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'VS',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: dark ? Colors.white70 : const Color(0xFF7E7A9C),
        ),
      ),
    );
  }
}

class _RpsPad extends StatelessWidget {
  const _RpsPad({
    required this.move,
    required this.accent,
    required this.shake,
    required this.pop,
    required this.winner,
    required this.loser,
    required this.animation,
  });

  final String? move;
  final Color accent;
  final bool shake;
  final bool pop;
  final bool winner;
  final bool loser;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget pad = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: winner ? accent : (dark ? const Color(0xFF382F57) : const Color(0xFFEAE6F8)),
          width: winner ? 2.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: winner
                ? accent.withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: winner ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedOpacity(
        opacity: loser ? .48 : 1.0,
        duration: const Duration(milliseconds: 250),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: move == null
              ? const FittedBox(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB9ACF0),
                    ),
                  ),
                )
              : _RpsMoveIcon(move: move!, size: 66),
        ),
      ),
    );
    pad = AspectRatio(aspectRatio: 1, child: pad);
    if (pop && move != null) {
      pad = TweenAnimationBuilder<double>(
        tween: Tween(begin: .65, end: 1),
        duration: const Duration(milliseconds: 400),
        builder: (context, scale, child) => Transform.rotate(
          angle: (1 - scale) * -.18,
          child: Transform.scale(scale: scale, child: child),
        ),
        child: pad,
      );
    }
    if (shake) {
      pad = AnimatedBuilder(
        animation: animation,
        child: pad,
        builder: (context, child) {
          final phase = animation.value * math.pi * 2;
          return Transform.translate(
            offset: Offset(0, math.sin(phase) * 8),
            child: Transform.rotate(angle: math.sin(phase) * .025, child: child),
          );
        },
      );
    }
    return pad;
  }
}

class _RpsMoveTile extends StatelessWidget {
  const _RpsMoveTile({
    required this.move,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String move;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final label = switch (move) {
      'rock' => 'Rock',
      'paper' => 'Paper',
      _ => 'Scissors',
    };
    return Opacity(
      opacity: enabled || selected ? 1 : .55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF201B36) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? accent
                    : (dark ? const Color(0xFF382F57) : const Color(0xFFEAE6F8)),
                width: selected ? 2.2 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? accent.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _RpsMoveIcon(move: move, size: 38),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white : const Color(0xFF1E1A33),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RpsMoveIcon extends StatelessWidget {
  const _RpsMoveIcon({required this.move, required this.size});
  final String move;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = switch (move) {'rock' => const Color(0xFFF5A524), 'paper' => const Color(0xFF38BDF8), _ => const Color(0xFFEC4899)};
    return CustomPaint(size: Size.square(size), painter: _RpsMovePainter(move, color));
  }
}

class _RpsMovePainter extends CustomPainter {
  const _RpsMovePainter(this.move, this.color);
  final String move;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.save();
    canvas.scale(scale);
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    if (move == 'rock') {
      final path = Path()..moveTo(10, 40)..lineTo(7, 25)..lineTo(20, 10)..lineTo(42, 8)..lineTo(59, 21)..lineTo(61, 40)..lineTo(50, 55)..lineTo(26, 59)..close();
      canvas.drawPath(path, fill);
      final lines = Paint()..color = const Color(0xFFB9770E)..strokeWidth = 3..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(20, 11), const Offset(25, 25), lines);
      canvas.drawLine(const Offset(25, 25), const Offset(44, 29), lines);
      canvas.drawLine(const Offset(44, 29), const Offset(52, 15), lines);
      canvas.drawLine(const Offset(25, 25), const Offset(10, 40), lines);
      canvas.drawLine(const Offset(44, 29), const Offset(41, 50), lines);
    } else if (move == 'paper') {
      final path = Path()..moveTo(16, 6)..lineTo(38, 6)..lineTo(50, 18)..lineTo(50, 52)..quadraticBezierTo(50, 58, 44, 58)..lineTo(16, 58)..quadraticBezierTo(10, 58, 10, 52)..lineTo(10, 12)..quadraticBezierTo(10, 6, 16, 6)..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(Path()..moveTo(38, 6)..lineTo(38, 18)..lineTo(50, 18)..close(), Paint()..color = const Color(0xFF0E8FCB));
      final line = Paint()..color = Colors.white..strokeWidth = 4..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(20, 31), const Offset(42, 31), line);
      canvas.drawLine(const Offset(20, 40), const Offset(42, 40), line);
      canvas.drawLine(const Offset(20, 49), const Offset(34, 49), line);
    } else {
      final blade = Paint()..color = color..strokeWidth = 8..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(20, 8), const Offset(45, 40), blade);
      canvas.drawLine(const Offset(44, 8), const Offset(19, 40), blade);
      final ring = Paint()..color = color..strokeWidth = 6..style = PaintingStyle.stroke;
      canvas.drawCircle(const Offset(16, 49), 9, ring);
      canvas.drawCircle(const Offset(48, 49), 9, ring);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _RpsMovePainter oldDelegate) => oldDelegate.move != move || oldDelegate.color != color;
}

class _TicTacToeMatchPanel extends StatefulWidget {
  const _TicTacToeMatchPanel({
    required this.game,
    required this.currentUsername,
    required this.opponentUsername,
    required this.opponentName,
    required this.canJoinGroup,
    required this.sendingMove,
    required this.startingRematch,
    required this.isOfflineBot,
    required this.onSendBoard,
    required this.onPlayAgain,
    this.onRematchAction,
  });

  final Map<String, dynamic> game;
  final String currentUsername;
  final String opponentUsername;
  final String opponentName;
  final bool canJoinGroup;
  final bool sendingMove;
  final bool startingRematch;
  final bool isOfflineBot;
  final Future<bool> Function(List<dynamic> board, String playerX, String playerO) onSendBoard;
  final Future<void> Function() onPlayAgain;
  final Future<void> Function(String action)? onRematchAction;

  @override
  State<_TicTacToeMatchPanel> createState() => _TicTacToeMatchPanelState();
}

class _TicTacToeMatchPanelState extends State<_TicTacToeMatchPanel> {
  List<dynamic>? _optimisticBoard;
  String? _error;
  bool _gameOverModalShown = false;

  Map<String, dynamic> get _data => widget.game['data'] is Map
      ? Map<String, dynamic>.from(widget.game['data'] as Map)
      : <String, dynamic>{};

  bool get _finished => widget.game['state']?.toString() == 'finished';

  @override
  void initState() {
    super.initState();
    if (_finished) {
      _gameOverModalShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOver();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _TicTacToeMatchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game['data'] != widget.game['data']) {
      _optimisticBoard = null;
      _error = null;
    }
    if (_finished && !_gameOverModalShown) {
      _gameOverModalShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOver();
      });
    } else if (!_finished) {
      _gameOverModalShown = false;
    }
  }

  void _showGameOver() {
    final winner = widget.game['winner']?.toString() ?? '';
    final meWon = winner.toLowerCase() == widget.currentUsername.toLowerCase();
    final tie = winner == 'draw';
    final opponentName = widget.opponentName.trim().isEmpty ? widget.opponentUsername : widget.opponentName.trim();
    final data = _data;
    final playerX = data['playerX']?.toString() ?? widget.game['createdBy']?.toString() ?? '';
    final playerO = data['playerO']?.toString() ?? widget.game['opponent']?.toString() ?? widget.opponentUsername;
    final isPlayerX = widget.currentUsername.toLowerCase() == playerX.toLowerCase();
    final winsX = (data['p1Score'] as num?)?.toInt() ?? (_finished && winner.toLowerCase() == playerX.toLowerCase() ? 1 : 0);
    final winsO = (data['p2Score'] as num?)?.toInt() ?? (_finished && winner.toLowerCase() == playerO.toLowerCase() ? 1 : 0);
    final myScore = isPlayerX ? winsX : winsO;
    final opponentScore = isPlayerX ? winsO : winsX;

    final rematch = data['rematch'];
    final isOpponentRequest = rematch is Map &&
        rematch['status'] == 'pending' &&
        rematch['requestedBy']?.toString().toLowerCase() !=
            widget.currentUsername.toLowerCase();

    final playerLeft = data['playerLeft']?.toString() ??
        (rematch is Map && rematch['status'] == 'opponent_left'
            ? rematch['leftBy']?.toString()
            : null);

    _showGameOverModal(
      context,
      emoji: tie ? '🤝' : (meWon ? '🏆' : '⚡'),
      title: tie ? 'It’s a draw' : (meWon ? 'You won!' : '$opponentName wins!'),
      subtitle: tie
          ? 'Evenly matched. Want a rematch?'
          : (meWon ? 'Great match! Want a rematch?' : 'So close. Want a rematch?'),
      score: '$myScore : $opponentScore',
      onPlayAgain: widget.onPlayAgain,
      onClose: () => Navigator.of(context).maybePop(),
      onRematchAction: widget.onRematchAction,
      isOpponentRequest: isOpponentRequest,
      playerLeft: playerLeft,
      opponentName: opponentName,
      isOfflineBot: widget.isOfflineBot,
    );
  }

  Future<void> _tapCell(int index, List<dynamic> board, String playerX, String playerO, String symbol) async {
    if (_finished || widget.sendingMove || board[index] != null) return;
    HapticFeedback.lightImpact();
    final next = List<dynamic>.from(board)..[index] = symbol;
    setState(() { _optimisticBoard = next; _error = null; });
    final success = await widget.onSendBoard(
      next,
      playerX,
      widget.canJoinGroup ? widget.currentUsername : playerO,
    );
    if (!mounted) return;
    // Offline bot moves update the local game map after a short delay. Clear
    // the player's optimistic snapshot so the board can render the bot reply.
    if (success && widget.game['isOfflineBot'] == true) {
      setState(() => _optimisticBoard = null);
      return;
    }
    if (success) return;
    setState(() { _optimisticBoard = null; _error = 'Move not sent · tap again to retry'; });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final playerX = data['playerX']?.toString() ?? widget.game['createdBy']?.toString() ?? '';
    final playerO = data['playerO']?.toString() ?? widget.game['opponent']?.toString() ?? widget.opponentUsername;
    final isPlayerX = widget.currentUsername.toLowerCase() == playerX.toLowerCase();
    final mySymbol = isPlayerX ? 'X' : 'O';
    final opponentSymbol = isPlayerX ? 'O' : 'X';
    final canJoin = widget.canJoinGroup;
    final board = _optimisticBoard ?? (data['board'] is List ? List<dynamic>.from(data['board'] as List) : List<dynamic>.filled(9, null));
    final winningCells = data['winningLine'] is List
        ? (data['winningLine'] as List).whereType<num>().map((value) => value.toInt()).toSet()
        : <int>{};
    final winner = widget.game['winner']?.toString() ?? '';
    final meWon = winner.toLowerCase() == widget.currentUsername.toLowerCase();
    final tie = winner == 'draw';
    final isMyTurn = widget.game['turn']?.toString().toLowerCase() == widget.currentUsername.toLowerCase() || canJoin;
    final winsX = (data['p1Score'] as num?)?.toInt() ?? (_finished && winner.toLowerCase() == playerX.toLowerCase() ? 1 : 0);
    final winsO = (data['p2Score'] as num?)?.toInt() ?? (_finished && winner.toLowerCase() == playerO.toLowerCase() ? 1 : 0);
    final myScore = isPlayerX ? winsX : winsO;
    final opponentScore = isPlayerX ? winsO : winsX;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final opponentName = widget.opponentName.trim().isEmpty ? widget.opponentUsername : widget.opponentName.trim();

    final myStatus = _finished
        ? (meWon ? 'Winner' : (tie ? 'Draw' : 'Waiting'))
        : (isMyTurn ? 'Your turn' : 'Waiting');
    final myPillSolid = _finished ? meWon : isMyTurn;

    final opponentStatus = _finished
        ? (!meWon && !tie ? 'Winner' : (tie ? 'Draw' : 'Waiting'))
        : (!isMyTurn ? 'Thinking...' : 'Waiting');
    final opponentPillSolid = _finished ? (!meWon && !tie) : !isMyTurn;

    final statusText = _error ?? (_finished
        ? (tie ? 'It’s a draw' : (meWon ? 'You win!' : '$opponentName wins!'))
        : (isMyTurn ? 'Your move' : '$opponentName is thinking…'));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TttPlayerCard(
                name: 'You',
                username: '@${widget.currentUsername}',
                mark: mySymbol,
                accent: accent,
                active: !_finished && isMyTurn,
                status: myStatus,
                isSolidPill: myPillSolid,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  Text(
                    '$myScore : $opponentScore',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : const Color(0xFF1E1A33),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Wins',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white60 : const Color(0xFF7E7A9C),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _TttPlayerCard(
                name: opponentName,
                username: '@${widget.opponentUsername}',
                mark: opponentSymbol,
                accent: const Color(0xFFD81E5B),
                active: !_finished && !isMyTurn,
                status: opponentStatus,
                isSolidPill: opponentPillSolid,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: dark ? Colors.white : const Color(0xFF1E1A33),
          ),
        ),
        const SizedBox(height: 18),
        AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final value = board[index]?.toString();
              final winning = winningCells.contains(index);
              final canTap = !_finished && !widget.sendingMove && isMyTurn && value == null;
              return Semantics(
                button: canTap,
                label: value == null ? 'Empty cell' : '$value${winning ? ', winning tile' : ''}',
                child: Material(
                  key: ValueKey('tic-tac-toe-cell-$index'),
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canTap ? () => _tapCell(index, board, playerX, playerO, mySymbol) : null,
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF201B36) : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: winning
                              ? accent
                              : (dark ? const Color(0xFF382F57) : const Color(0xFFEAE6F8)),
                          width: winning ? 2.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: winning
                                ? accent.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.03),
                            blurRadius: winning ? 14 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                        child: value == 'X'
                            ? Text(
                                'X',
                                key: ValueKey('x'),
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                ),
                              )
                            : value == 'O'
                                ? const Text(
                                    'O',
                                    key: ValueKey('o'),
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFD81E5B),
                                    ),
                                  )
                                : const SizedBox.expand(key: ValueKey('empty')),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.sendingMove) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_finished) ...[
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _showGameOver,
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('View match results'),
            style: TextButton.styleFrom(
              foregroundColor: accent,
            ),
          ),
        ],
      ],
    );
  }
}

class _TttPlayerCard extends StatelessWidget {
  const _TttPlayerCard({
    required this.name,
    required this.username,
    required this.mark,
    required this.accent,
    required this.active,
    required this.status,
    required this.isSolidPill,
  });

  final String name;
  final String username;
  final String mark;
  final Color accent;
  final bool active;
  final String status;
  final bool isSolidPill;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active ? accent : (dark ? const Color(0xFF382F57) : const Color(0xFFEAE6F8)),
          width: active ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: active ? accent.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dark ? const Color(0xFF201B36) : const Color(0xFFEAE6F8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    mark,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : const Color(0xFF1E1A33),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: dark ? Colors.white60 : const Color(0xFF7E7A9C),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSolidPill ? accent : (dark ? const Color(0xFF2C2649) : const Color(0xFFF3F0FA)),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              status,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSolidPill ? Colors.white : (dark ? Colors.white70 : const Color(0xFF7E7A9C)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RockPaperScissorsPanel extends StatefulWidget {
  const _RockPaperScissorsPanel({
    required this.game,
    required this.currentUsername,
    required this.opponentUsername,
    required this.opponentName,
    required this.sendingMove,
    required this.startingRematch,
    required this.onSendMove,
    required this.onPlayAgain,
    this.onRematchAction,
  });

  final Map<String, dynamic> game;
  final String currentUsername;
  final String opponentUsername;
  final String opponentName;
  final bool sendingMove;
  final bool startingRematch;
  final Future<bool> Function(String move) onSendMove;
  final Future<void> Function() onPlayAgain;
  final Future<void> Function(String action)? onRematchAction;

  @override
  State<_RockPaperScissorsPanel> createState() => _RockPaperScissorsPanelState();
}

class _RockPaperScissorsPanelState extends State<_RockPaperScissorsPanel> with SingleTickerProviderStateMixin {
  static const _moves = ['rock', 'paper', 'scissors'];
  static const _countdownWords = ['Rock…', 'Paper…', 'Scissors…', 'Shoot!'];
  late final AnimationController _shakeController;
  Timer? _shuffleTimer;
  Timer? _statusTimer;
  Timer? _revealTimer;
  Timer? _nextRoundTimer;
  String? _revealKey;
  String? _selectedMove;
  String? _error;
  bool _isCountingDown = false;
  bool _revealed = false;
  bool _roundTransitioning = false;
  bool _gameOverModalShown = false;
  String _leftShuffle = 'rock';
  String _rightShuffle = 'paper';
  String _status = 'Pick your move';
  int _statusIndex = 0;
  int _lastRound = 0;
  Object? _lastObservedData;
  String? _lastObservedState;

  // Delayed scores and round: updated only when reveal finishes!
  int _displayedP1Score = 0;
  int _displayedP2Score = 0;
  int _displayedRound = 1;

  Map<String, dynamic> get _data => widget.game['data'] is Map
      ? Map<String, dynamic>.from(widget.game['data'] as Map)
      : <String, dynamic>{};
  bool get _finished => widget.game['state']?.toString() == 'finished';
  String get _opponentLabel => widget.opponentName.trim().isEmpty
      ? 'Opponent'
      : widget.opponentName.trim().split(' ').first;
  String get _opponentFullName => widget.opponentName.trim().isEmpty
      ? widget.opponentUsername
      : widget.opponentName.trim();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final data = _data;
    // The parent mutates the shared game map in place, so keep our own
    // snapshot of the data reference instead of comparing oldWidget.game.
    _lastObservedData = widget.game['data'];
    _lastObservedState = widget.game['state']?.toString();
    _lastRound = (data['round'] as num?)?.toInt() ?? 1;
    _displayedP1Score = (data['p1Score'] as num?)?.toInt() ?? 0;
    _displayedP2Score = (data['p2Score'] as num?)?.toInt() ?? 0;
    _displayedRound = _lastRound;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncGame();
    });
  }

  @override
  void didUpdateWidget(covariant _RockPaperScissorsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentData = widget.game['data'];
    final currentState = widget.game['state']?.toString();
    if (!identical(_lastObservedData, currentData) ||
        _lastObservedState != currentState) {
      _lastObservedData = currentData;
      _lastObservedState = currentState;
      _syncGame();
    }
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _statusTimer?.cancel();
    _revealTimer?.cancel();
    _nextRoundTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _syncGame() {
    final data = _data;
    final round = (data['round'] as num?)?.toInt() ?? 1;
    if (round > _lastRound) {
      _lastRound = round;
      _shuffleTimer?.cancel();
      _statusTimer?.cancel();
      _revealTimer?.cancel();
      _nextRoundTimer?.cancel();
      _shakeController.stop();
      _revealKey = null;
      setState(() {
        _roundTransitioning = false;
        _revealed = false;
        _isCountingDown = false;
        _selectedMove = null;
        _error = null;
        _status = 'Pick your move';
      });
    }
    if (!_finished) {
      _gameOverModalShown = false;
    }
    final p1Move = data['p1Move']?.toString();
    final p2Move = data['p2Move']?.toString();
    final shouldReveal = p1Move != null && p2Move != null &&
        (data['roundResolved'] == true || _finished);
    if (shouldReveal) _beginReveal(data, round);
  }

  void _beginReveal(Map<String, dynamic> data, int round) {
    final p1Move = data['p1Move']?.toString();
    final p2Move = data['p2Move']?.toString();
    if (!_moves.contains(p1Move) || !_moves.contains(p2Move)) return;
    final resolvedAt = data['roundResolvedAt'] is num
        ? (data['roundResolvedAt'] as num).toInt()
        : DateTime.now().millisecondsSinceEpoch;
    final key = '$round:$resolvedAt';
    if (_revealKey == key) return;
    _revealKey = key;
    _shuffleTimer?.cancel();
    _statusTimer?.cancel();
    _revealTimer?.cancel();
    _nextRoundTimer?.cancel();
    final elapsed = (DateTime.now().millisecondsSinceEpoch - resolvedAt)
        .clamp(0, 1740);
    _statusIndex = (elapsed ~/ 420).clamp(0, 3);
    _shakeController.repeat();
    // Do NOT update displayed scores yet during shuffle/countdown!
    setState(() {
      _roundTransitioning = false;
      _isCountingDown = true;
      _revealed = false;
      _status = _countdownWords[_statusIndex];
      _error = null;
    });
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || !_isCountingDown) return;
      setState(() {
        _leftShuffle = _moves[math.Random().nextInt(_moves.length)];
        _rightShuffle = _moves[math.Random().nextInt(_moves.length)];
      });
    });
    _statusTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted || !_isCountingDown) return;
      setState(() {
        _statusIndex = (_statusIndex + 1).clamp(0, 3);
        _status = _countdownWords[_statusIndex];
      });
    });
    final remaining = math.max(0, 1740 - elapsed);
    _revealTimer = Timer(
      Duration(milliseconds: remaining),
      () => _finishReveal(data, round),
    );
  }

  void _finishReveal(Map<String, dynamic> data, int round) {
    if (!mounted) return;
    _shuffleTimer?.cancel();
    _statusTimer?.cancel();
    _shakeController.stop();
    final p1Move = data['p1Move']?.toString() ?? '';
    final p2Move = data['p2Move']?.toString() ?? '';
    final winner = data['roundWinner']?.toString() ??
        widget.game['winner']?.toString() ?? 'draw';
    final isTie = p1Move == p2Move || winner == 'draw';
    final iWon = winner.toLowerCase() == widget.currentUsername.toLowerCase();
    final roundResult = isTie
        ? 'It’s a tie'
        : iWon
            ? 'You take the round!'
            : '$_opponentLabel takes the round!';

    // Update displayed scores and round exactly when cards reveal!
    setState(() {
      _displayedP1Score = (data['p1Score'] as num?)?.toInt() ?? 0;
      _displayedP2Score = (data['p2Score'] as num?)?.toInt() ?? 0;
      _displayedRound = round;
      _isCountingDown = false;
      _revealed = true;
      _status = _finished
          ? (iWon ? 'You win the match!' : '$_opponentLabel wins the match!')
          : roundResult;
    });

    if (_finished) {
      if (!_gameOverModalShown) {
        _gameOverModalShown = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showGameOver();
        });
      }
      return;
    }

    _nextRoundTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _roundTransitioning = true;
        _displayedRound = (data['round'] as num?)?.toInt() ?? (round + 1);
        _revealed = false;
        _selectedMove = null;
        _error = null;
        _status = 'Pick your move';
      });
    });
  }

  void _showGameOver() {
    final winner = widget.game['winner']?.toString() ?? '';
    final iWon = winner.toLowerCase() == widget.currentUsername.toLowerCase();
    final tie = winner == 'draw';
    final myScore = _isPlayer1 ? _displayedP1Score : _displayedP2Score;
    final otherScore = _isPlayer1 ? _displayedP2Score : _displayedP1Score;

    final rematch = widget.game['data']?['rematch'];
    final isOpponentRequest = rematch is Map &&
        rematch['status'] == 'pending' &&
        rematch['requestedBy']?.toString().toLowerCase() !=
            widget.currentUsername.toLowerCase();

    final playerLeft = widget.game['data']?['playerLeft']?.toString() ??
        (rematch is Map && rematch['status'] == 'opponent_left'
            ? rematch['leftBy']?.toString()
            : null);

    _showGameOverModal(
      context,
      emoji: tie ? '🤝' : (iWon ? '🏆' : '⚡'),
      title: tie ? 'It’s a draw' : (iWon ? 'You won!' : '$_opponentFullName wins!'),
      subtitle: tie
          ? 'Evenly matched. Want a rematch?'
          : (iWon ? 'Great match! Want a rematch?' : 'So close. Want a rematch?'),
      score: '$myScore : $otherScore',
      onPlayAgain: widget.onPlayAgain,
      onClose: () => Navigator.of(context).maybePop(),
      onRematchAction: widget.onRematchAction,
      isOpponentRequest: isOpponentRequest,
      playerLeft: playerLeft,
      opponentName: _opponentFullName,
    );
  }

  Future<void> _pickMove(String move) async {
    if (!_canPick || widget.sendingMove) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedMove = move;
      _error = null;
    });
    final sent = await widget.onSendMove(move);
    if (!mounted || sent) return;
    setState(() {
      _selectedMove = null;
      _error = 'Move not sent · choose again';
      _status = 'Could not send move. Try again.';
    });
  }

  bool get _isPlayer1 =>
      (_data['player1']?.toString() ?? widget.game['createdBy']?.toString() ?? '')
          .toLowerCase() == widget.currentUsername.toLowerCase();
  String? get _myServerMove =>
      (_isPlayer1 ? _data['p1Move'] : _data['p2Move'])?.toString();
  String? get _opponentServerMove =>
      (_isPlayer1 ? _data['p2Move'] : _data['p1Move'])?.toString();
  String? get _myMove => _roundTransitioning
      ? _selectedMove
      : _selectedMove ?? _myServerMove;
  bool get _canPick => !_finished &&
      !_isCountingDown &&
      !_revealed &&
      (_roundTransitioning || _data['roundResolved'] != true) &&
      _myMove == null;
  bool get _winnerIsMe =>
      widget.game['winner']?.toString().toLowerCase() ==
      widget.currentUsername.toLowerCase();

  String _initial(String value) =>
      value.trim().isEmpty ? '?' : value.trim().characters.first.toUpperCase();

  String _statusFor(bool opponentLocked, String? myMove, bool bothLocked) {
    if (_isCountingDown || _revealed) return _status;
    if (_roundTransitioning) return 'Pick your move';
    if (bothLocked) return 'Revealing moves…';
    if (myMove != null) return 'Waiting for $_opponentLabel…';
    if (opponentLocked) return '$_opponentFullName is ready. Pick your move.';
    return 'Pick your move';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final myMove = _myMove;
    final opponentLocked = !_roundTransitioning &&
        !_isCountingDown &&
        !_revealed &&
        data['roundResolved'] != true &&
        _opponentServerMove != null;
    final bothLocked = !_roundTransitioning &&
        (_isCountingDown || _revealed || data['roundResolved'] == true);

    final myScore = _isPlayer1 ? _displayedP1Score : _displayedP2Score;
    final otherScore = _isPlayer1 ? _displayedP2Score : _displayedP1Score;

    final myTag = _finished
        ? (_winnerIsMe ? 'Winner' : 'Waiting')
        : (_revealed
            ? 'Locked in'
            : (myMove != null || bothLocked)
                ? 'Locked in'
                : 'Thinking...');
    final myPillSolid = _finished
        ? _winnerIsMe
        : (myMove != null && !_revealed || bothLocked && !_revealed);

    final otherTag = _finished
        ? (!_winnerIsMe && widget.game['winner'] != 'draw' ? 'Winner' : 'Waiting')
        : (_revealed
            ? 'Locked in'
            : (opponentLocked || bothLocked)
                ? 'Locked in'
                : 'Thinking...');
    final otherPillSolid = _finished
        ? (!_winnerIsMe && widget.game['winner'] != 'draw')
        : (opponentLocked || bothLocked || !_revealed);

    final showMoves = _revealed;
    final leftMove = _isCountingDown ? _leftShuffle : showMoves ? data['p1Move']?.toString() : null;
    final rightMove = _isCountingDown ? _rightShuffle : showMoves ? data['p2Move']?.toString() : null;
    final roundWinner = data['roundWinner']?.toString() ?? '';
    final leftWin = showMoves && roundWinner.toLowerCase() == (data['player1']?.toString() ?? '').toLowerCase();
    final rightWin = showMoves && roundWinner.toLowerCase() == (data['player2']?.toString() ?? widget.opponentUsername).toLowerCase();
    final tied = showMoves && roundWinner == 'draw';
    final status = _error ?? (_revealed && _finished
        ? (_winnerIsMe ? 'You win the match!' : '$_opponentFullName wins the match!')
        : _statusFor(opponentLocked, myMove, bothLocked));
    final enabled = _canPick && !widget.sendingMove;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _RpsPlayerCard(
                name: 'You',
                username: '@${widget.currentUsername}',
                mark: _initial(widget.currentUsername),
                accent: accent,
                status: myTag,
                active: !_finished && myMove == null,
                isSolidPill: myPillSolid,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  Text(
                    '$myScore : $otherScore',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : const Color(0xFF1E1A33),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _finished ? 'Final' : 'Round $_displayedRound',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white60 : const Color(0xFF7E7A9C),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _RpsPlayerCard(
                name: _opponentFullName,
                username: '@${widget.opponentUsername}',
                mark: _initial(_opponentFullName),
                accent: const Color(0xFFD81E5B),
                status: otherTag,
                active: !_finished && opponentLocked,
                isSolidPill: otherPillSolid,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: dark ? Colors.white : const Color(0xFF1E1A33),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _RpsPad(
                move: leftMove,
                accent: accent,
                shake: _isCountingDown,
                pop: _revealed,
                winner: leftWin,
                loser: showMoves && !leftWin && !tied,
                animation: _shakeController,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: _RpsVsBadge(),
            ),
            Expanded(
              child: _RpsPad(
                move: rightMove,
                accent: const Color(0xFFD81E5B),
                shake: _isCountingDown,
                pop: _revealed,
                winner: rightWin,
                loser: showMoves && !rightWin && !tied,
                animation: _shakeController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 56),
        Row(
          children: _moves.map((move) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _RpsMoveTile(
                move: move,
                selected: myMove == move,
                enabled: enabled,
                onTap: () => _pickMove(move),
              ),
            ),
          )).toList(),
        ),
        if (widget.sendingMove) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_finished) ...[
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _showGameOver,
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('View match results'),
            style: TextButton.styleFrom(
              foregroundColor: accent,
            ),
          ),
        ],
      ],
    );
  }
}