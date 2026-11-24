import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/user_avatar.dart';
import 'raja_mantri_screen.dart';
import 'raja_mantri_online_game_screen.dart';

class RajaMantriLobbyScreen extends StatefulWidget {
  const RajaMantriLobbyScreen({super.key});

  @override
  State<RajaMantriLobbyScreen> createState() => _RajaMantriLobbyScreenState();
}

class _RMRoomMember {
  const _RMRoomMember({
    required this.name,
    this.username = '',
    this.photoUrl = '',
    this.isHost = false,
    this.isBot = false,
    this.isJoined = false,
    this.messageId = '',
  });

  final String name;
  final String username;
  final String photoUrl;
  final bool isHost;
  final bool isBot;
  final bool isJoined;
  final String messageId;

  _RMRoomMember copyWith({bool? isJoined, String? messageId}) => _RMRoomMember(
        name: name,
        username: username,
        photoUrl: photoUrl,
        isHost: isHost,
        isBot: isBot,
        isJoined: isJoined ?? this.isJoined,
        messageId: messageId ?? this.messageId,
      );
}

class _RajaMantriLobbyScreenState extends State<RajaMantriLobbyScreen> {
  static const _purple = Color(0xFF5E4CF2);
  static const _ink = Color(0xFF1E1A43);
  static const _muted = Color(0xFF625D8C);

  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<_RMRoomMember?>> _roomMembers =
      ValueNotifier<List<_RMRoomMember?>>(<_RMRoomMember?>[]);
  final ValueNotifier<int> _searchProgress = ValueNotifier<int>(1);
  final ValueNotifier<List<Map<String, dynamic>>> _searchRoster = ValueNotifier<List<Map<String, dynamic>>>(const []);
  final ValueNotifier<int> _searchSeconds = ValueNotifier<int>(60);
  List<UserModel> _friends = [];
  final Set<String> _selectedFriends = <String>{};
  final Set<String> _acceptedInviteIds = <String>{};
  int _playerCount = 3;
  bool _loadingFriends = false;
  bool _sendingInvites = false;
  bool _searchingPlayers = false;
  bool _searchRouteOpen = false;
  bool _cancellingSearch = false;
  bool _friendLoadFailed = false;
  bool _roomStarted = false;
  Timer? _searchTimer;
  DateTime? _searchDeadline;
  SocketService? _socket;
  AuthService? _auth;

  int get _requiredFriends => _playerCount - 1;
  String get _account => _auth?.user?.username ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _auth = context.read<AuthService>();
      _socket = context.read<SocketService>();
      _socket!.onGameInviteAccepted = _handleFriendInviteAccepted;
      _socket!.onGameInviteTimeout = _handleFriendInviteTimeout;
      _socket!.onRajaMantriMatchFound = _handleRandomMatchFound;
      _socket!.onRajaMantriMatchProgress = _handleRandomMatchProgress;
      _socket!.onRajaMantriMatchTimeout = _handleRandomMatchTimeout;
      _socket!.addListener(_handleSocketStateChanged);
      _loadFriends();
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    if (_socket != null) {
      if (!_roomStarted) {
        final pendingInvites = _roomMembers.value
            .whereType<_RMRoomMember>()
            .where((member) => !member.isHost && !member.isBot && member.messageId.isNotEmpty)
            .map((member) => member.messageId)
            .toSet();
        for (final messageId in pendingInvites) {
          unawaited(_socket!.cancelGameInvite(messageId).catchError((_) {}));
        }
      }
      _socket!.removeListener(_handleSocketStateChanged);
      _socket!.onGameInviteAccepted = null;
      _socket!.onGameInviteTimeout = null;
      _socket!.onRajaMantriMatchFound = null;
      _socket!.onRajaMantriMatchProgress = null;
      _socket!.onRajaMantriMatchTimeout = null;
      if (_searchingPlayers) {
        unawaited(_socket!.cancelRajaMantriMatchmaking().catchError((_) {}));
      }
    }
    _roomMembers.dispose();
    _searchProgress.dispose();
    _searchRoster.dispose();
    _searchSeconds.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final username = _auth?.user?.username.trim() ?? '';
    if (username.isEmpty) return;
    setState(() {
      _loadingFriends = true;
      _friendLoadFailed = false;
    });
    try {
      final service = context.read<FriendService>();
      final cached = service.cachedFriends;
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() {
          _friends = cached;
          _loadingFriends = false;
        });
      }
      final fresh = await service.friendsStream(username).first;
      if (!mounted) return;
      setState(() {
        _friends = fresh;
        _loadingFriends = false;
        _selectedFriends.removeWhere(
          (name) => !_friends.any((friend) => friend.username.toLowerCase() == name),
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingFriends = false;
          _friendLoadFailed = true;
        });
      }
    }
  }

  List<UserModel> get _filteredFriends {
    final query = _searchController.text.trim().toLowerCase();
    final used = _roomMembers.value.whereType<_RMRoomMember>()
        .map((member) => member.username.toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    return _friends.where((friend) {
      final username = friend.username.toLowerCase();
      if (username == _account.toLowerCase() || used.contains(username)) return false;
      if (query.isEmpty) return true;
      return friend.name.toLowerCase().contains(query) || username.contains(query);
    }).toList();
  }

  void _changePlayerCount(int count) {
    if (_searchingPlayers || _sendingInvites) return;
    setState(() {
      _playerCount = count;
      _selectedFriends.clear();
    });
  }

  void _toggleFriend(UserModel friend, bool selected) {
    final key = friend.username.toLowerCase();
    setState(() {
      if (selected) {
        if (_selectedFriends.length < _requiredFriends) {
          _selectedFriends.add(key);
        }
      } else {
        _selectedFriends.remove(key);
      }
    });
  }

  void _setMembers(List<_RMRoomMember?> members) {
    _roomMembers.value = List<_RMRoomMember?>.unmodifiable(members);
  }

  List<_RMRoomMember?> _newRoom() {
    final user = _auth?.user;
    final hostName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : (user?.username.trim().isNotEmpty == true ? user!.username : 'You');
    return <_RMRoomMember?>[
      _RMRoomMember(
        name: hostName,
        username: user?.username ?? '',
        photoUrl: user?.avatarId ?? '',
        isHost: true,
        isJoined: true,
      ),
      ...List<_RMRoomMember?>.filled(_requiredFriends, null),
    ];
  }

  Future<void> _inviteSelectedFriends() async {
    if (_sendingInvites || _selectedFriends.isEmpty) return;
    final selected = _friends
        .where((friend) => _selectedFriends.contains(friend.username.toLowerCase()))
        .take(_requiredFriends)
        .toList();
    if (selected.isEmpty) return;
    setState(() => _sendingInvites = true);
    final members = _newRoom();
    _acceptedInviteIds.clear();
    _setMembers(members);
    try {
      final socket = _socket ?? context.read<SocketService>();
      for (var index = 0; index < selected.length; index++) {
        final friend = selected[index];
        final slot = index + 1;
        final displayName = friend.name.trim().isNotEmpty ? friend.name : friend.username;
        members[slot] = _RMRoomMember(
          name: displayName,
          username: friend.username,
          photoUrl: friend.photoUrl,
        );
        _setMembers(members);
        try {
          final messageId = await socket.sendGameChallenge('rajamantri', friend.username);
          if (!mounted) {
            unawaited(socket.cancelGameInvite(messageId).catchError((_) {}));
            return;
          }
          final acceptedEarly = _acceptedInviteIds.remove(messageId);
          members[slot] = _RMRoomMember(
            name: displayName,
            username: friend.username,
            photoUrl: friend.photoUrl,
            messageId: messageId,
            isJoined: acceptedEarly,
          );
          _setMembers(members);
        } catch (error) {
          if (!mounted) return;
          members[slot] = null;
          _setMembers(members);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not invite @${friend.username}: ${error is StateError ? error.message : 'Please retry.'}'),
              ),
            );
          }
        }
      }
      if (!mounted) return;
      setState(() => _selectedFriends.clear());
      _showWaitingRoom();
    } finally {
      if (mounted) setState(() => _sendingInvites = false);
    }
  }

  void _handleFriendInviteAccepted(Map data) {
    if (!mounted) return;
    final messageId = data['messageId']?.toString() ?? '';
    if (messageId.isEmpty) return;
    final updated = List<_RMRoomMember?>.from(_roomMembers.value);
    final index = updated.indexWhere((member) => member?.messageId == messageId);
    if (index < 0) {
      // The recipient can accept while the send challenge acknowledgement
      // is still returning to this device. Cache that early acceptance.
      _acceptedInviteIds.add(messageId);
      return;
    }
    updated[index] = updated[index]!.copyWith(isJoined: true);
    _setMembers(updated);
  }

  void _handleFriendInviteTimeout(Map data) {
    if (!mounted || data['gameType']?.toString() != 'rajamantri') return;
    final messageId = data['messageId']?.toString() ?? '';
    final updated = List<_RMRoomMember?>.from(_roomMembers.value);
    final index = updated.indexWhere((member) => member?.messageId == messageId);
    if (index < 0) return;
    final expired = updated[index];
    updated[index] = null;
    _setMembers(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('@${expired?.username ?? 'Friend'} invite expired.')),
    );
  }

  void _showWaitingRoom() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _RMWaitingRoomSheet(
          playerCount: _playerCount,
          members: _roomMembers,
          onFillWithBots: _fillOpenSlotsWithBots,
          onStart: () => _startLocalRoom(sheetContext),
          onCancelInvite: _cancelRoomInvite,
          onClose: () => _closeWaitingRoom(sheetContext),
        );
      },
    );
  }

  Future<void> _cancelRoomInvite(int index) async {
    final updated = List<_RMRoomMember?>.from(_roomMembers.value);
    if (index < 1 || index >= updated.length) return;
    final member = updated[index];
    if (member == null || member.isBot || member.isHost) return;
    if (member.messageId.isNotEmpty) {
      try {
        await (_socket ?? context.read<SocketService>()).cancelGameInvite(member.messageId);
      } catch (error) {
        _showMessage(error is StateError ? error.message.toString() : 'Could not cancel this invite. Please retry.');
        return;
      }
    }
    updated[index] = null;
    _setMembers(updated);
  }

  Future<void> _fillOpenSlotsWithBots() async {
    final updated = List<_RMRoomMember?>.from(_roomMembers.value);
    for (var i = 1; i < updated.length; i++) {
      final member = updated[i];
      if (member != null && !member.isBot && !member.isJoined) {
        if (member.messageId.isNotEmpty) {
          try {
            await (_socket ?? context.read<SocketService>()).cancelGameInvite(member.messageId);
          } catch (error) {
            _showMessage(error is StateError ? error.message.toString() : 'Could not replace a pending invite with a bot.');
            return;
          }
        }
        updated[i] = null;
      }
    }
    var botNumber = 1;
    for (var i = 1; i < updated.length; i++) {
      if (updated[i] == null) {
        while (updated.whereType<_RMRoomMember>().any(
            (member) => member.name == 'Bot $botNumber')) {
          botNumber++;
        }
        updated[i] = _RMRoomMember(
          name: 'Bot $botNumber',
          isBot: true,
          isJoined: true,
        );
        botNumber++;
      }
    }
    _setMembers(updated);
  }

  bool get _roomReady => _roomMembers.value.length == _playerCount &&
      _roomMembers.value.every((member) =>
          member != null && (member.isJoined || member.isBot || member.isHost));

  Future<void> _startLocalRoom(BuildContext sheetContext) async {
    if (!_roomReady || _sendingInvites) return;
    final members = _roomMembers.value.whereType<_RMRoomMember>().toList();
    final inviteMessageIds = members
        .where((member) => !member.isHost && !member.isBot && member.isJoined)
        .map((member) => member.messageId)
        .where((messageId) => messageId.isNotEmpty)
        .toList(growable: false);
    final botCount = members.where((member) => member.isBot).length;
    if (inviteMessageIds.length + botCount != _playerCount - 1) {
      _showMessage('Every player must be joined or filled with a bot before starting.');
      return;
    }

    final rootNavigator = Navigator.of(context);
    final sheetNavigator = Navigator.of(sheetContext);
    if (inviteMessageIds.isEmpty && botCount == _playerCount - 1) {
      final user = _auth?.user;
      final opponents = members
          .where((member) => !member.isHost)
          .map((member) => member.name)
          .toList(growable: false);
      sheetNavigator.pop();
      rootNavigator.pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => RajaMantriScreen(
            currentUsername: user?.username ?? '',
            playerPhotoUrl: user?.avatarId ?? '',
            customOpponents: opponents,
            playerCount: _playerCount,
          ),
        ),
      );
      return;
    }

    setState(() => _sendingInvites = true);
    try {
      final result = await (_socket ?? context.read<SocketService>()).startRajaMantriFriendRoom(
        playerCount: _playerCount,
        inviteMessageIds: inviteMessageIds,
        botCount: botCount,
      );
      if (!mounted || !sheetContext.mounted) return;
      final sessionId = result['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) {
        throw StateError('The room was created but its session ID was missing.');
      }
      sheetNavigator.pop();
      rootNavigator.pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => RajaMantriOnlineGameScreen(sessionId: sessionId),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is StateError
              ? error.message.toString()
              : 'Could not start the room. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _sendingInvites = false);
    }
  }

  Future<void> _closeWaitingRoom(BuildContext sheetContext) async {
    final pending = _roomMembers.value
        .whereType<_RMRoomMember>()
        .where((member) => !member.isHost && !member.isBot)
        .toList(growable: false);
    for (final member in pending) {
      if (member.messageId.isEmpty) continue;
      try {
        await (_socket ?? context.read<SocketService>()).cancelGameInvite(member.messageId);
      } catch (_) {
        // The room is leaving; the invite will still expire server-side.
      }
    }
    if (!mounted || !sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    _setMembers(const []);
    _acceptedInviteIds.clear();
  }

  void _openFillBotsRoom() {
    if (_sendingInvites || _searchingPlayers) return;
    _setMembers(_newRoom());
    unawaited(_fillOpenSlotsWithBots());
    _showWaitingRoom();
  }

  Future<void> _startRandomSearch() async {
    if (_searchingPlayers || _sendingInvites) return;
    final socket = _socket ?? context.read<SocketService>();
    if (!socket.isConnected || !socket.isAuthenticated) {
      _showMessage('Reconnect to Novyn before searching for players.');
      return;
    }
    setState(() {
      _searchingPlayers = true;
      _cancellingSearch = false;
      _searchProgress.value = 1;
      _searchRoster.value = const [];
      _searchSeconds.value = 60;
      _searchRouteOpen = false;
      _searchDeadline = DateTime.now().add(const Duration(seconds: 60));
    });
    try {
      final result = await socket.joinRajaMantriMatchmaking(_playerCount);
      if (!mounted || !_searchingPlayers) return;
      final found = int.tryParse(result['playersFound']?.toString() ?? '');
      if (found != null) _searchProgress.value = found;
      _searchTimer?.cancel();
      _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_searchingPlayers) {
          timer.cancel();
          return;
        }
        final deadline = _searchDeadline;
        if (deadline == null) return;
        final remaining = deadline.difference(DateTime.now()).inSeconds.clamp(0, 60);
        _searchSeconds.value = remaining;
        if (remaining <= 0) {
          timer.cancel();
          _handleRandomMatchTimeout({
            'playerCount': _playerCount,
            'message': 'No complete group found. Please try again.',
          });
        }
      });
      _searchRouteOpen = true;
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _RajaMantriSearchingScreen(
            playerCount: _playerCount,
            progress: _searchProgress,
            roster: _searchRoster,
            secondsRemaining: _searchSeconds,
            onCancel: _cancelRandomSearch,
          ),
        ),
      ).whenComplete(() {
        _searchRouteOpen = false;
        if (mounted && _searchingPlayers && !_cancellingSearch) {
          unawaited(_cancelRandomSearch());
        }
      });
    } catch (error) {
      if (!mounted) return;
      _searchTimer?.cancel();
      setState(() {
        _searchingPlayers = false;
        _searchDeadline = null;
      });
      _showMessage(error is StateError ? error.message.toString() : 'Could not start player search.');
    }
  }

  void _handleRandomMatchProgress(Map data) {
    if (!mounted || !_searchingPlayers) return;
    if (int.tryParse(data['playerCount']?.toString() ?? '') != _playerCount) return;
    final count = int.tryParse(data['playersFound']?.toString() ?? '');
    if (count != null) _searchProgress.value = count;
    final players = data['players'];
    if (players is List) {
      _searchRoster.value = players
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
    }
  }

  void _handleRandomMatchFound(Map data) {
    if (!mounted || !_searchingPlayers) return;
    final playerCount = int.tryParse(data['playerCount']?.toString() ?? '') ?? 0;
    final rawPlayers = data['players'];
    if (playerCount != _playerCount || rawPlayers is! List || rawPlayers.length != playerCount) return;
    final players = rawPlayers.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList();
    if (players.length != playerCount) return;
    _searchTimer?.cancel();
    setState(() {
      _searchingPlayers = false;
      _cancellingSearch = false;
      _searchDeadline = null;
    });
    final searchRoute = Navigator.of(context);
    if (_searchRouteOpen && searchRoute.canPop()) {
      _searchRouteOpen = false;
      searchRoute.pop();
    }
    final sessionId = data['sessionId']?.toString() ?? data['matchId']?.toString() ?? '';
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _RajaMantriMatchFoundScreen(
          playerCount: playerCount,
          players: players,
          onStart: () {
            if (!mounted) return;
            if (sessionId.isEmpty) {
              _showMessage('The match room could not be opened. Please search again.');
              Navigator.of(context).pop();
              return;
            }
            Navigator.of(context).pushReplacement<void, void>(
              MaterialPageRoute<void>(
                builder: (_) => RajaMantriOnlineGameScreen(sessionId: sessionId),
              ),
            );
          },
          onLeave: () {
            unawaited(
              (_socket ?? context.read<SocketService>())
                  .leaveRajaMantriGame(sessionId)
                  .catchError((_) {}),
            );
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _handleRandomMatchTimeout(Map data) {
    if (!mounted || !_searchingPlayers) return;
    _searchTimer?.cancel();
    setState(() {
      _searchingPlayers = false;
      _searchDeadline = null;
    });
    if (_searchRouteOpen && Navigator.of(context).canPop()) {
      _searchRouteOpen = false;
      Navigator.of(context).pop();
    }
    _showMessage(data['message']?.toString() ?? 'No complete group found. Please try again.');
  }

  void _handleSocketStateChanged() {
    if (!mounted || !_searchingPlayers || (_socket?.isConnected == true && _socket?.isAuthenticated == true)) return;
    _searchTimer?.cancel();
    setState(() {
      _searchingPlayers = false;
      _searchDeadline = null;
    });
    if (_searchRouteOpen && Navigator.of(context).canPop()) {
      _searchRouteOpen = false;
      Navigator.of(context).pop();
    }
    _showMessage('Connection lost. Player search was cancelled.');
  }

  Future<void> _cancelRandomSearch() async {
    if (!_searchingPlayers || _cancellingSearch) return;
    setState(() => _cancellingSearch = true);
    try {
      await (_socket ?? context.read<SocketService>()).cancelRajaMantriMatchmaking();
    } catch (_) {}
    if (!mounted) return;
    _searchTimer?.cancel();
    setState(() {
      _searchingPlayers = false;
      _cancellingSearch = false;
      _searchDeadline = null;
    });
    if (_searchRouteOpen && Navigator.of(context).canPop()) {
      _searchRouteOpen = false;
      Navigator.of(context).pop();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF141026) : const Color(0xFFF6F5FD);
    final foreground = isDark ? Colors.white : _ink;
    final muted = isDark ? Colors.white60 : _muted;
    final friends = _filteredFriends;
    final needed = _requiredFriends;
    return PopScope<void>(
      canPop: !_sendingInvites && !_searchingPlayers,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showMessage(_searchingPlayers
              ? 'Cancel player search before leaving this screen.'
              : 'Wait for invitations to finish before leaving.');
        }
      },
      child: Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
              child: Row(
                children: [
                  Material(
                    color: isDark ? const Color(0xFF201B36) : Colors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _sendingInvites || _searchingPlayers
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_rounded, color: foreground, size: 26),
                      iconSize: 26,
                      padding: const EdgeInsets.all(14),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Raja Mantri Chor Sipahi',
                      maxLines: 2,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: foreground,
                        height: 1.12,
                      ),
                    ),
                  ),
                  PopupMenuButton<int>(
                    initialValue: _playerCount,
                    onSelected: _changePlayerCount,
                    color: isDark ? const Color(0xFF201B36) : Colors.white,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 3, child: Text('3 players')),
                      PopupMenuItem(value: 4, child: Text('4 players')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2648) : const Color(0xFFEDE9FC),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$_playerCount players', style: TextStyle(color: foreground, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 3),
                          Icon(Icons.expand_more_rounded, color: foreground, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Text('Quick play', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: muted)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _RMQuickPlayTile(
                          title: 'Fill with bots',
                          subtitle: 'Works offline',
                          icon: Icons.smart_toy_outlined,
                          iconBackground: const Color(0xFFDDF3E9),
                          iconColor: const Color(0xFF176B45),
                          background: isDark ? const Color(0xFF201B36) : Colors.white,
                          foreground: foreground,
                          subtitleColor: muted,
                          playColor: _purple,
                          onTap: _openFillBotsRoom,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _RMQuickPlayTile(
                          title: 'Random players',
                          subtitle: 'Find a match online',
                          icon: Icons.public_rounded,
                          iconBackground: const Color(0xFF796CF4),
                          iconColor: Colors.white,
                          background: _purple,
                          foreground: Colors.white,
                          subtitleColor: Colors.white.withValues(alpha: .88),
                          playColor: Colors.white,
                          onTap: _startRandomSearch,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Invite friends', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: muted)),
                      ),
                      Text(
                        '${_selectedFriends.length} of $needed selected',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: foreground, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search by username',
                      hintStyle: TextStyle(color: muted, fontSize: 15),
                      prefixIcon: Icon(Icons.search_rounded, color: muted, size: 24),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF201B36) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: _purple, width: 1.5),
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: Icon(Icons.close_rounded, color: muted),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingFriends && _friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_friendLoadFailed && _friends.isEmpty)
                    TextButton.icon(
                      onPressed: _loadFriends,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Could not load friends · Retry'),
                    )
                  else if (friends.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text(
                        _friends.isEmpty ? 'Add friends in Contacts to invite them here.' : 'No friends found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted),
                      ),
                    )
                  else
                    ...friends.map((friend) {
                      final key = friend.username.toLowerCase();
                      final selected = _selectedFriends.contains(key);
                      final canSelect = selected || _selectedFriends.length < needed;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Material(
                          color: selected
                              ? (isDark ? const Color(0xFF332A57) : const Color(0xFFEEEAFE))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            onTap: canSelect ? () => _toggleFriend(friend, !selected) : null,
                            borderRadius: BorderRadius.circular(22),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    name: friend.name.isNotEmpty ? friend.name : friend.username,
                                    photoUrl: friend.photoUrl,
                                    radius: 23,
                                    isOnline: friend.isOnline,
                                    presence: friend.status,
                                    showOnlineIndicator: true,
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.name.isNotEmpty ? friend.name : friend.username,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 15),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '@${friend.username} · ${friend.isOnline ? friend.status : 'Offline'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: muted, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected ? _purple : Colors.transparent,
                                      border: Border.all(
                                        color: selected ? _purple : const Color(0xFF9690B7),
                                        width: 2,
                                      ),
                                    ),
                                    child: selected
                                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                child: SizedBox(
                  height: 62,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedFriends.isNotEmpty && !_sendingInvites
                        ? _inviteSelectedFriends
                        : null,
                    icon: _sendingInvites
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_alt_1_rounded, size: 22),
                    label: Text(
                      _sendingInvites
                          ? 'Sending invites…'
                          : _selectedFriends.isEmpty
                              ? 'Select friends to invite'
                              : 'Invite ${_selectedFriends.length} friend${_selectedFriends.length == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E0F6),
                      disabledForegroundColor: muted,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _RMQuickPlayTile extends StatelessWidget {
  const _RMQuickPlayTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.background,
    required this.foreground,
    required this.subtitleColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final Color background;
  final Color foreground;
  final Color subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 150,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subtitleColor, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RMWaitingRoomSheet extends StatelessWidget {
  const _RMWaitingRoomSheet({
    required this.playerCount,
    required this.members,
    required this.onFillWithBots,
    required this.onStart,
    required this.onCancelInvite,
    required this.onClose,
  });

  final int playerCount;
  final ValueListenable<List<_RMRoomMember?>> members;
  final Future<void> Function() onFillWithBots;
  final VoidCallback onStart;
  final Future<void> Function(int) onCancelInvite;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);
    final surface = isDark ? const Color(0xFF201B36) : const Color(0xFFF5F3FC);
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * .52,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF201B36) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, -4))],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: isDark ? Colors.white24 : const Color(0xFFD4CEEF), borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In this room', style: TextStyle(color: foreground, fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      ValueListenableBuilder<List<_RMRoomMember?>>(
                        valueListenable: members,
                        builder: (context, values, _) {
                          final joined = values.whereType<_RMRoomMember>().where((member) => member.isJoined || member.isBot || member.isHost).length;
                          return Text('$joined of $playerCount joined', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w700));
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close room',
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ValueListenableBuilder<List<_RMRoomMember?>>(
                valueListenable: members,
                builder: (context, values, _) => ListView.separated(
                  itemCount: playerCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = index < values.length ? values[index] : null;
                    if (member == null) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFCFC7F4), width: 1.5, style: BorderStyle.solid),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(color: Color(0xFFEDE9FC), shape: BoxShape.circle),
                              child: const Icon(Icons.add_rounded, color: _RajaMantriLobbyScreenState._purple),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Open slot', style: TextStyle(color: muted, fontWeight: FontWeight.w800))),
                            Text('Empty', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    }
                    final ready = member.isHost || member.isBot || member.isJoined;
                    final statusColor = ready ? const Color(0xFF18A05E) : const Color(0xFFE9A400);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
                      child: Row(
                        children: [
                          UserAvatar(name: member.name, photoUrl: member.photoUrl, radius: 20, showOnlineIndicator: false),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.isHost ? '${member.name} · Host' : member.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                                if (member.isBot)
                                  const Text('Bot player', style: TextStyle(color: Color(0xFF0D9488), fontSize: 11, fontWeight: FontWeight.w700)),
                                if (member.isHost)
                                  const Text('Room owner', style: TextStyle(color: Color(0xFF5E4CF2), fontSize: 11, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: ready ? const Color(0xFFDDF3E9) : const Color(0xFFFFF0C2),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 9, color: statusColor),
                                const SizedBox(width: 6),
                                Text(
                                  ready ? (member.isBot ? 'Bot ready' : 'Joined') : 'Joining…',
                                  style: TextStyle(color: ready ? const Color(0xFF176B45) : const Color(0xFF8A5B00), fontWeight: FontWeight.w800, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (!member.isHost && !member.isBot)
                            IconButton(
                              tooltip: 'Cancel invitation',
                              onPressed: () => onCancelInvite(index),
                              icon: Icon(Icons.close_rounded, color: muted, size: 18),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: onFillWithBots,
                      icon: const Icon(Icons.smart_toy_outlined, size: 20),
                      label: const Text('Fill with bots', maxLines: 1, overflow: TextOverflow.ellipsis),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5141E5),
                        backgroundColor: const Color(0xFFEDE9FC),
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ValueListenableBuilder<List<_RMRoomMember?>>(
                    valueListenable: members,
                    builder: (context, values, _) {
                      final ready = values.length == playerCount && values.every(
                        (member) => member != null && (member.isHost || member.isBot || member.isJoined),
                      );
                      return SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: ready ? onStart : null,
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text('Start match', maxLines: 1, overflow: TextOverflow.ellipsis),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF5E4CF2),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE5E0F6),
                            disabledForegroundColor: const Color(0xFF777195),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RajaMantriSearchingScreen extends StatelessWidget {
  const _RajaMantriSearchingScreen({
    required this.playerCount,
    required this.progress,
    required this.roster,
    required this.secondsRemaining,
    required this.onCancel,
  });

  final int playerCount;
  final ValueListenable<int> progress;
  final ValueListenable<List<Map<String, dynamic>>> roster;
  final ValueListenable<int> secondsRemaining;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF141026) : const Color(0xFFF5F3FC);
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);
    final surface = isDark ? const Color(0xFF201B36) : Colors.white;
    return PopScope<void>(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: [
                    Material(
                      color: surface,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: onCancel,
                        icon: Icon(Icons.close_rounded, color: foreground),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Raja Mantri Chor Sipahi', style: TextStyle(color: foreground, fontSize: 19, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(color: const Color(0xFFEDE9FC), borderRadius: BorderRadius.circular(22)),
                      child: Text('$playerCount players', style: const TextStyle(color: Color(0xFF403875), fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(300.0, math.min(constraints.maxWidth - 48, constraints.maxHeight * .43)).clamp(150.0, 300.0).toDouble();
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        SizedBox(
                          width: size,
                          height: size,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (final factor in [1.0, .77, .54])
                                Container(
                                  width: size * factor,
                                  height: size * factor,
                                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFBDB5F3).withValues(alpha: .45), width: 1.5)),
                                ),
                              for (final dot in const [
                                [0.18, 0.28, 13.0, Color(0xFFD5F1E5)],
                                [0.82, 0.18, 11.0, Color(0xFFFFDCE7)],
                                [0.25, 0.82, 10.0, Color(0xFFE6E0FF)],
                                [0.84, 0.78, 14.0, Color(0xFFFFE5D4)],
                              ])
                                Positioned(
                                  left: size * (dot[0] as double) - (dot[2] as double) / 2,
                                  top: size * (dot[1] as double) - (dot[2] as double) / 2,
                                  child: Container(
                                    width: dot[2] as double,
                                    height: dot[2] as double,
                                    decoration: BoxDecoration(color: dot[3] as Color, shape: BoxShape.circle),
                                  ),
                                ),
                              Container(
                                width: size * .37,
                                height: size * .37,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1A43),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF6250F5), width: 5),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.groups_rounded, color: Colors.white, size: 42),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Finding players', style: TextStyle(color: foreground, fontSize: 28, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            ValueListenableBuilder<int>(
                              valueListenable: progress,
                              builder: (context, count, _) => Text(
                                '$count of $playerCount players found',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: muted, fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 18),
                            ValueListenableBuilder<int>(
                              valueListenable: secondsRemaining,
                              builder: (context, seconds, _) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time_rounded, color: muted, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      '0:${seconds.toString().padLeft(2, '0')}',
                                      style: const TextStyle(color: Color(0xFF403875), fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: roster,
                          builder: (context, players, _) {
                            final occupied = players.take(playerCount).toList();
                            final slots = List<Map<String, dynamic>?>.generate(
                              playerCount,
                              (index) => index < occupied.length ? occupied[index] : null,
                            );
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(playerCount, (index) {
                                  final player = slots[index];
                                  final name = player?['displayName']?.toString() ??
                                      player?['username']?.toString() ?? 'Searching';
                                  final joined = player != null;
                                  final dotColor = joined
                                      ? const Color(0xFF18A05E)
                                      : const Color(0xFFE9A400);
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 54,
                                            height: 54,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: joined
                                                  ? const [Color(0xFF1E1A43), Color(0xFFD92D66), Color(0xFF0D9472), Color(0xFFB86A00)][index]
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: dotColor,
                                                width: joined ? 3 : 2,
                                                style: joined ? BorderStyle.solid : BorderStyle.solid,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              joined && name.isNotEmpty ? name[0].toUpperCase() : '?',
                                              style: TextStyle(
                                                color: joined ? Colors.white : const Color(0xFF8A5B00),
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: joined ? foreground : muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: joined ? const Color(0xFFDDF3E9) : const Color(0xFFFFF0C2),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.circle, size: 7, color: dotColor),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    joined ? 'Joined' : 'Joining…',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: joined ? const Color(0xFF176B45) : const Color(0xFF8A5B00),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
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
                                }),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onCancel,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF282046) : const Color(0xFFEDE9FC),
                      foregroundColor: const Color(0xFF5141E5),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Cancel search', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RajaMantriMatchFoundScreen extends StatefulWidget {
  const _RajaMantriMatchFoundScreen({
    required this.playerCount,
    required this.players,
    required this.onStart,
    required this.onLeave,
  });

  final int playerCount;
  final List<Map<String, dynamic>> players;
  final VoidCallback onStart;
  final VoidCallback onLeave;

  @override
  State<_RajaMantriMatchFoundScreen> createState() => _RajaMantriMatchFoundScreenState();
}

class _RajaMantriMatchFoundScreenState extends State<_RajaMantriMatchFoundScreen> {
  Timer? _timer;
  int _seconds = 3;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_seconds <= 1) {
        timer.cancel();
        widget.onStart();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF141026) : const Color(0xFFF5F3FC);
    final foreground = isDark ? Colors.white : const Color(0xFF1E1A43);
    final muted = isDark ? Colors.white60 : const Color(0xFF625D8C);
    const colors = [Color(0xFF6250F5), Color(0xFFE32C62), Color(0xFF0D9472), Color(0xFFB86A00)];
    return PopScope<void>(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: [
                    Material(
                      color: isDark ? const Color(0xFF201B36) : Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: widget.onLeave,
                        icon: Icon(Icons.close_rounded, color: foreground),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Raja Mantri Chor Sipahi', maxLines: 2, style: TextStyle(color: foreground, fontSize: 19, fontWeight: FontWeight.w900))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(color: const Color(0xFFEDE9FC), borderRadius: BorderRadius.circular(22)),
                      child: Text('${widget.playerCount} players', style: const TextStyle(color: Color(0xFF403875), fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = widget.playerCount == 3 && constraints.maxWidth > 380 ? 3 : 2;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: const Color(0xFFDDF3E9), borderRadius: BorderRadius.circular(22)),
                              child: const Text('Match found', style: TextStyle(color: Color(0xFF176B45), fontWeight: FontWeight.w800, fontSize: 14)),
                            ),
                            const SizedBox(height: 18),
                            Text('Get ready!', style: TextStyle(color: foreground, fontSize: 30, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 20,
                            runSpacing: 22,
                            children: List.generate(widget.players.length, (index) {
                              final player = widget.players[index];
                              final name = player['displayName']?.toString() ?? player['username']?.toString() ?? 'Player';
                              final avatarSize = columns == 3 ? 78.0 : 88.0;
                              return SizedBox(
                                width: columns == 3 ? 96 : (constraints.maxWidth - 100) / 2,
                                child: Column(
                                  children: [
                                    Container(
                                      width: avatarSize,
                                      height: avatarSize,
                                      decoration: BoxDecoration(
                                        color: colors[index % colors.length],
                                        shape: BoxShape.circle,
                                        border: Border.all(color: colors[index % colors.length], width: 3),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase(),
                                        style: TextStyle(color: Colors.white, fontSize: avatarSize * .4, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontWeight: FontWeight.w900, fontSize: 15)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                      decoration: BoxDecoration(color: const Color(0xFFEDE9FC), borderRadius: BorderRadius.circular(22)),
                                      child: Text(index == 0 ? 'Host' : 'Joined', style: const TextStyle(color: Color(0xFF403875), fontWeight: FontWeight.w800, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: LinearProgressIndicator(
                                  value: _seconds / 3,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFE3DFF5),
                                  valueColor: const AlwaysStoppedAnimation<Color>(_RajaMantriLobbyScreenState._purple),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Starting in $_seconds seconds', style: TextStyle(color: muted, fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onLeave,
                    style: FilledButton.styleFrom(backgroundColor: isDark ? const Color(0xFF282046) : const Color(0xFFEDE9FC), foregroundColor: const Color(0xFF5141E5), shape: const StadiumBorder()),
                    child: const Text('Leave match', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
