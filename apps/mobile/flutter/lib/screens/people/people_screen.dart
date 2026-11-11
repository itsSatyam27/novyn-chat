import 'package:flutter/material.dart';
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
              subtitle: 'Your people, all in one place',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: NovynSearchField(
                hint: 'Search friends...',
                onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
              ),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _FriendCard(
                      user: filtered[i], myUid: myUid, friendService: friends),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6554F5) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? const Color(0xFF6554F5) : Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w700,
          color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        )),
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
    return GestureDetector(
      onTap: () => _openChat(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .65)),
        ),
        child: Row(
          children: [
            UserAvatar(
              name: user.name,
              photoUrl: user.photoUrl,
              radius: 27,
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
                    style: NovynText.body(15, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NovynText.body(12, color: NovynColors.textMuted),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: user.isOnline ? NovynColors.mint : NovynColors.offline,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.isOnline ? 'Online' : 'Offline',
                        style: NovynText.body(
                          11,
                          weight: FontWeight.w600,
                          color: user.isOnline ? NovynColors.mint : NovynColors.timeMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            NovynIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              size: 38,
              radius: 12,
              iconSize: 17,
              onTap: () => _openChat(context),
            ),
          ],
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

