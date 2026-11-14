import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
                  titleWeight: FontWeight.w600,
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
                              builder: (_) => DiscoverPeopleScreen(myUid: myUid, initialTab: 2),
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
                padding: const EdgeInsets.only(bottom: 112),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: NovynSearchField(
                      hint: 'Find people by name or @username...',
                      onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
                    ),
                  ),
                  StreamBuilder<List<String>>(
                    stream: friends.friendUidsStream(myUid),
                    builder: (context, friendSnap) {
                      if (friendSnap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                          child: _buildLoadError(
                            'Could not load your connections',
                            'Try refreshing Discover.',
                            () => context.read<SocketService>().requestDiscover(),
                          ),
                        );
                      }
                      final friendUids = friendSnap.data ?? [];
                      return StreamBuilder<List<UserModel>>(
                        stream: friends.discoverUsersStream(myUid, friendUids),
                        builder: (context, userSnap) {
                          if (userSnap.hasError) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                              child: _buildLoadError(
                                'Could not load people',
                                'Check your connection and pull to refresh.',
                                () => context.read<SocketService>().requestDiscover(),
                              ),
                            );
                          }
                          if (userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData) {
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
                              .toList();
                          bool isOnline(UserModel user) =>
                              user.isOnline &&
                              !{'invisible', 'offline'}.contains(user.status.trim().toLowerCase());
                          final onlineUsers = filtered.where(isOnline).toList()
                            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                          final recentUsers = filtered.where((user) => !isOnline(user)).toList()
                            ..sort((a, b) {
                              final aSeen = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
                              final bSeen = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
                              return bSeen.compareTo(aSeen);
                            });

                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                              child: _buildEmpty(myUid),
                            );
                          }

                          return StreamBuilder<Set<String>>(
                            stream: friends.sentPendingUidsStream(myUid),
                            builder: (context, pendingSnap) {
                              if (pendingSnap.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                                  child: _buildLoadError(
                                    'Could not load request status',
                                    'Refresh Discover to try again.',
                                    () => context.read<SocketService>().requestDiscover(),
                                  ),
                                );
                              }
                              final pendingUids = pendingSnap.data ?? <String>{};
                              Widget userGroup(String title, List<UserModel> users) {
                                if (users.isEmpty) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 2, bottom: 10),
                                        child: Text(
                                          title,
                                          style: NovynText.body(
                                            11,
                                            weight: FontWeight.w800,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ).copyWith(letterSpacing: 1.1),
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surface,
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .58),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6D5DFC).withValues(alpha: .045),
                                              blurRadius: 18,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: List.generate(users.length, (index) {
                                            final user = users[index];
                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (index > 0)
                                                  Divider(
                                                    height: 1,
                                                    thickness: 1,
                                                    indent: 16,
                                                    endIndent: 16,
                                                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .48),
                                                  ),
                                                _DiscoverPersonRow(
                                                  user: user,
                                                  isOnline: isOnline(user),
                                                  isPending: pendingUids.contains(user.uid) ||
                                                      pendingUids.contains(user.username),
                                                  isSending: _sendingRequests.contains(user.uid),
                                                  onAddFriend: () => _sendDiscoveredRequest(myUid, user),
                                                  onOpenProfile: () {
                                                    HapticService.vibrate(
                                                      NovynHapticType.light,
                                                      category: HapticCategory.navigation,
                                                    );
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
                                                ),
                                              ],
                                            );
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  userGroup('ONLINE NOW · ${onlineUsers.length}', onlineUsers),
                                  userGroup('RECENTLY ACTIVE', recentUsers),
                                ],
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

  Widget _buildEmpty(String myUid) {
    if (_search.isNotEmpty) {
      return const NovynEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching people',
        description: 'Try another name or username.',
      );
    }

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          SizedBox(
            width: 232,
            height: 218,
            child: CustomPaint(
              painter: _DiscoverEmptyPainter(
                ring: theme.colorScheme.primary.withValues(alpha: dark ? .22 : .13),
                accent: theme.colorScheme.primary,
              ),
              child: Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: .11),
                      width: 9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: .13),
                        blurRadius: 26,
                        spreadRadius: 7,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.explore_rounded,
                    color: theme.colorScheme.primary,
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'No one online yet',
            textAlign: TextAlign.center,
            style: NovynText.display(25, weight: FontWeight.w600, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Check back in a moment or invite a friend below.',
              textAlign: TextAlign.center,
              style: NovynText.body(14, color: muted).copyWith(height: 1.45),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 222,
            height: 56,
            child: FilledButton.icon(
              onPressed: () async {
                await Share.share(
                  'Join me on Novyn! Find me as @$myUid. https://novyn.app',
                  subject: 'Join me on Novyn',
                );
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: Text('Invite a friend', style: NovynText.body(15, weight: FontWeight.w600, color: Colors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _DiscoverEmptyAction(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Scan QR code',
                  subtitle: 'Add someone in person',
                  tint: const Color(0xFFE9E4FF),
                  accent: theme.colorScheme.primary,
                  onTap: () => _showScanPlaceholder(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DiscoverEmptyAction(
                  icon: Icons.mail_outline_rounded,
                  title: 'Friend requests',
                  subtitle: 'See who wants to connect',
                  tint: const Color(0xFFE9E4FF),
                  accent: theme.colorScheme.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiscoverPeopleScreen(myUid: myUid, initialTab: 0),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError(String title, String message, VoidCallback onRetry) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 34, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(title, style: NovynText.body(14, weight: FontWeight.w600, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center, style: NovynText.body(12, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 17), label: const Text('Try again')),
        ],
      ),
    );
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
      builder: (sheetContext) {
        final screenHeight = MediaQuery.of(sheetContext).size.height;
        final sheetHeight = screenHeight * 0.82;
        return Container(
          height: sheetHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .45)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 28, offset: const Offset(0, -8)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: NovynGradients.selected(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scan a Novyn QR', style: NovynText.display(19, color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 3),
                            Text('Align the code inside the frame to open a profile.', style: NovynText.body(11.5, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close scanner',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final side = math.min(constraints.maxWidth - 28, constraints.maxHeight - 8).clamp(150.0, 280.0).toDouble();
                        return Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: side, maxHeight: side),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(color: theme.colorScheme.primary.withValues(alpha: .16), blurRadius: 22, spreadRadius: 1),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    MobileScanner(
                                      onDetect: (capture) {
                                        if (_isResolvingQr) return;
                                        for (final barcode in capture.barcodes) {
                                          if (barcode.rawValue != null) {
                                            _onQRScanned(barcode.rawValue!);
                                            break;
                                          }
                                        }
                                      },
                                    ),
                                    Center(
                                      child: SizedBox(
                                        width: side * .68,
                                        height: side * .68,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.white.withValues(alpha: .9), width: 2.4),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0, right: 0, bottom: 12,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .58), borderRadius: BorderRadius.circular(20)),
                                          child: const Text('Scanning automatically', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: manualUsername,
                          textInputAction: TextInputAction.go,
                          onSubmitted: (value) => _onQRScanned(value),
                          decoration: InputDecoration(
                            hintText: 'Enter username instead',
                            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 19),
                            isDense: true,
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => _onQRScanned(manualUsername.text),
                          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          child: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
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


class _DiscoverPersonRow extends StatelessWidget {
  const _DiscoverPersonRow({
    required this.user,
    required this.isOnline,
    required this.isPending,
    required this.isSending,
    required this.onAddFriend,
    required this.onOpenProfile,
  });

  final UserModel user;
  final bool isOnline;
  final bool isPending;
  final bool isSending;
  final VoidCallback onAddFriend;
  final VoidCallback onOpenProfile;

  String _recentLabel() {
    final lastSeen = user.lastSeen;
    if (lastSeen == null) return 'Recently active';
    final elapsed = DateTime.now().difference(lastSeen);
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
    if (elapsed.inDays == 1) return 'Yesterday';
    return '${elapsed.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusText = isOnline ? 'Online' : _recentLabel();
    final statusColor = isOnline ? const Color(0xFF25864C) : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onOpenProfile,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            UserAvatar(
              name: user.name,
              photoUrl: user.photoUrl,
              radius: 38,
              showOnlineIndicator: true,
              isOnline: isOnline,
              presence: user.status,
              fallbackColor: user.avatarColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NovynText.body(17, weight: FontWeight.w600, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user.username} · $statusText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NovynText.body(13, color: statusColor).copyWith(
                      fontWeight: isOnline ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              height: 52,
              child: FilledButton(
                onPressed: (isPending || isSending) ? null : onAddFriend,
                style: FilledButton.styleFrom(
                  backgroundColor: isPending
                      ? scheme.surfaceContainerHighest
                      : scheme.primary.withValues(alpha: .12),
                  foregroundColor: isPending ? scheme.onSurfaceVariant : scheme.primary,
                  disabledBackgroundColor: scheme.surfaceContainerHighest,
                  disabledForegroundColor: scheme.onSurfaceVariant,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                ),
                child: Text(
                  isSending ? 'Sending' : isPending ? 'Requested' : 'Add',
                  style: NovynText.body(14, weight: FontWeight.w800,
                    color: isPending || isSending ? scheme.onSurfaceVariant : scheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverEmptyAction extends StatelessWidget {
  const _DiscoverEmptyAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 15, 10, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: accent, size: 25),
              ),
              const SizedBox(height: 17),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NovynText.body(14, weight: FontWeight.w600, color: scheme.onSurface),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: NovynText.body(11.5, color: scheme.onSurfaceVariant).copyWith(height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverEmptyPainter extends CustomPainter {
  const _DiscoverEmptyPainter({required this.ring, required this.accent});

  final Color ring;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .47;
    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var index = 1; index <= 4; index++) {
      canvas.drawCircle(center, radius * index / 4, ringPaint);
    }

    final dots = <Offset>[
      Offset(size.width * .16, size.height * .22),
      Offset(size.width * .84, size.height * .32),
      Offset(size.width * .22, size.height * .73),
      Offset(size.width * .72, size.height * .79),
    ];
    for (var index = 0; index < dots.length; index++) {
      final dotPaint = Paint()
        ..color = accent.withValues(alpha: .48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1;
      const dash = 4.0;
      const gap = 3.5;
      final circleRadius = index.isEven ? 14.0 : 16.0;
      final path = Path();
      final circumference = 2 * math.pi * circleRadius;
      for (double offset = 0; offset < circumference; offset += dash + gap) {
        final start = offset / circleRadius;
        final end = math.min(offset + dash, circumference) / circleRadius;
        path.addArc(
          Rect.fromCircle(center: dots[index], radius: circleRadius),
          start,
          end - start,
        );
      }
      canvas.drawPath(path, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiscoverEmptyPainter oldDelegate) =>
      oldDelegate.ring != ring || oldDelegate.accent != accent;
}
