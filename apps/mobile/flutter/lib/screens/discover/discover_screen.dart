import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_ui.dart';
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
            StreamBuilder<int>(
              stream: friends.pendingRequestsCountStream(myUid),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return NovynHeader(
                  title: 'Discover',
                  subtitle: 'Find new people to connect with',
                  actions: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NovynIconButton(
                          icon: Icons.notifications_none_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DiscoverPeopleScreen(myUid: myUid),
                            ),
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: NovynColors.danger,
                                shape: BoxShape.circle,
                                border: Border.all(color: NovynColors.bg, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '$count',
                                  style: NovynText.body(10, weight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    NovynIconButton(
                      icon: Icons.qr_code_scanner_rounded,
                      onTap: () => _showScanPlaceholder(context),
                    ),
                  ],
                );
              },
            ),

            // ── Search ──────────────────────────────────────────────
            NovynSearchField(
              hint: 'Search by name or username...',
              onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
            ),

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
            const Icon(Icons.qr_code_scanner_rounded, size: 64, color: Color(0xFFBDBDBD)),
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

  static const _palettes = [
    AvatarPalette.purple,
    AvatarPalette.blue,
    AvatarPalette.green,
    AvatarPalette.pink,
  ];

  static String _lastSeenText(DateTime? lastSeen) {
    if (lastSeen == null) return 'Last seen: unknown';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Last seen: just now';
    if (diff.inMinutes < 60) return 'Last seen: ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen: ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen: yesterday';
    if (diff.inDays < 7) return 'Last seen: ${diff.inDays}d ago';
    return 'Last seen: ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty
        ? user.name.substring(0, 1).toUpperCase()
        : '?';
    final palette = _palettes[(user.name.isNotEmpty ? user.name.codeUnitAt(0) : 0) % _palettes.length];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovynColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NovynColors.glassBorder),
      ),
      child: Row(
        children: [
          NovynAvatar(
            size: 54,
            letter: initial,
            colors: palette,
            statusColor: user.isOnline ? NovynColors.mint : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NovynText.body(15, weight: FontWeight.w700),
                      ),
                    ),
                    if (user.isOnline) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: NovynColors.mint,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text('@${user.username}', style: NovynText.body(12, color: NovynColors.textMuted)),
                const SizedBox(height: 5),
                Text(
                  user.isOnline ? 'Active now' : _lastSeenText(user.lastSeen),
                  style: NovynText.body(
                    11.5,
                    weight: user.isOnline ? FontWeight.w700 : FontWeight.w500,
                    color: user.isOnline ? NovynColors.mint : NovynColors.timeMuted,
                  ),
                ),
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    user.bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NovynText.body(11.5, color: NovynColors.textSub),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: isPending ? null : onAddFriend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                gradient: isPending ? null : NovynGradients.primary,
                color: isPending ? NovynColors.glass : null,
                borderRadius: BorderRadius.circular(12),
                border: isPending ? Border.all(color: NovynColors.glassBorder) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPending ? Icons.hourglass_top_rounded : Icons.person_add_alt_1_rounded,
                    size: 14,
                    color: isPending ? NovynColors.textMuted : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isPending ? 'Pending' : 'Add',
                    style: NovynText.body(
                      12,
                      weight: FontWeight.w700,
                      color: isPending ? NovynColors.textMuted : Colors.white,
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
