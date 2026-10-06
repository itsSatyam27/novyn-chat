import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/user_avatar.dart';

class DiscoverPeopleScreen extends StatefulWidget {
  final String myUid;
  const DiscoverPeopleScreen({super.key, required this.myUid});

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  int _activeTab = 0; // 0 for Requests, 1 for Discover

  @override
  Widget build(BuildContext context) {
    final friendService = context.read<FriendService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1D2E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Connect',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1D2E),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildToggle(),
          const SizedBox(height: 20),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _activeTab == 0
                  ? _buildRequestsTab(friendService)
                  : _buildDiscoverTab(friendService),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(6),
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFEAECF5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: _activeTab == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: (MediaQuery.of(context).size.width - 60) / 2,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeTab = 0),
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Text(
                        'Requests',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 0 ? const Color(0xFF7C6FF7) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeTab = 1),
                  child: Container(
                    color: Colors.transparent,
                    child: Center(
                      child: Text(
                        'Discover',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 1 ? const Color(0xFF7C6FF7) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(FriendService friendService) {
    return StreamBuilder<List<FriendRequest>>(
      key: const ValueKey('requests'),
      stream: friendService.pendingRequestsStream(widget.myUid),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Oops!',
            subtitle: 'Something went wrong while fetching requests.',
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 5,
            itemBuilder: (_, __) => NovynShimmer.chatItem(),
          );
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No pending requests',
            subtitle: 'Incoming friend requests will appear here',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: requests.length,
          itemBuilder: (context, i) {
            final req = requests[i];
            return _RequestItem(
              request: req,
              onAccept: () => friendService.acceptRequest(req.id, widget.myUid, req.fromUid),
              onDecline: () => friendService.declineRequest(req.id),
            );
          },
        );
      },
    );
  }

  Widget _buildDiscoverTab(FriendService friendService) {
    return StreamBuilder<List<String>>(
      key: const ValueKey('discover'),
      stream: friendService.friendUidsStream(widget.myUid),
      builder: (context, friendSnap) {
        final friendUids = friendSnap.data ?? [];
        return StreamBuilder<List<UserModel>>(
          stream: friendService.discoverUsersStream(widget.myUid, friendUids),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 5,
                itemBuilder: (_, __) => NovynShimmer.chatItem(),
              );
            }
            final all = userSnap.data ?? [];
            final online = all.where((u) => u.isOnline).toList();
            
            if (online.isEmpty) {
              return _buildEmptyState(
                icon: Icons.explore_outlined,
                title: 'No one to discover',
                subtitle: 'Check back later for new people online',
              );
            }
            
            return StreamBuilder<Set<String>>(
              stream: friendService.sentPendingUidsStream(widget.myUid),
              builder: (context, pendingSnap) {
                final pendingUids = pendingSnap.data ?? {};
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: online.length,
                  itemBuilder: (context, i) {
                    final u = online[i];
                    return _DiscoverItem(
                      user: u,
                      isPending: pendingUids.contains(u.uid),
                      onAdd: () => friendService.sendRequest(widget.myUid, u.uid),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, size: 48, color: const Color(0xFF7C6FF7)),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D2E),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Items (Simplified from PeopleScreen) ──────────────────────────────

class _RequestItem extends StatelessWidget {
  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestItem({required this.request, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final user = request.fromUser;
    if (user == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5F0)),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: user.name,
            photoUrl: user.photoUrl,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14)),
                Text('@${user.username}', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onDecline,
                icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 20),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFFEF2F2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onAccept,
                icon: const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 20),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFF0FDF4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscoverItem extends StatelessWidget {
  final UserModel user;
  final bool isPending;
  final VoidCallback onAdd;

  const _DiscoverItem({required this.user, required this.isPending, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5F0)),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: user.name,
            photoUrl: user.photoUrl,
            radius: 22,
            fallbackColor: const Color(0xFFF59E0B),
            showOnlineIndicator: true,
            isOnline: user.isOnline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14)),
                Text('@${user.username}', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          GestureDetector(
            onTap: isPending ? null : onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isPending ? const Color(0xFFF1F5F9) : const Color(0xFFECEAFD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isPending ? 'Pending' : 'Add',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPending ? const Color(0xFF94A3B8) : const Color(0xFF7C6FF7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
