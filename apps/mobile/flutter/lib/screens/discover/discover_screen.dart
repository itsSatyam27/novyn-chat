import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/profile_preview_sheet.dart';
import '../people/discover_people_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _search = '';

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
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Discover',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  StreamBuilder<int>(
                    stream: friends.pendingRequestsCountStream(myUid),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      return Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => DiscoverPeopleScreen(myUid: myUid)),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.notifications_none_rounded,
                                    color: count > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                    size: 22,
                                  ),
                                ),
                                if (count > 0)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.error,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                      child: Center(
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _showScanPlaceholder(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Find new people to connect with',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.8),
                ),
              ),
            ),

            // ── Search ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search_rounded,
                        color: Color(0xFF94A3B8), size: 20),
                    hintText: 'Search by name or username...',
                    hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF94A3B8),
                        fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── User list ────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: friends.friendUidsStream(myUid),
                builder: (context, friendSnap) {
                  final friendUids = friendSnap.data ?? [];

                  return StreamBuilder<List<UserModel>>(
                    stream: friends.discoverUsersStream(myUid, friendUids),
                    builder: (context, userSnap) {
                      if (userSnap.connectionState ==
                          ConnectionState.waiting) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: 6,
                          itemBuilder: (_, __) => NovynShimmer.discoverItem(),
                        );
                      }

                      final all = userSnap.data ?? [];
                      final filtered = _search.isEmpty
                          ? all
                          : all
                              .where((u) =>
                                  u.name
                                      .toLowerCase()
                                      .contains(_search) ||
                                  u.username
                                      .toLowerCase()
                                      .contains(_search))
                              .toList();

                      // Sort: online first
                      filtered.sort((a, b) =>
                          (b.isOnline ? 1 : 0) - (a.isOnline ? 1 : 0));

                      if (filtered.isEmpty) {
                        return _buildEmpty();
                      }

                      return StreamBuilder<Set<String>>(
                        stream: friends.sentPendingUidsStream(myUid),
                        builder: (context, pendingSnap) {
                          final pendingUids = pendingSnap.data ?? {};

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                16, 8, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final user = filtered[i];
                              final isPending =
                                  pendingUids.contains(user.uid);
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => ProfilePreviewSheet(
                                      user: user,
                                      showActions: false, 
                                    ),
                                  );
                                },
                                child: _DiscoverCard(
                                  user: user,
                                  isPending: isPending,
                                  onAddFriend: () => friends.sendRequest(
                                      myUid, user.uid),
                                ),
                              );
                            },
                          );
                        },
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

  Widget _buildEmpty() {
    return const NovynEmptyState(
      icon: Icons.explore_outlined,
      title: 'No one to discover',
      description: 'Check back when more people join',
    );
  }

  void _onQRScanned(String data) async {
    if (!data.startsWith('https://novyn.app/user/')) return;
    final uid = data.replaceFirst('https://novyn.app/user/', '');

    final friendService = context.read<FriendService>();
    final user = await friendService.getUser(uid);

    if (user != null && mounted) {
      // Close the scan placeholder bottom sheet
      Navigator.pop(context);

      // Show the profile preview sheet
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => ProfilePreviewSheet(user: user),
      );
    }
  }

  void _showScanPlaceholder(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera permission is required to scan QR codes'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(sheetContext).size.height * 0.75,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            const Icon(Icons.qr_code_scanner_rounded, size: 64, color: Color(0xFFF59E0B)),
            const SizedBox(height: 24),
            Text(
              'Scan QR Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Hold your device over a friend\'s QR code to connect instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(32),
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            _onQRScanned(barcode.rawValue!);
                            break;
                          }
                        }
                      },
                    ),
                    // Optional Scanner Overlay
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Discover card
// ═══════════════════════════════════════════════════════════════════════════
class _DiscoverCard extends StatelessWidget {
  final UserModel user;
  final bool isPending;
  final VoidCallback onAddFriend;

  const _DiscoverCard({
    required this.user,
    required this.isPending,
    required this.onAddFriend,
  });

  // Gradient pairs per first letter bucket
  static const _gradients = [
    [Color(0xFF7C6FF7), Color(0xFFEC4899)],
    [Color(0xFF0EA5E9), Color(0xFF00D4A0)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFF10B981), Color(0xFF4A8FFF)],
    [Color(0xFFEC4899), Color(0xFFF59E0B)],
  ];

  static String _lastSeenText(DateTime? lastSeen) {
    if (lastSeen == null) return 'Last seen: unknown';
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) return 'Last seen: just now';
    if (diff.inMinutes < 60) return 'Last seen: ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen: ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen: yesterday';
    if (diff.inDays < 7) return 'Last seen: ${diff.inDays}d ago';
    // Older — show date
    return 'Last seen: ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty        ? user.name.substring(0, 1).toUpperCase()
        : '?';
    final gradientIndex =
        (user.name.isNotEmpty ? user.name.codeUnitAt(0) : 0) %
            _gradients.length;
    final gradient = _gradients[gradientIndex];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // ── Avatar with online ring ───────────────────────────────
          Stack(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: user.isOnline
                      ? LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFE2E5F0), Color(0xFFCBD5E1)],
                        ),
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: user.isOnline ? gradient[0] : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ),
              if (user.isOnline)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF22C55E), width: 2),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 14),

          // ── Name + username + bio ─────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (user.isOnline) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                // Status / Join Date
                Text(
                  user.isOnline 
                    ? 'Active Now' 
                    : _lastSeenText(user.lastSeen),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: user.isOnline 
                        ? const Color(0xFF10B981) 
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
                    fontWeight: user.isOnline ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.bio,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── Add friend button ─────────────────────────────────────
          GestureDetector(
            onTap: isPending ? null : onAddFriend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isPending
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : const Color(0xFFECEAFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPending
                      ? Theme.of(context).colorScheme.outlineVariant
                      : const Color(0xFF7C6FF7).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPending
                        ? Icons.hourglass_top_rounded
                        : Icons.person_add_rounded,
                    size: 14,
                    color: isPending
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF7C6FF7),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isPending ? 'Pending' : 'Add',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPending
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF7C6FF7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

