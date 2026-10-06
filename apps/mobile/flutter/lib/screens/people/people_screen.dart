import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/user_avatar.dart';
import '../chats/chat_detail_screen.dart';
import 'discover_people_screen.dart';
import 'create_group_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String _search = '';
  final ScrollController _scrollController = ScrollController();
  final List<String> _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#'.split('');

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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'People',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // Create Group Button
                  _HeaderAction(
                    icon: Icons.group_add_rounded,
                    isActive: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateGroupScreen(myUid: myUid),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    icon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.outline, size: 20),
                    hintText: 'Search friends...',
                    hintStyle: TextStyle(fontFamily: 'Inter', color: Theme.of(context).colorScheme.outline, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: friends.friendsStream(myUid),
                initialData: friends.cachedFriends,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      snap.data == null) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: 6,
                      itemBuilder: (_, __) => NovynShimmer.friendCard(),
                    );
                  }
                  final all = snap.data ?? [];
                  // Sort alphabetically
                  all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  
                  final filtered = _search.isEmpty
                      ? all
                      : all.where((u) =>
                          u.name.toLowerCase().contains(_search) ||
                          u.username.toLowerCase().contains(_search)).toList();

                  if (filtered.isEmpty) return _buildEmpty();

                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 40, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final user = filtered[i];
                          return _FriendCard(user: user, myUid: myUid, friendService: friends);
                        },
                      ),
                      // Alphabet Index
                      if (_search.isEmpty)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _alphabet.map((letter) {
                                return GestureDetector(
                                  onTap: () => _scrollToLetter(letter, filtered),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToLetter(String letter, List<UserModel> users) {
    int index = -1;
    if (letter == '#') {
      index = users.indexWhere((u) => !RegExp(r'[a-zA-Z]').hasMatch(u.name[0]));
    } else {
      index = users.indexWhere((u) => u.name.toUpperCase().startsWith(letter));
    }
    
    if (index != -1) {
      // Approximate height of a card (padding + margin + height)
      const itemHeight = 84.0; 
      _scrollController.animateTo(
        index * itemHeight,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Theme.of(context).colorScheme.outline)),
          ),
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
        ],
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            UserAvatar(
              name: user.name,
              photoUrl: user.photoUrl,
              radius: 25,
              showOnlineIndicator: true,
              isOnline: user.isOnline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            // Action (Message button)
            GestureDetector(
              onTap: () => _openChat(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
              ),
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

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.isActive,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              size: 22,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
