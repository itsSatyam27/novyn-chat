import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/novyn_ui.dart';
import '../chats/chat_detail_screen.dart';
import 'create_group_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String _search = '';
  String _filter = 'All';
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final friends = context.read<FriendService>();
    final myUid = auth.user?.username;
    final cachedFriends = friends.cachedFriends ?? <UserModel>[];

    if (myUid == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NovynHeader(
              title: 'Contacts',
              subtitle: '${cachedFriends.length} friend${cachedFriends.length == 1 ? '' : 's'} · ${cachedFriends.where((u) => u.isOnline).length} online',
              actions: [
                NovynIconButton(
                  icon: Icons.group_add_rounded,
                  primary: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateGroupScreen(myUid: myUid),
                      ),
                    );
                  },
                ),
              ],
            ),
            NovynSearchField(
              hint: 'Search contacts by name or username...',
              onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                _filterChip('All', _filter == 'All', () => setState(() => _filter = 'All')),
                const SizedBox(width: 8),
                _filterChip('Online', _filter == 'Online', () => setState(() => _filter = 'Online')),
                const SizedBox(width: 8),
              ]),
            ),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: friends.friendsStream(myUid),
                initialData: friends.cachedFriends,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: 5,
                      itemBuilder: (_, __) => NovynShimmer.friendCard(),
                    );
                  }
                  final all = List<UserModel>.from(snap.data ?? []);
                  all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  final filtered = all.where((u) {
                    if (_filter == 'Online' && !u.isOnline) return false;
                    if (_search.isNotEmpty &&
                        !u.name.toLowerCase().contains(_search) &&
                        !u.username.toLowerCase().contains(_search)) return false;
                    return true;
                  }).toList();
                  if (filtered.isEmpty) {
                    return _buildEmpty();
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                    itemCount: filtered.length + 2,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: NovynSectionLabel(
                                  _search.isEmpty ? 'ALL CONTACTS' : 'SEARCH RESULTS',
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              Text(
                                '${filtered.length}',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (i == filtered.length + 1) {
                        return _buildInviteCard(context, myUid);
                      }
                      return _FriendCard(
                        user: filtered[i - 1],
                        myUid: myUid,
                        friendService: friends,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(BuildContext context, String myUid) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 18, 4, 24),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: .22), style: BorderStyle.solid),
        color: color.withValues(alpha: .035),
      ),
      child: Column(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
          child: Icon(Icons.person_add_alt_1_rounded, color: color)),
        const SizedBox(height: 12),
        Text('Add more friends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 5),
        Text('Invite people to Novyn or share your username so they can find you.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.45, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, children: [
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '@$myUid'));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username copied')));
            },
            icon: const Icon(Icons.share_outlined, size: 17), label: const Text('Invite')),
          OutlinedButton.icon(
            onPressed: () {
              showDialog<void>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Your Novyn username'),
                content: SelectableText('@$myUid'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              ));
            },
            icon: const Icon(Icons.qr_code_2_rounded, size: 17), label: const Text('My QR')),
        ]),
      ]),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? NovynGradients.selected(context) : null,
            color: selected
                ? null
                : (dark ? const Color(0xFF171622) : Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: .7)
                  : theme.colorScheme.outlineVariant.withValues(alpha: .7),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .22),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const NovynEmptyState(
      icon: Icons.people_outline_rounded,
      title: 'No friends yet',
      description: 'Find people to start chatting\nwith them',
    );
  }
}

class _FriendCard extends StatelessWidget {
  final UserModel user;
  final String myUid;
  final FriendService friendService;

  const _FriendCard({
    required this.user,
    required this.myUid,
    required this.friendService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final statusColor = user.isOnline
        ? const Color(0xFF3DDC97)
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openChat(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .42),
              ),
            ),
          ),
          child: Row(
            children: [
              UserAvatar(
                name: user.name,
                photoUrl: user.photoUrl,
                radius: 24,
                showOnlineIndicator: true,
                isOnline: user.isOnline,
                presence: user.status,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: user.isOnline
                                ? [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: .35),
                                      blurRadius: 7,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          user.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· @${user.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withValues(alpha: .16)),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 17,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailScreen(peer: user)),
    );
  }
}

