import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_ui.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/user_avatar.dart';

class DiscoverPeopleScreen extends StatefulWidget {
  final String myUid;
  const DiscoverPeopleScreen({super.key, required this.myUid});

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final service = context.read<FriendService>();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Friend Requests',
          style: NovynText.display(20, color: theme.colorScheme.onSurface)),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Text('Manage your connections',
              style: NovynText.body(13, color: theme.colorScheme.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF171622) : const Color(0xFFF0EDFA),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .45)),
              ),
              child: Row(children: [
                _tab('Received', 0, service),
                _tab('Sent', 1, service),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _activeTab == 0
                  ? _received(service)
                  : _sent(service),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label, int index, FriendService service) {
    final selected = _activeTab == index;
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? NovynGradients.selected(context) : null,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected ? [
              BoxShadow(color: theme.colorScheme.primary.withValues(alpha: .2),
                blurRadius: 12, offset: const Offset(0, 4))
            ] : null,
          ),
          child: Center(child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: NovynText.body(13, weight: FontWeight.w700,
                color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant)),
              if (index == 0) ...[
                const SizedBox(width: 6),
                StreamBuilder<int>(
                  stream: service.pendingRequestsCountStream(widget.myUid),
                  builder: (_, snap) {
                    final count = snap.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: .2) : theme.colorScheme.primary.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$count', style: NovynText.body(10, weight: FontWeight.w800,
                        color: selected ? Colors.white : theme.colorScheme.primary)),
                    );
                  },
                ),
              ],
            ],
          )),
        ),
      ),
    );
  }

  Widget _received(FriendService service) {
    return StreamBuilder<List<FriendRequest>>(
      key: const ValueKey('received-requests'),
      stream: service.pendingRequestsStream(widget.myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return _empty(Icons.error_outline_rounded, 'Could not load requests', 'Please check your connection and try again.');
        final requests = snap.data ?? [];
        if (requests.isEmpty) return _empty(Icons.mark_email_read_outlined, 'No received requests', 'When someone sends you a friend request, it will appear here.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final request = requests[i];
            final user = request.fromUser;
            if (user == null) return const SizedBox.shrink();
            return _RequestCard(
              user: user,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _actionIcon(Icons.close_rounded, NovynColors.danger, () async {
                  try { await service.declineRequest(request.id); }
                  catch (_) { _message('Could not decline request.'); }
                }),
                const SizedBox(width: 7),
                _actionIcon(Icons.check_rounded, NovynColors.mint, () async {
                  try {
                    await service.acceptRequest(request.id, widget.myUid, request.fromUid);
                    _message('You are now friends with @${user.username}.');
                  } catch (_) { _message('Could not accept request.'); }
                }),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _sent(FriendService service) {
    return StreamBuilder<Set<String>>(
      key: const ValueKey('sent-requests'),
      stream: service.sentPendingUidsStream(widget.myUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final names = (snap.data ?? <String>{}).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        if (names.isEmpty) return _empty(Icons.send_rounded, 'No sent requests', 'Friend requests you send will be listed here.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
          itemCount: names.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final username = names[i];
            return FutureBuilder<UserModel?>(
              future: service.getUser(username),
              builder: (context, userSnap) {
                final user = userSnap.data ?? UserModel(
                  uid: username, username: username, name: username,
                  email: '', bio: '', createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                );
                return _RequestCard(
                  user: user,
                  trailing: OutlinedButton(
                    onPressed: () async {
                      try {
                        await service.cancelSentRequest(username);
                        _message('Request to @${username} cancelled.');
                      } catch (_) { _message('Could not cancel request.'); }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NovynColors.danger,
                      side: BorderSide(color: NovynColors.danger.withValues(alpha: .45)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    ),
                    child: Text('Cancel', style: NovynText.body(12, weight: FontWeight.w700, color: NovynColors.danger)),
                  ),
                  subtitle: 'Pending response',
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _empty(IconData icon, String title, String subtitle) {
    return NovynEmptyState(icon: icon, title: title, description: subtitle);
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 40, height: 40, child: Icon(icon, color: color, size: 19)),
      ),
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _RequestCard extends StatelessWidget {
  final UserModel user;
  final Widget trailing;
  final String? subtitle;
  const _RequestCard({required this.user, required this.trailing, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF13141D) : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .48)),
      ),
      child: Row(children: [
        UserAvatar(name: user.name, photoUrl: user.photoUrl, radius: 23,
          showOnlineIndicator: true, isOnline: user.isOnline, presence: user.status),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: NovynText.body(13.5, weight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 3),
          Text('@${user.username}', style: NovynText.body(11.5, color: theme.colorScheme.onSurfaceVariant)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: NovynText.body(10.5, color: theme.colorScheme.primary, weight: FontWeight.w600)),
          ],
        ])),
        const SizedBox(width: 8),
        trailing,
      ]),
    );
  }
}
