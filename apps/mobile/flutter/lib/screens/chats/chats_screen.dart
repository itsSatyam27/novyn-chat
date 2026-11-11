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

enum ChatFilter { all, unread, favourites, groups, archived }

class _ChatsScreenState extends State<ChatsScreen> {
  List<ChatPreview> _chats = [];
  List<ChatPreview> _filtered = [];
  bool _loading = true;
  String _search = '';
  ChatFilter _activeFilter = ChatFilter.all;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = true;

  // Static cache moved to ChatsScreen widget class

  @override
  void initState() {
    super.initState();
    // Never hydrate from a previous signed-in account's in-memory previews.
    final owner = context.read<AuthService>().user?.username.toLowerCase();
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

  void _handleSocketUpdate() {
    if (!mounted) return;
    final owner = context.read<AuthService>().user?.username.toLowerCase();
    if (owner == null) return;

    final previews =
        List<ChatPreview>.from(context.read<SocketService>().conversations);
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
    final auth = context.read<AuthService>();
    final myUsername = auth.user?.username;
    if (myUsername == null) {
      if (!silent) setState(() => _loading = false);
      return;
    }

    // 1. Load from local cache first (instant)
    if (!silent) {
      final cachedChats = await HybridDbService.getChats();
      if (!mounted || context.read<AuthService>().user?.username != myUsername) return;
      if (cachedChats.isNotEmpty && mounted) {
        final peerUids = cachedChats
            .map((c) => c['peerUid'] as String?)
            .where((uid) => uid != null)
            .cast<String>()
            .toList();
        final cachedUsers = await HybridDbService.getUsers(peerUids);
        if (!mounted || context.read<AuthService>().user?.username != myUsername) return;

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
            _filtered = _search.isEmpty
                ? previews
                : previews
                    .where((c) =>
                        c.peer.name.toLowerCase().contains(_search) ||
                        c.peer.username.toLowerCase().contains(_search))
                    .toList();
            _loading = false;
          });
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
      final settings = context.read<SettingsService>();
      setState(() {
        _chats = previews;
        _applyFilters();
        _loading = false;
      });
      return;
    }

    // 3. Fallback: getChats returns empty on novyn-chat (data comes via socket)
    if (!silent) setState(() => _loading = false);
  }

  @override
  void dispose() {
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

    setState(() {
      if (isDecoy) {
        _filtered = [];
        return;
      }
      _filtered = _chats.where((c) {
        // 1. Blocked check
        if (blockedUids.contains(c.peerUid)) return false;

        // 2. Archive check
        if (_activeFilter == ChatFilter.archived) {
          if (!c.isArchived) return false;
        } else {
          if (c.isArchived) return false;
        }

        // 3. Unread check
        if (_activeFilter == ChatFilter.unread && c.unreadCount == 0) return false;

        // Favourites are represented by the existing persistent pin state.
        if (_activeFilter == ChatFilter.favourites && !c.isPinned) return false;

        // 4. Group check
        if (_activeFilter == ChatFilter.groups && !c.isGroup) return false;

        // 5. Hide groups in "All" if user wants (optional, but usually "All" shows everything)
        // If we are in "All", maybe we don't filter groups.

        // 5. Search check
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          return c.peer.name.toLowerCase().contains(q) ||
              c.peer.username.toLowerCase().contains(q);
        }

        return true;
      }).toList();
    });
  }

  void _onSearch(String query) {
    _search = query.toLowerCase();
    _applyFilters();
  }

  void _setFilter(ChatFilter filter) {
    HapticFeedback.selectionClick();
    setState(() => _activeFilter = filter);
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final isDecoy = context.watch<SettingsService>().decoyMode;
    final activeChats = isDecoy ? <ChatPreview>[] : _filtered;

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
                subtitle: '${_chats.length} chats · all caught up',
                titleSize: 28,
                titleColor: Theme.of(context).colorScheme.onSurface,
                subtitleColor: Theme.of(context).colorScheme.onSurfaceVariant,
                actions: [
                  NovynIconButton(
                    icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
                    size: 56,
                    radius: 20,
                    iconSize: 24,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _search = '';
                          _applyFilters();
                        }
                      });
                      if (_isSearching) _searchFocusNode.requestFocus();
                    },
                  ),
                  NovynIconButton(
                    icon: Icons.edit_outlined,
                    primary: true,
                    size: 56,
                    radius: 20,
                    iconSize: 24,
                    onTap: () => widget.onNavigateToPeople?.call(),
                  ),
                ],
              ),
            ),
            if (_isSearching) ...[
              _buildSearch(),
              const SizedBox(height: 8),
            ],
            _buildFilters(),

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
                          if (activeChats.any((c) => c.isPinned)) ...[
                            SliverToBoxAdapter(
                              child: _buildSectionLabel('PINNED', icon: Icons.push_pin_outlined),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildStories(),
                              ),
                            ),
                          ],

                          // ── All chats ──────────────────────────────────────
                          SliverToBoxAdapter(
                            child: _buildSectionLabel('ALL CHATS'),
                          ),
                          activeChats.isEmpty && !_loading
                              ? SliverFillRemaining(child: _buildEmpty())
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) {
                                      final recentChats = activeChats
                                          .where((c) => !c.isPinned)
                                          .toList();
                                      if (i >= recentChats.length) return null;
                                      return _buildChatCard(recentChats[i]);
                                    },
                                    childCount: activeChats
                                        .where((c) => !c.isPinned)
                                        .length,
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
      // Compose is available in the header; pinned-section + is the secondary shortcut.
    );
  }

  Widget _buildSearch() {
    return NovynSearchField(
      hint: 'Search conversations…',
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearch,
    );
  }

  Widget _buildFilters() {
    const filters = <String>['All', 'Unread', 'Favourites', 'Groups'];
    final selected = switch (_activeFilter) {
      ChatFilter.all => 0,
      ChatFilter.unread => 1,
      ChatFilter.favourites => 2,
      ChatFilter.groups => 3,
      ChatFilter.archived => 0,
    };
    return NovynChipRow(
      labels: filters,
      selected: selected,
      bottomPadding: 16,
      onSelected: (index) {
        const values = <ChatFilter>[
          ChatFilter.all,
          ChatFilter.unread,
          ChatFilter.favourites,
          ChatFilter.groups,
        ];
        _setFilter(values[index]);
      },
    );
  }

  Widget _buildStories() {
    final pinnedChats = _chats.where((chat) => chat.isPinned).toList();
    if (pinnedChats.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...pinnedChats.map((chat) => Padding(
                padding: const EdgeInsets.only(right: 22),
                child: _StoryCard(
                  name: chat.peer.name.split(' ').first,
                  color: chat.peer.avatarColor,
                  initials: chat.peer.initials,
                  onTap: () => _openChat(chat),
                ),
              )),
          _StoryAddButton(onTap: () => widget.onNavigateToPeople?.call()),
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

  Widget _buildChatCard(ChatPreview preview) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _ChatCard(
        preview: preview,
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

// ── Redesigned Chat Card ───────────────────────────────────────────────────
class _ChatCard extends StatelessWidget {
  final ChatPreview preview;
  final VoidCallback onTap;

  const _ChatCard({required this.preview, required this.onTap});

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
            HapticFeedback.lightImpact();
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
                          Text(
                            _formatTime(preview.lastTime),
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
                          if (preview.isPinned) ...[
                            Icon(Icons.push_pin_rounded,
                                size: 13,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 5),
                          ],
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
  final String initials;
  final Color color;
  final VoidCallback? onTap;

  const _StoryCard({
    required this.name,
    required this.initials,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == Colors.transparent
                      ? Theme.of(context).colorScheme.primary
                      : (dark ? const Color(0xFF31D5A0) : const Color(0xFF16B987)),
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 23,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: labelColor.withValues(alpha: .82),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StoryAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final meta = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primary.withValues(alpha: .65),
                  width: 1.6,
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(Icons.add_rounded, color: primary, size: 25),
            ),
            const SizedBox(height: 8),
            Text(
              'Pin',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                color: meta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inDays == 0) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $p';
  } else if (diff.inDays == 1) {
    return 'Yesterday';
  } else if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  } else {
    return '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
  }
}
