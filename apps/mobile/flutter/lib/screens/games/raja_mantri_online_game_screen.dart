import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/game_history_service.dart';
import '../../services/socket_service.dart';

class RajaMantriOnlineGameScreen extends StatefulWidget {
  const RajaMantriOnlineGameScreen({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  @override
  State<RajaMantriOnlineGameScreen> createState() => _RajaMantriOnlineGameScreenState();
}

class _RajaMantriOnlineGameScreenState extends State<RajaMantriOnlineGameScreen> {
  static const _purple = Color(0xFF5E4CF2);
  static const _ink = Color(0xFF1E1A43);
  static const _muted = Color(0xFF625D8C);

  SocketService? _socket;
  AuthService? _auth;
  Map<String, dynamic>? _game;
  bool _loading = true;
  bool _acting = false;
  bool _recorded = false;
  bool _wasConnected = true;
  bool _matchAbandoned = false;
  String _abandonedBy = '';

  String get _username => _auth?.user?.username.trim().toLowerCase() ?? '';
  List<Map<String, dynamic>> get _players {
    final raw = _game?['players'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList();
  }

  String get _phase => _game?['phase']?.toString() ?? 'picking';
  int get _round => int.tryParse(_game?['round']?.toString() ?? '') ?? 1;
  int get _totalRounds => int.tryParse(_game?['totalRounds']?.toString() ?? '') ?? 5;
  bool get _isHost => _game?['isHost'] == true;
  bool get _myPicked => _game?['myPicked'] == true;
  String get _myRole => _game?['myRole']?.toString() ?? '';
  bool get _isSipahi => _game?['sipahiUsername']?.toString().toLowerCase() == _username;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _auth = context.read<AuthService>();
      _socket = context.read<SocketService>();
      _socket!.onRajaMantriGameUpdated = _handleGameUpdated;
      _socket!.onRajaMantriGameAbandoned = _handleGameAbandoned;
      _socket!.addListener(_handleSocketStateChanged);
      _loadGame();
    });
  }

  @override
  void dispose() {
    if (_socket != null) {
      _socket!.removeListener(_handleSocketStateChanged);
      _socket!.onRajaMantriGameUpdated = null;
      _socket!.onRajaMantriGameAbandoned = null;
    }
    super.dispose();
  }

  Future<void> _loadGame() async {
    try {
      final result = await (_socket ?? context.read<SocketService>()).getRajaMantriGame(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _game = Map<String, dynamic>.from(result['game'] as Map);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(error is StateError ? error.message.toString() : 'Could not load this match.');
    }
  }

  void _handleGameUpdated(Map data) {
    if (!mounted || data['sessionId']?.toString() != widget.sessionId || data['game'] is! Map) return;
    setState(() {
      _game = Map<String, dynamic>.from(data['game'] as Map);
      _loading = false;
    });
    _recordFinishedResult();
  }

  void _handleGameAbandoned(Map data) {
    if (!mounted || data['sessionId']?.toString() != widget.sessionId) return;
    setState(() {
      _matchAbandoned = true;
      _abandonedBy = data['leftDisplayName']?.toString().trim().isNotEmpty == true
          ? data['leftDisplayName'].toString()
          : (data['leftUsername']?.toString() ?? 'A player');
    });
    _showMessage('$_abandonedBy left the match. The room has ended.');
  }

  void _handleSocketStateChanged() {
    if (!mounted) return;
    final connected = _socket?.isConnected == true && _socket?.isAuthenticated == true;
    if (connected) {
      _wasConnected = true;
      return;
    }
    if (_wasConnected) {
      _wasConnected = false;
      _showMessage('Connection lost. Reconnect to continue this match.');
    }
  }

  Future<void> _perform(
    Future<Map<String, dynamic>> Function() action, {
    String? successMessage,
  }) async {
    if (_acting || _matchAbandoned) return;
    setState(() => _acting = true);
    try {
      final result = await action();
      if (!mounted) return;
      final game = result['game'];
      if (game is Map) {
        setState(() => _game = Map<String, dynamic>.from(game));
        _recordFinishedResult();
      }
      if (successMessage != null) _showMessage(successMessage);
    } catch (error) {
      if (mounted) {
        _showMessage(error is StateError ? error.message.toString() : 'Could not update the match. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _pickChit() => _perform(
        () => (_socket ?? context.read<SocketService>()).pickRajaMantriChit(widget.sessionId),
      );

  Future<void> _guessPlayer(String username) => _perform(
        () => (_socket ?? context.read<SocketService>()).guessRajaMantriChor(widget.sessionId, username),
      );

  Future<void> _nextRound() => _perform(
        () => (_socket ?? context.read<SocketService>()).advanceRajaMantriRound(widget.sessionId),
      );

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _recordFinishedResult() {
    if (_recorded || _phase != 'finished' || _username.isEmpty || _players.isEmpty) return;
    _recorded = true;
    final sorted = List<Map<String, dynamic>>.from(_players)
      ..sort((a, b) => (int.tryParse(b['score']?.toString() ?? '') ?? 0)
          .compareTo(int.tryParse(a['score']?.toString() ?? '') ?? 0));
    final myScore = int.tryParse(sorted.firstWhere((p) => p['username']?.toString().toLowerCase() == _username)['score']?.toString() ?? '') ?? 0;
    final topScore = int.tryParse(sorted.first['score']?.toString() ?? '') ?? 0;
    final topCount = sorted.where((player) => (int.tryParse(player['score']?.toString() ?? '') ?? 0) == topScore).length;
    final result = topCount > 1 && myScore == topScore
        ? 'draw'
        : myScore == topScore
            ? 'win'
            : 'loss';
    final opponents = sorted
        .where((player) => player['username']?.toString().toLowerCase() != _username)
        .map((player) => player['displayName']?.toString() ?? player['username']?.toString() ?? 'Player')
        .join(', ');
    unawaited(GameHistoryService.recordFinishedMatch(
      username: _username,
      matchId: widget.sessionId,
      gameType: 'rajamantri',
      opponent: opponents,
      result: result,
      playedAt: DateTime.now(),
    ));
  }

  Future<bool> _confirmLeave() async {
    if (_phase == 'finished' || _matchAbandoned) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Leave this match?'),
            content: const Text('You can’t rejoin this round after leaving.'),
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF141026) : const Color(0xFFF5F3FC);
    final foreground = isDark ? Colors.white : _ink;
    final muted = isDark ? Colors.white60 : _muted;
    if (_loading) {
      return Scaffold(
        backgroundColor: background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_game == null) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          title: const Text('Raja Mantri Chor Sipahi'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_esports_outlined, size: 48, color: _purple),
                const SizedBox(height: 14),
                Text('Match unavailable', style: TextStyle(color: foreground, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('This room may have expired. Return to Games and start a new match.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                const SizedBox(height: 18),
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to Games')),
              ],
            ),
          ),
        ),
      );
    }

    final players = _players;
    final myRole = _myRole;
    final isPicking = _phase == 'picking';
    final isGuessing = _phase == 'guessing';
    final isResult = _phase == 'result';
    final isFinished = _phase == 'finished';
    final isAbandoned = _matchAbandoned;
    final guessedSipahi = _game?['sipahiUsername']?.toString() ?? '';
    final lastResult = _game?['lastResult'] is Map
        ? Map<String, dynamic>.from(_game!['lastResult'] as Map)
        : null;
    final myGuessTargets = players.where((player) {
      final username = player['username']?.toString().toLowerCase() ?? '';
      final role = player['role']?.toString() ?? '';
      if (username == _username) return false;
      if (role == 'raja') return false;
      return true;
    }).toList();

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave() && mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          leading: IconButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmLeave() && mounted) navigator.pop();
            },
            icon: Icon(Icons.arrow_back_rounded, color: foreground),
          ),
          title: Text(
            'Raja Mantri Chor Sipahi',
            style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FC), borderRadius: BorderRadius.circular(22)),
                  child: Text('Round $_round/$_totalRounds', style: const TextStyle(color: Color(0xFF403875), fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  children: [
                    if (isAbandoned)
                      _InfoCard(
                        title: 'Match ended',
                        subtitle: '$_abandonedBy left the room. Return to Games to start another match.',
                        foreground: foreground,
                        muted: muted,
                      )
                    else
                      _PhaseBanner(
                        phase: _phase,
                        myRole: myRole,
                        isSipahi: _isSipahi,
                        foreground: foreground,
                        muted: muted,
                      ),
                    const SizedBox(height: 18),
                    Text('Players', style: TextStyle(color: muted, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 10),
                    ...players.map((player) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _OnlinePlayerRow(
                            player: player,
                            isMe: player['username']?.toString().toLowerCase() == _username,
                            foreground: foreground,
                            muted: muted,
                          ),
                        )),
                    if (isPicking) ...[
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: _myPicked ? 'Your chit is picked' : 'Pick your chit',
                        subtitle: _myPicked
                            ? 'Waiting for the other players to reveal their roles.'
                            : 'Tap below to reveal your role privately. Other players cannot see it yet.',
                        foreground: foreground,
                        muted: muted,
                      ),
                    ],
                    if (isGuessing && !_isSipahi) ...[
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Sipahi is choosing',
                        subtitle: guessedSipahi == _username ? 'Choose who you think is the Chor.' : 'Waiting for the Sipahi to identify the Chor.',
                        foreground: foreground,
                        muted: muted,
                      ),
                    ],
                    if (isGuessing && _isSipahi) ...[
                      const SizedBox(height: 12),
                      Text('Who is the Chor?', style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 20)),
                      const SizedBox(height: 10),
                      ...myGuessTargets.map((player) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _SuspectButton(
                              player: player,
                              enabled: !_acting,
                              onTap: () => _guessPlayer(player['username'].toString()),
                            ),
                          )),
                    ],
                    if (isResult && lastResult != null) ...[
                      const SizedBox(height: 12),
                      _RoundResultCard(
                        result: lastResult,
                        players: players,
                        foreground: foreground,
                        muted: muted,
                      ),
                    ],
                    if (isFinished) ...[
                      const SizedBox(height: 12),
                      _FinalResultCard(players: players, username: _username, foreground: foreground, muted: muted),
                    ],
                  ],
                ),
              ),
              _buildBottomAction(
                isDark: isDark,
                isPicking: isPicking,
                isGuessing: isGuessing,
                isResult: isResult,
                isFinished: isFinished,
                isAbandoned: isAbandoned,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required bool isDark,
    required bool isPicking,
    required bool isGuessing,
    required bool isResult,
    required bool isFinished,
    required bool isAbandoned,
  }) {
    Widget child;
    if (isAbandoned) {
      child = FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.done_rounded),
        label: const Text('Back to Games'),
      );
    } else if (isPicking && !_myPicked) {
      child = FilledButton.icon(
        onPressed: _acting ? null : _pickChit,
        icon: const Icon(Icons.style_rounded),
        label: const Text('Pick your chit'),
      );
    } else if (isPicking) {
      child = _disabledAction('Waiting for players to pick');
    } else if (isGuessing && _isSipahi) {
      child = _disabledAction('Choose a suspect above');
    } else if (isGuessing) {
      child = _disabledAction('Waiting for the Sipahi');
    } else if (isResult && _isHost) {
      child = FilledButton.icon(
        onPressed: _acting ? null : _nextRound,
        icon: const Icon(Icons.navigate_next_rounded),
        label: Text(_round >= _totalRounds ? 'Show final scores' : 'Next round'),
      );
    } else if (isResult) {
      child = _disabledAction('Waiting for the host to continue');
    } else {
      child = FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.done_rounded),
        label: const Text('Back to Games'),
      );
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF201B36) : Colors.white,
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, -5))],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: child,
        ),
      ),
    );
  }

  Widget _disabledAction(String label) => FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          disabledBackgroundColor: const Color(0xFFE5E0F6),
          disabledForegroundColor: const Color(0xFF777195),
        ),
      );
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({
    required this.phase,
    required this.myRole,
    required this.isSipahi,
    required this.foreground,
    required this.muted,
  });

  final String phase;
  final String myRole;
  final bool isSipahi;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final (title, detail) = switch (phase) {
      'picking' => ('Choose your chit', 'Everyone picks once. Your role stays private.'),
      'guessing' => isSipahi
          ? ('You are the Sipahi', 'Choose who you believe is the Chor.')
          : ('Sipahi is guessing', 'Wait while the Sipahi chooses a suspect.'),
      'result' => ('Round complete', 'See the revealed roles and points earned this round.'),
      _ => ('Match complete', 'Final scores are ready.'),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _RajaMantriOnlineGameScreenState._purple, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(detail, style: const TextStyle(color: Color(0xFF625D8C), fontSize: 13, fontWeight: FontWeight.w600)),
          if (myRole.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Your role: ${_roleLabel(myRole)}', style: const TextStyle(color: Color(0xFF403875), fontWeight: FontWeight.w900)),
          ],
        ],
      ),
    );
  }
}

class _OnlinePlayerRow extends StatelessWidget {
  const _OnlinePlayerRow({
    required this.player,
    required this.isMe,
    required this.foreground,
    required this.muted,
  });

  final Map<String, dynamic> player;
  final bool isMe;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final name = player['displayName']?.toString() ?? player['username']?.toString() ?? 'Player';
    final role = player['role']?.toString();
    final score = int.tryParse(player['score']?.toString() ?? '') ?? 0;
    final delta = int.tryParse(player['roundDelta']?.toString() ?? '') ?? 0;
    final picked = player['picked'] == true;
    final isBot = player['isBot'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFEDE9FC) : Theme.of(context).brightness == Brightness.dark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: Color(0xFF1E1A43), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMe ? '$name · You' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 3),
                Text(
                  role != null ? _roleLabel(role) : picked ? 'Chit picked' : isBot ? 'Bot' : 'Choosing a chit',
                  style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$score pts', style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 13)),
              if (delta != 0) Text('${delta > 0 ? '+' : ''}$delta', style: const TextStyle(color: Color(0xFF16834C), fontWeight: FontWeight.w800, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.muted,
  });

  final String title;
  final String subtitle;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF201B36) : Colors.white, borderRadius: BorderRadius.circular(19)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: foreground, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(subtitle, style: TextStyle(color: muted, fontSize: 12, height: 1.35)),
          ],
        ),
      );
}

class _SuspectButton extends StatelessWidget {
  const _SuspectButton({required this.player, required this.enabled, required this.onTap});
  final Map<String, dynamic> player;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = player['displayName']?.toString() ?? player['username']?.toString() ?? 'Player';
    return Material(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF201B36) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.person_search_rounded, color: _RajaMantriOnlineGameScreenState._purple, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
              const Icon(Icons.chevron_right_rounded, color: _RajaMantriOnlineGameScreenState._purple),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundResultCard extends StatelessWidget {
  const _RoundResultCard({
    required this.result,
    required this.players,
    required this.foreground,
    required this.muted,
  });

  final Map<String, dynamic> result;
  final List<Map<String, dynamic>> players;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final guesser = players.firstWhere(
      (player) => player['username']?.toString() == result['guesserUsername']?.toString(),
      orElse: () => const {},
    );
    final suspect = players.firstWhere(
      (player) => player['username']?.toString() == result['suspectUsername']?.toString(),
      orElse: () => const {},
    );
    final correct = result['correct'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: correct ? const Color(0xFFDDF3E9) : const Color(0xFFFFF0C2), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(correct ? 'Chor caught!' : 'Wrong guess!', style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            '${guesser['displayName'] ?? 'Sipahi'} chose ${suspect['displayName'] ?? 'a player'} — ${_roleLabel(result['suspectRole']?.toString() ?? '')}.',
            style: TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FinalResultCard extends StatelessWidget {
  const _FinalResultCard({
    required this.players,
    required this.username,
    required this.foreground,
    required this.muted,
  });

  final List<Map<String, dynamic>> players;
  final String username;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(players)
      ..sort((a, b) => (int.tryParse(b['score']?.toString() ?? '') ?? 0).compareTo(int.tryParse(a['score']?.toString() ?? '') ?? 0));
    final top = int.tryParse(sorted.first['score']?.toString() ?? '') ?? 0;
    final winners = sorted.where((player) => (int.tryParse(player['score']?.toString() ?? '') ?? 0) == top).toList();
    final mine = winners.any((player) => player['username']?.toString().toLowerCase() == username);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFEDE9FC), borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          Text(mine ? 'You won!' : winners.length > 1 ? 'It’s a draw!' : 'Match complete', style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 6),
          Text('Final scores', style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...sorted.map((player) {
            final score = int.tryParse(player['score']?.toString() ?? '') ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(player['displayName']?.toString() ?? 'Player', style: TextStyle(color: foreground, fontWeight: FontWeight.w800))),
                  Text('$score pts', style: TextStyle(color: foreground, fontWeight: FontWeight.w900)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'raja':
      return 'Raja';
    case 'mantri':
      return 'Mantri';
    case 'sipahi':
      return 'Sipahi';
    case 'chor':
      return 'Chor';
    default:
      return 'Hidden role';
  }
}

class RajaMantriInviteWaitingScreen extends StatefulWidget {
  const RajaMantriInviteWaitingScreen({
    super.key,
    required this.messageId,
    required this.hostName,
  });

  final String messageId;
  final String hostName;

  @override
  State<RajaMantriInviteWaitingScreen> createState() => _RajaMantriInviteWaitingScreenState();
}

class _RajaMantriInviteWaitingScreenState extends State<RajaMantriInviteWaitingScreen> {
  SocketService? _socket;
  bool _opening = false;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _socket = context.read<SocketService>();
      _socket!.onRajaMantriRoomStarted = _handleRoomStarted;
      _socket!.onGameInviteTimeout = _handleInviteTimeout;
      final existing = _socket!.rajaMantriSessionForInvite(widget.messageId);
      if (existing != null) _openSession(existing);
    });
  }

  @override
  void dispose() {
    if (_socket != null) {
      _socket!.onRajaMantriRoomStarted = null;
      _socket!.onGameInviteTimeout = null;
    }
    super.dispose();
  }

  void _handleRoomStarted(Map packet) {
    if (!mounted || _opening) return;
    final messageId = packet['messageId']?.toString() ?? '';
    final inviteIds = packet['inviteMessageIds'];
    final matches = messageId == widget.messageId ||
        (inviteIds is List && inviteIds.any((value) => value?.toString() == widget.messageId));
    if (!matches) return;
    final sessionId = packet['sessionId']?.toString() ?? '';
    if (sessionId.isNotEmpty) _openSession(sessionId);
  }

  void _handleInviteTimeout(Map packet) {
    if (!mounted || packet['messageId']?.toString() != widget.messageId) return;
    setState(() => _expired = true);
  }

  Future<void> _leaveRoom() async {
    if (_opening) return;
    try {
      await (_socket ?? context.read<SocketService>()).leaveRajaMantriInvite(widget.messageId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error is StateError ? error.message.toString() : 'Could not leave this room.')),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _openSession(String sessionId) {
    if (!mounted || _opening) return;
    _opening = true;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => RajaMantriOnlineGameScreen(sessionId: sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF141026) : const Color(0xFFF5F3FC);
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);
    return PopScope<void>(
      canPop: false,
      child: Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        leading: IconButton(
          onPressed: _leaveRoom,
          icon: Icon(Icons.arrow_back_rounded, color: foreground),
        ),
        title: Text(
          'Raja Mantri Chor Sipahi',
          style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 17),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _expired ? Icons.hourglass_disabled_rounded : Icons.groups_rounded,
                  color: const Color(0xFF5E4CF2),
                  size: 54,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _expired ? 'Invite expired' : 'You’ve joined the room',
                style: TextStyle(color: foreground, fontSize: 23, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 9),
              Text(
                _expired
                    ? 'The host did not start the match in time. Return to the chat and ask for a new invite.'
                    : 'Waiting for ${widget.hostName} to fill the remaining seats and start the match.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (!_expired)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2.2)),
                    SizedBox(width: 10),
                    Text('Waiting for host', style: TextStyle(color: Color(0xFF5E4CF2), fontWeight: FontWeight.w800)),
                  ],
                ),
              if (_expired) ...[
                const SizedBox(height: 5),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to chat'),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}

