import 'dart:async';
import 'dart:math' as math;
import '../../widgets/novyn_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/profile_deep_link_service.dart';
import '../../services/friend_service.dart';
import '../../services/socket_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_ui.dart';
import '../../widgets/profile_preview_sheet.dart';
import '../../widgets/user_avatar.dart';
import 'discover_people_screen.dart';
import '../profile/public_profile_screen.dart';
import 'package:novyn/services/haptic_service.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _isResolvingQr = false;
  final Set<String> _sendingRequests = <String>{};
  final Set<String> _pendingUids = <String>{};
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  List<FriendSearchResult> _searchResults = <FriendSearchResult>[];
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim().replaceFirst(RegExp(r'^@'), '');
    final generation = ++_searchGeneration;
    if (query.length < 2) {
      setState(() {
        _searchResults = <FriendSearchResult>[];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final matches = await context.read<FriendService>().searchUsers(query);
        if (!mounted || generation != _searchGeneration) return;
        final myUid = context.read<AuthService>().user?.username.toLowerCase();
        setState(() {
          _searchResults = matches
              .where((result) => result.user.username.toLowerCase() != myUid)
              .toList();
          _searching = false;
        });
      } catch (_) {
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _searchResults = <FriendSearchResult>[];
          _searching = false;
          _searchError = 'Could not search right now. Check your connection.';
        });
      }
    });
  }

  Future<void> _sendSearchRequest(
      String myUid, FriendSearchResult result) async {
    final user = result.user;
    if (!result.canRequest || _sendingRequests.contains(user.uid)) return;
    setState(() => _sendingRequests.add(user.uid));
    try {
      await context.read<FriendService>().sendRequest(myUid, user.uid);
      if (!mounted) return;
      setState(() => _pendingUids.add(user.uid));
      NovynAlert.showEvent(
          context, NovynAlertEvent.requestSent('@${user.username}'));
    } catch (_) {
      if (mounted)
        NovynAlert.show(context, 'Could not send request to @${user.username}.',
            isError: true);
    } finally {
      if (mounted) setState(() => _sendingRequests.remove(user.uid));
    }
  }

  void _openProfilePreview(UserModel user) {
    HapticService.vibrate(NovynHapticType.light,
        category: HapticCategory.navigation);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfilePreviewSheet(user: user, showActions: false),
    );
  }

  Future<void> _sendDiscoveredRequest(String myUid, UserModel user) async {
    if (_sendingRequests.contains(user.uid)) return;
    setState(() => _sendingRequests.add(user.uid));
    try {
      await context.read<FriendService>().sendRequest(myUid, user.uid);
      if (!mounted) return;
      setState(() => _pendingUids.add(user.uid));
      NovynAlert.showEvent(
          context, NovynAlertEvent.requestSent('@${user.username}'));
    } catch (_) {
      if (mounted)
        NovynAlert.show(context, 'Could not send request to @${user.username}.',
            isError: true);
    } finally {
      if (mounted) setState(() => _sendingRequests.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final friends = context.read<FriendService>();
    final myUid = auth.user?.username;
    if (myUid == null) return const Center(child: Text('Not logged in'));

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = const Color(0xFF6547F5);
    final foreground = dark ? Colors.white : const Color(0xFF211D36);
    final muted = dark ? Colors.white60 : const Color(0xFF716B89);
    final surface = dark ? const Color(0xFF201B36) : Colors.white;
    final query = _searchController.text.trim().replaceFirst(RegExp(r'^@'), '');

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF141026) : const Color(0xFFF5F1FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
          children: [
            Row(children: [
              if (Navigator.of(context).canPop()) ...[
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back_rounded,
                      color: foreground, size: 27),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text('Discover',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
                      color: foreground,
                    )),
              ),
              _DiscoverHeaderButton(
                tooltip: 'Refresh people',
                icon: Icons.refresh_rounded,
                onTap: () {
                  context.read<SocketService>().requestDiscover();
                  if (query.length >= 2) _onSearchChanged(query);
                },
              ),
              const SizedBox(width: 10),
              _DiscoverHeaderButton(
                tooltip: 'Scan QR code',
                icon: Icons.qr_code_2_rounded,
                onTap: () => _showScanPlaceholder(context),
              ),
            ]),
            const SizedBox(height: 34),
            Text('ADD A FRIEND',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.15,
                )),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color:
                          query.isNotEmpty ? accent : const Color(0xFFDCD4F7),
                      width: query.isNotEmpty ? 1.8 : 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                        color: foreground,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 17),
                      prefixIcon: Icon(Icons.alternate_email_rounded,
                          color: muted, size: 24),
                      hintText: 'Enter username',
                      hintStyle: TextStyle(
                          color: muted,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              icon: Icon(Icons.close_rounded, color: muted),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 58,
                height: 58,
                child: FilledButton(
                  onPressed:
                      query.length < 2 ? null : () => _onSearchChanged(query),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    disabledBackgroundColor: accent.withValues(alpha: .28),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Icon(Icons.send_rounded, size: 23),
                ),
              ),
            ]),
            const SizedBox(height: 28),
            if (query.isNotEmpty) ...[
              if (query.length < 2)
                const _DiscoverMessageCard(
                    message: 'Enter at least 2 characters to search.')
              else if (_searching)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_searchError != null)
                _DiscoverMessageCard(
                    message: _searchError!,
                    onRetry: () => _onSearchChanged(query))
              else if (_searchResults.isEmpty)
                const _DiscoverMessageCard(
                    message:
                        'No Novyn users found. Check the username and try again.')
              else
                _buildPeopleCard(
                  _searchResults
                      .map((result) => _DiscoverEntry(
                            user: result.user,
                            status: _pendingUids.contains(result.user.uid)
                                ? 'Pending'
                                : result.requestStatus == 'friend'
                                    ? 'Friends'
                                    : (result.requestStatus == 'sent' ||
                                            result.requestStatus == 'incoming')
                                        ? 'Pending'
                                        : result.user.isOnline
                                            ? 'Online'
                                            : 'Available',
                            canRequest: result.canRequest &&
                                !_pendingUids.contains(result.user.uid),
                            isSending:
                                _sendingRequests.contains(result.user.uid),
                          ))
                      .toList(),
                  heading:
                      '${_searchResults.length} MATCH${_searchResults.length == 1 ? '' : 'ES'}',
                  query: query,
                  onAdd: (entry) {
                    final result = _searchResults
                        .firstWhere((item) => item.user.uid == entry.user.uid);
                    _sendSearchRequest(myUid, result);
                  },
                ),
            ] else ...[
              Row(children: [
                Expanded(
                    child: Text('ONLINE NOW',
                        style: TextStyle(
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.15,
                        ))),
                Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFF12A85A),
                      shape: BoxShape.circle,
                    )),
              ]),
              const SizedBox(height: 14),
              _buildOnlinePeople(friends, myUid),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOnlinePeople(FriendService friends, String myUid) {
    return StreamBuilder<List<String>>(
      stream: friends.friendUidsStream(myUid),
      builder: (context, friendSnap) {
        if (friendSnap.hasError) {
          return _buildLoadError(
              'Could not load your connections',
              'Try refreshing Discover.',
              () => context.read<SocketService>().requestDiscover());
        }
        return StreamBuilder<List<UserModel>>(
          stream:
              friends.discoverUsersStream(myUid, friendSnap.data ?? <String>[]),
          builder: (context, userSnap) {
            if (userSnap.hasError) {
              return _buildLoadError(
                  'Could not load people',
                  'Check your connection and try again.',
                  () => context.read<SocketService>().requestDiscover());
            }
            if (userSnap.connectionState == ConnectionState.waiting &&
                !userSnap.hasData) {
              return Column(
                  children: List.generate(
                      3,
                      (_) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: NovynShimmer.discoverItem(),
                          )));
            }
            final online = (userSnap.data ?? <UserModel>[])
                .where((user) =>
                    user.isOnline &&
                    !{'invisible', 'offline'}
                        .contains(user.status.trim().toLowerCase()))
                .toList()
              ..sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            if (online.isEmpty) {
              return const _DiscoverMessageCard(
                  message:
                      'No one is online right now. Try searching by username.');
            }
            return StreamBuilder<Set<String>>(
              stream: friends.sentPendingUidsStream(myUid),
              builder: (context, pendingSnap) => _buildPeopleCard(
                online
                    .map((user) => _DiscoverEntry(
                          user: user,
                          status: _pendingUids.contains(user.uid) ||
                                  (pendingSnap.data ?? <String>{})
                                      .contains(user.uid) ||
                                  (pendingSnap.data ?? <String>{})
                                      .contains(user.username)
                              ? 'Pending'
                              : 'Online',
                          canRequest: !_pendingUids.contains(user.uid) &&
                              !(pendingSnap.data ?? <String>{})
                                  .contains(user.uid) &&
                              !(pendingSnap.data ?? <String>{})
                                  .contains(user.username),
                          isSending: _sendingRequests.contains(user.uid),
                        ))
                    .toList(),
                onAdd: (entry) => _sendDiscoveredRequest(myUid, entry.user),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPeopleCard(
    List<_DiscoverEntry> entries, {
    String? heading,
    String query = '',
    required ValueChanged<_DiscoverEntry> onAdd,
  }) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 17, 14, 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(27),
        border:
            Border.all(color: const Color(0xFFDCD4F7).withValues(alpha: .9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6547F5).withValues(alpha: dark ? .06 : .08),
            blurRadius: 24,
            offset: const Offset(0, 9),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (heading != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(heading,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF625B78),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .9,
                )),
          ),
        ...List.generate(entries.length, (index) {
          final entry = entries[index];
          return Column(children: [
            if (index > 0)
              Divider(
                  height: 1,
                  indent: 4,
                  endIndent: 4,
                  color: const Color(0xFFEAE5F5).withValues(alpha: .9)),
            _DiscoverResultRow(
              entry: entry,
              query: query,
              onAdd: () => onAdd(entry),
              onOpen: () => _openProfilePreview(entry.user),
            ),
          ]);
        }),
      ]),
    );
  }

  Widget _buildEmpty(String myUid) {
    final inviteUrl = Uri.parse('chat-novyn.web.app')
        .replace(queryParameters: {'invite': myUid});
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
                ring: theme.colorScheme.primary
                    .withValues(alpha: dark ? .22 : .13),
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
            style: NovynText.display(25,
                weight: FontWeight.w600, color: theme.colorScheme.onSurface),
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
                  'Join me on Novyn! Find me as @$myUid. Open my profile in Novyn: $inviteUrl',
                  subject: 'Join me on Novyn',
                );
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: Text('Invite a friend',
                  style: NovynText.body(15,
                      weight: FontWeight.w600, color: Colors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
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
                        builder: (_) =>
                            DiscoverPeopleScreen(myUid: myUid, initialTab: 2),
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
          Icon(Icons.cloud_off_rounded,
              size: 34, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(title,
              style: NovynText.body(14,
                  weight: FontWeight.w600, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center,
              style: NovynText.body(12,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Try again')),
        ],
      ),
    );
  }

  String? _usernameFromQr(String value) {
    final raw = value.trim();
    final candidate = raw.startsWith('@') ? raw.substring(1) : raw;
    final validHandle = candidate.length >= 3 &&
        candidate.length <= 24 &&
        !RegExp(r'[^a-zA-Z0-9_]').hasMatch(candidate);
    if (validHandle) return candidate.toLowerCase();

    final linkedUsername = ProfileDeepLinkService.usernameFromLink(raw);
    // Legacy Google-created usernames may contain spaces. They are valid
    // only when supplied through an encoded Novyn profile link.
    if (linkedUsername != null && linkedUsername.isNotEmpty) {
      return linkedUsername.toLowerCase();
    }
    return null;
  }

  Future<void> _onQRScanned(String data) async {
    if (_isResolvingQr) return;
    _isResolvingQr = true;
    try {
      final username = _usernameFromQr(data);
      if (username == null) {
        if (mounted) {
          NovynAlert.show(context, 'This QR code is not a valid Novyn profile.',
              isError: true,
              title: 'Invalid QR code',
              icon: Icons.qr_code_rounded);
        }
        return;
      }

      final profile = await ApiService.getPublicProfile(username);
      if (!mounted) return;
      if (profile == null) {
        NovynAlert.show(context, 'Novyn user not found.',
            isError: true,
            title: 'User not found',
            icon: Icons.person_search_rounded);
        return;
      }

      // Resolve through the public profile API so privacy-limited Discover
      // search results do not prevent a valid QR from opening a profile.
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            username: username,
            initialProfile: profile,
          ),
        ),
      );
    } finally {
      _isResolvingQr = false;
    }
  }

  Future<void> _showScanPlaceholder(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        NovynAlert.show(
            context, 'Camera permission is required to scan QR codes.',
            isError: true,
            title: 'Camera permission needed',
            icon: Icons.camera_alt_rounded,
            actionLabel: 'Settings',
            onAction: () => openAppSettings());
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
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .45)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .18),
                  blurRadius: 28,
                  offset: const Offset(0, -8)),
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
                        child: const Icon(Icons.qr_code_scanner_rounded,
                            color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scan a Novyn QR',
                                style: NovynText.display(19,
                                    color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 3),
                            Text(
                                'Align the code inside the frame to open a profile.',
                                style: NovynText.body(11.5,
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close scanner',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close_rounded,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final side = math
                            .min(constraints.maxWidth - 28,
                                constraints.maxHeight - 8)
                            .clamp(150.0, 280.0)
                            .toDouble();
                        return Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              constraints: BoxConstraints(
                                  maxWidth: side, maxHeight: side),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: .16),
                                      blurRadius: 22,
                                      spreadRadius: 1),
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
                                        for (final barcode
                                            in capture.barcodes) {
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
                                            border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: .9),
                                                width: 2.4),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 12,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 11, vertical: 6),
                                          decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: .58),
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          child: const Text(
                                              'Scanning automatically',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600)),
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
                            prefixIcon: const Icon(
                                Icons.alternate_email_rounded,
                                size: 19),
                            isDense: true,
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: .5),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => _onQRScanned(manualUsername.text),
                          style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
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

class _DiscoverEntry {
  const _DiscoverEntry({
    required this.user,
    required this.status,
    required this.canRequest,
    required this.isSending,
  });

  final UserModel user;
  final String status;
  final bool canRequest;
  final bool isSending;
}

class _DiscoverHeaderButton extends StatelessWidget {
  const _DiscoverHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: const Color(0xFF6547F5),
          side: const BorderSide(color: Color(0xFFDCD4F7)),
        ),
        icon: Icon(icon, size: 24),
      ),
    );
  }
}

class _DiscoverMessageCard extends StatelessWidget {
  const _DiscoverMessageCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF201B36) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCD4F7)),
      ),
      child: Row(children: [
        Expanded(
            child: Text(message,
                style: TextStyle(
                  color: dark ? Colors.white70 : const Color(0xFF716B89),
                  fontSize: 14,
                  height: 1.4,
                ))),
        if (onRetry != null)
          IconButton(
            tooltip: 'Try again',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6547F5)),
          ),
      ]),
    );
  }
}

class _DiscoverResultRow extends StatelessWidget {
  const _DiscoverResultRow({
    required this.entry,
    required this.query,
    required this.onAdd,
    required this.onOpen,
  });

  final _DiscoverEntry entry;
  final String query;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  TextSpan _highlight(String text, Color normal, Color accent, {TextStyle? baseStyle}) {
    final lower = text.toLowerCase();
    final needle = query.toLowerCase();
    final index = needle.isEmpty ? -1 : lower.indexOf(needle);
    final normalStyle = (baseStyle ?? const TextStyle()).copyWith(color: normal);
    final accentStyle = (baseStyle ?? const TextStyle()).copyWith(color: accent);
    if (index < 0) return TextSpan(text: text, style: normalStyle);
    return TextSpan(children: [
      if (index > 0)
        TextSpan(
            text: text.substring(0, index), style: normalStyle),
      TextSpan(
          text: text.substring(index, index + needle.length),
          style: accentStyle),
      if (index + needle.length < text.length)
        TextSpan(
            text: text.substring(index + needle.length),
            style: normalStyle),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final normal = dark ? Colors.white : const Color(0xFF211D36);
    final muted = dark ? Colors.white60 : const Color(0xFF716B89);
    final accent = const Color(0xFF6547F5);
    final alreadyConnected = entry.status == 'Friends';
    final pending = entry.status == 'Pending';
    final online = entry.status == 'Online';
    final buttonLabel = entry.isSending
        ? 'Sending'
        : alreadyConnected
            ? 'Added'
            : pending
                ? 'Requested'
                : 'Add';

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(children: [
          UserAvatar(
            name: entry.user.name,
            photoUrl: entry.user.photoUrl,
            radius: 29,
            showOnlineIndicator: true,
            isOnline: online || entry.user.isOnline,
            presence: entry.user.status,
            fallbackColor: entry.user.avatarColor,
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: _highlight(
                  entry.user.name,
                  normal,
                  accent,
                  baseStyle: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: normal,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(children: [
                  const TextSpan(text: '@'),
                  _highlight(entry.user.username, muted, accent),
                  TextSpan(
                      text: '  ·  ${entry.status}',
                      style: TextStyle(color: muted)),
                ], style: TextStyle(fontSize: 13, color: muted)),
              ),
            ],
          )),
          const SizedBox(width: 9),
          SizedBox(
            height: 42,
            child: FilledButton(
              onPressed: entry.canRequest && !entry.isSending ? onAdd : null,
              style: FilledButton.styleFrom(
                backgroundColor: accent.withValues(alpha: .11),
                foregroundColor: accent,
                disabledBackgroundColor: const Color(0xFFF0EDF6),
                disabledForegroundColor: const Color(0xFF716B89),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                shape: const StadiumBorder(),
              ),
              child: Text(buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
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
            child: CustomPaint(
                painter: _RadarPainter(
              ring: theme.colorScheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? .28 : .18),
              accent: theme.colorScheme.primary,
            )),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('LIVE DISCOVER',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    )),
                const SizedBox(height: 4),
                Text('People around you',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    )),
                const SizedBox(height: 3),
                Text('Online people appear first',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
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
    final stroke = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, stroke);
    }
    final sector = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx, center.dy - radius)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -math.pi / 2,
          .95, false)
      ..close();
    canvas.drawPath(sector, Paint()..color = accent.withValues(alpha: .18));
    canvas.drawCircle(center, 5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.ring != ring || oldDelegate.accent != accent;
}

class _DiscoverCountCard extends StatelessWidget {
  const _DiscoverCountCard(
      {required this.label,
      required this.icon,
      required this.stream,
      this.onTap});
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
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: StreamBuilder<int>(
          stream: stream,
          builder: (context, snapshot) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const Spacer(),
                Text('${snapshot.data ?? 0}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              Text(label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
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

    return InkWell(
      onTap: onOpenProfile,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          children: [
            UserAvatar(
              name: user.name,
              photoUrl: user.photoUrl,
              radius: 26,
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
                    style: NovynText.body(15,
                        weight: FontWeight.w500, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(children: [
                      TextSpan(
                          text: '@${user.username}',
                          style: NovynText.body(13,
                              color: scheme.onSurfaceVariant)),
                      TextSpan(
                          text: ' · ',
                          style: NovynText.body(13,
                              color: scheme.onSurfaceVariant)),
                      TextSpan(
                          text: statusText,
                          style: NovynText.body(13,
                              weight: FontWeight.w500,
                              color: isOnline
                                  ? const Color(0xFF25864C)
                                  : scheme.onSurfaceVariant)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 84,
              height: 40,
              child: FilledButton(
                onPressed: (isPending || isSending) ? null : onAddFriend,
                style: FilledButton.styleFrom(
                  backgroundColor: isPending
                      ? scheme.surfaceContainerHighest
                      : scheme.primary.withValues(alpha: .12),
                  foregroundColor:
                      isPending ? scheme.onSurfaceVariant : scheme.primary,
                  disabledBackgroundColor: scheme.surfaceContainerHighest,
                  disabledForegroundColor: scheme.onSurfaceVariant,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  isSending
                      ? 'Sending'
                      : isPending
                          ? 'Requested'
                          : 'Add',
                  style: NovynText.body(12,
                      weight: FontWeight.w600,
                      color: isPending || isSending
                          ? scheme.onSurfaceVariant
                          : scheme.primary),
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
                style: NovynText.body(14,
                    weight: FontWeight.w600, color: scheme.onSurface),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: NovynText.body(11.5, color: scheme.onSurfaceVariant)
                    .copyWith(height: 1.25),
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
