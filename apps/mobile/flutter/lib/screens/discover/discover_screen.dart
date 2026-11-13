import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../services/socket_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_ui.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/profile_preview_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../people/discover_people_screen.dart';
import 'package:novyn/services/haptic_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _search = '';
  bool _isResolvingQr = false;
  final Set<String> _sendingRequests = <String>{};

  Future<void> _sendDiscoveredRequest(String myUid, UserModel user) async {
    if (_sendingRequests.contains(user.uid)) return;
    setState(() => _sendingRequests.add(user.uid));
    try {
      await context.read<FriendService>().sendRequest(myUid, user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Friend request sent to @${user.username}.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send request to @${user.username}.')));
    } finally {
      if (mounted) setState(() => _sendingRequests.remove(user.uid));
    }
  }
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
                  titleSize: 34,
                  subtitle: 'Find people and grow your circle',
                  actions: [
                    PopupMenuButton<String>(
                      tooltip: 'Discover options',
                      icon: const Icon(Icons.more_horiz_rounded, size: 25),
                      offset: const Offset(0, 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 10,
                      onSelected: (value) {
                        if (value == 'requests') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DiscoverPeopleScreen(myUid: myUid),
                            ),
                          );
                        } else if (value == 'refresh') {
                          context.read<SocketService>().requestDiscover();
                        } else if (value == 'scan') {
                          _showScanPlaceholder(context);
                        }
                      },
                      itemBuilder: (menuContext) => [
                        PopupMenuItem(
                          value: 'requests',
                          height: 54,
                          child: Row(children: [
                            Icon(Icons.mark_email_unread_outlined, color: Theme.of(menuContext).colorScheme.primary),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('Friend requests')),
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: NovynColors.danger, borderRadius: BorderRadius.circular(20)),
                                child: Text('$count', style: NovynText.body(10, weight: FontWeight.w800, color: Colors.white)),
                              ),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'refresh',
                          height: 52,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.refresh_rounded),
                            title: Text('Refresh people'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'scan',
                          height: 52,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.qr_code_scanner_rounded),
                            title: Text('Scan QR code'),
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            // Keep the whole Discover content in one scroll view. The previous
            // fixed-height column squeezed the people list on normal phone screens.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: _DiscoverRadarCard(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: NovynSearchField(
                      hint: 'Find people by name or @username...',
                      onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
                    ),
                  ),
                  StreamBuilder<List<String>>(
                    stream: friends.friendUidsStream(myUid),
                    builder: (context, friendSnap) {
                      final friendUids = friendSnap.data ?? [];
                      return StreamBuilder<List<UserModel>>(
                        stream: friends.discoverUsersStream(myUid, friendUids),
                        builder: (context, userSnap) {
                          if (userSnap.connectionState == ConnectionState.waiting) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                children: List.generate(4, (_) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: NovynShimmer.discoverItem(),
                                )),
                              ),
                            );
                          }

                          final filtered = (userSnap.data ?? <UserModel>[])
                              .where((user) => _search.isEmpty ||
                                  user.name.toLowerCase().contains(_search) ||
                                  user.username.toLowerCase().contains(_search))
                              .toList()
                            ..sort((a, b) => (b.isOnline ? 1 : 0) - (a.isOnline ? 1 : 0));

                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                              child: _buildEmpty(),
                            );
                          }

                          return StreamBuilder<Set<String>>(
                            stream: friends.sentPendingUidsStream(myUid),
                            builder: (context, pendingSnap) {
                              final pendingUids = pendingSnap.data ?? <String>{};
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final user = filtered[i];
                                  return GestureDetector(
                                    onTap: () {
                                      HapticService.vibrate(NovynHapticType.light, category: HapticCategory.navigation);
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => ProfilePreviewSheet(user: user, showActions: false),
                                      );
                                    },
                                    child: _DiscoverCard(
                                      user: user,
                                      isPending: pendingUids.contains(user.uid),
                                      isSending: _sendingRequests.contains(user.uid),
                                      onAddFriend: () => _sendDiscoveredRequest(myUid, user),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    if (_search.isNotEmpty) return const NovynEmptyState(icon: Icons.search_off_rounded, title: 'No matching people', description: 'Try another name or username.');
    return const NovynEmptyState(icon: Icons.explore_outlined, title: 'No one online yet', description: 'Check back in a moment or invite a friend below.');
  }

  String? _usernameFromQr(String value) {
    final raw = value.trim();
    final valid = RegExp(r'^[a-zA-Z0-9_.-]{1,30}$');
    final candidate = raw.startsWith('@') ? raw.substring(1) : raw;
    if (valid.hasMatch(candidate)) return candidate;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final userIndex = segments.indexWhere((segment) => segment.toLowerCase() == 'user');
    final fromPath = userIndex >= 0 && userIndex + 1 < segments.length ? segments[userIndex + 1] : null;
    final username = fromPath ?? uri.queryParameters['user'];
    return username != null && valid.hasMatch(username) ? username : null;
  }

  Future<void> _onQRScanned(String data) async {
    if (_isResolvingQr) return;
    _isResolvingQr = true;
    try {
      final username = _usernameFromQr(data);
      if (username == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This QR code is not a valid Novyn profile.')),
          );
        }
        return;
      }

      final user = await context.read<FriendService>().getUser(username);
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Novyn user not found.')),
        );
        return;
      }

      // Close the scanner sheet before showing the matching profile.
      Navigator.pop(context);
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => ProfilePreviewSheet(user: user),
      );
    } finally {
      _isResolvingQr = false;
    }
  }
  Future<void> _showScanPlaceholder(BuildContext context) async {
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
    final manualUsername = TextEditingController();
    final theme = Theme.of(context);
    await showModalBottomSheet(
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
                        if (_isResolvingQr) return;
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
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: manualUsername,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (value) => _onQRScanned(value),
                      decoration: const InputDecoration(
                        hintText: 'Or enter a username',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _onQRScanned(manualUsername.text),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    manualUsername.dispose();
  }
}


class _DiscoverRadarCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: CustomPaint(painter: _RadarPainter(
              ring: theme.colorScheme.primary.withValues(alpha: theme.brightness == Brightness.dark ? .28 : .18),
              accent: theme.colorScheme.primary,
            )),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('LIVE DISCOVER', style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                )),
                const SizedBox(height: 4),
                Text('People around you', style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 16,
                  fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface,
                )),
                const SizedBox(height: 3),
                Text('Online people appear first', style: TextStyle(
                  fontFamily: 'PlusJakartaSans', fontSize: 11.5,
                  color: theme.colorScheme.onSurfaceVariant,
                )),
              ],
            ),
          ),
          Icon(Icons.radar_rounded, color: theme.colorScheme.primary, size: 20),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.ring, required this.accent});
  final Color ring;
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height * .44;
    final stroke = Paint()..color = ring..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, stroke);
    }
    final sector = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx, center.dy - radius)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, .95, false)
      ..close();
    canvas.drawPath(sector, Paint()..color = accent.withValues(alpha: .18));
    canvas.drawCircle(center, 5, Paint()..color = accent);
  }
  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.ring != ring || oldDelegate.accent != accent;
}

class _DiscoverCountCard extends StatelessWidget {
  const _DiscoverCountCard({required this.label, required this.icon, required this.stream, this.onTap});
  final String label;
  final IconData icon;
  final Stream<int> stream;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text('${snapshot.data ?? 0}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    ),
  ));
}

class _DiscoverCard extends StatelessWidget {
  final UserModel user;
  final bool isPending;
  final bool isSending;
  final VoidCallback onAddFriend;

  const _DiscoverCard({
    required this.user,
    required this.isPending,
    required this.isSending,
    required this.onAddFriend,
  });

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
    final theme = Theme.of(context);
    final online = user.isOnline && !{'invisible', 'offline'}.contains(user.status.trim().toLowerCase());
    final presenceColor = !online ? theme.colorScheme.onSurfaceVariant : switch (user.status.trim().toLowerCase()) { 'away' => const Color(0xFFF59E0B), 'busy' || 'dnd' => const Color(0xFFEC4899), _ => const Color(0xFF10B981) };
    final presenceLabel = !online ? _lastSeenText(user.lastSeen) : switch (user.status.trim().toLowerCase()) { 'away' => 'Away', 'busy' || 'dnd' => 'Do not disturb', _ => 'Online now' };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .65)),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: user.name,
            photoUrl: user.photoUrl,
            radius: 24,
            showOnlineIndicator: true,
            isOnline: online,
            presence: user.status,
            fallbackColor: user.avatarColor,
          ),
          const SizedBox(width: 11),
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
                        style: NovynText.body(14, weight: FontWeight.w800, color: theme.colorScheme.onSurface),
                      ),
                    ),
                    if (online) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: presenceColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text('@${user.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: NovynText.body(11.5, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 5),
                Text(
                  presenceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NovynText.body(10.5, weight: FontWeight.w700, color: presenceColor),
                ),
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    user.bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NovynText.body(10.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: (isPending || isSending) ? null : onAddFriend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                gradient: isPending ? null : NovynGradients.selected(context),
                color: isPending ? theme.colorScheme.surfaceContainerHighest : null,
                borderRadius: BorderRadius.circular(12),
                border: isPending ? Border.all(color: theme.colorScheme.outlineVariant) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSending ? Icons.hourglass_empty_rounded : (isPending ? Icons.hourglass_top_rounded : Icons.person_add_alt_1_rounded),
                    size: 14,
                    color: isPending ? theme.colorScheme.onSurfaceVariant : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isSending ? 'Sending' : (isPending ? 'Pending' : 'Add'),
                    style: NovynText.body(
                      12,
                      weight: FontWeight.w700,
                      color: isPending ? theme.colorScheme.onSurfaceVariant : Colors.white,
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