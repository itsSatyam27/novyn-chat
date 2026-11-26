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
import '../../widgets/novyn_header_actions.dart';
import '../../utils/presence_utils.dart';
import '../../theme/novyn_theme.dart';
import '../chats/chat_detail_screen.dart';
import 'received_friend_requests_screen.dart';
import 'discover_screen.dart';
import 'package:novyn/services/haptic_service.dart';

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

  void _openChat(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(peer: user),
      ),
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
                      'Buddy',
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
                  NovynHeaderActions(
                    searchVisible: _isSearchVisible,
                    onSearchTap: () {
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
                    trailingAction: StreamBuilder<int>(
                      stream: friends.pendingRequestsCountStream(myUid),
                      builder: (context, requestSnapshot) {
                        return _buildContactsOverflowMenu(
                          theme: Theme.of(context),
                          requestCount: requestSnapshot.data ?? 0,
                          myUid: myUid,
                        );
                      },
                    ),
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

                  final onlineBuddies =
                      all.where((user) => user.isOnline).toList();

                  return Column(
                    children: [
                      _buildFilters(all),
                      Expanded(
                        child: _buildContactsList(
                          filtered,
                          myUid,
                          onlineBuddies: onlineBuddies,
                          totalBuddiesCount: all.length,
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
                  hintText: 'Search buddies',
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
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
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
                padding: const EdgeInsets.only(right: 10),
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
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _filter == item.$1
                          ? primary
                          : (isDark ? const Color(0xFF201B36) : Colors.white),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _filter == item.$1
                            ? primary
                            : (isDark ? Colors.white10 : const Color(0xFFEAE6F7)),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _filter == item.$1
                              ? primary.withValues(alpha: 0.28)
                              : (isDark ? Colors.black26 : primary.withValues(alpha: 0.04)),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14.5,
                        fontWeight: _filter == item.$1 ? FontWeight.w700 : FontWeight.w600,
                        color: _filter == item.$1
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF2D2942)),
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
    String myUid, {
    required List<UserModel> onlineBuddies,
    required int totalBuddiesCount,
  }) {
    if (contacts.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (_search.trim().isNotEmpty) {
        return ListView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 112),
          children: [
            NovynEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No buddies found',
              description: 'No buddies match "$_search".',
            ),
          ],
        );
      }

      Widget emptyState;
      if (_filter == 'Favourites') {
        emptyState = NovynEmptyState(
          illustration: NovynEmptyIllustrations.peopleGroupHeart(isDark: isDark),
          title: 'No favourites yet',
          description: 'Tap the star on a buddy to keep your closest people here',
          buttonLabel: 'See all $totalBuddiesCount buddies',
          isSecondaryButton: true,
          onButtonTap: () => setState(() => _filter = 'All'),
        );
      } else if (_filter == 'Online') {
        emptyState = NovynEmptyState(
          illustration: NovynEmptyIllustrations.personOffline(isDark: isDark),
          title: 'No one’s online',
          description: 'Your buddies are offline right now. Check back in a bit',
          buttonLabel: 'See all $totalBuddiesCount buddies',
          isSecondaryButton: true,
          onButtonTap: () => setState(() => _filter = 'All'),
        );
      } else {
        emptyState = NovynEmptyState(
          illustration: NovynEmptyIllustrations.peopleGroupPlus(isDark: isDark),
          title: 'No buddies yet',
          description: 'Connect with people to chat and play games together',
          buttonLabel: 'Discover people',
          buttonIcon: Icons.explore_outlined,
          onButtonTap: _openDiscover,
        );
      }

      return ListView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 112),
        children: [
          emptyState,
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
      if (_filter == 'All' && _search.isEmpty && onlineBuddies.isNotEmpty)
        _buildOnlineBuddiesStrip(onlineBuddies),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 22, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _search.isEmpty ? 'BUDDIES' : 'SEARCH RESULTS',
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
                      onOpenChat: () => _openChat(users[index]),
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

  Color _avatarColorFor(UserModel user) {
    final value = user.username.isNotEmpty ? user.username : user.name;
    final seed = value.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return _avatarPalette[seed % _avatarPalette.length];
  }

  Widget _buildOnlineBuddiesStrip(List<UserModel> buddies) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ONLINE NOW',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${buddies.length} online',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: buddies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final user = buddies[index];
                final displayName = user.name.trim().isNotEmpty
                    ? user.name.trim()
                    : user.username.trim();
                final statusColor = presenceStatusColor(
                  user.status,
                  isOnline: user.isOnline,
                );

                return SizedBox(
                  width: 62,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openChat(user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                UserAvatar(
                                  name: displayName.isNotEmpty
                                      ? displayName
                                      : '?',
                                  photoUrl: user.photoUrl.trim(),
                                  radius: 24,
                                  fallbackColor: _avatarColorFor(user),
                                  showOnlineIndicator: false,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              displayName.isNotEmpty
                                  ? displayName
                                  : '@${user.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
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
        ],
      ),
    );
  }

  Widget _buildContactsOverflowMenu({
    required ThemeData theme,
    required int requestCount,
    required String myUid,
  }) {
    final accent = theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showContactsOverflowMenu(
          requestCount: requestCount,
          myUid: myUid,
        ),
        child: SizedBox(
          width: 48,
          height: 46,
          child: Icon(
            Icons.more_horiz_rounded,
            color: accent,
            size: 25,
          ),
        ),
      ),
    );
  }

  void _showContactsOverflowMenu({
    required int requestCount,
    required String myUid,
  }) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close buddy actions',
      barrierColor: Colors.black.withValues(alpha: .26),
      transitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final media = MediaQuery.of(dialogContext);
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final accent = Theme.of(dialogContext).colorScheme.primary;
        final panelColor = isDark ? const Color(0xFF191B2B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF20213E);
        final lineColor = isDark
            ? Colors.white.withValues(alpha: .08)
            : const Color(0xFFECE7F7);

        Widget item({
          required IconData icon,
          required String title,
          required VoidCallback action,
          int badge = 0,
        }) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(dialogContext).pop();
                HapticService.vibrate(
                  NovynHapticType.selection,
                  category: HapticCategory.navigation,
                );
                action();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? .17 : .12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: accent, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: textColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.15,
                        ),
                      ),
                    ),
                    if (badge > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: media.padding.top + 72,
              right: 14,
              child: SafeArea(
                child: Material(
                  color: panelColor,
                  elevation: 18,
                  shadowColor: Colors.black.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: (media.size.width - 48)
                        .clamp(220.0, 252.0)
                        .toDouble(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              item(
                                icon: Icons.person_search_rounded,
                                title: 'Find buddies',
                                action: _openDiscover,
                              ),
                              item(
                                icon: Icons.person_add_alt_1_rounded,
                                title: 'Buddy requests',
                                badge: requestCount,
                                action: () => _showReceivedRequests(myUid),
                              ),
                              item(
                                icon: Icons.link_rounded,
                                title: 'Invite buddies',
                                action: () => _shareInvite(myUid),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
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
                  const SizedBox(height: 3),
                  Text(
                    user.username.trim().isEmpty
                        ? 'Novyn member'
                        : '@${user.username.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
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
