import 'package:flutter/material.dart';
import '../../widgets/novyn_alert.dart';
import 'package:provider/provider.dart';

import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/novyn_ui.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/novyn_theme.dart';

class ReceivedFriendRequestsScreen extends StatefulWidget {
  final String myUid;

  const ReceivedFriendRequestsScreen({
    super.key,
    required this.myUid,
  });

  @override
  State<ReceivedFriendRequestsScreen> createState() =>
      _ReceivedFriendRequestsScreenState();
}

class _ReceivedFriendRequestsScreenState
    extends State<ReceivedFriendRequestsScreen> {
  final Set<String> _processing = <String>{};
  bool _showSentRequests = false;

  Future<void> _accept(FriendService service, FriendRequest request) async {
    if (!_processing.add(request.id)) return;
    setState(() {});
    try {
      await service.acceptRequest(request.id, widget.myUid, request.fromUid);
      _message('You are now friends with @${request.fromUser?.username ?? 'this user'}.');
    } catch (_) {
      _message('Could not accept this request. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _processing.remove(request.id));
      }
    }
  }

  Future<void> _decline(FriendService service, FriendRequest request) async {
    if (!_processing.add(request.id)) return;
    setState(() {});
    try {
      await service.declineRequest(request.id);
    } catch (_) {
      _message('Could not decline this request. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _processing.remove(request.id));
      }
    }
  }

  void _message(String value) {
    if (!mounted) return;
    NovynAlert.show(
      context,
      value,
      isError: value.toLowerCase().contains('could not'),
      title: value.startsWith('You are now friends') ? 'Request accepted' : null,
      icon: value.startsWith('You are now friends') ? Icons.how_to_reg_rounded : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FriendService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Friend Requests',
          style: NovynText.display(20, color: theme.colorScheme.onSurface),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  _requestTab('Received', selected: !_showSentRequests, onTap: () {
                    if (_showSentRequests) setState(() => _showSentRequests = false);
                  }),
                  _requestTab('Sent', selected: _showSentRequests, onTap: () {
                    if (!_showSentRequests) setState(() => _showSentRequests = true);
                  }),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _showSentRequests
                  ? _sentRequests(service, theme, isDark, muted)
                  : _receivedRequests(service, theme, isDark, muted),
            ),
          ),
        ],
      ),    );
  }

  Widget _requestTab(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: selected ? theme.colorScheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: NovynText.body(
                  13,
                  weight: FontWeight.w700,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receivedRequests(
    FriendService service,
    ThemeData theme,
    bool isDark,
    Color muted,
  ) {
    return StreamBuilder<List<FriendRequest>>(
        stream: service.pendingRequestsStream(widget.myUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const NovynEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load requests',
              description: 'Check your connection and try again.',
            );
          }

          final requests = snapshot.data ?? <FriendRequest>[];
          final visibleRequests =
              requests.where((request) => request.fromUser != null).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: .42),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Received requests',
                              style: NovynText.body(
                                14,
                                weight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Review and manage people who want to connect.',
                              style: NovynText.body(11.5, color: muted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${visibleRequests.length}',
                          style: NovynText.body(
                            12,
                            weight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: visibleRequests.isEmpty
                    ? const NovynEmptyState(
                        icon: Icons.mark_email_read_outlined,
                        title: 'No received requests',
                        description:
                            'When someone sends you a friend request, it will appear here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        itemCount: visibleRequests.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 11),
                        itemBuilder: (context, index) {
                          final request = visibleRequests[index];
                          final user = request.fromUser!;
                          final busy = _processing.contains(request.id);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF171622)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: .42),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    UserAvatar(
                                      name: user.name,
                                      photoUrl: user.photoUrl,
                                      radius: 25,
                                      showOnlineIndicator: true,
                                      isOnline: user.isOnline,
                                      presence: user.status,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: NovynText.body(
                                              14,
                                              weight: FontWeight.w800,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '@${user.username}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: NovynText.body(
                                              12,
                                              color: muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (busy)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.person_add_alt_1_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 19,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 13),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => _decline(service, request),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Decline'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.error,
                                          side: BorderSide(
                                            color: theme.colorScheme.error
                                                .withValues(alpha: .45),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 11,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(13),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => _accept(service, request),
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Accept'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 11,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(13),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
  }

  Widget _sentRequests(
    FriendService service,
    ThemeData theme,
    bool isDark,
    Color muted,
  ) {
    return StreamBuilder<Set<String>>(
      stream: service.sentPendingUidsStream(widget.myUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const NovynEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load sent requests',
            description: 'Check your connection and try again.',
          );
        }

        final names = (snapshot.data ?? <String>{}).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: .42),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: theme.colorScheme.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sent requests',
                            style: NovynText.body(
                              14,
                              weight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'People you have invited to connect.',
                            style: NovynText.body(11.5, color: muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '\${names.length}',
                        style: NovynText.body(
                          12,
                          weight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: names.isEmpty
                  ? const NovynEmptyState(
                      icon: Icons.send_outlined,
                      title: 'No sent requests',
                      description: 'Friend requests you send will appear here until they accept.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: names.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 11),
                      itemBuilder: (context, index) {
                        final username = names[index];
                        final processingKey = 'sent:\${username.toLowerCase()}';
                        final busy = _processing.contains(processingKey);
                        return FutureBuilder<UserModel?>(
                          future: service.getUser(username),
                          builder: (context, userSnapshot) {
                            final user = userSnapshot.data ??
                                UserModel(
                                  uid: username,
                                  username: username,
                                  name: username,
                                  email: '',
                                  bio: '',
                                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                                );

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF171622) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: .42),
                                ),
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    name: user.name,
                                    photoUrl: user.photoUrl,
                                    radius: 25,
                                    showOnlineIndicator: true,
                                    isOnline: user.isOnline,
                                    presence: user.status,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: NovynText.body(
                                            14,
                                            weight: FontWeight.w800,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '@\${user.username} · Pending response',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: NovynText.body(12, color: muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: busy || userSnapshot.connectionState == ConnectionState.waiting
                                        ? null
                                        : () => _cancelSentRequest(service, username),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.colorScheme.error,
                                      side: BorderSide(
                                        color: theme.colorScheme.error.withValues(alpha: .45),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: busy
                                        ? const SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Cancel'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelSentRequest(FriendService service, String username) async {
    final processingKey = 'sent:\${username.toLowerCase()}';
    if (!_processing.add(processingKey)) return;
    setState(() {});
    try {
      await service.cancelSentRequest(username);
      _message('Request to @\$username cancelled.');
    } catch (_) {
      _message('Could not cancel request to @\$username. Please try again.');
    } finally {
      if (mounted) setState(() => _processing.remove(processingKey));
    }
  }

}
