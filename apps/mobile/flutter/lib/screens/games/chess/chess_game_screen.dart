import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../services/chess_voice_service.dart';
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
  static const _lightSquare = Color(0xFFE9E3CE);
  static const _darkSquare = Color(0xFF4F817D);
  static const _whitePieces = 'KQRBNP';
  static const _blackPieces = 'kqrbnp';

  final TextEditingController _chatController = TextEditingController();
  SocketService? _socket;
  Map<String, dynamic> _game = <String, dynamic>{};
  Timer? _clockTimer;
  int _now = DateTime.now().millisecondsSinceEpoch;
  int? _selected;
  bool _busy = false;
  bool _sendingChat = false;
  bool _timeoutClaimSent = false;
  bool _voiceJoining = false;
  bool _voiceMediaStarting = false;
  bool _voiceMediaReady = false;
  bool _voiceIncoming = false;
  bool _voiceSpeakerEnabled = true;
  String _voiceStatus = 'off';
  String _voicePeerUsername = '';
  String? _voiceRoomId;
  final List<Map<String, dynamic>> _pendingVoiceSignals = <Map<String, dynamic>>[];
  ChessVoiceService? _voice;
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
  bool get _isWhite =>
      (_data['white'] ?? _data['player1'])?.toString().trim().toLowerCase() == _user;
  bool get _isBlack =>
      (_data['black'] ?? _data['player2'])?.toString().trim().toLowerCase() == _user;
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
      _socket!.onChessVoiceInviteCallback = _handleChessVoiceInvite;
      _socket!.onChessVoicePeerJoinedCallback = _handleChessVoicePeerJoined;
      _socket!.onChessVoiceSignalCallback = _handleChessVoiceSignal;
      _socket!.onChessVoicePeerLeftCallback = _handleChessVoicePeerLeft;
      _socket!.addListener(_syncFromSocket);
      _syncFromSocket();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _socket?.removeListener(_syncFromSocket);
    _socket?.onChessVoiceInviteCallback = null;
    _socket?.onChessVoicePeerJoinedCallback = null;
    _socket?.onChessVoiceSignalCallback = null;
    _socket?.onChessVoicePeerLeftCallback = null;
    _stopChessVoice(updateUi: false);
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
      if (_finished && _voiceRoomId != null) _stopChessVoice();
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
    if (text.isEmpty || _sendingChat) return;
    setState(() => _sendingChat = true);
    try {
      final socket = _socket ?? context.read<SocketService>();
      final sessionId = widget.randomSessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        await socket.sendRandomGameChat(sessionId, text);
      } else if (widget.peerUsername.trim().isNotEmpty) {
        await socket.sendMessage(text, widget.peerUsername);
      } else {
        return;
      }
      _chatController.clear();
    } catch (error) {
      if (mounted) setState(() => _message =
          error is StateError ? error.message.toString() : 'Message could not be sent.');
    } finally {
      if (mounted) setState(() => _sendingChat = false);
    }
  }

  bool _matchesChessVoiceMatch(Map<String, dynamic> packet) {
    if (widget.randomSessionId != null) {
      return packet['scope'] == 'random' &&
          packet['sessionId']?.toString() == widget.randomSessionId;
    }
    return packet['scope'] == 'friend' &&
        packet['messageId']?.toString() == widget.messageId;
  }

  void _handleChessVoiceInvite(Map<String, dynamic> packet) {
    if (!mounted || !_matchesChessVoiceMatch(packet) || _voiceRoomId != null ||
        _voice != null || _finished) return;
    setState(() {
      _voiceIncoming = true;
      _voiceRoomId = packet['roomId']?.toString();
      _voicePeerUsername = packet['peerUsername']?.toString() ?? widget.peerUsername;
      _voiceStatus = 'incoming';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your opponent invited you to Chess voice. Tap Join voice to connect.')),
    );
  }

  void _handleChessVoicePeerJoined(Map<String, dynamic> packet) {
    if (!mounted || packet['roomId']?.toString() != _voiceRoomId) return;
    _voicePeerUsername = packet['peerUsername']?.toString() ?? _voicePeerUsername;
    unawaited(_startChessVoiceMedia(
      _voicePeerUsername,
      packet['initiator'] == true,
    ));
  }

  Future<void> _handleChessVoiceSignal(Map<String, dynamic> packet) async {
    if (!mounted || packet['roomId']?.toString() != _voiceRoomId) return;
    final signal = packet['signal'];
    if (signal is! Map) return;
    final normalized = Map<String, dynamic>.from(signal);
    if (_voice == null || !_voiceMediaReady) {
      if (_pendingVoiceSignals.length < 32) _pendingVoiceSignals.add(normalized);
      return;
    }
    try {
      await _voice!.handleSignal(normalized);
    } catch (error) {
      debugPrint('[NovynChessVoice] Signal handling failed: $error');
    }
  }

  void _handleChessVoicePeerLeft(Map<String, dynamic> packet) {
    if (!mounted || packet['roomId']?.toString() != _voiceRoomId) return;
    _stopChessVoice(notifyServer: false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your opponent left Chess voice. The match is still active.')),
    );
  }

  Future<void> _toggleChessVoice() async {
    if (_voiceJoining || _voiceMediaStarting || _finished) return;
    final activeVoice = _voice;
    if (activeVoice != null) {
      activeVoice.setMuted(!activeVoice.isMuted);
      return;
    }
    if (_voiceRoomId != null && _voiceStatus == 'waiting') {
      _stopChessVoice();
      return;
    }

    final socket = _socket ?? context.read<SocketService>();
    setState(() {
      _voiceJoining = true;
      _voiceIncoming = false;
      _voiceStatus = 'connecting';
    });
    try {
      final result = await socket.joinChessVoice(
        scope: widget.randomSessionId != null ? 'random' : 'friend',
        sessionId: widget.randomSessionId,
        messageId: widget.messageId,
        peerUsername: widget.peerUsername,
      );
      if (!mounted) {
        socket.leaveChessVoice(result['roomId']?.toString() ?? '');
        return;
      }
      _voiceRoomId = result['roomId']?.toString();
      _voicePeerUsername = result['peerUsername']?.toString() ?? widget.peerUsername;
      if (result['peerReady'] == true) {
        await _startChessVoiceMedia(
          _voicePeerUsername,
          result['initiator'] == true,
        );
      } else {
        setState(() => _voiceStatus = 'waiting');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _voiceStatus = 'off';
          _voiceIncoming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error is StateError
              ? error.message.toString()
              : 'Could not join Chess voice. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _voiceJoining = false);
    }
  }

  Future<void> _startChessVoiceMedia(String peerUsername, bool isOfferer) async {
    final roomId = _voiceRoomId;
    if (roomId == null || roomId.isEmpty || _voice != null ||
        _voiceMediaStarting || _finished) return;
    _voiceMediaStarting = true;
    final service = ChessVoiceService();
    _voice = service;
    service.addListener(_onChessVoiceChanged);
    if (mounted) setState(() => _voiceStatus = 'connecting');
    try {
      await service.start(
        socket: _socket ?? context.read<SocketService>(),
        roomId: roomId,
        isOfferer: isOfferer,
      );
      await service.setSpeakerEnabled(_voiceSpeakerEnabled);
      _voicePeerUsername = peerUsername;
      _voiceMediaReady = true;
      final pending = List<Map<String, dynamic>>.from(_pendingVoiceSignals);
      _pendingVoiceSignals.clear();
      for (final signal in pending) {
        await service.handleSignal(signal);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error is StateError
              ? error.message.toString()
              : 'Could not start the microphone. Check your connection and permission.')),
        );
      }
      _stopChessVoice();
    } finally {
      _voiceMediaStarting = false;
    }
  }

  void _onChessVoiceChanged() {
    if (!mounted || _voice == null) return;
    setState(() => _voiceStatus = _voice!.status);
  }

  Future<void> _toggleChessVoiceSpeaker() async {
    final next = !_voiceSpeakerEnabled;
    setState(() => _voiceSpeakerEnabled = next);
    try {
      if (_voice != null) {
        await _voice!.setSpeakerEnabled(next);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _voiceSpeakerEnabled = !next);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not change the audio output.')),
        );
      }
    }
  }

  void _stopChessVoice({bool notifyServer = true, bool updateUi = true}) {
    final roomId = _voiceRoomId;
    _voiceRoomId = null;
    if (notifyServer && roomId != null) {
      _socket?.leaveChessVoice(roomId);
    }
    final service = _voice;
    _voice = null;
    _voiceMediaReady = false;
    _pendingVoiceSignals.clear();
    service?.removeListener(_onChessVoiceChanged);
    service?.dispose();
    _voiceIncoming = false;
    _voiceMediaStarting = false;
    if (updateUi && mounted) {
      setState(() => _voiceStatus = 'off');
    } else {
      _voiceStatus = 'off';
    }
  }

  String get _voiceMicLabel {
    if (_voiceJoining || _voiceMediaStarting || _voiceStatus == 'connecting') return 'Connecting';
    if (_voiceStatus == 'incoming') return 'Join voice';
    if (_voiceStatus == 'waiting') return 'Waiting';
    if (_voice?.isMuted == true) return 'Unmute';
    if (_voice?.isConnected == true) return 'Mute';
    return 'Mic';
  }

  String get _voiceMicHint {
    if (_voiceStatus == 'incoming') return 'Opponent invite';
    if (_voiceStatus == 'waiting') return 'Tap to cancel';
    if (_voiceStatus == 'connecting') return 'Connecting audio';
    if (_voiceStatus == 'reconnecting') return 'Reconnecting';
    if (_voice?.isConnected == true) return _voice!.isMuted ? 'Mic muted' : 'Voice live';
    return 'In-game voice';
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
    final isMe = white ? _isWhite : _isBlack;
    final opponentName = widget.opponentDisplayName?.trim() ?? '';
    if (!isMe && opponentName.isNotEmpty) return opponentName;
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

  Widget _playerCard(bool white, Color foreground, Color muted, Color panel, Color accent) {
    final whiteToMove = _fen.split(' ').length > 1 && _fen.split(' ')[1] != 'b';
    final active = !_finished && whiteToMove == white;
    final mine = (white ? _data['white'] : _data['black'])?.toString().toLowerCase() == _user;
    final name = _playerName(white);
    final timerColor = white ? accent : const Color(0xFF10131B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active ? accent : muted.withValues(alpha: .18),
          width: active ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? accent : muted.withValues(alpha: .3),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 23,
                  backgroundColor: white ? const Color(0xFFE8D6BC) : const Color(0xFF171923),
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                      color: white ? const Color(0xFF332515) : Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mine ? 'You · ' + (white ? 'White' : 'Black') : (white ? 'White' : 'Black'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'TURN',
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: timerColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              _formatClock(white),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(17),
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
                    style: TextStyle(fontSize: 48, color: _whitePieces.contains(piece) ? const Color(0xFFFFFEF7) : const Color(0xFF171717),
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

  Future<void> _openMatchPanel() async {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(screenSize.width * .76, 820.0);
    final dialogHeight = math.min(screenSize.height * .84, 620.0);
    var showMoves = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: .36),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final theme = Theme.of(dialogContext);
          final foreground = theme.colorScheme.onSurface;
          final muted = theme.colorScheme.onSurfaceVariant;
          final accent = theme.colorScheme.primary;
          final dark = theme.brightness == Brightness.dark;
          final panelColor = theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: dark ? .98 : 1);
          Widget content = _rightPanel(
            foreground,
            muted,
            panelColor,
            accent,
            showMoves,
            (value) => setDialogState(() => showMoves = value),
            () => Navigator.of(dialogContext).pop(),
          );
          final socket = _socket;
          if (socket != null) {
            content = AnimatedBuilder(
              animation: socket,
              builder: (context, _) => _rightPanel(
                foreground,
                muted,
                panelColor,
                accent,
                showMoves,
                (value) => setDialogState(() => showMoves = value),
                () => Navigator.of(dialogContext).pop(),
              ),
            );
          }
          return Dialog(
            backgroundColor: panelColor,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: dialogHeight,
            ),
            child: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _rightPanel(
    Color foreground,
    Color muted,
    Color panel,
    Color accent,
    bool showMoves,
    ValueChanged<bool> onTabChanged,
    VoidCallback onClose,
  ) {
    final messages = _socket?.messages ?? [];
    final directMessages = messages.where((message) =>
      message.chatId.toLowerCase() == widget.peerUsername.toLowerCase()).toList();
    final randomMessages = widget.randomSessionId == null
        ? const <Map<String, dynamic>>[]
        : (_socket?.randomGameChatFor(widget.randomSessionId!) ?? const <Map<String, dynamic>>[]);
    final hasMessages = widget.randomSessionId != null
        ? randomMessages.isNotEmpty
        : directMessages.isNotEmpty;
    final canChat = widget.randomSessionId != null || widget.peerUsername.isNotEmpty;

    Widget chatContent;
    if (!hasMessages) {
      chatContent = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 38, color: muted.withValues(alpha: .55)),
            const SizedBox(height: 12),
            Text(
              'No messages yet',
              style: TextStyle(color: foreground, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              canChat ? 'Send a message to your opponent.' : 'Match chat is unavailable for this game.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      );
    } else if (widget.randomSessionId != null) {
      chatContent = ListView.builder(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        itemCount: randomMessages.length,
        itemBuilder: (context, index) {
          final message = randomMessages[index];
          final mine = message['from']?.toString().toLowerCase() == _user;
          return Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: mine ? accent : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message['text']?.toString() ?? '',
                style: TextStyle(color: mine ? Colors.white : foreground, fontSize: 13),
              ),
            ),
          );
        },
      );
    } else {
      chatContent = ListView.builder(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        itemCount: directMessages.length,
        itemBuilder: (context, index) {
          final message = directMessages[index];
          final mine = message.isFromMe;
          return Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: mine ? accent : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: TextStyle(color: mine ? Colors.white : foreground, fontSize: 13),
              ),
            ),
          );
        },
      );
    }

    return Container(
      color: panel,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _tab(
                  'Chat',
                  Icons.chat_bubble_outline_rounded,
                  !showMoves,
                  foreground,
                  accent,
                  () => onTabChanged(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tab(
                  'Moves',
                  Icons.history_rounded,
                  showMoves,
                  foreground,
                  accent,
                  () => onTabChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onClose,
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, color: foreground, size: 26),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: muted.withValues(alpha: .16)),
          const SizedBox(height: 8),
          Expanded(
            child: showMoves ? _moveHistory(foreground, muted) : chatContent,
          ),
          if (!showMoves) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    enabled: canChat,
                    minLines: 1,
                    maxLines: 2,
                    style: TextStyle(color: foreground, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: canChat ? 'Message...' : 'Chat unavailable',
                      hintStyle: TextStyle(color: muted, fontSize: 13),
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendChat(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 50,
                  height: 50,
                  child: IconButton.filled(
                    onPressed: !canChat || _sendingChat ? null : _sendChat,
                    tooltip: 'Send message',
                    icon: const Icon(Icons.send_rounded, size: 21),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tab(String label, IconData icon, bool active, Color foreground, Color accent, VoidCallback onTap) =>
    InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(color: active ? accent : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: active ? Colors.white : foreground),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: active ? Colors.white : foreground, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      ),
    );

  Widget _moveHistory(Color foreground, Color muted) {
    if (_moves.isEmpty) {
      return Center(
        child: Text(
          'Moves will appear here',
          style: TextStyle(color: muted, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      itemCount: (_moves.length / 2).ceil(),
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: muted.withValues(alpha: .12),
      ),
      itemBuilder: (context, index) {
        final white = _moves[index * 2];
        final black = index * 2 + 1 < _moves.length ? _moves[index * 2 + 1] : '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  (index + 1).toString() + '.',
                  style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(
                  _prettyMove(white),
                  style: TextStyle(color: foreground, fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: Text(
                  _prettyMove(black),
                  style: TextStyle(color: foreground, fontSize: 14),
                ),
              ),
            ],
          ),
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
    final panel = theme.colorScheme.surfaceContainerHighest.withValues(alpha: dark ? .88 : .98);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < constraints.maxHeight) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.screen_rotation_rounded, color: accent, size: 42),
                      const SizedBox(height: 10),
                      Text(
                        'Rotate your phone to play Chess',
                        style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                    ],
                  ),
                );
              }

              final sideWidth = (constraints.maxWidth * .265)
                  .clamp(168.0, 360.0)
                  .toDouble();

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
                child: Column(
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _confirmLeave,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.arrow_back_rounded, color: foreground),
                          ),
                          Expanded(
                            child: Text(
                              'Chess · 1v1 Online',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: foreground,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Icon(
                            _socket?.isConnected == true
                                ? Icons.circle
                                : Icons.circle_outlined,
                            color: _socket?.isConnected == true ? Colors.green : Colors.orange,
                            size: 10,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _socket?.isConnected == true ? 'Live' : 'Reconnecting',
                            style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 13),
                          Material(
                            color: accent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: _openMatchPanel,
                              customBorder: const CircleBorder(),
                              child: const SizedBox(
                                width: 46,
                                height: 46,
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: sideWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _playerCard(false, foreground, muted, panel, accent),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _voiceControl(
                                      _voice?.isMuted == true
                                          ? Icons.mic_off_rounded
                                          : Icons.mic_none_rounded,
                                      _voiceMicLabel,
                                      foreground,
                                      muted,
                                      _toggleChessVoice,
                                      hint: _voiceMicHint,
                                      active: _voice?.isConnected == true && _voice?.isMuted != true,
                                    ),
                                    _voiceControl(
                                      _voiceSpeakerEnabled
                                          ? Icons.volume_up_rounded
                                          : Icons.hearing_rounded,
                                      _voiceSpeakerEnabled ? 'Speaker' : 'Earpiece',
                                      foreground,
                                      muted,
                                      _toggleChessVoiceSpeaker,
                                      hint: 'Audio output',
                                      active: _voiceSpeakerEnabled,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, boardConstraints) {
                                      final size = math.min(
                                        boardConstraints.maxWidth,
                                        boardConstraints.maxHeight,
                                      ).toDouble();
                                      return Center(
                                        child: SizedBox(
                                          width: size,
                                          height: size,
                                          child: _board(accent),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Text(
                                    _message.isNotEmpty ? _message : _status(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _message.isNotEmpty ? theme.colorScheme.error : muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w80
  Widget _voiceControl(
    IconData icon,
    String label,
    Color foreground,
    Color muted,
    VoidCallback onTap, {
    String hint = '',
    bool active = false,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: surface,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Icon(
                  icon,
                  size: 26,
                  color: active ? accent : foreground,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w800),
          ),
          if (hint.isNotEmpty)
            Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 9),
            ),
        ],
      ),
    );
  }

}
