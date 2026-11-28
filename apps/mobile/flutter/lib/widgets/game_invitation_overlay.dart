import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/socket_service.dart';
import '../screens/games/raja_mantri/raja_mantri_online_game_screen.dart';
import '../screens/games/invitations/game_invitation_utils.dart';
import '../screens/games/shared/room/game_room_screen.dart';

/// App-wide, non-modal game invitation surface.
///
/// It is mounted beside the app Navigator, so invitations can be accepted or
/// declined from any route (including an active chat) without replacing that
/// route or blocking the message composer.
class GameInvitationOverlay extends StatefulWidget {
  const GameInvitationOverlay({
    super.key,
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<GameInvitationOverlay> createState() => _GameInvitationOverlayState();
}

class _GameInvitationOverlayState extends State<GameInvitationOverlay> {
  SocketService? _socket;
  StreamSubscription<Map<String, dynamic>>? _invitationSubscription;
  StreamSubscription<Map<String, dynamic>>? _timeoutSubscription;
  final Queue<Map<String, dynamic>> _queue =
      Queue<Map<String, dynamic>>();
  static const int _maxRememberedInvitationIds = 256;
  final LinkedHashSet<String> _seenIds = LinkedHashSet<String>();
  Map<String, dynamic>? _activeInvitation;
  bool _working = false;
  bool _wasConnected = false;
  String? _actionError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final socket = context.read<SocketService>();
    if (identical(socket, _socket)) return;

    _detachSocket();
    _wasConnected = false;
    _socket = socket;
    socket.addListener(_handleSocketChanged);
    _invitationSubscription = socket.gameInvitationStream.listen(
      _enqueueInvitation,
    );
    _timeoutSubscription = socket.gameInvitationTimeoutStream.listen(
      _expireInvitation,
    );
    _handleSocketChanged();
  }

  void _detachSocket() {
    _socket?.removeListener(_handleSocketChanged);
    final invitationSubscription = _invitationSubscription;
    if (invitationSubscription != null) {
      unawaited(invitationSubscription.cancel());
    }
    final timeoutSubscription = _timeoutSubscription;
    if (timeoutSubscription != null) {
      unawaited(timeoutSubscription.cancel());
    }
    _invitationSubscription = null;
    _timeoutSubscription = null;
  }

  void _handleSocketChanged() {
    final socket = _socket;
    if (socket == null) return;
    final connected = socket.isConnected && socket.isAuthenticated;
    if (!connected) {
      _wasConnected = false;
      if (socket.myUsername == null &&
          (_activeInvitation != null || _queue.isNotEmpty)) {
        setState(() {
          _activeInvitation = null;
          _queue.clear();
          _actionError = null;
          _working = false;
        });
      } else {
        _scheduleConnectionUiRefresh();
      }
      return;
    }
    if (!_wasConnected) {
      _wasConnected = true;
      if (_actionError == 'Reconnect to respond to this invitation.') {
        _actionError = null;
      }
      _scheduleConnectionUiRefresh();
      unawaited(_loadPendingInvitations(socket));
    }
  }

  void _scheduleConnectionUiRefresh() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadPendingInvitations(SocketService socket) async {
    final idsAtRequestStart = <String>{
      if ((_activeInvitation?['messageId']?.toString() ?? '').isNotEmpty)
        _activeInvitation!['messageId'].toString(),
      ..._queue
          .map((invite) => invite['messageId']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    };
    try {
      final invitations = await socket.getPendingGameInvitations();
      if (!mounted || !identical(socket, _socket)) return;

      // The server is authoritative for invitations that existed when the
      // request began. Preserve any live invite delivered after that snapshot
      // started so a concurrent arrival is not mistaken for stale server data.
      final pendingById = <String, Map<String, dynamic>>{};
      for (final invite in invitations) {
        final id = invite['messageId']?.toString() ?? '';
        if (id.isNotEmpty && !isGameInvitationExpired(invite)) {
          pendingById[id] = invite;
        }
      }

      void preserveLiveArrival(Map<String, dynamic> invite) {
        final id = invite['messageId']?.toString() ?? '';
        if (id.isNotEmpty &&
            !idsAtRequestStart.contains(id) &&
            !isGameInvitationExpired(invite)) {
          pendingById[id] = invite;
        }
      }

      final activeAtResponse = _activeInvitation;
      if (activeAtResponse != null) preserveLiveArrival(activeAtResponse);
      for (final invite in _queue) {
        preserveLiveArrival(invite);
      }

      final pendingInvitations = pendingById.values.toList()
        ..sort((a, b) => (gameInvitationExpiryTimestamp(a) ?? 0)
            .compareTo(gameInvitationExpiryTimestamp(b) ?? 0));
      final pendingIds = pendingById.keys.toSet();

      setState(() {
        _queue.removeWhere(
          (invite) => !pendingIds.contains(invite['messageId']?.toString()),
        );

        final activeId = _activeInvitation?['messageId']?.toString() ?? '';
        if (activeId.isNotEmpty && !pendingIds.contains(activeId)) {
          _activeInvitation = null;
          _actionError = null;
          _working = false;
        }

        // Restore newest invitations first without duplicating a live arrival.
        for (final invitation in pendingInvitations.reversed) {
          final id = invitation['messageId']?.toString() ?? '';
          if (id.isEmpty ||
              _activeInvitation?['messageId']?.toString() == id ||
              _queue.any((item) => item['messageId']?.toString() == id)) {
            continue;
          }
          if (_rememberInvitationId(id)) {
            _queue.addLast(Map<String, dynamic>.from(invitation));
          }
        }
        _activateNext();
      });
    } catch (_) {
      // A temporary reconnect must not disturb whichever screen is open.
    }
  }

  bool _rememberInvitationId(String id) {
    if (id.isEmpty || !_seenIds.add(id)) return false;
    while (_seenIds.length > _maxRememberedInvitationIds) {
      _seenIds.remove(_seenIds.first);
    }
    return true;
  }

  void _enqueueInvitation(Map<String, dynamic> invitation) {
    final id = invitation['messageId']?.toString() ?? '';
    if (!mounted ||
        isGameInvitationExpired(invitation) ||
        !_rememberInvitationId(id)) {
      return;
    }
    setState(() {
      _queue.addLast(Map<String, dynamic>.from(invitation));
      _activateNext();
    });
  }

  void _activateNext() {
    if (_activeInvitation != null || _queue.isEmpty) return;
    _activeInvitation = _queue.removeFirst();
    _actionError = null;
    _working = false;
  }

  void _expireInvitation(Map<String, dynamic> packet) {
    final id = packet['messageId']?.toString() ?? '';
    if (id.isEmpty || !mounted) return;
    setState(() {
      _queue.removeWhere((invite) => invite['messageId']?.toString() == id);
      if (_activeInvitation?['messageId']?.toString() == id) {
        _activeInvitation = null;
        _actionError = null;
        _working = false;
        _activateNext();
      }
    });
  }

  void _dismissActive() {
    if (!mounted) return;
    setState(() {
      _activeInvitation = null;
      _actionError = null;
      _working = false;
      _activateNext();
    });
  }

  Future<void> _declineInvitation() async {
    final invitation = _activeInvitation;
    final socket = _socket;
    final id = invitation?['messageId']?.toString() ?? '';
    if (socket == null || id.isEmpty || _working) return;
    if (!socket.isConnected || !socket.isAuthenticated) {
      setState(() => _actionError = 'Reconnect to respond to this invitation.');
      return;
    }

    setState(() {
      _working = true;
      _actionError = null;
    });
    try {
      await socket.rejectGameInvite(id);
      if (mounted && _activeInvitation?['messageId']?.toString() == id) {
        _dismissActive();
      }
    } catch (error) {
      if (!mounted || _activeInvitation?['messageId']?.toString() != id) {
        return;
      }
      setState(() {
        _working = false;
        _actionError = _friendlyError(error);
      });
    }
  }

  Future<void> _acceptInvitation() async {
    final invitation = _activeInvitation;
    final socket = _socket;
    final id = invitation?['messageId']?.toString() ?? '';
    final navigator = widget.navigatorKey.currentState;
    if (socket == null || id.isEmpty || _working) return;
    if (!socket.isConnected || !socket.isAuthenticated) {
      setState(() => _actionError = 'Reconnect to respond to this invitation.');
      return;
    }
    if (navigator == null) {
      setState(() => _actionError = 'Unable to open the game right now.');
      return;
    }

    setState(() {
      _working = true;
      _actionError = null;
    });
    try {
      await socket.acceptGameInvite(id);
      if (!mounted) return;
      _dismissActive();
      FocusManager.instance.primaryFocus?.unfocus();

      final gameType = invitation?['gameType']?.toString().toLowerCase() ?? '';
      final peer = invitation?['from']?.toString() ?? '';
      if (gameType == 'rajamantri') {
        await navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => RajaMantriInviteWaitingScreen(
              messageId: id,
              hostName: invitation?['displayName']?.toString() ?? peer,
            ),
          ),
        );
      } else if (invitation?['game'] is Map) {
        await navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => GameRoomScreen(
              currentUsername: socket.myUsername ?? '',
              initialGame: Map<String, dynamic>.from(
                invitation!['game'] as Map,
              ),
              messageId: id,
              peerUsername: peer,
              opponentDisplayName: invitation['displayName']?.toString(),
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted || _activeInvitation?['messageId']?.toString() != id) {
        return;
      }
      setState(() {
        _working = false;
        _actionError = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');

  String _gameName(String type) => switch (type.toLowerCase()) {
        'tictactoe' => 'Tic-Tac-Toe',
        'rps' => 'Rock Paper Scissors',
        'rajamantri' => 'Raja Mantri',
        _ => 'a game',
      };

  @override
  void dispose() {
    _detachSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invitation = _activeInvitation;
    if (invitation == null) return const SizedBox.shrink();

    final canRespond = _socket?.isConnected == true &&
        _socket?.isAuthenticated == true;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sender = invitation['displayName']?.toString().trim().isNotEmpty == true
        ? invitation['displayName'].toString().trim()
        : invitation['from']?.toString().trim().isNotEmpty == true
            ? invitation['from'].toString().trim()
            : 'Your friend';
    final game = _gameName(invitation['gameType']?.toString() ?? '');

    return Positioned(
      top: MediaQuery.of(context).padding.top + 72,
      left: 12,
      right: 12,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: colors.surface,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .65),
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: colors.primaryContainer,
                          child: Icon(
                            Icons.sports_esports_rounded,
                            color: colors.onPrimaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Game invitation',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$sender invited you to play $game',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_working)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    if (_actionError != null || !canRespond) ...[
                      const SizedBox(height: 8),
                      Text(
                        _actionError ??
                            'Reconnect to accept or decline this invitation.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _actionError != null
                              ? colors.error
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Spacer(),
                        OutlinedButton(
                          onPressed:
                              _working || !canRespond ? null : _declineInvitation,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(94, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: const Text('Decline'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed:
                              _working || !canRespond ? null : _acceptInvitation,
                          icon: const Icon(Icons.check_rounded, size: 17),
                          label: const Text('Accept'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(106, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
