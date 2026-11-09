import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';

class GameMessageCard extends StatefulWidget {
  final String messageId;
  final Map<String, dynamic> game;
  final String currentUsername;
  final String peerUsername;

  const GameMessageCard({
    super.key,
    required this.messageId,
    required this.game,
    required this.currentUsername,
    required this.peerUsername,
  });

  @override
  State<GameMessageCard> createState() => _GameMessageCardState();
}

class _GameMessageCardState extends State<GameMessageCard> {
  final TextEditingController _number = TextEditingController();
  final TextEditingController _guess = TextEditingController();
  List<Map<String, dynamic>> _strokes = [];

  @override
  void didUpdateWidget(covariant GameMessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStrokes = oldWidget.game['data'] is Map ? (oldWidget.game['data'] as Map)['strokes'] : null;
    final newStrokes = widget.game['data'] is Map ? (widget.game['data'] as Map)['strokes'] : null;
    if (oldStrokes != newStrokes && newStrokes is List) {
      _strokes = newStrokes.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _guess.dispose();
    super.dispose();
  }

  String get _type => widget.game['gameType']?.toString() ?? '';
  String get _title => widget.game['title']?.toString() ?? 'Game';
  String get _creator => widget.game['createdBy']?.toString() ?? '';
  String get _opponent => widget.game['opponent']?.toString() ?? widget.peerUsername;
  String get _turn => widget.game['turn']?.toString() ?? '';
  String get _state => widget.game['state']?.toString() ?? 'in_progress';
  String get _winner => widget.game['winner']?.toString() ?? '';
  Map<String, dynamic> get _data => widget.game['data'] is Map
      ? Map<String, dynamic>.from(widget.game['data'])
      : <String, dynamic>{};
  bool get _myTurn => _turn.toLowerCase() == widget.currentUsername.toLowerCase();
  bool get _finished => _state == 'finished';

  void _move(Map<String, dynamic> data) {
    context.read<SocketService>().makeGameMove(
      widget.messageId,
      widget.peerUsername,
      data,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 258,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports_rounded, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(_title, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Text(_finished ? 'FINISHED' : 'LIVE', style: const TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _finished
                ? (_winner == 'draw' ? 'It\'s a draw!' : _winner.toLowerCase() == widget.currentUsername.toLowerCase() ? 'You won!' : '$_winner won')
                : _myTurn ? 'Your turn' : 'Waiting for opponent',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 10),
          if (_type == 'tictactoe') _ticTacToe(),
          if (_type == 'connect4') _connect4(),
          if (_type == 'rps') _rockPaperScissors(),
          if (_type == 'numberclash') _numberClash(),
          if (_type == 'updown') _upDown(),
          if (_type == 'doodle') _doodle(),
        ],
      ),
    );
  }

  Widget _ticTacToe() {
    final board = _data['board'] is List ? List<dynamic>.from(_data['board']) : List<dynamic>.filled(9, null);
    final playerX = _data['playerX']?.toString() ?? _creator;
    final playerO = _data['playerO']?.toString() ?? _opponent;
    final canJoin = (_data['playerO'] == null || _data['playerO'] == '') &&
        widget.currentUsername.toLowerCase() != playerX.toLowerCase();
    final symbol = widget.currentUsername.toLowerCase() == playerX.toLowerCase() ? 'X' : 'O';
    return Column(
      children: [
        Text('@$playerX  ✕     @$playerO  ◯', style: const TextStyle(fontFamily: 'Inter', fontSize: 10)),
        const SizedBox(height: 8),
        SizedBox(
          width: 204,
          height: 204,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 5, mainAxisSpacing: 5),
            itemBuilder: (context, index) => InkWell(
              onTap: !_finished && (_myTurn || canJoin) && board[index] == null
                  ? () {
                      final next = List<dynamic>.from(board);
                      next[index] = symbol;
                      _move({'board': next, 'playerX': playerX, 'playerO': canJoin ? widget.currentUsername : playerO});
                    }
                  : null,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  board[index] == 'X' ? '✕' : board[index] == 'O' ? '◯' : '',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: board[index] == 'X' ? const Color(0xFF64748B) : const Color(0xFF0EA5E9)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _connect4() {
    final board = _data['board'] is List ? List<dynamic>.from(_data['board']) : List<dynamic>.filled(42, null);
    final player1 = _data['player1']?.toString() ?? _creator;
    final chip = widget.currentUsername.toLowerCase() == player1.toLowerCase() ? 'R' : 'Y';
    return Column(
      children: [
        Text('@$player1   VS   @$player2', style: const TextStyle(fontFamily: 'Inter', fontSize: 10)),
        const SizedBox(height: 8),
        Row(
          children: List.generate(7, (column) => Expanded(
            child: TextButton(
              onPressed: !_finished && _myTurn ? () {
                final next = List<dynamic>.from(board);
                for (var row = 5; row >= 0; row--) {
                  final index = row * 7 + column;
                  if (next[index] == null) {
                    next[index] = chip;
                    _move({'board': next});
                    break;
                  }
                }
              } : null,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 25)),
              child: const Icon(Icons.arrow_downward_rounded, size: 13),
            ),
          )),
        ),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 3, mainAxisSpacing: 3),
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: board[index] == 'R' ? const Color(0xFF64748B) : board[index] == 'Y' ? const Color(0xFF0EA5E9) : Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rockPaperScissors() {
    final player1 = _data['player1']?.toString() ?? _creator;
    final player2 = _data['player2']?.toString() ?? _opponent;
    final isP1 = widget.currentUsername.toLowerCase() == player1.toLowerCase();
    final myMove = isP1 ? _data['p1Move'] : _data['p2Move'];
    final p1Move = _data['p1Move']?.toString();
    final p2Move = _data['p2Move']?.toString();
    const choices = {'rock': '🪨', 'paper': '📄', 'scissors': '✂️'};
    if (_finished || (p1Move != null && p2Move != null)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(choices[p1Move] ?? '…', style: const TextStyle(fontSize: 28)),
          const Text('VS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
          Text(choices[p2Move] ?? '…', style: const TextStyle(fontSize: 28)),
        ],
      );
    }
    if (myMove != null) return const Center(child: Text('Your move is locked. Waiting…', style: TextStyle(fontFamily: 'Inter', fontSize: 11)));
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: choices.entries.map((entry) => OutlinedButton(
        onPressed: () => _move({'move': entry.key}),
        child: Text(entry.value, style: const TextStyle(fontSize: 20)),
      )).toList(),
    );
  }

  Widget _numberClash() {
    final player1 = _data['player1']?.toString() ?? _creator;
    final isP1 = widget.currentUsername.toLowerCase() == player1.toLowerCase();
    final myNumber = isP1 ? _data['p1Number'] : _data['p2Number'];
    final p1 = _data['p1Number'];
    final p2 = _data['p2Number'];
    if (myNumber != null) {
      return Text(p1 != null && p2 != null ? '$p1  VS  $p2  •  Target ${_data['target']}' : 'Your number is locked. Waiting…',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700));
    }
    return Row(
      children: [
        Expanded(child: TextField(controller: _number, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '1–100', isDense: true))),
        const SizedBox(width: 7),
        IconButton(
          onPressed: () {
            final number = int.tryParse(_number.text.trim());
            if (number != null && number >= 1 && number <= 100) _move({'number': number});
          },
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }

  Widget _upDown() {
    final player1 = _data['player1']?.toString() ?? _creator;
    final isP1 = widget.currentUsername.toLowerCase() == player1.toLowerCase();
    final myPrediction = isP1 ? _data['p1Prediction'] : _data['p2Prediction'];
    if (myPrediction != null) {
      return Text('Prediction locked • ${_data['currentCard']} → ${_data['nextCard']}',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 12));
    }
    return Row(
      children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => _move({'prediction': 'higher'}), icon: const Icon(Icons.arrow_upward_rounded), label: const Text('Higher'))),
        const SizedBox(width: 7),
        Expanded(child: OutlinedButton.icon(onPressed: () => _move({'prediction': 'lower'}), icon: const Icon(Icons.arrow_downward_rounded), label: const Text('Lower'))),
      ],
    );
  }

  Widget _doodle() {
    final player1 = _data['player1']?.toString() ?? _creator;
    final isDrawer = widget.currentUsername.toLowerCase() == player1.toLowerCase();
    if (!isDrawer) {
      return Column(
        children: [
          const Text('Guess the drawing', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700)),
          TextField(
            controller: _guess,
            decoration: const InputDecoration(hintText: 'Your guess', isDense: true),
            onSubmitted: (value) => _move({'action': 'guess', 'guess': value}),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _move({'action': 'guess', 'guess': _guess.text}), child: const Text('Submit guess')),
          ),
        ],
      );
    }
    final raw = _data['strokes'];
    if (_strokes.isEmpty && raw is List) {
      _strokes = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final strokes = _strokes;
    return Column(
      children: [
        Text('Draw: ${_data['word'] ?? 'secret word'}', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700)),
        GestureDetector(
          onPanStart: (details) => setState(() => _strokes = [..._strokes, {'x1': details.localPosition.dx / 200, 'y1': details.localPosition.dy / 150, 'x2': details.localPosition.dx / 200, 'y2': details.localPosition.dy / 150}]),
          onPanUpdate: (details) {
            if (_strokes.isEmpty) return;
            final last = Map<String, dynamic>.from(_strokes.last);
            last['x2'] = details.localPosition.dx / 200;
            last['y2'] = details.localPosition.dy / 150;
            setState(() => _strokes = [..._strokes.sublist(0, _strokes.length - 1), last]);
          },
          onPanEnd: (_) => _move({'action': 'draw', 'strokes': _strokes}),
          child: CustomPaint(
            size: const Size(200, 150),
            painter: _DoodlePainter(strokes),
            child: Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final List<Map<String, dynamic>> strokes;
  _DoodlePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF64748B)..strokeWidth = 3..strokeCap = StrokeCap.round;
    for (final stroke in strokes) {
      final x1 = (stroke['x1'] as num?)?.toDouble() ?? 0;
      final y1 = (stroke['y1'] as num?)?.toDouble() ?? 0;
      final x2 = (stroke['x2'] as num?)?.toDouble() ?? x1;
      final y2 = (stroke['y2'] as num?)?.toDouble() ?? y1;
      canvas.drawLine(Offset(x1 * size.width, y1 * size.height), Offset(x2 * size.width, y2 * size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => oldDelegate.strokes != strokes;
}
