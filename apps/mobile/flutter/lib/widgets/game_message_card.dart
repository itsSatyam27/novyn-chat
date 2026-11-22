import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import 'novyn_alert.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../services/game_history_service.dart';
import '../screens/games/game_room_screen.dart';

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
    _recordFinishedGame(widget.game);
  }

  void _recordFinishedGame(Map<String, dynamic> game) {
    if (_recordedFinishedGame || game['state']?.toString() != 'finished') return;
    final username = widget.currentUsername.trim();
    final matchId = game['id']?.toString().trim().isNotEmpty == true
        ? game['id'].toString()
        : widget.messageId.trim();
    if (username.isEmpty || matchId.isEmpty) return;
    _recordedFinishedGame = true;
    final winner = game['winner']?.toString().trim().toLowerCase() ?? '';
    final result = winner.isEmpty || winner == 'draw'
        ? 'draw'
        : winner == username.toLowerCase()
            ? 'win'
            : 'loss';
    final rawUpdatedAt = game['updatedAt'];
    final playedAt = rawUpdatedAt is num
        ? DateTime.fromMillisecondsSinceEpoch(rawUpdatedAt.toInt())
        : DateTime.tryParse(rawUpdatedAt?.toString() ?? '') ?? DateTime.now();
    unawaited(GameHistoryService.recordFinishedMatch(
      username: username,
      matchId: matchId,
      gameType: game['gameType']?.toString() ?? 'unknown',
      opponent: widget.peerUsername,
      result: result,
      playedAt: playedAt,
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

  Future<bool> _move(Map<String, dynamic> data) async {
    if (_sendingMove || _finished) return false;
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
        onSendBoard: (board, playerX, playerO) => _move({
          'board': board,
          'playerX': playerX,
          'playerO': playerO,
        }),
        onPlayAgain: _startRematch,
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
    if (_startingRematch) return;
    setState(() => _startingRematch = true);
    try {
      final socket = context.read<SocketService>();
      final messageId = await socket.sendGameChallenge(
        _type,
        widget.peerUsername,
        isGroup: widget.isGroup,
      );
      final history = await socket.openChat(
        widget.peerUsername,
        const <Message>[],
        isGroup: widget.isGroup,
      );
      Map<String, dynamic>? nextGame;
      for (final message in history) {
        if (message.id == messageId && message.game != null) {
          nextGame = Map<String, dynamic>.from(message.game!);
          break;
        }
      }
      if (!mounted) return;
      if (nextGame == null) {
        throw StateError('The rematch was sent, but its game room could not be loaded.');
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => GameRoomScreen(
            messageId: messageId,
            peerUsername: widget.peerUsername,
            currentUsername: widget.currentUsername,
            initialGame: nextGame!,
            isGroup: widget.isGroup,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      NovynAlert.show(
        context,
        error is StateError
            ? error.message.toString()
            : 'Could not start the rematch. Check your connection and try again.',
        isError: true,
        title: 'Could not start rematch',
        icon: Icons.sports_esports_rounded,
      );
    } finally {
      if (mounted) setState(() => _startingRematch = false);
    }
  }
}

class _RpsPlayerCard extends StatelessWidget {
  const _RpsPlayerCard({required this.name, required this.username, required this.mark, required this.accent, required this.status, required this.active});
  final String name;
  final String username;
  final String mark;
  final Color accent;
  final String status;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
      decoration: BoxDecoration(color: active ? scheme.surface : scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: accent.withValues(alpha: active ? .95 : .3), width: active ? 1.4 : 1)),
      child: Column(children: [
        Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(gradient: LinearGradient(colors: [accent.withValues(alpha: .7), accent]), shape: BoxShape.circle), child: Text(mark, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),
        const SizedBox(height: 3),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        Text(username, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 7, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 5),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 5), alignment: Alignment.center, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(13)), child: _RpsPlayerTag(status: status)),
      ]),
    );
  }
}

class _RpsPlayerTag extends StatelessWidget {
  const _RpsPlayerTag({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    if (status != 'THINKING') return Text(status, maxLines: 1, overflow: TextOverflow.clip, style: const TextStyle(color: Colors.white, fontSize: 7, letterSpacing: .1, fontWeight: FontWeight.w900));
    return const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('THINKING', style: TextStyle(color: Colors.white, fontSize: 7, letterSpacing: .1, fontWeight: FontWeight.w900)), SizedBox(width: 3), _RpsBlinkDots()]);
  }
}

class _RpsBlinkDots extends StatefulWidget {
  const _RpsBlinkDots();
  @override
  State<_RpsBlinkDots> createState() => _RpsBlinkDotsState();
}

class _RpsBlinkDotsState extends State<_RpsBlinkDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _controller, builder: (context, _) => Opacity(opacity: .25 + .75 * (1 - (_controller.value - .5).abs() * 2), child: const Text('•••', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900))));
}

class _RpsVsBadge extends StatelessWidget {
  const _RpsVsBadge();
  @override
  Widget build(BuildContext context) => Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE4DEF7))), child: Text('VS', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurfaceVariant)));
}

class _RpsPad extends StatelessWidget {
  const _RpsPad({required this.move, required this.accent, required this.shake, required this.pop, required this.winner, required this.loser, required this.animation});
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
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(color: dark ? const Color(0xFF2A2244) : Colors.white, borderRadius: BorderRadius.circular(23), border: Border.all(color: winner ? accent : (dark ? const Color(0xFF493D70) : const Color(0xFFE4DEF7)), width: winner ? 2 : 1), boxShadow: [BoxShadow(color: dark ? const Color(0xFF17122B) : const Color(0xFFB9ACF0), offset: const Offset(0, 5), blurRadius: 0), if (winner) BoxShadow(color: accent.withValues(alpha: .32), blurRadius: 17, spreadRadius: 2)]),
      child: AnimatedOpacity(opacity: loser ? .52 : 1, duration: const Duration(milliseconds: 250), child: Padding(padding: const EdgeInsets.all(18), child: move == null ? const FittedBox(child: Text('?', style: TextStyle(fontSize: 43, fontWeight: FontWeight.w800, color: Color(0xFFB9ACF0)))) : _RpsMoveIcon(move: move!, size: 66))),
    );
    pad = AspectRatio(aspectRatio: 1, child: pad);
    if (pop && move != null) pad = TweenAnimationBuilder<double>(tween: Tween(begin: .65, end: 1), duration: const Duration(milliseconds: 400), builder: (context, scale, child) => Transform.rotate(angle: (1 - scale) * -.18, child: Transform.scale(scale: scale, child: child)), child: pad);
    if (shake) pad = AnimatedBuilder(animation: animation, child: pad, builder: (context, child) { final phase = animation.value * math.pi * 2; return Transform.translate(offset: Offset(0, math.sin(phase) * 8), child: Transform.rotate(angle: math.sin(phase) * .025, child: child)); });
    return pad;
  }
}

class _RpsMoveTile extends StatelessWidget {
  const _RpsMoveTile({required this.move, required this.selected, required this.enabled, required this.onTap});
  final String move;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label = switch (move) {'rock' => 'Rock', 'paper' => 'Paper', _ => 'Scissors'};
    return Opacity(opacity: enabled || selected ? 1 : .58, child: Material(color: Colors.transparent, child: InkWell(onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(16), child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.fromLTRB(4, 8, 4, 6), decoration: BoxDecoration(color: dark ? const Color(0xFF2A2244) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: selected ? const Color(0xFF6C4DF6) : (dark ? const Color(0xFF493D70) : const Color(0xFFE4DEF7)), width: selected ? 2 : 1), boxShadow: [BoxShadow(color: dark ? const Color(0xFF17122B) : const Color(0xFFB9ACF0), offset: const Offset(0, 3), blurRadius: 0)]), child: Column(children: [_RpsMoveIcon(move: move, size: 34), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700))])))));
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
    required this.onSendBoard,
    required this.onPlayAgain,
  });

  final Map<String, dynamic> game;
  final String currentUsername;
  final String opponentUsername;
  final String opponentName;
  final bool canJoinGroup;
  final bool sendingMove;
  final bool startingRematch;
  final Future<bool> Function(List<dynamic> board, String playerX, String playerO) onSendBoard;
  final Future<void> Function() onPlayAgain;

  @override
  State<_TicTacToeMatchPanel> createState() => _TicTacToeMatchPanelState();
}

class _TicTacToeMatchPanelState extends State<_TicTacToeMatchPanel> {
  List<dynamic>? _optimisticBoard;
  String? _error;

  Map<String, dynamic> get _data => widget.game['data'] is Map
      ? Map<String, dynamic>.from(widget.game['data'] as Map)
      : <String, dynamic>{};

  bool get _finished => widget.game['state']?.toString() == 'finished';

  @override
  void didUpdateWidget(covariant _TicTacToeMatchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game['data'] != widget.game['data']) {
      _optimisticBoard = null;
      _error = null;
    }
  }

  Future<void> _tapCell(int index, List<dynamic> board, String playerX, String playerO, String symbol) async {
    if (_finished || widget.sendingMove || board[index] != null) return;
    final next = List<dynamic>.from(board)..[index] = symbol;
    setState(() { _optimisticBoard = next; _error = null; });
    final success = await widget.onSendBoard(
      next,
      playerX,
      widget.canJoinGroup ? widget.currentUsername : playerO,
    );
    if (!mounted || success) return;
    setState(() { _optimisticBoard = null; _error = 'Move not sent · tap again to retry'; });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final playerX = data['playerX']?.toString() ?? widget.game['createdBy']?.toString() ?? '';
    final playerO = data['playerO']?.toString() ?? widget.game['opponent']?.toString() ?? widget.opponentUsername;
    final isPlayerX = widget.currentUsername.toLowerCase() == playerX.toLowerCase();
    final mySymbol = isPlayerX ? 'X' : 'O';
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
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final opponentName = widget.opponentName.trim().isEmpty ? widget.opponentUsername : widget.opponentName.trim();
    final status = _error ?? (_finished
        ? tie ? 'It’s a draw' : meWon ? 'You win!' : '$opponentName wins!'
        : isMyTurn ? 'Your turn' : '$opponentName is thinking…');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [dark ? const Color(0xFF17132A) : const Color(0xFFF0EBFF), dark ? const Color(0xFF241A3C) : const Color(0xFFE7DFFF)]),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(children: [
        Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tic-Tac-Toe', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text('Playing with $opponentName', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11)),
        ])),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _TttPlayerCard(name: 'You', username: '@${widget.currentUsername}', mark: mySymbol, accent: const Color(0xFF6C4DF6), active: !_finished && isMyTurn, winner: _finished && meWon)),
          SizedBox(width: 48, child: Column(children: [
            Text('$myScore : $opponentScore', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFF1E1A33))),
            Text('WINS', style: theme.textTheme.labelSmall?.copyWith(fontSize: 8, letterSpacing: .6, color: scheme.onSurfaceVariant)),
          ])),
          Expanded(child: _TttPlayerCard(name: opponentName, username: '@${widget.opponentUsername}', mark: isPlayerX ? 'O' : 'X', accent: const Color(0xFFE8458B), active: !_finished && !isMyTurn, winner: _finished && !meWon && !tie)),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(status, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800))),
          if (_finished) ...[const SizedBox(width: 8), _smallReplayButton(widget.startingRematch, widget.onPlayAgain)],
        ]),
        const SizedBox(height: 13),
        AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemBuilder: (context, index) {
              final value = board[index]?.toString();
              final winning = winningCells.contains(index);
              final canTap = !_finished && !widget.sendingMove && isMyTurn && value == null;
              final markColor = value == 'X' ? const Color(0xFF6847F5) : const Color(0xFFE8458B);
              return Semantics(
                button: canTap,
                label: value == null ? 'Empty cell' : '$value${winning ? ', winning tile' : ''}',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canTap ? () => _tapCell(index, board, playerX, playerO, mySymbol) : null,
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF2D2549) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: winning ? const Color(0xFF6C4DF6) : (dark ? const Color(0xFF493D70) : const Color(0xFFE4DEF7)), width: winning ? 2 : 1.3),
                        boxShadow: [
                          BoxShadow(color: dark ? const Color(0xFF100D1C) : const Color(0xFFB9ACF0), offset: const Offset(0, 4), blurRadius: 0),
                          if (winning) BoxShadow(color: const Color(0xFF6C4DF6).withValues(alpha: .35), blurRadius: 17, spreadRadius: 2),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: RotationTransition(turns: Tween<double>(begin: -.04, end: 0).animate(animation), child: child)),
                        child: value == 'X'
                            ? Icon(Icons.close_rounded, key: const ValueKey('x'), size: 56, color: markColor)
                            : value == 'O'
                                ? Icon(Icons.circle_outlined, key: const ValueKey('o'), size: 48, color: markColor)
                                : const SizedBox.expand(key: ValueKey('empty')),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.sendingMove) ...[const SizedBox(height: 9), const LinearProgressIndicator(minHeight: 2)],
      ]),
    );
  }
}

class _TttPlayerCard extends StatelessWidget {
  const _TttPlayerCard({required this.name, required this.username, required this.mark, required this.accent, required this.active, required this.winner});
  final String name;
  final String username;
  final String mark;
  final Color accent;
  final bool active;
  final bool winner;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(6, 9, 6, 8),
      decoration: BoxDecoration(color: dark ? const Color(0xFF241E3B) : Colors.white.withValues(alpha: .85), borderRadius: BorderRadius.circular(18), border: Border.all(color: active || winner ? accent : (dark ? const Color(0xFF3A3258) : const Color(0xFFE4DEF7)), width: active || winner ? 1.7 : 1), boxShadow: active || winner ? [BoxShadow(color: accent.withValues(alpha: .13), blurRadius: 10, offset: const Offset(0, 3))] : null),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: accent, shape: BoxShape.circle), alignment: Alignment.center, child: Text(name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))),
          Positioned(right: -5, bottom: -2, child: Container(width: 19, height: 19, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: accent.withValues(alpha: .3))), alignment: Alignment.center, child: Text(mark, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w900)))),
        ]),
        const SizedBox(height: 4),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        Text(username, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(color: active || winner ? accent : accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text(winner ? 'WINNER' : active ? 'YOUR TURN' : 'WAITING', maxLines: 1, style: TextStyle(fontSize: 8, letterSpacing: .2, fontWeight: FontWeight.w800, color: active || winner ? Colors.white : scheme.onSurfaceVariant))),
      ]),
    );
  }
}

Widget _smallReplayButton(bool loading, Future<void> Function() onPressed) => FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C4DF6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: loading ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Play again', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    );

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
  });

  final Map<String, dynamic> game;
  final String currentUsername;
  final String opponentUsername;
  final String opponentName;
  final bool sendingMove;
  final bool startingRematch;
  final Future<bool> Function(String move) onSendMove;
  final Future<void> Function() onPlayAgain;

  @override
  State<_RockPaperScissorsPanel> createState() => _RockPaperScissorsPanelState();
}

class _RockPaperScissorsPanelState extends State<_RockPaperScissorsPanel> with SingleTickerProviderStateMixin {
  static const _moves = ['rock', 'paper', 'scissors'];
  static const _labels = {'rock': 'Rock', 'paper': 'Paper', 'scissors': 'Scissors'};
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
  String _leftShuffle = 'rock';
  String _rightShuffle = 'paper';
  String _status = 'Pick your move';
  int _statusIndex = 0;
  int _lastRound = 0;
  int? _roundOverride;

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
    _lastRound = (_data['round'] as num?)?.toInt() ?? 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncGame();
    });
  }

  @override
  void didUpdateWidget(covariant _RockPaperScissorsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game['data'] != widget.game['data'] ||
        oldWidget.game['state'] != widget.game['state']) {
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
        _roundOverride = null;
        _revealed = false;
        _isCountingDown = false;
        _selectedMove = null;
        _error = null;
        _status = 'Pick your move';
      });
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
    setState(() {
      _roundTransitioning = false;
      _roundOverride = null;
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
    final player1 = data['player1']?.toString() ?? '';
    final winningMove = winner.toLowerCase() == player1.toLowerCase()
        ? p1Move
        : p2Move;
    final losingMove = winningMove == p1Move ? p2Move : p1Move;
    final result = isTie
        ? 'It’s a tie'
        : '${_cap(_labels[winningMove] ?? winningMove)} beats ${_cap(_labels[losingMove] ?? losingMove)} · ${iWon ? 'You win' : _opponentLabel} wins the round';
    setState(() {
      _isCountingDown = false;
      _revealed = true;
      _status = _finished
          ? (iWon ? 'You win the match!' : '$_opponentLabel wins the match!')
          : result;
    });
    if (_finished) return;
    _nextRoundTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _roundTransitioning = true;
        _roundOverride = round + 1;
        _revealed = false;
        _selectedMove = null;
        _error = null;
        _status = 'Pick your move';
      });
    });
  }

  String _cap(String value) => value.isEmpty
      ? value
      : '${value[0].toUpperCase()}${value.substring(1)}';

  Future<void> _pickMove(String move) async {
    if (!_canPick || widget.sendingMove) return;
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
    if (opponentLocked) return '$_opponentLabel is ready · pick your move';
    return 'Pick your move';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final myMove = _myMove;
    final opponentLocked = !_roundTransitioning &&
        !_isCountingDown &&
        !_revealed &&
        data['roundResolved'] != true &&
        _opponentServerMove != null;
    final bothLocked = !_roundTransitioning &&
        (_isCountingDown || _revealed || data['roundResolved'] == true);
    final displayRound = _roundOverride ?? (data['round'] as num?)?.toInt() ?? 1;
    final p1Score = (data['p1Score'] as num?)?.toInt() ?? 0;
    final p2Score = (data['p2Score'] as num?)?.toInt() ?? 0;
    final myScore = _isPlayer1 ? p1Score : p2Score;
    final otherScore = _isPlayer1 ? p2Score : p1Score;
    final myTag = _finished ? 'FINAL' : _revealed ? 'ROUND OVER' : (myMove != null || bothLocked) ? 'LOCKED IN' : 'THINKING';
    final otherTag = _finished ? 'FINAL' : _revealed ? 'ROUND OVER' : (opponentLocked || bothLocked) ? 'LOCKED IN' : 'THINKING';
    final showMoves = _revealed;
    final leftMove = _isCountingDown ? _leftShuffle : showMoves ? data['p1Move']?.toString() : null;
    final rightMove = _isCountingDown ? _rightShuffle : showMoves ? data['p2Move']?.toString() : null;
    final roundWinner = data['roundWinner']?.toString() ?? '';
    final leftWin = showMoves && roundWinner.toLowerCase() == (data['player1']?.toString() ?? '').toLowerCase();
    final rightWin = showMoves && roundWinner.toLowerCase() == (data['player2']?.toString() ?? widget.opponentUsername).toLowerCase();
    final tied = showMoves && roundWinner == 'draw';
    final status = _error ?? (_revealed && _finished
        ? (_winnerIsMe ? 'You win the match!' : '$_opponentLabel wins the match!')
        : _statusFor(opponentLocked, myMove, bothLocked));
    final enabled = _canPick && !widget.sendingMove;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [dark ? const Color(0xFF17132A) : const Color(0xFFF0EBFF), dark ? const Color(0xFF241A3C) : const Color(0xFFE7DFFF)]),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(children: [
        Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rock Paper Scissors', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text('Playing with $_opponentFullName', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11)),
        ])),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(child: _RpsPlayerCard(name: 'You', username: '@${widget.currentUsername}', mark: _initial(widget.currentUsername), accent: const Color(0xFF6C4DF6), status: myTag, active: !_finished)),
          SizedBox(width: 48, child: Column(children: [
            Text('$myScore : $otherScore', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            Text(_finished ? 'FINAL' : 'ROUND $displayRound', textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(fontSize: 7, letterSpacing: .3, color: scheme.onSurfaceVariant)),
          ])),
          Expanded(child: _RpsPlayerCard(name: _opponentFullName, username: '@${widget.opponentUsername}', mark: _initial(_opponentFullName), accent: const Color(0xFFC42A72), status: otherTag, active: !_finished)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(status, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
          if (_finished) ...[const SizedBox(width: 7), _smallReplayButton(widget.startingRematch, widget.onPlayAgain)],
        ]),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _RpsPad(move: leftMove, accent: const Color(0xFF6C4DF6), shake: _isCountingDown, pop: _revealed, winner: leftWin, loser: showMoves && !leftWin && !tied, animation: _shakeController)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: _RpsVsBadge()),
          Expanded(child: _RpsPad(move: rightMove, accent: const Color(0xFFC42A72), shake: _isCountingDown, pop: _revealed, winner: rightWin, loser: showMoves && !rightWin && !tied, animation: _shakeController)),
        ]),
        const SizedBox(height: 13),
        Align(alignment: Alignment.centerLeft, child: Text('CHOOSE YOUR MOVE', style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 9))),
        const SizedBox(height: 8),
        Row(children: _moves.map((move) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _RpsMoveTile(move: move, selected: myMove == move, enabled: enabled, onTap: () => _pickMove(move)),
        ))).toList()),
        if (widget.sendingMove) ...[const SizedBox(height: 7), const LinearProgressIndicator(minHeight: 2)],
      ]),
    );
  }
}
