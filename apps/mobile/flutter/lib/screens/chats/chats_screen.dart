import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/socket_service.dart';
import '../../services/hybrid_db_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/doodle_background.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/neomorphic_widgets.dart';
import '../../theme/novyn_theme.dart';
import '../../widgets/novyn_ui.dart';
import '../../models/chat_preview.dart';
import 'chat_detail_screen.dart';
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
  bool _isSearching = false;
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

    // Refresh when socket reconnects or notifies (new group created, etc)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = context.read<SocketService>();

      // Initial load
      _loadChats(silent: true);

      // Listen for real-time changes (like new group creation)
      socket.addListener(_handleSocketUpdate);

      socket.onConnected = () {
        if (mounted) _loadChats(silent: true);
      };
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
          final peer = cachedUsers[peerUid];
          if (peer == null) continue;
          final lastTime =
              DateTime.tryParse(chat['lastTime'] ?? '') ?? DateTime.now();
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

    // 2. Use conversations from SocketService (populated via friend_list event)
    final socket = context.read<SocketService>();
    final conversations = socket.conversations;

    if (conversations.isNotEmpty && mounted) {
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

    // 3. Fallback: getChats returns empty on novyn-chat (data comes via socket)
    if (!silent) setState(() => _loading = false);
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
            ChatDetailScreen(peer: chat.peer),
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
    final unreadCount =
        activeChats.fold<int>(0, (total, chat) => total + chat.unreadCount);

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Novyn redesigned header ───────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: NovynHeader(
                title: 'Messages',
                subtitle: '${activeChats.length} conversations · $unreadCount unread',
                titleSize: 28,
                titleColor: Theme.of(context).colorScheme.onSurface,
                subtitleColor: Theme.of(context).colorScheme.onSurfaceVariant,
                actions: [
                  NovynIconButton(
                    icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
                    size: 46,
                    radius: 16,
                    iconSize: 21,
                    onTap: () {
                      HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.chat);
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _search = '';
                          _searchController.clear();
                        }
                      });
                      _applyFilters();
                      if (_isSearching) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _searchFocusNode.requestFocus();
                        });
                      } else {
                        _searchFocusNode.unfocus();
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ChatFilterChip(label: 'All', value: 'all', selected: _selectedTab, count: allChats.length, onTap: _selectTab),
                    const SizedBox(width: 8),
                    _ChatFilterChip(label: 'Unread', value: 'unread', selected: _selectedTab, count: allChats.where((c) => c.unreadCount > 0).length, onTap: _selectTab),
                    const SizedBox(width: 8),
                    _ChatFilterChip(label: 'Favorites', value: 'favorites', selected: _selectedTab, count: allChats.where((c) => favorites.contains(c.chatId)).length, onTap: _selectTab),
                    const SizedBox(width: 8),
                    _ChatFilterChip(label: 'Groups', value: 'groups', selected: _selectedTab, count: allChats.where((c) => c.isGroup).length, onTap: _selectTab),
                  ],
                ),
              ),
            ),
            if (_isSearching) ...[
              _buildSearch(),
              const SizedBox(height: 8),
            ],

            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary))
                  : RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: _loadChats,
                      child: CustomScrollView(
                        slivers: [
                          // ── Pinned Section ─────────────────────────────────
                          if (pinnedChats.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _buildSectionLabel('PINNED', icon: Icons.push_pin_outlined),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildStories(pinnedChats),
                              ),
                            ),
                          ],

                          // ── All chats ──────────────────────────────────────
                          SliverToBoxAdapter(
                            child: _buildSectionLabel('ALL MESSAGES', icon: Icons.forum_outlined),
                          ),
                          activeChats.isEmpty && !_loading
                              ? SliverFillRemaining(child: _buildEmpty())
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) {
                                      if (i >= recentChats.length) return null;
                                      return _buildChatCard(recentChats[i]);
                                    },
                                    childCount: recentChats.length,
                                  ),
                                ),

                          // Bottom padding
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 100)),
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
          child: const Icon(Icons.add_rounded, size: 29),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSearch() {
    return NovynSearchField(
      hint: 'Search chats by name or username...',
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
                  ChatDetailScreen(peer: preview.peer),
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

class _ChatFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final int count;
  final ValueChanged<String> onTap;
  const _ChatFilterChip({required this.label, required this.value, required this.selected, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: active ? colors.primary : colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: active ? colors.primary : colors.outlineVariant.withValues(alpha: .65)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? colors.onPrimary : colors.onSurface)),
            const SizedBox(width: 6),
            Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? colors.onPrimary.withValues(alpha: .8) : colors.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

// ── Redesigned Chat Card ───────────────────────────────────────────────────
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
    final titleColor = theme.colorScheme.onSurface;
    final metaColor = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticService.vibrate(NovynHapticType.light, category: HapticCategory.chat);
            onTap();
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(
                  name: preview.peer.name,
                  photoUrl: preview.peer.photoUrl,
                  radius: 28,
                  showOnlineIndicator: true,
                  isOnline: preview.peer.isOnline,
                  presence: preview.peer.status,
                ),
                const SizedBox(width: 16),
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
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.35,
                                color: titleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isFavorite) const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB300)),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(preview.lastTime, context.watch<SettingsService>().timeFormat),
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12,
                              color: metaColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview.lastMessage.isEmpty
                                  ? 'Tap to chat'
                                  : preview.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13.5,
                                color: hasUnread ? titleColor : metaColor,
                                fontWeight:
                                    hasUnread ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                            padding: EdgeInsets.zero,
                            tooltip: 'Chat options',
                            onPressed: onOptions,
                            icon: Icon(Icons.keyboard_arrow_down_rounded,
                              size: 23, color: metaColor.withValues(alpha: .8)),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: NovynGradients.selected(context),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${preview.unreadCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
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
