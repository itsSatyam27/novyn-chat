import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/socket_service.dart';
import '../../../widgets/user_avatar.dart';
import '../raja_mantri/raja_mantri_online_game_screen.dart';
import '../shared/room/game_room_screen.dart';
import 'game_invitation_utils.dart';

int? _gameInvitationExpiryMillis(Map<String, dynamic> invite) =>
    gameInvitationExpiryTimestamp(invite);

List<Map<String, dynamic>> mergeGameInvitationLists({
  required Iterable<Map<String, dynamic>> snapshot,
  required Iterable<Map<String, dynamic>> live,
  required Set<String> resolvedIds,
  int? nowMillis,
}) {
  final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
  final byId = <String, Map<String, dynamic>>{};

  void addAll(Iterable<Map<String, dynamic>> items) {
    for (final invite in items) {
      final id = invite['messageId']?.toString().trim() ?? '';
      if (id.isEmpty || resolvedIds.contains(id)) continue;
      final expiry = _gameInvitationExpiryMillis(invite);
      if (expiry != null && expiry <= now) continue;
      byId[id] = Map<String, dynamic>.from(invite);
    }
  }

  addAll(snapshot);
  addAll(live);
  final merged = byId.values.toList();
  merged.sort((a, b) {
    final aExpiry = _gameInvitationExpiryMillis(a);
    final bExpiry = _gameInvitationExpiryMillis(b);
    if (aExpiry == null || bExpiry == null) return 0;
    return bExpiry.compareTo(aExpiry);
  });
  return merged;
}

class GameInvitationsScreen extends StatefulWidget {
  const GameInvitationsScreen({
    super.key,
    required this.socket,
  });

  final SocketService socket;

  @override
  State<GameInvitationsScreen> createState() => _GameInvitationsScreenState();
}

class _GameInvitationsScreenState extends State<GameInvitationsScreen> {
  List<Map<String, dynamic>> _invitations = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  final Set<String> _busyIds = <String>{};
  final Set<String> _resolvedIds = <String>{};
  StreamSubscription<String>? _resolvedSubscription;
  StreamSubscription<Map<String, dynamic>>? _timeoutSubscription;

  @override
  void initState() {
    super.initState();
    widget.socket.onGameInvitationReceived = _onInvitationReceived;
    _resolvedSubscription = widget.socket.gameInvitationResolvedStream.listen(
      _onInvitationResolved,
    );
    _timeoutSubscription = widget.socket.gameInvitationTimeoutStream.listen(
      _onInvitationTimedOut,
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.socket.onGameInvitationReceived = null;
    unawaited(_resolvedSubscription?.cancel());
    unawaited(_timeoutSubscription?.cancel());
    super.dispose();
  }

  void _onInvitationReceived(Map packet) {
    final invite = Map<String, dynamic>.from(packet);
    final id = invite['messageId']?.toString() ?? '';
    if (id.isEmpty || _resolvedIds.contains(id)) return;
    if (mounted) {
      setState(() {
        _invitations = mergeGameInvitationLists(
          snapshot: <Map<String, dynamic>>[invite],
          live: _invitations,
          resolvedIds: _resolvedIds,
        );
      });
    }
  }

  Future<void> _load() async {
    final idsAtRequestStart = _invitations
        .map((invite) => invite['messageId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    try {
      final invitations = await widget.socket.getPendingGameInvitations();
      if (!mounted) return;
      final arrivalsDuringRefresh = _invitations.where((invite) {
        final id = invite['messageId']?.toString() ?? '';
        return id.isNotEmpty && !idsAtRequestStart.contains(id);
      });
      setState(() {
        _invitations = mergeGameInvitationLists(
          snapshot: invitations.reversed,
          live: arrivalsDuringRefresh,
          resolvedIds: _resolvedIds,
        );
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _onInvitationResolved(String id) {
    final key = id.trim();
    if (key.isEmpty) return;
    _resolvedIds.add(key);
    if (!mounted) return;
    setState(() {
      _invitations.removeWhere((invite) => invite['messageId']?.toString() == key);
    });
  }

  void _onInvitationTimedOut(Map<String, dynamic> packet) {
    final id = packet['messageId']?.toString() ?? '';
    _busyIds.remove(id);
    _onInvitationResolved(id);
  }

  Future<void> _accept(Map<String, dynamic> invite) async {
    final id = invite['messageId']?.toString() ?? '';
    if (id.isEmpty || !_busyIds.add(id)) return;
    setState(() {});
    try {
      await widget.socket.acceptGameInvite(id);
      widget.socket.notifyGameInvitationResolved(id);
      if (!mounted) return;
      setState(() => _invitations.removeWhere((item) => item['messageId'] == id));
      final game = invite['game'];
      final gameType = invite['gameType']?.toString().toLowerCase() ?? '';
      final peer = invite['from']?.toString() ?? '';
      if (gameType == 'rajamantri') {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => RajaMantriInviteWaitingScreen(
              messageId: id,
              hostName: invite['displayName']?.toString() ?? peer,
            ),
          ),
        );
      } else if (game is Map) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => GameRoomScreen(
              currentUsername: widget.socket.myUsername ?? '',
              initialGame: Map<String, dynamic>.from(game),
              messageId: id,
              peerUsername: peer,
              opponentDisplayName: invite['displayName']?.toString(),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      _busyIds.remove(id);
      if (mounted) setState(() {});
      unawaited(_load());
    }
  }

  Future<void> _reject(Map<String, dynamic> invite) async {
    final id = invite['messageId']?.toString() ?? '';
    if (id.isEmpty || !_busyIds.add(id)) return;
    setState(() {});
    try {
      await widget.socket.rejectGameInvite(id);
      widget.socket.notifyGameInvitationResolved(id);
      if (mounted) setState(() => _invitations.removeWhere((item) => item['messageId'] == id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      _busyIds.remove(id);
      if (mounted) setState(() {});
      unawaited(_load());
    }
  }

  String _gameName(String type) => switch (type.toLowerCase()) {
        'tictactoe' => 'Tic-Tac-Toe',
        'rps' => 'Rock Paper Scissors',
        'rajamantri' => 'Raja Mantri',
        _ => 'Game',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = colors.primary;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141026) : const Color(0xFFF4F2FA),
      appBar: AppBar(
        title: const Text('Game Invitations', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _invitations.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.wifi_off_rounded, size: 42, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Center(child: Text(_error!, textAlign: TextAlign.center)),
                      const SizedBox(height: 12),
                      Center(child: TextButton(onPressed: _load, child: const Text('Try again'))),
                    ],
                  )
                : _invitations.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          Icon(Icons.mail_outline_rounded, size: 52, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .65)),
                          const SizedBox(height: 14),
                          Center(child: Text('No game invitations', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                          const SizedBox(height: 6),
                          Center(child: Text('Invites from your friends will appear here.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                        itemCount: _invitations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final invite = _invitations[index];
                          final id = invite['messageId']?.toString() ?? '';
                          final name = invite['displayName']?.toString().trim().isNotEmpty == true
                              ? invite['displayName'].toString()
                              : invite['from']?.toString() ?? 'A friend';
                          final busy = _busyIds.contains(id);
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF211B37) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accent.withValues(alpha: .18)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    UserAvatar(
                                      name: name,
                                      photoUrl: invite['avatarId']?.toString() ?? '',
                                      radius: 24,
                                      fallbackColor: accent,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 3),
                                          Text('Invited you to ${_gameName(invite['gameType']?.toString() ?? '')}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.sports_esports_rounded, color: accent),
                                  ],
                                ),
                                const SizedBox(height: 13),
                                Row(
                                  children: [
                                    Expanded(child: OutlinedButton(onPressed: busy ? null : () => _reject(invite), child: const Text('Reject'))),
                                    const SizedBox(width: 9),
                                    Expanded(child: FilledButton(onPressed: busy ? null : () => _accept(invite), style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: colors.onPrimary), child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Accept'))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
