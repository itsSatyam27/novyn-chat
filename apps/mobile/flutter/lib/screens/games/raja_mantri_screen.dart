import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/game_history_service.dart';

import '../../widgets/user_avatar.dart';

enum RMRole {
  raja,
  mantri,
  chor,
  sipahi;

  String get label {
    switch (this) {
      case RMRole.raja:
        return 'Raja';
      case RMRole.mantri:
        return 'Mantri';
      case RMRole.chor:
        return 'Chor';
      case RMRole.sipahi:
        return 'Sipahi';
    }
  }

  String get emoji {
    switch (this) {
      case RMRole.raja:
        return '👑';
      case RMRole.mantri:
        return '🧠';
      case RMRole.chor:
        return '🥷';
      case RMRole.sipahi:
        return '💂';
    }
  }

  int get points {
    switch (this) {
      case RMRole.raja:
        return 1000;
      case RMRole.mantri:
        return 800;
      case RMRole.sipahi:
        return 500;
      case RMRole.chor:
        return 0;
    }
  }
}

class RMPlayer {
  RMPlayer({
    required this.id,
    required this.name,
    required this.color,
    this.photoUrl = '',
    this.isUser = false,
    this.score = 0,
    this.roundDelta = 0,
    this.currentRole,
    this.isRoleRevealed = false,
  });

  final String id;
  final String name;
  final Color color;
  final String photoUrl;
  final bool isUser;
  int score;
  int roundDelta;
  RMRole? currentRole;
  bool isRoleRevealed;

  RMPlayer copyWith({
    int? score,
    int? roundDelta,
    RMRole? currentRole,
    bool? isRoleRevealed,
  }) {
    return RMPlayer(
      id: id,
      name: name,
      color: color,
      photoUrl: photoUrl,
      isUser: isUser,
      score: score ?? this.score,
      roundDelta: roundDelta ?? this.roundDelta,
      currentRole: currentRole ?? this.currentRole,
      isRoleRevealed: isRoleRevealed ?? this.isRoleRevealed,
    );
  }
}

enum RMGameState {
  shuffling,
  pickChit,
  revealedWaitingGuess,
  userGuessing,
  roundResult,
  gameOver;
}

class _FloatingEmojiData {
  final Key key;
  final String emoji;
  final double leftRatio;

  _FloatingEmojiData({
    required this.key,
    required this.emoji,
    required this.leftRatio,
  });
}

class RajaMantriScreen extends StatefulWidget {
  const RajaMantriScreen({
    super.key,
    required this.currentUsername,
    this.playerPhotoUrl = '',
    this.customOpponents,
    this.isPassAndPlay = false,
  });

  final String currentUsername;
  final String playerPhotoUrl;
  final List<String>? customOpponents;
  final bool isPassAndPlay;

  @override
  State<RajaMantriScreen> createState() => _RajaMantriScreenState();
}

class _RajaMantriScreenState extends State<RajaMantriScreen>
    with TickerProviderStateMixin {
  static const int totalRounds = 5;

  late List<RMPlayer> _players;
  int _currentRound = 1;
  RMGameState _gameState = RMGameState.shuffling;

  late List<RMRole> _shuffledRoles;
  int? _userPickedChitIndex;
  int? _guessSuspectIndex;
  bool _lastGuessWasCorrect = false;
  String _statusMessage = 'Shuffling chits...';

  // Guessing Timer (Feature 4)
  Timer? _guessTimer;
  int _guessSecondsRemaining = 15;
  bool _historyRecorded = false;
  String _historyMatchId = 'rajamantri_${DateTime.now().microsecondsSinceEpoch}';

  // Floating Reactions (Feature 3)
  final List<_FloatingEmojiData> _floatingEmojis = [];

  // Animation Controllers
  late AnimationController _shuffleAnimController;
  late AnimationController _bobAnimController;

  @override
  void initState() {
    super.initState();
    _initPlayers();
    _initAnimations();
    _startRound(1);
  }

  void _initPlayers() {
    final rawOpponents = (widget.customOpponents != null &&
            widget.customOpponents!.length >= 3)
        ? widget.customOpponents!
        : ['Bot 1', 'Bot 2', 'Bot 3'];

    // Ensure bot names are strictly Bot 1, Bot 2, Bot 3
    final opponentNames = List<String>.generate(3, (idx) {
      final name = rawOpponents[idx];
      if (name.toLowerCase().contains('bot') || name.startsWith('Player')) {
        return 'Bot ${idx + 1}';
      }
      return name;
    });

    _players = [
      RMPlayer(
        id: 'user',
        name: widget.isPassAndPlay ? 'Player 1' : 'You',
        color: const Color(0xFF5E44F3),
        photoUrl: widget.playerPhotoUrl,
        isUser: true,
      ),
      RMPlayer(
        id: 'p1',
        name: widget.isPassAndPlay ? 'Player 2' : opponentNames[0],
        color: const Color(0xFFD92D66),
      ),
      RMPlayer(
        id: 'p2',
        name: widget.isPassAndPlay ? 'Player 3' : opponentNames[1],
        color: const Color(0xFFF59E0B),
      ),
      RMPlayer(
        id: 'p3',
        name: widget.isPassAndPlay ? 'Player 4' : opponentNames[2],
        color: const Color(0xFF0D9488),
      ),
    ];
  }

  void _spawnEmoji(String emoji) {
    HapticFeedback.lightImpact();
    final item = _FloatingEmojiData(
      key: UniqueKey(),
      emoji: emoji,
      leftRatio: 0.15 + math.Random().nextDouble() * 0.7,
    );
    setState(() {
      _floatingEmojis.add(item);
    });
    Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        _floatingEmojis.remove(item);
      });
    });
  }

  void _startGuessTimer() {
    _guessTimer?.cancel();
    _guessSecondsRemaining = 15;
    _guessTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_guessSecondsRemaining <= 1) {
        timer.cancel();
        _autoPickSuspect();
      } else {
        setState(() => _guessSecondsRemaining--);
      }
    });
  }

  void _autoPickSuspect() {
    if (_gameState != RMGameState.userGuessing) return;
    final chorIndex = _players.indexWhere((p) => p.currentRole == RMRole.chor);
    final mantriIndex = _players.indexWhere((p) => p.currentRole == RMRole.mantri);
    final candidates = [chorIndex, mantriIndex];
    candidates.shuffle();
    _onUserSelectSuspect(candidates.first);
  }

  Future<void> _recordGameStats(RMPlayer winner) async {
    if (_historyRecorded) return;
    _historyRecorded = true;
    final opponents = _players.where((p) => !p.isUser).map((p) => p.name).join(', ');
    final isBotMatch = !widget.isPassAndPlay &&
        _players.where((p) => !p.isUser).every(
          (player) => player.name.toLowerCase().startsWith('bot '),
        );
    unawaited(GameHistoryService.recordFinishedMatch(
      username: widget.currentUsername,
      matchId: _historyMatchId,
      gameType: 'rajamantri',
      opponent: opponents,
      result: winner.isUser ? 'win' : 'loss',
      playedAt: DateTime.now(),
      isBotMatch: isBotMatch,
    ));
    try {
      final prefs = await SharedPreferences.getInstance();
      final played = (prefs.getInt('rm_played') ?? 0) + 1;
      await prefs.setInt('rm_played', played);
      if (winner.isUser) {
        final wins = (prefs.getInt('rm_wins') ?? 0) + 1;
        await prefs.setInt('rm_wins', wins);
      }
      final user = _players.firstWhere((p) => p.isUser);
      final high = prefs.getInt('rm_highscore') ?? 0;
      if (user.score > high) {
        await prefs.setInt('rm_highscore', user.score);
      }
    } catch (_) {}
  }

  void _initAnimations() {
    // Shuffle: 0.5s loop with ±18px and ±6°
    _shuffleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Pick hint: 1.2s loop bobbing up and down 6px
    _bobAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _guessTimer?.cancel();
    _shuffleAnimController.dispose();
    _bobAnimController.dispose();
    super.dispose();
  }

  void _startRound(int round) {
    setState(() {
      _currentRound = round;
      _gameState = RMGameState.shuffling;
      _userPickedChitIndex = null;
      _guessSuspectIndex = null;
      _statusMessage = 'Shuffling chits...';

      // Reset round deltas and role reveal
      for (final p in _players) {
        p.roundDelta = 0;
        p.isRoleRevealed = false;
      }

      // Shuffle 4 roles
      final roles = [RMRole.raja, RMRole.mantri, RMRole.sipahi, RMRole.chor];
      roles.shuffle(math.Random());
      _shuffledRoles = roles;

      // Assign to players
      for (int i = 0; i < 4; i++) {
        _players[i].currentRole = _shuffledRoles[i];
      }
    });

    _shuffleAnimController.repeat(reverse: true);

    // After 1.2s shuffle, prompt user to pick chit
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _shuffleAnimController.stop();
      _shuffleAnimController.reset();

      setState(() {
        _gameState = RMGameState.pickChit;
        _statusMessage = 'Tap a chit to see your role';
      });
    });
  }

  void _onChitTapped(int index) {
    if (_gameState != RMGameState.pickChit) return;

    HapticFeedback.lightImpact();

    setState(() {
      _userPickedChitIndex = index;
      _gameState = RMGameState.revealedWaitingGuess;
      _players[0].isRoleRevealed = true;
    });

    final rajaIndex = _players.indexWhere((p) => p.currentRole == RMRole.raja);
    final sipahiIndex = _players.indexWhere((p) => p.currentRole == RMRole.sipahi);

    _players[rajaIndex].isRoleRevealed = true;

    final guesserIndex = sipahiIndex;
    final guesser = _players[guesserIndex];

    if (guesser.isUser) {
      setState(() {
        _gameState = RMGameState.userGuessing;
        _statusMessage = 'You are ${guesser.currentRole!.label}. Who is the Chor?';
      });
      _startGuessTimer();
    } else {
      setState(() {
        _statusMessage = '${guesser.name} is thinking...';
      });

      Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        _botMakeGuess(guesserIndex);
      });
    }
  }

  void _botMakeGuess(int guesserIndex) {
    final chorIndex = _players.indexWhere((p) => p.currentRole == RMRole.chor);
    final mantriIndex = _players.indexWhere((p) => p.currentRole == RMRole.mantri);

    final candidates = [chorIndex, mantriIndex];
    candidates.shuffle();
    final pickedIndex = candidates.first;

    _resolveRound(guesserIndex: guesserIndex, pickedSuspectIndex: pickedIndex);
  }

  void _onUserSelectSuspect(int suspectIndex) {
    _guessTimer?.cancel();
    HapticFeedback.mediumImpact();
    if (_gameState != RMGameState.userGuessing) return;
    _resolveRound(guesserIndex: 0, pickedSuspectIndex: suspectIndex);
  }

  void _resolveRound({
    required int guesserIndex,
    required int pickedSuspectIndex,
  }) {
    _guessTimer?.cancel();
    final guesser = _players[guesserIndex];
    final suspect = _players[pickedSuspectIndex];
    final isCorrect = suspect.currentRole == RMRole.chor;

    if (isCorrect) {
      HapticFeedback.heavyImpact();
      if (!guesser.isUser) _spawnEmoji('👑');
    } else {
      HapticFeedback.vibrate();
      final chorIndex = _players.indexWhere((p) => p.currentRole == RMRole.chor);
      if (!_players[chorIndex].isUser) _spawnEmoji('😂');
    }

    final rajaPlayer = _players.firstWhere((p) => p.currentRole == RMRole.raja);
    final mantriPlayer = _players.firstWhere((p) => p.currentRole == RMRole.mantri);
    final sipahiPlayer = _players.firstWhere((p) => p.currentRole == RMRole.sipahi);
    final chorPlayer = _players.firstWhere((p) => p.currentRole == RMRole.chor);

    // Raja always gets 1000
    rajaPlayer.roundDelta = 1000;

    if (isCorrect) {
      // Sipahi/Mantri caught the Chor!
      sipahiPlayer.roundDelta = 500;
      mantriPlayer.roundDelta = 800;
      chorPlayer.roundDelta = 0;
    } else {
      // Wrong guess! Chor escaped and takes detective's points
      if (guesser.currentRole == RMRole.sipahi) {
        sipahiPlayer.roundDelta = 0;
        chorPlayer.roundDelta = 500;
        mantriPlayer.roundDelta = 800;
      } else {
        mantriPlayer.roundDelta = 0;
        chorPlayer.roundDelta = 800;
        sipahiPlayer.roundDelta = 500;
      }
    }

    // Apply scores
    for (final p in _players) {
      p.score += p.roundDelta;
      p.isRoleRevealed = true;
    }

    setState(() {
      _lastGuessWasCorrect = isCorrect;
      _guessSuspectIndex = pickedSuspectIndex;
      _gameState =
          (_currentRound >= totalRounds) ? RMGameState.gameOver : RMGameState.roundResult;

      if (isCorrect) {
        _statusMessage =
            '${guesser.name} picked ${suspect.name}. Chor caught! 🎉';
      } else {
        _statusMessage =
            '${guesser.name} picked ${suspect.name}. Wrong! Chor escapes 😈';
      }
    });

    if (_gameState == RMGameState.gameOver) {
      // Show final result bottom sheet after short delay
      Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _showFinalResultModal();
      });
    }
  }

  void _showFinalResultModal() {
    final sorted = List<RMPlayer>.from(_players)
      ..sort((a, b) => b.score.compareTo(a.score));
    final winner = sorted.first;
    _recordGameStats(winner);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x8C140E32),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF201B36) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '👑',
                          style: TextStyle(fontSize: 54),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${winner.name} wins!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF1E1A33),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Ranking Rows
                        ...List.generate(sorted.length, (idx) {
                          final p = sorted[idx];
                          final isFirst = idx == 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2C2449)
                                  : const Color(0xFFF4F2FA),
                              borderRadius: BorderRadius.circular(12),
                              border: isFirst
                                  ? Border.all(
                                      color: const Color(0xFFF59E0B),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${idx + 1}. ${p.name}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isFirst
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1A33),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${p.score}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1A33),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // Pinned buttons at bottom
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5E44F3),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _restartGame();
                          },
                          child: const Text(
                            'Play again',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF2C2449)
                                : const Color(0xFFF4F2FA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Close room',
                            style: TextStyle(
                              color: Color(0xFFE53468),
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _restartGame() {
    _historyRecorded = false;
    _historyMatchId = 'rajamantri_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      for (final p in _players) {
        p.score = 0;
      }
      _startRound(1);
    });
  }

  void _onNextRound() {
    if (_currentRound < totalRounds) {
      _startRound(_currentRound + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(isDark),

                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Column(
                      children: [
                        // 2x2 Players Grid
                        _buildPlayersGrid(isDark),
                        const SizedBox(height: 24),

                        // Status Text
                        _buildStatusBanner(isDark),
                        const SizedBox(height: 20),

                        // 4 Chits Row
                        _buildChitsRow(isDark),
                      ],
                    ),
                  ),
                ),

                // Floating Reactions Bar
                _buildReactionsBar(isDark),

                // Sticky Bottom Action Area (Lifted)
                _buildBottomActionArea(isDark),
              ],
            ),
          ),
          ..._buildFloatingEmojisOverlay(),
        ],
      ),
    );
  }

  Widget _buildReactionsBar(bool isDark) {
    const emojis = ['😂', '🤫', '👀', '👑', '🔥'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: emojis.map((e) {
          return GestureDetector(
            onTap: () => _spawnEmoji(e),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF241C40) : const Color(0xFFEEEAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF382B5C) : const Color(0xFFDDD7F8),
                  width: 1,
                ),
              ),
              child: Text(e, style: const TextStyle(fontSize: 18)),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildFloatingEmojisOverlay() {
    final size = MediaQuery.of(context).size;
    return _floatingEmojis.map((data) {
      return Positioned(
        left: size.width * data.leftRatio,
        bottom: 90,
        child: TweenAnimationBuilder<double>(
          key: data.key,
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 2000),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            final dy = -260 * val;
            final opacity = (1.0 - val).clamp(0.0, 1.0);
            final scale = 0.8 + 0.5 * math.sin(val * math.pi);
            return Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Text(data.emoji, style: const TextStyle(fontSize: 34)),
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201B36) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF2C2449) : const Color(0xFFECE8F6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: isDark ? Colors.white : const Color(0xFF1E1A33),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Raja Mantri Chor Sipahi',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E1A33),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2449) : const Color(0xFFEEEAFB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Round $_currentRound/$totalRounds',
              style: const TextStyle(
                color: Color(0xFF5E44F3),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersGrid(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _players.map((player) {
            return SizedBox(
              width: itemWidth,
              child: _buildPlayerCard(player, isDark),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPlayerCard(RMPlayer player, bool isDark) {
    final isYou = player.isUser;
    final isRaja = player.isRoleRevealed && player.currentRole == RMRole.raja;

    Color borderColor = Colors.transparent;
    if (isYou) {
      borderColor = const Color(0xFF5E44F3);
    } else if (isRaja) {
      borderColor = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          UserAvatar(
            name: player.name,
            photoUrl: player.photoUrl,
            radius: 22,
            fallbackColor: player.color,
          ),
          const SizedBox(width: 10),
          // Name and Role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1A33),
                  ),
                ),
                const SizedBox(height: 2),
                _buildRoleLine(player, isDark),
              ],
            ),
          ),
          // Score on Right
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${player.score}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1E1A33),
                ),
              ),
              if (player.roundDelta > 0)
                Text(
                  '+${player.roundDelta}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16A34A),
                  ),
                )
              else if (player.isRoleRevealed && player.roundDelta == 0)
                const Text(
                  '+0',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7E7A9C),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleLine(RMPlayer player, bool isDark) {
    if (!player.isRoleRevealed || player.currentRole == null) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '❓',
            style: TextStyle(fontSize: 11),
          ),
          SizedBox(width: 4),
          Text(
            'Hidden',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7E7A9C),
            ),
          ),
        ],
      );
    }

    final role = player.currentRole!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          role.emoji,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          role.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : const Color(0xFF5A5579),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(bool isDark) {
    // Rich status narration
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: _buildRichStatusText(isDark),
      ),
    );
  }

  Widget _buildRichStatusText(bool isDark) {
    if (_gameState == RMGameState.pickChit) {
      return Text(
        _statusMessage,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF1E1A33),
        ),
      );
    }

    if (_gameState == RMGameState.userGuessing) {
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E1A33),
          ),
          children: const [
            TextSpan(
              text: 'You ',
              style: TextStyle(color: Color(0xFF5E44F3)),
            ),
            TextSpan(text: 'are Sipahi. Who is the Chor?'),
          ],
        ),
      );
    }

    if (_gameState == RMGameState.roundResult || _gameState == RMGameState.gameOver) {
      // Check last guess text
      if (_guessSuspectIndex != null) {
        final suspect = _players[_guessSuspectIndex!];
        final guesser = _players.firstWhere((p) => p.currentRole == RMRole.sipahi);

        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1A33),
            ),
            children: [
              TextSpan(
                text: '${guesser.name} ',
                style: TextStyle(color: guesser.color),
              ),
              const TextSpan(text: 'picked '),
              TextSpan(
                text: '${suspect.name}. ',
                style: TextStyle(color: suspect.color),
              ),
              TextSpan(
                text: _lastGuessWasCorrect
                    ? 'Chor caught! 🎉'
                    : 'Wrong! Chor escapes 😈',
              ),
            ],
          ),
        );
      }
    }

    return Text(
      _statusMessage,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : const Color(0xFF1E1A33),
      ),
    );
  }

  Widget _buildChitsRow(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const totalSpacing = 3 * 10.0;
        final chitWidth = (constraints.maxWidth - totalSpacing) / 4;
        final chitHeight = chitWidth * (4 / 3);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            return _buildChit(index, chitWidth, chitHeight, isDark);
          }),
        );
      },
    );
  }

  Widget _buildChit(
    int index,
    double width,
    double height,
    bool isDark,
  ) {
    final isPicked = _userPickedChitIndex == index;
    final isShuffling = _gameState == RMGameState.shuffling;
    final canPick = _gameState == RMGameState.pickChit;

    return AnimatedBuilder(
      animation: Listenable.merge([_shuffleAnimController, _bobAnimController]),
      builder: (context, child) {
        double dx = 0;
        double dy = 0;
        double angle = 0;

        if (isShuffling) {
          // Shuffle: move ±18px and rotate ±6° over 0.5s with 70ms stagger
          final stagger = (index * 0.15) % 1.0;
          final val = math.sin((_shuffleAnimController.value + stagger) * 2 * math.pi);
          dx = val * 18 * (index % 2 == 0 ? 1 : -1);
          angle = val * (6 * math.pi / 180);
        } else if (canPick) {
          // Pick hint: bob up and down 6px
          dy = math.sin(_bobAnimController.value * math.pi) * -6;
        }

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _onChitTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF201B36) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: isPicked
                ? Border.all(color: const Color(0xFF5E44F3), width: 3)
                : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xFF110D20)
                    : const Color(0xFFD6CEF8),
                blurRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: isPicked
              ? _buildOpenedChitContent(index, isDark)
              : Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? const Color(0xFF453A6D)
                          : const Color(0xFFD0C7F5),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOpenedChitContent(int index, bool isDark) {
    final role = _players[0].currentRole ?? RMRole.sipahi;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          role.emoji,
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 6),
        Text(
          role.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E1A33),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionArea(bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 2, 16, 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1838) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF332757) : const Color(0xFFE9E5F5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        alignment: Alignment.center,
        child: _buildActionButtonContent(isDark),
      ),
    );
  }

  Widget _buildActionButtonContent(bool isDark) {
    if (_gameState == RMGameState.userGuessing) {
      // Suspect buttons for the 2 hidden suspects
      final chorIndex = _players.indexWhere((p) => p.currentRole == RMRole.chor);
      final mantriIndex = _players.indexWhere((p) => p.currentRole == RMRole.mantri);

      final suspects = [_players[chorIndex], _players[mantriIndex]];
      suspects.sort((a, b) => a.name.compareTo(b.name));

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD92D66).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: Color(0xFFD92D66)),
                    const SizedBox(width: 4),
                    Text(
                      '${_guessSecondsRemaining}s to guess',
                      style: const TextStyle(
                        color: Color(0xFFD92D66),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: suspects.map((suspect) {
              final sIndex = _players.indexOf(suspect);
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onUserSelectSuspect(sIndex),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    height: 58,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF282046) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? const Color(0xFF4A3D7A) : const Color(0xFFD6CEF8),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: suspect.color.withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: suspect.color,
                          child: Text(
                            suspect.name.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suspect.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF1E1A33),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'Tap to accuse',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF7E7A9C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    if (_gameState == RMGameState.roundResult) {
      return SizedBox(
        width: 170,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5E44F3),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            shadowColor: const Color(0xFF3823B5),
          ),
          onPressed: _onNextRound,
          child: const Text(
            'Next round',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    if (_gameState == RMGameState.gameOver) {
      return SizedBox(
        width: 190,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5E44F3),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            shadowColor: const Color(0xFF3823B5),
          ),
          onPressed: _showFinalResultModal,
          child: const Text(
            'See final result',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
