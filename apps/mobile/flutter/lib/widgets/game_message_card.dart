import 'dart:async';

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
  final bool isGroup;
  final bool compact;
  final String? randomSessionId;

  const GameMessageCard({
    super.key,
    required this.messageId,
    required this.game,
    required this.currentUsername,
    required this.peerUsername,
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

  Future<void> _move(Map<String, dynamic> data) async {
    if (_sendingMove || _finished) return;
    final previousData = _optimisticData;
    setState(() {
      _sendingMove = true;
      _optimisticData = Map<String, dynamic>.from(data);
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
    } finally {
      if (mounted) setState(() => _sendingMove = false);
    }
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
            onPressed: () {
              Navigator.of(context).push<void>(
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
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildSummary(context);
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
          if (_type == 'tictactoe') _ticTacToe(),
          if (_type == 'rps') _rockPaperScissors(),
          if (_finished &&
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

  Widget _ticTacToe() {
    final board = _data['board'] is List
        ? List<dynamic>.from(_data['board'])
        : List<dynamic>.filled(9, null);
    final playerX = _data['playerX']?.toString() ?? _creator;
    final playerO = _data['playerO']?.toString() ??
        (widget.isGroup ? 'Waiting for player' : _opponent);
    final canJoin = widget.isGroup &&
        playerO == 'Waiting for player' &&
        board.any((cell) => cell != null) &&
        widget.currentUsername.toLowerCase() != playerX.toLowerCase();
    final symbol =
        widget.currentUsername.toLowerCase() == playerX.toLowerCase() ? 'X' : 'O';
    final rawWinningLine = _data['winningLine'];
    final winningCells = rawWinningLine is List
        ? rawWinningLine
            .whereType<num>()
            .map((index) => index.toInt())
            .where((index) => index >= 0 && index < 9)
            .toSet()
        : <int>{};
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _gamePlayerCard('@$playerX', 'X', colors.primary, _myTurn && !_finished)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('VS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: colors.onSurfaceVariant)),
            ),
            Expanded(child: _gamePlayerCard('@$playerO', 'O', colors.tertiary, !_myTurn && !_finished && !_canJoinGroup)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final isWinningCell = winningCells.contains(index);
              final value = board[index]?.toString();
              final canTap = !_finished &&
                  !_sendingMove &&
                  (_myTurn || canJoin) &&
                  value == null;
              final position = 'Row ${index ~/ 3 + 1}, column ${index % 3 + 1}';
              final cellLabel = value == null ? 'empty' : value;
              return Semantics(
                button: canTap,
                enabled: canTap,
                label: '$position, $cellLabel${isWinningCell ? ', winning line' : ''}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: canTap
                      ? () {
                          final next = List<dynamic>.from(board);
                          next[index] = symbol;
                          _move({
                            'board': next,
                            'playerX': playerX,
                            'playerO': canJoin ? widget.currentUsername : playerO,
                          });
                        }
                      : null,
                  child: Container(
                    key: ValueKey('tic-tac-toe-cell-$index'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isWinningCell
                            ? [colors.primaryContainer, colors.primaryContainer.withValues(alpha: .72)]
                            : [colors.surface, colors.surfaceContainerHighest],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isWinningCell
                            ? colors.primary
                            : colors.outlineVariant.withValues(alpha: .55),
                        width: isWinningCell ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(color: colors.shadow.withValues(alpha: .09), blurRadius: 7, offset: const Offset(0, 4)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      value == 'X' ? '×' : value == 'O' ? '○' : '',
                      style: TextStyle(
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        color: value == 'X' ? colors.primary : colors.tertiary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _gamePlayerCard(String name, String mark, Color accent, bool active) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: .10) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? accent.withValues(alpha: .8) : scheme.outlineVariant.withValues(alpha: .5), width: active ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent.withValues(alpha: .14), shape: BoxShape.circle),
            child: Text(mark, style: TextStyle(color: accent, fontSize: 27, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(active ? 'YOUR TURN' : 'PLAYER', style: TextStyle(fontSize: 9, letterSpacing: .6, color: active ? accent : scheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
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

  Widget _rockPaperScissors() {
    final player1 = _data['player1']?.toString() ?? _creator;
    final isP1 = widget.currentUsername.toLowerCase() == player1.toLowerCase();
    final myMove = isP1 ? _data['p1Move'] : _data['p2Move'];
    final p1Move = _data['p1Move']?.toString();
    final p2Move = _data['p2Move']?.toString();
    final isP2 = _opponent.toLowerCase() == widget.currentUsername.toLowerCase();
    const moves = <String, (IconData, String)> {
      'rock': (Icons.pan_tool_rounded, 'Rock'),
      'paper': (Icons.back_hand_rounded, 'Paper'),
      'scissors': (Icons.content_cut_rounded, 'Scissors'),
    };
    final canChoose = !_finished && myMove == null && (isP1 || isP2 || _canJoinGroup);
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _gamePlayerCard('@$player1', 'P1', accent, isP1 && myMove == null && !_finished)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('VS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: _gamePlayerCard('@$_opponent', 'P2', const Color(0xFFE8458B), isP2 && myMove == null && !_finished)),
          ],
        ),
        const SizedBox(height: 18),
        if (p1Move != null && p2Move != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent.withValues(alpha: .12), const Color(0xFFE8458B).withValues(alpha: .10)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _moveReveal(moves[p1Move]!.$1, moves[p1Move]!.$2, accent),
                Text('VS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                _moveReveal(moves[p2Move]!.$1, moves[p2Move]!.$2, const Color(0xFFE8458B)),
              ],
            ),
          )
        else if (myMove != null)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text('Move locked · waiting for the other player', textAlign: TextAlign.center),
          )
        else if (!canChoose)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('This game already has two players.', textAlign: TextAlign.center),
          )
        else
          Row(
            children: moves.entries.map((entry) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _moveChoice(entry.key, entry.value.$1, entry.value.$2, accent),
              ),
            )).toList(),
          ),
      ],
    );
  }

  Widget _moveReveal(IconData icon, String label, Color accent) => Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: accent.withValues(alpha: .14), shape: BoxShape.circle),
            child: Icon(icon, color: accent, size: 34),
          ),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      );

  Widget _moveChoice(String move, IconData icon, String label, Color accent) => OutlinedButton(
        onPressed: _sendingMove ? null : () => _move({'move': move}),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
          side: BorderSide(color: accent.withValues(alpha: .25)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 26),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );

}