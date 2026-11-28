import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../services/socket_service.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({
    super.key,
    required this.currentUsername,
    required this.initialGame,
    this.messageId,
    this.peerUsername = '',
    this.randomSessionId,
    this.opponentDisplayName,
    this.isGroup = false,
  });

  final String currentUsername;
  final Map<String, dynamic> initialGame;
  final String? messageId;
  final String peerUsername;
  final String? randomSessionId;
  final String? opponentDisplayName;
  final bool isGroup;

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  static const _lightSquare = Color(0xFFF0D9B5);
  static const _darkSquare = Color(0xFFB58863);
  static const _whitePieces = 'KQRBNP';
  static const _blackPieces = 'kqrbnp';

  final TextEditingController _chatController = TextEditingController();
  SocketService? _socket;
  Map<String, dynamic> _game = <String, dynamic>{};
  Timer? _clockTimer;
  int _now = DateTime.now().millisecondsSinceEpoch;
  int? _selected;
  bool _busy = false;
  bool _movesTab = false;
  bool _voiceNoticeShown = false;
  bool _timeoutClaimSent = false;
  String _message = '';

  String get _user => widget.currentUsername.trim().toLowerCase();
  Map<String, dynamic> get _data {
    final raw = _game['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }
  String get _fen => _data['fen']?.toString() ??
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  List<String> get _moves => (_data['moves'] is List)
      ? (_data['moves'] as List).map((e) => e.toString()).toList()
      : <String>[];
  List<String> get _legal => (_data['legalMoves'] is List)
      ? (_data['legalMoves'] as List).map((e) => e.toString()).toList()
      : <String>[];
  bool get _finished => _game['state']?.toString() == 'finished';
  bool get _myTurn => !_finished && _game['turn']?.toString().toLowerCase() == _user;
  String get _drawOffer => _data['drawOfferBy']?.toString().toLowerCase() ?? '';

  @override
  void initState() {
    super.initState();
    _game = Map<String, dynamic>.from(widget.initialGame);
    unawaited(SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now().millisecondsSinceEpoch);
      final whiteTurn = _fen.split(' ').length > 1 && _fen.split(' ')[1] != 'b';
      if (!_finished && !_timeoutClaimSent && _time(whiteTurn) <= 0) {
        _timeoutClaimSent = true;
        unawaited(_sendAction('claim_timeout'));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _socket = context.read<SocketService>();
      _socket!.addListener(_syncFromSocket);
      _syncFromSocket();
      final clockStartedAt = (_data['lastMoveAt'] as num?)?.toInt() ?? 0;
      if (clockStartedAt <= 0) unawaited(_sendAction('start_clock'));
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _socket?.removeListener(_syncFromSocket);
    _chatController.dispose();
    unawaited(SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]));
    super.dispose();
  }

  void _syncFromSocket() {
    if (!mounted || _socket == null) return;
    Map<String, dynamic>? latest;
    final session = widget.randomSessionId;
    if (session != null && session.isNotEmpty) {
      final value = _socket!.randomGameFor(session);
      if (value != null) latest = Map<String, dynamic>.from(value);
    } else {
      for (final message in _socket!.messages) {
        if (message.id == widget.messageId && message.game != null) {
          latest = Map<String, dynamic>.from(message.game!);
          break;
        }
      }
    }
    if (latest != null) {
      setState(() {
        _game = latest!;
        _selected = null;
      });
    }
  }

  List<String> _boardFromFen() {
    final output = <String>[];
    final placement = _fen.split(' ').first;
    for (final rank in placement.split('/')) {
      for (final token in rank.split('')) {
        final count = int.tryParse(token);
        if (count != null) {
          output.addAll(List<String>.filled(count, ''));
        } else {
          output.add(token);
        }
      }
    }
    return output.length == 64 ? output : List<String>.filled(64, '');
  }

  String _square(int index) =>
      'abcdefgh'[index % 8] + (8 - index ~/ 8).toString();

  int _squareIndex(String value) {
    if (value.length != 2) return -1;
    final file = value.codeUnitAt(0) - 97;
    final rank = int.tryParse(value[1]);
    if (file < 0 || file > 7 || rank == null || rank < 1 || rank > 8) return -1;
    return (8 - rank) * 8 + file;
  }

  Set<int> get _targets {
    if (_selected == null) return <int>{};
    final from = _square(_selected!);
    return _legal
        .where((move) => move.length >= 4 && move.substring(0, 2) == from)
        .map((move) => _squareIndex(move.substring(2, 4)))
        .where((square) => square >= 0)
        .toSet();
  }

  Future<void> _tapSquare(int index, List<String> board) async {
    if (!_myTurn || _busy || _finished) return;
    final piece = board[index];
    final whiteToMove = (_fen.split(' ').length > 1 && _fen.split(' ')[1] != 'b');
    final owned = piece.isNotEmpty &&
        (whiteToMove ? _whitePieces.contains(piece) : _blackPieces.contains(piece));
    if (_selected == null) {
      if (owned) setState(() { _selected = index; _message = ''; });
      return;
    }
    if (owned) {
      setState(() => _selected = index == _selected ? null : index);
      return;
    }
    final from = _square(_selected!);
    final to = _square(index);
    final candidates = _legal.where((move) =>
        move.length >= 4 && move.substring(0, 2) == from && move.substring(2, 4) == to).toList();
    if (candidates.isEmpty) {
      setState(() {
        _selected = null;
        _message = 'That move is not legal.';
      });
      return;
    }
    var move = candidates.first;
    if (candidates.length > 1) {
      final promotion = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Promote pawn'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'q'), child: const Text('Queen')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'r'), child: const Text('Rook')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'b'), child: const Text('Bishop')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'n'), child: const Text('Knight')),
          ],
        ),
      );
      if (promotion == null || !mounted) return;
      move = candidates.firstWhere((candidate) => candidate.endsWith(promotion));
    }
    await _sendMove(move);
  }

  Future<void> _sendMove(String move) => _sendActionData({'move': move});

  Future<void> _sendAction(String action) => _sendActionData({'action': action});

  Future<void> _sendActionData(Map<String, dynamic> payload) async {
    if (_busy) return;
    setState(() { _busy = true; _message = ''; });
    try {
      final socket = _socket ?? context.read<SocketService>();
      final result = widget.randomSessionId != null
          ? await socket.moveRandomGame(widget.randomSessionId!, payload)
          : await socket.makeGameMove(widget.messageId ?? '', widget.peerUsername, payload, isGroup: widget.isGroup);
      if (result['game'] is Map && mounted) {
        setState(() {
          _game = Map<String, dynamic>.from(result['game'] as Map);
          _selected = null;
          _timeoutClaimSent = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() {
        _selected = null;
        if (payload['action'] == 'claim_timeout') _timeoutClaimSent = false;
        _message = error is StateError ? error.message.toString() : 'Could not sync this move. Reconnect and retry.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Chess match?'),
        content: Text(_finished
            ? 'Return to Games?'
            : 'Leaving now will forfeit this match.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Leave match')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _sendChat() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || widget.randomSessionId != null || widget.peerUsername.trim().isEmpty) return;
    try {
      await (_socket ?? context.read<SocketService>()).sendMessage(text, widget.peerUsername);
      _chatController.clear();
    } catch (error) {
      if (mounted) setState(() => _message = error is StateError ? error.message.toString() : 'Message could not be sent.');
    }
  }

  int _time(bool white) {
    final base = ((white ? _data['whiteTimeMs'] : _data['blackTimeMs']) as num?)?.toInt() ?? 300000;
    final whiteTurn = (_fen.split(' ').length > 1 && _fen.split(' ')[1] != 'b');
    if (white != whiteTurn || _finished) return math.max(0, base).toInt();
    final started = (_data['lastMoveAt'] as num?)?.toInt() ?? 0;
    if (started <= 0) return base;
    return math.max(0, base - math.max(0, _now - started)).toInt();
  }

  String _formatClock(bool white) {
    final seconds = (_time(white) / 1000).floor();
    return (seconds ~/ 60).toString().padLeft(2, '0') + ':' +
        (seconds % 60).toString().padLeft(2, '0');
  }

  String _playerName(bool white) {
    final value = (white ? _data['whiteName'] : _data['blackName'])?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
    return (white ? _data['white'] : _data['black'])?.toString() ?? (white ? 'White' : 'Black');
  }

  String _status() {
    if (_finished) {
      final winner = _game['winner']?.toString() ?? '';
      if (winner == 'draw') return 'Draw · ' + (_data['endReason']?.toString() ?? '').replaceAll('_', ' ');
      return winner == _user ? 'You won' : (winner.isEmpty ? 'Match finished' : winner + ' won');
    }
    final whiteTurn = (_fen.split(' ').length > 1 && _fen.split(' ')[1] != 'b');
    return (whiteTurn ? 'White' : 'Black') + ' to move' + (_data['check'] == true ? ' · Check' : '');
  }

  void _voiceInfo(String label) {
    if (_voiceNoticeShown) return;
    _voiceNoticeShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label + ' voice transport is not connected to Chess yet.')),
    );
  }

  Widget _playerCard(bool white, Color foreground, Color muted, Color panel, Color accent) {
    final active = !_finished && ((_fen.split(' ').length > 1 && _fen.split(' ')[1] != 'b')) == white;
    final mine = (white ? _data['white'] : _data['black'])?.toString().toLowerCase() == _user;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: active ? accent : accent.withValues(alpha: .2), width: active ? 1.6 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: white ? const Color(0xFFE8D6BC) : const Color(0xFF35304F),
            child: Text(_playerName(white).isEmpty ? '?' : _playerName(white)[0].toUpperCase(),
              style: TextStyle(color: white ? const Color(0xFF332515) : Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 4),
          Text(_playerName(white), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 11)),
          if (mine) Text('YOU', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(color: active ? accent.withValues(alpha: .14) : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.timer_outlined, size: 14, color: active ? accent : muted),
              const SizedBox(width: 4),
              Text(_formatClock(white), style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 15)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _board(Color accent) {
    final pieces = _boardFromFen();
    final targets = _targets;
    final last = _data['lastMove']?.toString() ?? '';
    final lastFrom = last.length >= 4 ? _squareIndex(last.substring(0, 2)) : -1;
    final lastTo = last.length >= 4 ? _squareIndex(last.substring(2, 4)) : -1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 64,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemBuilder: (context, index) {
          final row = index ~/ 8;
          final col = index % 8;
          final light = (row + col).isEven;
          final isLast = index == lastFrom || index == lastTo;
          final color = index == _selected
              ? const Color(0xFFE7D34D)
              : isLast ? const Color(0xFF91B95B) : light ? _lightSquare : _darkSquare;
          final piece = pieces[index];
          return GestureDetector(
            onTap: () => _tapSquare(index, pieces),
            child: Container(
              color: color,
              child: Stack(fit: StackFit.expand, children: [
                if (piece.isNotEmpty)
                  Center(child: FittedBox(child: Text(_glyph(piece),
                    style: TextStyle(fontSize: 38, color: _whitePieces.contains(piece) ? const Color(0xFFFFFEF7) : const Color(0xFF171717),
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 2))])))),
                if (targets.contains(index))
                  Center(child: Container(
                    width: piece.isNotEmpty ? 30 : 12,
                    height: piece.isNotEmpty ? 30 : 12,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: piece.isNotEmpty ? Colors.transparent : const Color(0x80336B3A),
                      border: piece.isNotEmpty ? Border.all(color: const Color(0xFF336B3A), width: 3) : null),
                  )),
                if (col == 0) Positioned(left: 3, top: 1, child: Text((8 - row).toString(),
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: light ? _darkSquare : _lightSquare))),
                if (row == 7) Positioned(right: 3, bottom: 0, child: Text('abcdefgh'[col],
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: light ? _darkSquare : _lightSquare))),
              ]),
            ),
          );
        },
      ),
    );
  }

  String _glyph(String piece) {
    const glyphs = {
      'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
      'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟︎',
    };
    return glyphs[piece] ?? '';
  }

  Widget _pillAction(String label, IconData icon, Color foreground, Color panel, VoidCallback? action) =>
    Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: OutlinedButton.icon(
        onPressed: _busy ? null : action,
        icon: Icon(icon, size: 14),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground, backgroundColor: panel,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          side: BorderSide(color: foreground.withValues(alpha: .16)),
          shape: const StadiumBorder(),
        ),
      ),
    ));

  Widget _rightPanel(Color foreground, Color muted, Color panel, Color accent) {
    final messages = _socket?.messages ?? [];
    final directMessages = messages.where((message) =>
      message.chatId.toLowerCase() == widget.peerUsername.toLowerCase()).toList();
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17),
        border: Border.all(color: accent.withValues(alpha: .18))),
      child: Column(children: [
        Row(children: [
          Expanded(child: _tab('Chat', Icons.chat_bubble_outline_rounded, !_movesTab, foreground, accent,
            () => setState(() => _movesTab = false))),
          const SizedBox(width: 5),
          Expanded(child: _tab('Moves', Icons.history_rounded, _movesTab, foreground, accent,
            () => setState(() => _movesTab = true))),
        ]),
        const SizedBox(height: 6),
        Expanded(child: _movesTab
          ? _moveHistory(foreground, muted)
          : directMessages.isEmpty
            ? Center(child: Text(widget.randomSessionId == null ? 'Your match chat appears here.' : 'Public match chat is not available yet.',
                textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 10)))
            : ListView.builder(itemCount: directMessages.length, itemBuilder: (context, index) {
                final message = directMessages[index];
                final mine = message.isFromMe;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: mine ? accent : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(11)),
                    child: Text(message.text, style: TextStyle(color: mine ? Colors.white : foreground, fontSize: 10)),
                  ),
                );
              })),
        if (!_movesTab) ...[
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: TextField(
              controller: _chatController,
              enabled: widget.randomSessionId == null && widget.peerUsername.isNotEmpty,
              minLines: 1, maxLines: 2,
              style: TextStyle(color: foreground, fontSize: 10),
              decoration: InputDecoration(
                hintText: widget.randomSessionId == null ? 'Message…' : 'Chat unavailable',
                hintStyle: TextStyle(color: muted, fontSize: 10),
                isDense: true, filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _sendChat(),
            )),
            const SizedBox(width: 4),
            IconButton.filled(onPressed: _sendChat, visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.send_rounded, size: 15)),
          ]),
        ],
      ]),
    );
  }

  Widget _tab(String label, IconData icon, bool active, Color foreground, Color accent, VoidCallback onTap) =>
    InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: active ? accent : Colors.transparent, borderRadius: BorderRadius.circular(13)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13, color: active ? Colors.white : foreground),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: active ? Colors.white : foreground, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      ),
    );

  Widget _moveHistory(Color foreground, Color muted) {
    if (_moves.isEmpty) return Center(child: Text('Moves will appear here', style: TextStyle(color: muted, fontSize: 10)));
    return ListView.builder(
      itemCount: (_moves.length / 2).ceil(),
      itemBuilder: (context, index) {
        final white = _moves[index * 2];
        final black = index * 2 + 1 < _moves.length ? _moves[index * 2 + 1] : '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(children: [
            SizedBox(width: 20, child: Text((index + 1).toString() + '.', style: TextStyle(color: muted, fontSize: 10))),
            Expanded(child: Text(_prettyMove(white), style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(child: Text(_prettyMove(black), style: TextStyle(color: foreground, fontSize: 10))),
          ]),
        );
      },
    );
  }

  String _prettyMove(String move) => move.length < 4 ? move :
      move.substring(0, 2) + '–' + move.substring(2, 4) + (move.length > 4 ? '=' + move.substring(4).toUpperCase() : '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = theme.colorScheme.primary;
    final dark = theme.brightness == Brightness.dark;
    final panel = theme.colorScheme.surfaceContainerHighest.withValues(alpha: dark ? .78 : .95);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _confirmLeave(); },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < constraints.maxHeight) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.screen_rotation_rounded, color: accent, size: 42),
              const SizedBox(height: 10),
              Text('Rotate your phone to play Chess',
                style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 17)),
            ]));
          }
          final leftWidth = (constraints.maxWidth * .21).clamp(128.0, 225.0).toDouble();
          final rightWidth = (constraints.maxWidth * .245).clamp(150.0, 270.0).toDouble();
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 8, 7),
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: _confirmLeave, visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.arrow_back_rounded, color: foreground)),
                Text('NOVYN  /  GAMES', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
                const Spacer(),
                Icon(Icons.workspace_premium_rounded, color: accent, size: 17),
                const SizedBox(width: 5),
                Text('Chess · 1v1 Online', style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 13)),
                const Spacer(),
                Icon(_socket?.isConnected == true ? Icons.signal_cellular_alt_rounded : Icons.signal_wifi_off_rounded,
                  color: _socket?.isConnected == true ? Colors.green : Colors.orange, size: 16),
                const SizedBox(width: 5),
                Text(_socket?.isConnected == true ? 'Live' : 'Reconnecting',
                  style: TextStyle(color: muted, fontSize: 10)),
                IconButton(onPressed: _confirmLeave, visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_horiz_rounded, color: foreground)),
              ]),
              Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(width: leftWidth, child: Column(children: [
                  _playerCard(false, foreground, muted, panel, accent),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text('VS', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900))),
                  _playerCard(true, foreground, muted, panel, accent),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
                    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(15)),
                    child: Row(children: [
                      Expanded(child: _voiceControl(Icons.mic_none_rounded, 'Mic', foreground, muted, () => _voiceInfo('Mic'))),
                      Container(width: 1, height: 31, color: muted.withValues(alpha: .25)),
                      Expanded(child: _voiceControl(Icons.volume_up_rounded, 'Sound', foreground, muted, () => _voiceInfo('Sound'))),
                    ]),
                  ),
                ])),
                const SizedBox(width: 8),
                Expanded(child: Column(children: [
                  Expanded(child: LayoutBuilder(builder: (context, boardConstraints) {
                    final size = math.min(boardConstraints.maxWidth, boardConstraints.maxHeight).toDouble();
                    return Center(child: SizedBox(width: size, height: size, child: _board(accent)));
                  })),
                  SizedBox(height: 36, child: Row(children: [
                    _pillAction('Resign', Icons.flag_rounded, foreground, panel, _finished ? null : () => _sendAction('resign')),
                    if (_data['canClaimDraw'] == true && !_finished)
                      _pillAction('Claim Draw', Icons.handshake_rounded, foreground, panel, () => _sendAction('claim_draw'))
                    else if (_drawOffer.isNotEmpty && _drawOffer != _user) ...[
                      _pillAction('Accept Draw', Icons.handshake_rounded, foreground, panel, () => _sendAction('draw_accept')),
                      _pillAction('Decline', Icons.close_rounded, foreground, panel, () => _sendAction('draw_decline')),
                    ] else
                      _pillAction(_drawOffer == _user ? 'Draw Offered' : 'Offer Draw', Icons.handshake_rounded,
                        foreground, panel, _finished || _drawOffer.isNotEmpty ? null : () => _sendAction('draw_offer')),
                    if (_finished)
                      _pillAction('Rematch', Icons.refresh_rounded, foreground, panel, () {
                        final rematch = _data['rematch'];
                        if (rematch is Map && rematch['status'] == 'pending') {
                          _sendAction(rematch['requestedBy']?.toString().toLowerCase() == _user
                              ? 'rematch_cancel' : 'rematch_accept');
                        } else {
                          _sendAction('rematch_request');
                        }
                      }),
                  ])),
                  Padding(padding: const EdgeInsets.only(top: 3),
                    child: Text(_message.isNotEmpty ? _message : _status(),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _message.isNotEmpty ? theme.colorScheme.error : muted,
                        fontSize: 10, fontWeight: FontWeight.w700))),
                ])),
                const SizedBox(width: 8),
                SizedBox(width: rightWidth, child: _rightPanel(foreground, muted, panel, accent)),
              ])),
            ]),
          );
        })),
      ),
    );
  }

  Widget _voiceControl(IconData icon, String label, Color foreground, Color muted, VoidCallback onTap) =>
    InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(children: [
          Icon(icon, color: muted, size: 19),
          Text(label, style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800)),
          Text('Soon', style: TextStyle(color: muted, fontSize: 8)),
        ]),
      ));
}
