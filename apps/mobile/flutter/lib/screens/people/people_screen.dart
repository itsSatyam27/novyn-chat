import 'package:flutter/material.dart';
import '../../widgets/novyn_alert.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/user_avatar.dart';
import '../../utils/presence_utils.dart';
import '../../widgets/novyn_ui.dart';
import '../../theme/novyn_theme.dart';
import '../chats/chat_detail_screen.dart';
import 'received_friend_requests_screen.dart';
import '../discover/discover_screen.dart';
import 'package:novyn/services/haptic_service.dart';

enum _PeopleMenuAction { discover, requests, invite }

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  static const _avatarPalette = <Color>[
    Color(0xFF6D4CF5),
    Color(0xFFC03F72),
    Color(0xFF287A70),
    Color(0xFFB85A0A),
    Color(0xFF2865E8),
    Color(0xFF8054C9),
  ];

  String _search = '';
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _filter = 'All';
  Set<String> _favouriteUsernames = <String>{};
  String? _favouriteOwner;
  bool _favouritesLoaded = false;
  bool _favouriteLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final username = context.read<AuthService>().user?.username;
    if (username != null && username.isNotEmpty) {
      _loadFavourites(username);
    }
  }

  String _favouritesKey(String username) =>
      'novyn_contact_favorites_${username.trim().toLowerCase()}';

  Future<void> _loadFavourites(String username) async {
    _favouriteLoading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = prefs.getStringList(_favouritesKey(username)) ?? <String>[];
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username.trim().toLowerCase()) {
        return;
      }
      setState(() {
        _favouriteUsernames =
            values.map((value) => value.toLowerCase()).toSet();
        _favouriteOwner = username.trim().toLowerCase();
        _favouritesLoaded = true;
      });
    } catch (error) {
      debugPrint('Could not load contact favourites: $error');
    } finally {
      _favouriteLoading = false;
    }
  }

  Future<void> _toggleFavourite(UserModel user) async {
    final username =
        context.read<AuthService>().user?.username.trim().toLowerCase();
    final target = user.username.trim().toLowerCase();
    if (username == null || username.isEmpty || target.isEmpty) return;

    if (!_favouritesLoaded || _favouriteOwner != username) {
      await _loadFavourites(username);
    }
    if (!_favouritesLoaded || _favouriteOwner != username) {
      _showMessage('Favourites are still loading. Try again.');
      return;
    }

    final next = Set<String>.from(_favouriteUsernames);
    final isAdded = next.add(target);
    if (!isAdded) next.remove(target);

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
        _favouritesKey(username),
        next.toList(),
      );
      if (!saved) throw StateError('Could not save favourite contacts.');
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username) {
        return;
      }
      setState(() => _favouriteUsernames = next);
      HapticService.vibrate(
        NovynHapticType.selection,
        category: HapticCategory.navigation,
      );
      _showMessage(isAdded
          ? '${user.name} added to favourites'
          : '${user.name} removed from favourites');
    } catch (error) {
      if (mounted) _showMessage('Could not update favourite: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    NovynAlert.show(
      context,
      message,
      isError: message.toLowerCase().contains('could not') ||
          message.toLowerCase().contains('failed'),
    );
  }

  Future<void> _shareInvite(String myUid) async {
    final username = myUid.trim();
    final inviteUrl = Uri.parse('https://itssatyam27.github.io/novyn-chat/')
        .replace(queryParameters: {'invite': username})
        .toString();
    try {
      await Share.share(
        'Connect with me on Novyn: @$username. Open my profile or download the app: $inviteUrl',
        subject: 'Join me on Novyn',
      );
    } catch (_) {
      _showMessage('Could not open the share sheet.');
    }
  }

  void _showReceivedRequests(String myUid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceivedFriendRequestsScreen(myUid: myUid),
      ),
    );
  }

  void _openDiscover() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DiscoverScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final friends = context.read<FriendService>();
    final myUid = auth.user?.username;
    final cachedFriends = friends.cachedFriends;

    if (myUid != null &&
        myUid.isNotEmpty &&
        _favouriteOwner != null &&
        _favouriteOwner != myUid.trim().toLowerCase() &&
        !_favouriteLoading) {
      _favouritesLoaded = false;
      _favouriteOwner = null;
      _favouriteUsernames = <String>{};
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadFavourites(myUid);
      });
    }

    if (myUid == null || myUid.isEmpty) {
      return const Center(child: Text('Not logged in'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDark
        ? NovynTheme.pageBg(context)
        : const Color(0xFFF3EFFA);

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contacts',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 36,
                        height: 1.12,
                        letterSpacing: -1.25,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  NovynIconButton(
                    icon: _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
                    size: 46,
                    radius: 18,
                    iconSize: 22,
                    onTap: () {
                      setState(() {
                        _isSearchVisible = !_isSearchVisible;
                        if (!_isSearchVisible) {
                          _search = '';
                          _searchController.clear();
                        }
                      });
                      if (_isSearchVisible) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _isSearchVisible) {
                            _searchFocusNode.requestFocus();
                          }
                        });
                      } else {
                        _searchFocusNode.unfocus();
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  StreamBuilder<int>(
                    stream: friends.pendingRequestsCountStream(myUid),
                    builder: (context, requestSnapshot) {
                      return _buildContactsOverflowMenu(
                        theme: Theme.of(context),
                        requestCount: requestSnapshot.data ?? 0,
                        myUid: myUid,
                      );
                    },
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _isSearchVisible
                  ? TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      builder: (context, opacity, child) =>
                          Opacity(opacity: opacity, child: child),
                      child: _buildSearch(),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: friends.friendsStream(myUid),
                initialData: cachedFriends,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      snapshot.data == null) {
                    return ListView.builder(
                      itemCount: 5,
                      padding: const EdgeInsets.only(top: 10),
                      itemBuilder: (_, __) => NovynShimmer.friendCard(),
                    );
                  }

                  final all = List<UserModel>.from(snapshot.data ?? cachedFriends ?? const <UserModel>[])
                    ..sort((a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                  final filtered = all.where((user) {
                    final name = user.name.toLowerCase();
                    final username = user.username.toLowerCase();
                    if (_filter == 'Online' && !user.isOnline) return false;
                    if (_filter == 'Favourites' &&
                        !_favouriteUsernames.contains(username)) {
                      return false;
                    }
                    if (_search.isNotEmpty &&
                        !name.contains(_search) &&
                        !username.contains(_search)) {
                      return false;
                    }
                    return true;
                  }).toList();

                  return Column(
                    children: [
                      _buildFilters(all),
                      Expanded(
                        child: _buildContactsList(filtered, myUid),
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

  Widget _buildSearch() {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurfaceVariant;
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.surface
              : Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 21, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  setState(() => _search = value.trim().toLowerCase());
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(0);
                  }
                },
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                cursorColor: accent,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: 'Search contacts',
                  hintStyle: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _search = '');
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(0);
                    }
                    _searchFocusNode.requestFocus();
                  },
                  child: Icon(Icons.close_rounded, size: 18, color: textColor),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(List<UserModel> all) {
    final theme = Theme.of(context);
    final labels = <(String, String)>[
      ('All', 'All · ${all.length}'),
      ('Online', 'Online'),
      ('Favourites', 'Favourites'),
    ];

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Row(
          children: [
            for (final item in labels)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _filter = item.$1);
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(0);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _filter == item.$1
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _filter == item.$1
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList(
    List<UserModel> contacts,
    String myUid,
  ) {
    if (contacts.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 18, 112),
        children: [
          const SizedBox(height: 34),
          const NovynEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No contacts found',
            description: 'Try another search or choose a different filter.',
          ),
        ],
      );
    }

    final grouped = <String, List<UserModel>>{};
    for (final user in contacts) {
      final name = user.name.trim();
      final first = name.isEmpty ? '#' : name.substring(0, 1).toUpperCase();
      final letter = RegExp(r'^[A-Z]$').hasMatch(first) ? first : '#';
      grouped.putIfAbsent(letter, () => <UserModel>[]).add(user);
    }
    final letters = grouped.keys.toList()..sort();
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 22, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _search.isEmpty ? 'CONTACTS' : 'SEARCH RESULTS',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '${contacts.length}',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ];

    for (final letter in letters) {
      final users = grouped[letter]!;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 22, 8),
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
      children.add(
        Padding(
          padding: const EdgeInsets.only(right: 18, bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  for (var index = 0; index < users.length; index++) ...[
                    _ContactRow(
                      user: users[index],
                      isFavourite: _favouriteUsernames
                          .contains(users[index].username.toLowerCase()),
                      onFavourite: () => _toggleFavourite(users[index]),
                      onOpenChat: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(peer: users[index]),
                        ),
                      ),
                    ),
                    if (index != users.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 70,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: .07)
                            : const Color(0xFFF0ECF6),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    children.add(const SizedBox(height: 112));

    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
      children: children,
    );
  }

  Widget _buildContactsOverflowMenu({
    required ThemeData theme,
    required int requestCount,
    required String myUid,
  }) {
    final accent = theme.colorScheme.primary;
    return PopupMenuButton<_PeopleMenuAction>(
      tooltip: 'More contact options',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 10),
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: .16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      constraints: const BoxConstraints(minWidth: 258),
      onSelected: (action) {
        HapticService.vibrate(
          NovynHapticType.selection,
          category: HapticCategory.navigation,
        );
        switch (action) {
          case _PeopleMenuAction.discover:
            _openDiscover();
          case _PeopleMenuAction.requests:
            _showReceivedRequests(myUid);
          case _PeopleMenuAction.invite:
            _shareInvite(myUid);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_PeopleMenuAction>(
          value: _PeopleMenuAction.discover,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildOverflowMenuRow(
            icon: Icons.person_search_rounded,
            title: 'Discover people',
            accent: accent,
          ),
        ),
        PopupMenuItem<_PeopleMenuAction>(
          value: _PeopleMenuAction.requests,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildOverflowMenuRow(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Friend requests',
            accent: accent,
            badge: requestCount,
          ),
        ),
        PopupMenuItem<_PeopleMenuAction>(
          value: _PeopleMenuAction.invite,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _buildOverflowMenuRow(
            icon: Icons.link_rounded,
            title: 'Invite friends',
            accent: accent,
          ),
        ),
      ],
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.more_vert_rounded,
          size: 23,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildOverflowMenuRow({
    required IconData icon,
    required String title,
    required Color accent,
    int badge = 0,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 230,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 21, color: accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (badge > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.user,
    required this.isFavourite,
    required this.onFavourite,
    required this.onOpenChat,
  });

  final UserModel user;
  final bool isFavourite;
  final VoidCallback onFavourite;
  final VoidCallback onOpenChat;

  static const _palette = <Color>[
    Color(0xFF6D4CF5),
    Color(0xFFC03F72),
    Color(0xFF287A70),
    Color(0xFFB85A0A),
    Color(0xFF2865E8),
    Color(0xFF8054C9),
  ];

  Color get _avatarColor {
    final value = user.username.isNotEmpty ? user.username : user.name;
    final seed = value.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return _palette[seed % _palette.length];
  }

  String get _displayName => user.name.trim().isNotEmpty ? user.name.trim() : user.username.trim();

  String _presenceLabel() {
    if (user.isOnline) {
      return switch (user.status.trim().toLowerCase()) {
        'away' => 'Away',
        'busy' || 'dnd' => 'Busy',
        _ => 'Online',
      };
    }
    return formatLastSeenLabel(user.lastSeen);
  }

  Widget _avatar() {
    return UserAvatar(
      name: _displayName.isNotEmpty ? _displayName : '?',
      photoUrl: user.photoUrl.trim(),
      radius: 26,
      fallbackColor: _avatarColor,
      showOnlineIndicator: false,
      isOnline: user.isOnline,
      presence: user.status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = user.isOnline
        ? presenceStatusColor(user.status, isOnline: user.isOnline)
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onOpenChat,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 15, top: 11, bottom: 11),
        child: Row(
          children: [
            PresenceIndicatorBar(
              isOnline: user.isOnline,
              status: user.status,
              margin: const EdgeInsets.only(right: 10),
            ),
            _avatar(),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isFavourite) ...[
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: onFavourite,
                          child: const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Color(0xFFB36A24),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _presenceLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: theme.colorScheme.primary.withValues(alpha: .10),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onOpenChat,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 19,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
