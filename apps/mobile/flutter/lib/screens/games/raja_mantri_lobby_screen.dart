import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/user_avatar.dart';
import 'raja_mantri_screen.dart';

class RajaMantriLobbyScreen extends StatefulWidget {
  const RajaMantriLobbyScreen({super.key});

  @override
  State<RajaMantriLobbyScreen> createState() => _RajaMantriLobbyScreenState();
}

class _LobbySlot {
  _LobbySlot({
    required this.name,
    this.username = '',
    this.photoUrl = '',
    this.isHost = false,
    this.isBot = false,
    this.isReady = true,
    this.isPending = false,
  });

  final String name;
  final String username;
  final String photoUrl;
  final bool isHost;
  final bool isBot;
  final bool isReady;
  final bool isPending;
}

class _RajaMantriLobbyScreenState extends State<RajaMantriLobbyScreen> {
  final List<_LobbySlot?> _slots = List.filled(4, null);
  List<UserModel> _friends = [];
  bool _loadingFriends = false;
  final String _roomCode = '#RMCS-${2400 + (DateTime.now().millisecondsSinceEpoch % 7000)}';
  bool _isPassAndPlay = false;

  static const List<String> _defaultBots = ['Bot 1', 'Bot 2', 'Bot 3'];

  @override
  void initState() {
    super.initState();
    _initHost();
    _loadFriends();
  }

  void _initHost() {
    final user = Provider.of<AuthService?>(context, listen: false)?.user;
    final displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : (user?.username.trim().isNotEmpty == true ? user!.username : 'You');

    _slots[0] = _LobbySlot(
      name: displayName,
      photoUrl: user?.photoUrl ?? '',
      isHost: true,
      isReady: true,
    );
  }

  Future<void> _loadFriends() async {
    final user = Provider.of<AuthService?>(context, listen: false)?.user;
    final username = user?.username.trim() ?? '';
    if (username.isEmpty) return;

    setState(() => _loadingFriends = true);
    try {
      final friendService = context.read<FriendService>();
      final cached = friendService.cachedFriends;
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() {
          _friends = cached;
          _loadingFriends = false;
        });
      }
      final list = await friendService.friendsStream(username).first;
      if (mounted) {
        setState(() {
          _friends = list;
          _loadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  void _addBot(int slotIndex) {
    // Find next unused bot name
    final usedNames = _slots.whereType<_LobbySlot>().map((s) => s.name).toSet();
    final available = _defaultBots.firstWhere(
      (b) => !usedNames.contains(b),
      orElse: () => 'Bot ${slotIndex + 1}',
    );

    setState(() {
      _slots[slotIndex] = _LobbySlot(
        name: available,
        isBot: true,
        isReady: true,
      );
    });
  }

  void _fillAllWithBots() {
    setState(() {
      for (int i = 1; i < 4; i++) {
        if (_slots[i] == null) {
          _addBot(i);
        }
      }
    });
  }

  void _removeSlot(int slotIndex) {
    if (slotIndex == 0) return; // Cannot remove host
    setState(() {
      _slots[slotIndex] = null;
    });
  }

  Future<void> _inviteFriend(int slotIndex, UserModel friend) async {
    final displayName = friend.name.isNotEmpty ? friend.name : friend.username;
    setState(() {
      _slots[slotIndex] = _LobbySlot(
        name: displayName,
        username: friend.username,
        photoUrl: friend.photoUrl,
        isPending: true,
        isReady: false,
      );
    });

    try {
      final socket = Provider.of<SocketService?>(context, listen: false);
      if (socket != null && socket.isConnected) {
        await socket.sendGameChallenge('rajamantri', friend.username);
      }
    } catch (_) {
      // Offline fallback
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invited $displayName! Room code $_roomCode sent.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _startRandomMatchmaking() {
    int secondsLeft = 15;
    Timer? countdownTimer;
    bool isCancelled = false;

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (secondsLeft > 1) {
                setModalState(() => secondsLeft--);
                if (secondsLeft == 12 && !isCancelled) {
                  timer.cancel();
                  Navigator.of(ctx).pop();
                  _populateRandomMatchAndStart();
                }
              } else {
                timer.cancel();
                if (!isCancelled && mounted) {
                  Navigator.of(ctx).pop();
                  _fillAllWithBots();
                  _startGame();
                }
              }
            });

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF201B36) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E44F3).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.travel_explore_rounded,
                        color: Color(0xFF5E44F3),
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Finding 4 Players...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E1A33),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Searching for active players online ($secondsLeft s)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF7E7A9C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const LinearProgressIndicator(
                    backgroundColor: Color(0xFFEEEAFB),
                    color: Color(0xFF5E44F3),
                    minHeight: 4,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E44F3),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        isCancelled = true;
                        countdownTimer?.cancel();
                        Navigator.of(ctx).pop();
                        _fillAllWithBots();
                        _startGame();
                      },
                      icon: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Auto-fill with Bots & Play',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () {
                        isCancelled = true;
                        countdownTimer?.cancel();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF7E7A9C),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _populateRandomMatchAndStart() {
    setState(() {
      for (int i = 1; i < 4; i++) {
        _slots[i] = _LobbySlot(
          name: 'Player $i',
          isBot: false,
          isReady: true,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Matched with 3 random players! Starting game...'),
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _startGame();
    });
  }

  void _showInviteSheet(int slotIndex) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF201B36) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Invite a friend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1A33),
                    ),
                  ),
                  const Spacer(),
                  // Add Bot Shortcut
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _addBot(slotIndex);
                    },
                    icon: const Icon(Icons.smart_toy_rounded, size: 18, color: Color(0xFF5E44F3)),
                    label: const Text(
                      'Add Bot',
                      style: TextStyle(
                        color: Color(0xFF5E44F3),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loadingFriends
                    ? const Center(child: CircularProgressIndicator())
                    : _friends.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline_rounded,
                                    size: 48,
                                    color: isDark ? Colors.white30 : const Color(0xFF9E9AA7)),
                                const SizedBox(height: 10),
                                Text(
                                  'No friends found yet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5E44F3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _addBot(slotIndex);
                                  },
                                  icon: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
                                  label: const Text(
                                    'Fill slot with Bot',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _friends.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final friend = _friends[idx];
                              return ListTile(
                                leading: UserAvatar(
                                  name: friend.name.isNotEmpty ? friend.name : friend.username,
                                  photoUrl: friend.photoUrl,
                                  radius: 20,
                                ),
                                title: Text(
                                  friend.name.isNotEmpty ? friend.name : friend.username,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E1A33),
                                  ),
                                ),
                                subtitle: Text(
                                  '@${friend.username}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5E44F3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _inviteFriend(slotIndex, friend);
                                  },
                                  child: const Text(
                                    'Invite',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startGame() {
    // If some slots are still empty, auto-fill with bots
    for (int i = 1; i < 4; i++) {
      if (_slots[i] == null) {
        _addBot(i);
      }
    }

    final opponents = [
      _slots[1]!.name,
      _slots[2]!.name,
      _slots[3]!.name,
    ];

    final user = Provider.of<AuthService?>(context, listen: false)?.user;
    final username = user?.username.trim() ?? 'harsh';
    final photoUrl = user?.photoUrl ?? '';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RajaMantriScreen(
          currentUsername: username,
          playerPhotoUrl: photoUrl,
          customOpponents: opponents,
          isPassAndPlay: _isPassAndPlay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filledCount = _slots.whereType<_LobbySlot>().length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
      appBar: AppBar(
        titleSpacing: 4,
        backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: isDark ? Colors.white : const Color(0xFF1E1A33),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Raja Mantri Chor Sipahi',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? Colors.white : const Color(0xFF1E1A33),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '4-Player Match Lobby ($filledCount/4 Ready)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF7E7A9C),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF16A34A), size: 8),
                SizedBox(width: 5),
                Text(
                  'Live',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5E44F3), Color(0xFF7B61FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5E44F3).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 40)),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Royal 4-Player Showdown',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Invite 3 friends or fill with bots to begin!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      tooltip: 'Share room code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                          text: '👑 Join my Raja Mantri match on Novyn! Room Code: $_roomCode',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Room code $_roomCode copied! Share it with friends.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Slots Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PLAYERS (4 SLOTS)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5E44F3),
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (filledCount < 4)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Quick Match
                        GestureDetector(
                          onTap: _startRandomMatchmaking,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5E44F3).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF5E44F3)),
                                SizedBox(width: 3),
                                Text(
                                  'Quick Match',
                                  style: TextStyle(
                                    color: Color(0xFF5E44F3),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Fill with Bots
                        GestureDetector(
                          onTap: _fillAllWithBots,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2449) : const Color(0xFFEEEAFB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.smart_toy_rounded, size: 14, color: Color(0xFF5E44F3)),
                                SizedBox(width: 3),
                                Text(
                                  'Fill Bots',
                                  style: TextStyle(
                                    color: Color(0xFF5E44F3),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 4 Slots List
              Expanded(
                child: ListView.separated(
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final slot = _slots[index];
                    return _buildSlotTile(index, slot, isDark);
                  },
                ),
              ),

              // Pass & Play Mode Toggle (Feature 5)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF201B36) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isPassAndPlay
                        ? const Color(0xFF5E44F3)
                        : (isDark ? const Color(0xFF332757) : const Color(0xFFE9E5F5)),
                    width: _isPassAndPlay ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5E44F3).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.phone_android_rounded,
                          color: Color(0xFF5E44F3), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pass & Play (Party Mode)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Play on 1 phone by passing to friends',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7E7A9C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isPassAndPlay,
                      activeColor: const Color(0xFF5E44F3),
                      onChanged: (val) {
                        setState(() {
                          _isPassAndPlay = val;
                          if (val) {
                            for (int i = 1; i < 4; i++) {
                              _slots[i] = _LobbySlot(
                                name: 'Player ${i + 1}',
                                isBot: false,
                                isReady: true,
                              );
                            }
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Bottom Action Button
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
                    shadowColor: const Color(0xFF3823B5),
                  ),
                  onPressed: _startGame,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        filledCount == 4 ? 'Start Match' : 'Fill Bots & Start Match',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotTile(int index, _LobbySlot? slot, bool isDark) {
    if (slot == null) {
      // Empty Slot
      return GestureDetector(
        onTap: () => _showInviteSheet(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF201B36) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF322B52) : const Color(0xFFE5E0F6),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2449) : const Color(0xFFEEEAFB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Color(0xFF5E44F3), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Slot ${index + 1}: Empty',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF5A5579),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to invite friend or add bot',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7E7A9C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E44F3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                onPressed: () => _showInviteSheet(index),
                child: const Text(
                  '+ Invite',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Occupied Slot
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: slot.isHost
              ? const Color(0xFF5E44F3)
              : (isDark ? const Color(0xFF322B52) : const Color(0xFFE5E0F6)),
          width: slot.isHost ? 2 : 1.2,
        ),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: slot.name,
            photoUrl: slot.photoUrl,
            radius: 21,
            fallbackColor: slot.isHost
                ? const Color(0xFF5E44F3)
                : (slot.isBot ? const Color(0xFF0D9488) : const Color(0xFFD92D66)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        slot.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF1E1A33),
                        ),
                      ),
                    ),
                    if (slot.isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E44F3).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: Color(0xFF5E44F3),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ] else if (slot.isPending) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'INVITED',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ] else if (slot.isBot) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'BOT',
                          style: TextStyle(
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (slot.isPending)
                  const Row(
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Waiting for response...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Ready to play',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (!slot.isHost)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF7E7A9C)),
              onPressed: () => _removeSlot(index),
            ),
        ],
      ),
    );
  }
}
