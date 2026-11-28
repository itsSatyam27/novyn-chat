import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/socket_service.dart';
import '../../../widgets/user_avatar.dart';
import '../raja_mantri/raja_mantri_online_game_screen.dart';
import 'game_invitation_utils.dart';
import '../shared/room/game_room_screen.dart';

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
  StreamSubscription<Map<String, dynamic>>? _timeoutSubscription;

  @override
  void initState() {
    super.initState();
    widget.socket.onGameInvitationReceived = _onInvitationReceived;
    _timeoutSubscription = widget.socket.gameInvitationTimeoutStream.listen(
      _onInvitationExpired,
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.socket.onGameInvitationReceived = null;
    final timeoutSubscription = _timeoutSubscription;
    if (timeoutSubscription != null) {
      unawaited(timeoutSubscription.cancel());
    }
    super.dispose();
  }

  void _onInvitationReceived(Map packet) {
    final invite = Map<String, dynamic>.from(packet);
    final id = invite['messageId']?.toString() ?? '';
    if (id.isEmpty ||
        isGameInvitationExpired(invite) ||
        _invitations.any((item) => item['messageId'] == id)) {
      return;
    }
    if (mounted) {
      setState(() => _invitations = <Map<String, dynamic>>[invite, ..._invitations]);
    }
  }

  void _onInvitationExpired(Map<String, dynamic> packet) {
    final id = packet['messageId']?.toString() ?? '';
    if (id.isEmpty || !mounted) return;
    setState(() {
      _invitations.removeWhere((item) => item['messageId']?.toString() == id);
      _busyIds.remove(id);
    });
  }

  Future<void> _load() async {
    final existingIdsAtRequestStart = _invitations
        .map((invite) => invite['messageId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    try {
      final invitations = await widget.socket.getPendingGameInvitations();
      if (!mounted) return;

      final mergedById = <String, Map<String, dynamic>>{};
      for (final invite in invitations) {
        final id = invite['messageId']?.toString() ?? '';
        if (id.isNotEmpty && !isGameInvitationExpired(invite)) {
          mergedById[id] = invite;
        }
      }
      // Keep invitations delivered by the live socket while this request was
      // in flight; the server snapshot may have been taken just before delivery.
      for (final invite in _invitations) {
        final id = invite['messageId']?.toString() ?? '';
        if (id.isNotEmpty &&
            !existingIdsAtRequestStart.contains(id) &&
            !isGameInvitationExpired(invite)) {
          mergedById[id] = invite;
        }
      }
      final merged = mergedById.values.toList()
        ..sort((a, b) => (gameInvitationExpiryTimestamp(b) ?? 0)
            .compareTo(gameInvitationExpiryTimestamp(a) ?? 0));
      setState(() {
        _invitations = merged;
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

  Future<void> _accept(Map<String, dynamic> invite) async {
    final id = invite['messageId']?.toString() ?? '';
    if (id.isEmpty || !_busyIds.add(id)) return;
    setState(() {});
    try {
      await widget.socket.acceptGameInvite(id);
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
