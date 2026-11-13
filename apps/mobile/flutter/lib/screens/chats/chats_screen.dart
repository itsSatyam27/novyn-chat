import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/socket_service.dart';
import '../../services/hybrid_db_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../theme/novyn_theme.dart';
import '../../widgets/novyn_ui.dart';
import '../../models/chat_preview.dart';
import 'chat_detail_screen.dart';
import '../people/create_group_screen.dart';
import 'package:novyn/services/haptic_service.dart';

class ChatsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToPeople;
  const ChatsScreen({super.key, this.onNavigateToPeople});

  // Public statics for real-time updates from SocketService
  static int totalUnread = 0;
  static List<ChatPreview>? cachedChats;
  static String? cachedChatsOwner;

  static void resetAccountCache() {
    totalUnread = 0;
    cachedChats = null;
    cachedChatsOwner = null;
  }

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<ChatPreview> _chats = [];
  List<ChatPreview> _filtered = [];
  bool _loading = true;
  String _search = '';
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'all';
  AuthService? _authService;
  String? _observedUsername;
  int _loadGeneration = 0;

  // Static cache moved to ChatsScreen widget class

  @override
  void initState() {
    super.initState();
    // Observe auth transitions so a screen created before session restoration
    // can hydrate the account's local chats immediately after login.
    _authService = context.read<AuthService>();
    _observedUsername =
        _authService!.user?.username.trim().toLowerCase();
    _authService!.addListener(_handleAuthChanged);

    // Never hydrate from a previous signed-in account's in-memory previews.
    final owner = _observedUsername;
    if (owner == null || ChatsScreen.cachedChatsOwner != owner) {
      ChatsScreen.resetAccountCache();
    }
    // Show cache immediately, then refresh in background
    if (ChatsScreen.cachedChats != null) {
      _chats = ChatsScreen.cachedChats!;
      _filtered = ChatsScreen.cachedChats!;
      _loading = false;
      _loadChats(silent: true);
    } else {
      _loadChats();
    }

    // Listen for authenticated server snapshots and real-time changes.
    // The initial cache load above already runs once; avoid a second competing
    // load during the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final socket = context.read<SocketService>();
      socket.addListener(_handleSocketUpdate);
      // The socket may have authenticated before this screen attached.
      _handleSocketUpdate();
    });
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    final username =
        context.read<AuthService>().user?.username.trim().toLowerCase();
    if (username == _observedUsername) return;
    _observedUsername = username;
    _loadGeneration++;

    if (username == null || username.isEmpty) {
      ChatsScreen.resetAccountCache();
      setState(() {
        _chats = [];
        _filtered = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _chats = [];
      _filtered = [];
      _loading = true;
    });
    // Non-silent load first restores this account's username-scoped local DB.
    // The authenticated friend_list event will replace it with server state.
    _loadChats();
  }

  void _handleSocketUpdate() {
    if (!mounted) return;
    final owner = context.read<AuthService>().user?.username.toLowerCase();
    if (owner == null) return;
    final socket = context.read<SocketService>();
    // Socket emits many unrelated notifications (typing, presence, connect).
    // Do not let an empty, not-yet-authenticated socket snapshot erase cache.
    if (!socket.isAuthenticated || !socket.hasLoadedConversations ||
        socket.myUsername?.toLowerCase() != owner) return;

    // A completed server snapshot supersedes any in-flight cache hydration.
    // This prevents an older local read from overwriting fresh conversations.
    _loadGeneration++;
    final previews =
        List<ChatPreview>.from(socket.conversations);
    previews.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.lastTime.compareTo(a.lastTime);
    });
    ChatsScreen.cachedChats = previews;
    ChatsScreen.cachedChatsOwner = owner;
    ChatsScreen.totalUnread =
        previews.fold(0, (total, chat) => total + chat.unreadCount);

    setState(() {
      _chats = previews;
      _loading = false;
    });
    _applyFilters();
  }

  Future<void> _loadChats({bool silent = false}) async {
    final generation = silent ? _loadGeneration : ++_loadGeneration;
    final auth = context.read<AuthService>();
    final myUsername = auth.user?.username;
    if (myUsername == null) {
      if (!silent) setState(() => _loading = false);
      return;
    }

    // 1. Load from local cache first (instant)
    if (!silent) {
      final cachedChats = await HybridDbService.getChats();
      if (!mounted || generation != _loadGeneration ||
          context.read<AuthService>().user?.username != myUsername) return;
      if (cachedChats.isNotEmpty && mounted) {
        final peerUids = cachedChats
            .map((c) => c['peerUid'] as String?)
            .where((uid) => uid != null)
            .cast<String>()
            .toList();
        final cachedUsers = await HybridDbService.getUsers(peerUids);
        if (!mounted || generation != _loadGeneration ||
            context.read<AuthService>().user?.username != myUsername) return;

        final previews = <ChatPreview>[];
        for (final chat in cachedChats) {
          final peerUid = chat['peerUid'] as String?;
          if (peerUid == null) continue;
          final lastTime =
              DateTime.tryParse(chat['lastTime'] ?? '') ?? DateTime.now();
          // Older app versions stored chat rows without persisting peer
          // profiles. Rebuild a usable row from the username until the server
          // refresh supplies the full display name and avatar.
          final peer = cachedUsers[peerUid] ??
              UserModel(
                uid: peerUid,
                name: peerUid,
                username: peerUid,
                email: '',
                bio: '',
                createdAt: lastTime,
              );
          previews.add(ChatPreview(
            chatId: chat['chatId'] ?? '',
            peerUid: peerUid,
            peer: peer,
            lastMessage: chat['lastMessage'] ?? '',
            lastTime: lastTime,
            unreadCount: (chat['unreadCount'] as num?)?.toInt() ?? 0,
            isPinned: chat['isPinned'] == true,
            isArchived: chat['isArchived'] == true,
            isGroup: chat['isGroup'] == true,
          ));
        }
        if (previews.isNotEmpty && mounted) {
          setState(() {
            _chats = previews;
            _loading = false;
          });
          _applyFilters();
          ChatsScreen.cachedChats = previews;
          ChatsScreen.cachedChatsOwner = myUsername.toLowerCase();
          ChatsScreen.totalUnread =
              previews.fold(0, (s, c) => s + c.unreadCount);
        }
      }
    }

    // 2. Use only the authenticated account's completed server snapshot.
    // An unauthenticated/empty socket list must never replace the local cache.
    final socket = context.read<SocketService>();
    final hasCurrentServerSnapshot = socket.isAuthenticated &&
        socket.hasLoadedConversations &&
        socket.myUsername?.toLowerCase() == myUsername.toLowerCase();
    final conversations = socket.conversations;

    if (hasCurrentServerSnapshot && mounted) {
      final previews = List<ChatPreview>.from(conversations);
      previews.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.lastTime.compareTo(a.lastTime);
      });

      ChatsScreen.cachedChats = previews;
      ChatsScreen.cachedChatsOwner = myUsername.toLowerCase();
      ChatsScreen.totalUnread = previews.fold(0, (s, c) => s + c.unreadCount);

      if (!mounted) return;
      setState(() {
        _chats = previews;
        _loading = false;
      });
      _applyFilters();
      return;
    }

    // 3. No authenticated snapshot yet: keep the last account-scoped cache
    // visible while Socket.IO resumes and delivers friend_list.
    if (!silent && _chats.isEmpty && mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _authService?.removeListener(_handleAuthChanged);
    try {
      context.read<SocketService>().removeListener(_handleSocketUpdate);
    } catch (_) {}
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(ChatPreview chat) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChatDetailScreen(peer: chat.peer, isGroup: chat.isGroup),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    _loadChats();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      ),
    );
  }

  void _applyFilters() {
    final settings = context.read<SettingsService>();
    final blockedUids = settings.blockedUids;
    final isDecoy = settings.decoyMode;

    final next = isDecoy
        ? <ChatPreview>[]
        : _chats.where((chat) {
            if (chat.isArchived || blockedUids.contains(chat.peerUid)) {
              return false;
            }
            if (_search.isEmpty) return true;
            final query = _search.trim().toLowerCase();
            return chat.peer.name.toLowerCase().contains(query) ||
                chat.peer.username.toLowerCase().contains(query);
          }).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.lastTime.compareTo(a.lastTime);
      });

    if (!mounted) return;
    setState(() => _filtered = next);
  }

  void _selectTab(String value) {
    HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.chat);
    setState(() => _selectedTab = value);
  }

  void _onSearch(String query) {
    _search = query;
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final isDecoy = context.watch<SettingsService>().decoyMode;
    final allChats = isDecoy ? <ChatPreview>[] : _filtered;
    final settings = context.watch<SettingsService>();
    final favorites = settings.favoriteChatIds.toSet();
    final activeChats = allChats.where((chat) {
      switch (_selectedTab) {
        case 'unread': return chat.unreadCount > 0;
        case 'favorites': return favorites.contains(chat.chatId);
        case 'groups': return chat.isGroup;
        default: return true;
      }
    }).toList();
    final pinnedChats = activeChats.where((chat) => chat.isPinned).toList();
    final recentChats = activeChats.where((chat) => !chat.isPinned).toList();

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: NovynHeader(
                title: 'Chats',
                titleSize: 30,
                titleColor: Theme.of(context).colorScheme.onSurface,
                actions: [
                  NovynIconButton(
                    icon: Icons.qr_code_scanner_rounded,
                    size: 44,
                    radius: 17,
                    iconSize: 21,
                    onTap: widget.onNavigateToPeople,
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'More actions',
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 10),
                    elevation: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF211D30) : Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    onSelected: (value) {
                      if (value == 1) {
                        final myUid = context.read<AuthService>().user?.username;
                        if (myUid == null || myUid.isEmpty) return;
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CreateGroupScreen(myUid: myUid),
                        ));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<int>(
                        value: 1,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.group_add_rounded),
                          title: Text('Create group'),
                          subtitle: Text('Start a group conversation'),
                        ),
                      ),
                    ],
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(Icons.more_horiz_rounded,
                        color: Theme.of(context).colorScheme.onSurface, size: 23),
                    ),
                  ),
                ],
              ),
            ),
            _buildSearch(),
            _buildFilterCards(allChats, favorites),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary))
                  : RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: _loadChats,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (pinnedChats.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _buildSectionLabel('PINNED'),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildChatCard(pinnedChats[index]),
                                childCount: pinnedChats.length,
                              ),
                            ),
                          ],
                          if (recentChats.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _buildSectionLabel('ALL CHATS'),
                            ),
                          if (activeChats.isEmpty)
                            SliverFillRemaining(child: _buildEmpty())
                          else if (recentChats.isNotEmpty)
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildChatCard(recentChats[index]),
                                childCount: recentChats.length,
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 112)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton(
          heroTag: 'novyn_new_chat_fab',
          tooltip: 'New chat',
          onPressed: () {
            HapticService.vibrate(NovynHapticType.medium, category: HapticCategory.chat);
            widget.onNavigateToPeople?.call();
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 8,
          child: const Icon(Icons.edit_rounded, size: 25),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFilterCards(List<ChatPreview> chats, Set<String> favorites) {
    final filters = [
      ('all', 'All'),
      ('unread', 'Unread'),
      ('groups', 'Groups'),
      ('favorites', 'Favourites'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 13),
      child: Row(
        children: [
          for (final item in filters)
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: _selectedTab == item.$1,
                onSelected: (_) => _selectTab(item.$1),
                showCheckmark: false,
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                labelStyle: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _selectedTab == item.$1
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return NovynSearchField(
      hint: 'Search chats ya messages',
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearch,
    );
  }

  Widget _buildStories(List<ChatPreview> pinnedChats) {
    if (pinnedChats.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...pinnedChats.map((chat) => Padding(
                padding: const EdgeInsets.only(right: 18),
                child: _StoryCard(
                  name: chat.peer.name.split(' ').first,
                  peer: chat.peer,
                  onTap: () => _openChat(chat),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, {IconData? icon}) {
    return NovynSectionLabel(
      label,
      icon: icon,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    );
  }

  Future<void> _showChatOptions(ChatPreview chat) async {
    final settings = context.read<SettingsService>();
    final socket = context.read<SocketService>();
    final isFavorite = settings.favoriteChatIds.contains(chat.chatId);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        Widget option(IconData icon, String label, String value, {Color? color}) {
          return ListTile(
            leading: Icon(icon, color: color ?? colors.onSurfaceVariant),
            title: Text(label, style: TextStyle(color: color ?? colors.onSurface)),
            onTap: () => Navigator.pop(sheetContext, value),
          );
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(children: [
                  Expanded(
                    child: Text(chat.peer.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  if (chat.isGroup) const Chip(label: Text('Group')),
                ]),
              ),
              option(chat.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                chat.isPinned ? 'Pinned' : 'Pin chat', 'pin'),
              option(Icons.notifications_off_outlined, 'Mute notifications', 'mute'),
              option(isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                isFavorite ? 'Remove from favorites' : 'Add to favorites', 'favorite',
                color: isFavorite ? const Color(0xFFFFB300) : null),
              option(chat.unreadCount > 0 ? Icons.mark_chat_read_outlined : Icons.mark_chat_unread_outlined,
                chat.unreadCount > 0 ? 'Mark as read' : 'Mark as unread', 'read'),
              option(chat.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                chat.isArchived ? 'Unarchive chat' : 'Archive chat', 'archive'),
              const Divider(height: 8),
              if (!chat.isGroup)
                option(Icons.block_outlined, 'Block user', 'block', color: colors.error),
              option(Icons.cleaning_services_outlined, 'Clear chat', 'clear', color: colors.error),
              option(chat.isGroup ? Icons.logout_rounded : Icons.delete_outline_rounded,
                chat.isGroup ? 'Exit group' : 'Delete chat', 'delete', color: colors.error),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;

    // Only expose actions that the mobile client can currently execute safely.
    switch (action) {
      case 'favorite':
        await settings.toggleFavoriteChat(chat.chatId);
        break;
      case 'mute':
        try {
          socket.setMute(chat.peer.username, muted: true);
          _showSnackBar('Notifications muted');
        } catch (error) {
          _showSnackBar(error.toString());
        }
        break;
      case 'clear':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Clear chat?'),
            content: Text('Messages with ${chat.peer.name} will be cleared.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Clear'),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          try {
            socket.clearChat(chat.peer.username);
            _showSnackBar('Chat cleared');
            await _loadChats(silent: true);
          } catch (error) {
            _showSnackBar(error.toString());
          }
        }
        break;
      case 'delete':
        if (chat.isGroup) {
          _showSnackBar('Exit group is not yet supported in the mobile client.');
          break;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete chat?'),
            content: Text('Remove ${chat.peer.name} from your contacts and delete this chat?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          try {
            socket.removeFriend(chat.peer.username);
            await _loadChats(silent: true);
            _showSnackBar('Chat deleted');
          } catch (error) {
            _showSnackBar(error.toString());
          }
        }
        break;
      case 'pin':
      case 'read':
      case 'archive':
      case 'block':
        _showSnackBar('This chat action is not yet available in the mobile client.');
        break;
    }
  }

  Widget _buildChatCard(ChatPreview preview) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _ChatCard(
        preview: preview,
        isFavorite: context.watch<SettingsService>().favoriteChatIds.contains(preview.chatId),
        onOptions: () => _showChatOptions(preview),
        onTap: () async {
          await Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ChatDetailScreen(peer: preview.peer, isGroup: preview.isGroup),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
          _loadChats();
        },
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _loadChats,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _filtered.length,
        // Performance: Fixed height allows Flutter to skip layout calculations
        itemExtent: 86,
        itemBuilder: (context, i) {
          // Pre-load top chats in background (WhatsApp-style optimization)
          if (i == 0) {
            Future.microtask(() => _preloadTopChats());
          }

          return RepaintBoundary(
            child: _ChatCard(
              preview: _filtered[i],
              onTap: () => _openChat(_filtered[i]),
            ),
          );
        },
      ),
    );
  }

  // Pre-load top 3 chats for instant opening (WhatsApp optimization)
  Future<void> _preloadTopChats() async {
    for (int i = 0; i < 3 && i < _filtered.length; i++) {
      HybridDbService.getMessages(_filtered[i].chatId, limit: 20);
    }
  }

  Widget _buildEmpty() {
    return const NovynEmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'No chats yet',
      description: 'Tap the + button to start\na conversation',
    );
  }


}

class _ChatSummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;

  const _ChatSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outline = selected ? tint.withValues(alpha: 0.75) : colors.outlineVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? tint.withValues(alpha: 0.10) : NovynTheme.cardBg(context),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: outline, width: selected ? 1.4 : 1),
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tint, size: 17),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.05)),
                  const SizedBox(height: 3),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: NovynText.body(10, color: NovynColors.textMuted)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: tint, size: 15),
          ]),
        ),
      ),
    );
  }
}


class _ChatCard extends StatelessWidget {
  final ChatPreview preview;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onOptions;

  const _ChatCard({required this.preview, required this.onTap, this.isFavorite = false, this.onOptions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = preview.unreadCount > 0;
    final dark = theme.brightness == Brightness.dark;
    final titleColor = theme.colorScheme.onSurface;
    final metaColor = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          onTap: () {
            HapticService.vibrate(NovynHapticType.light, category: HapticCategory.chat);
            onTap();
          },
          onLongPress: onOptions,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: dark ? .18 : .28)),
            ),
            child: Row(
              children: [
                UserAvatar(
                  name: preview.peer.name,
                  photoUrl: preview.peer.photoUrl,
                  radius: 32,
                  showOnlineIndicator: true,
                  isOnline: preview.peer.isOnline,
                  presence: preview.peer.status,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview.peer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.35,
                                color: titleColor,
                              ),
                            ),
                          ),
                          if (preview.isPinned) ...[
                            const SizedBox(width: 5),
                            Icon(Icons.push_pin_rounded, size: 15, color: metaColor),
                          ],
                          if (isFavorite) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB300)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        preview.lastMessage.isEmpty ? 'Tap to chat' : preview.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          color: hasUnread ? titleColor : metaColor,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatTime(preview.lastTime, context.watch<SettingsService>().timeFormat),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w500,
                        color: hasUnread ? theme.colorScheme.primary : metaColor,
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(height: 7),
                      Container(
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                        child: Text(
                          '${preview.unreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper Widgets ──────────────────────────────────────────────────────────

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _HeaderAction(
      {required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00C97A).withValues(alpha: 0.12)
              : onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? const Color(0xFF00C97A).withValues(alpha: 0.2)
                : onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active
              ? const Color(0xFF00C97A)
              : onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final String name;
  final UserModel peer;
  final VoidCallback? onTap;

  const _StoryCard({
    required this.name,
    required this.peer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () {
        HapticService.vibrate(NovynHapticType.light, category: HapticCategory.chat);
        onTap?.call();
      },
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            UserAvatar(
              name: peer.name,
              photoUrl: peer.photoUrl,
              radius: 27,
              showOnlineIndicator: true,
              isOnline: peer.isOnline,
              presence: peer.status,
            ),
            const SizedBox(height: 7),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: labelColor.withValues(alpha: .88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime timestamp, String format) {
  final dt = timestamp.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(dt.year, dt.month, dt.day);
  final dayDifference = today.difference(messageDay).inDays;

  String clock() {
    final minute = dt.minute.toString().padLeft(2, '0');
    if (format == '24h') {
      return '${dt.hour.toString().padLeft(2, '0')}:$minute';
    }
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  if (dayDifference == 0) return clock();
  if (dayDifference == 1) return 'Yesterday';
  if (dayDifference >= 2 && dayDifference < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }
  return '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
}
