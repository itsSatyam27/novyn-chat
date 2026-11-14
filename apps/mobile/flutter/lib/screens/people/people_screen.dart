import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../models/user_model.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/novyn_ui.dart';
import '../../theme/novyn_theme.dart';
import '../chats/chat_detail_screen.dart';
import 'discover_people_screen.dart';
import 'package:novyn/services/haptic_service.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
  static const _avatarPalette = <Color>[
    Color(0xFF6D4CF5),
    Color(0xFFC03F72),
    Color(0xFF287A70),
    Color(0xFFB85A0A),
    Color(0xFF2865E8),
    Color(0xFF8054C9),
  ];

  String _search = '';
  String _filter = 'All';
  Set<String> _favouriteUsernames = <String>{};
  String? _favouriteOwner;
  bool _favouritesLoaded = false;
  bool _favouriteLoading = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _letterKeys = <String, GlobalKey>{};

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _openDiscoverPeople(String myUid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiscoverPeopleScreen(myUid: myUid),
      ),
    );
  }

  Future<void> _shareInvite(String myUid) async {
    final profileUrl = 'https://novyn.app/user/$myUid';
    try {
      await Share.share(
        'Connect with me on Novyn: $profileUrl',
        subject: 'Join me on Novyn',
      );
    } catch (_) {
      _showMessage('Could not open the share sheet.');
    }
  }

  Future<void> _showFriendRequests(
    String myUid,
    FriendService service,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Friend requests',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<FriendRequest>>(
                  stream: service.pendingRequestsStream(myUid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const NovynEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load requests',
                        description: 'Check your connection and try again.',
                      );
                    }
                    final requests = snapshot.data ?? <FriendRequest>[];
                    if (requests.isEmpty) {
                      return const NovynEmptyState(
                        icon: Icons.mark_email_read_outlined,
                        title: 'No friend requests',
                        description: 'New requests will appear here.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final user = request.fromUser;
                        if (user == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : const Color(0xFFF7F4FC),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                name: user.name,
                                photoUrl: user.photoUrl,
                                radius: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '@${user.username}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Decline request',
                                onPressed: () async {
                                  try {
                                    await service.declineRequest(request.id);
                                  } catch (_) {
                                    _showMessage('Could not decline request.');
                                  }
                                },
                                icon: const Icon(Icons.close_rounded),
                                color: Theme.of(context).colorScheme.error,
                              ),
                              IconButton(
                                tooltip: 'Accept request',
                                onPressed: () async {
                                  try {
                                    await service.acceptRequest(
                                      request.id,
                                      myUid,
                                      request.fromUid,
                                    );
                                    _showMessage(
                                      'You are now friends with @${user.username}.',
                                    );
                                  } catch (_) {
                                    _showMessage('Could not accept request.');
                                  }
                                },
                                icon: const Icon(Icons.check_rounded),
                                color: const Color(0xFF159C68),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToLetter(String letter, List<String> availableLetters) {
    if (availableLetters.isEmpty) return;
    var target = letter;
    if (!availableLetters.contains(target)) {
      final next = availableLetters.where((value) => value.compareTo(letter) >= 0);
      target = next.isNotEmpty ? next.first : availableLetters.last;
    }
    final targetContext = _letterKeys[target]?.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: .08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final friends = context.read<FriendService>();
    final myUid = auth.user?.username;
    final cachedFriends = friends.cachedFriends ?? <UserModel>[];

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
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contacts',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 30,
                        height: 1.12,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  NovynIconButton(
                    icon: Icons.person_add_alt_1_rounded,
                    size: 46,
                    radius: 17,
                    iconSize: 21,
                    onTap: () => _openDiscoverPeople(myUid),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Contact options',
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 10),
                    elevation: 12,
                    color: Theme.of(context).colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    onSelected: (value) {
                      if (value == 'requests') {
                        _showFriendRequests(myUid, friends);
                      } else if (value == 'invite') {
                        _shareInvite(myUid);
                      } else if (value == 'discover') {
                        _openDiscoverPeople(myUid);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'requests',
                        child: Text('Friend requests'),
                      ),
                      PopupMenuItem(
                        value: 'invite',
                        child: Text('Invite friends'),
                      ),
                      PopupMenuItem(
                        value: 'discover',
                        child: Text('Find people'),
                      ),
                    ],
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 23,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildSearch(),
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

                  final all = List<UserModel>.from(snapshot.data ?? cachedFriends)
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
                        child: _buildContactsList(filtered, myUid, friends),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 21,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: TextField(
                onChanged: (value) {
                  setState(() => _search = value.trim().toLowerCase());
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(0);
                  }
                },
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Contacts me dhundo',
                  hintStyle: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  filled: false,
                  isDense: true,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _filter == item.$1
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildContactsList(
    List<UserModel> contacts,
    String myUid,
    FriendService service,
  ) {
    if (contacts.isEmpty) {
      return const NovynEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No contacts found',
        description: 'Try another search or choose a different filter.',
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
      _buildActionTiles(myUid, service),
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
                  fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ];

    for (final letter in letters) {
      final key = _letterKeys.putIfAbsent(letter, () => GlobalKey());
      final users = grouped[letter]!;
      children.add(
        Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(8, 2, 22, 8),
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w800,
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

    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
          children: children,
        ),
        if (_search.isEmpty && _filter != 'Favourites' && letters.isNotEmpty)
          Positioned(
            right: 1,
            top: 0,
            bottom: 8,
            width: 17,
            child: _AlphabetRail(
              letters: _alphabet,
              available: letters.toSet(),
              onSelected: (letter) => _scrollToLetter(letter, letters),
            ),
          ),
      ],
    );
  }

  Widget _buildActionTiles(String myUid, FriendService service) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 18, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              StreamBuilder<int>(
                stream: service.pendingRequestsCountStream(myUid),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return _ContactActionTile(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Friend requests',
                    subtitle: 'Naye logon ne connect kiya',
                    badge: count,
                    onTap: () => _showFriendRequests(myUid, service),
                  );
                },
              ),
              Divider(
                height: 1,
                thickness: 1,
                indent: 70,
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: .07)
                    : const Color(0xFFF0ECF6),
              ),
              _ContactActionTile(
                icon: Icons.link_rounded,
                title: 'Invite friends',
                subtitle: 'Apna invite link share karo',
                onTap: () => _shareInvite(myUid),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _ContactActionTile extends StatelessWidget {
  const _ContactActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge > 0) ...[
                Container(
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
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
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 21,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
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

  String _presenceLabel() {
    if (user.isOnline) return 'Online';
    final lastSeen = user.lastSeen;
    if (lastSeen == null) return 'Last seen recently';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 60) {
      return 'Last seen ${diff.inMinutes.clamp(1, 59)}m ago';
    }
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen yesterday';
    if (diff.inDays < 7) return 'Last seen ${diff.inDays}d ago';
    return 'Offline';
  }

  Widget _avatar() {
    final color = _avatarColor;
    final first = user.name.trim().isEmpty
        ? '?'
        : user.name.trim().substring(0, 1).toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (user.photoUrl.isNotEmpty)
          UserAvatar(
            name: user.name,
            photoUrl: user.photoUrl,
            radius: 26,
          )
        else
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Text(
              first,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        if (user.isOnline)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF21C779),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = user.isOnline
        ? const Color(0xFF288C59)
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onOpenChat,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          children: [
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
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isFavourite) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFB36A24),
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
                      fontWeight: user.isOnline ? FontWeight.w700 : FontWeight.w500,
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
            const SizedBox(width: 4),
            IconButton(
              tooltip: isFavourite ? 'Remove from favourites' : 'Add to favourites',
              onPressed: onFavourite,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                size: 18,
                color: isFavourite
                    ? const Color(0xFFB36A24)
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: .65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlphabetRail extends StatelessWidget {
  const _AlphabetRail({
    required this.letters,
    required this.available,
    required this.onSelected,
  });

  final List<String> letters;
  final Set<String> available;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final letter in letters)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(letter),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 8.5,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: available.contains(letter)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: .42),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
