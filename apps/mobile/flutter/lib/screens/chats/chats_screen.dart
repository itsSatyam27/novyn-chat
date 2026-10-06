import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/hybrid_db_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/doodle_background.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/connection_banner.dart';
import '../../widgets/neomorphic_widgets.dart';
import '../../theme/novyn_theme.dart';
import '../../models/chat_preview.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToPeople;
  const ChatsScreen({super.key, this.onNavigateToPeople});

  // Public statics for real-time updates from SocketService
  static int totalUnread = 0;
  static List<ChatPreview>? cachedChats;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

enum ChatFilter { all, unread, groups, archived }

class _ChatsScreenState extends State<ChatsScreen> {
  List<ChatPreview> _chats = [];
  List<ChatPreview> _filtered = [];
  bool _loading = true;
  String _search = '';
  ChatFilter _activeFilter = ChatFilter.all;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  // Static cache moved to ChatsScreen widget class

  @override
  void initState() {
    super.initState();
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
    
    // If the cache was updated by socket service, sync our local state
    if (ChatsScreen.cachedChats != null) {
      setState(() {
        _chats = List.from(ChatsScreen.cachedChats!);
        _applyFilters(); // Re-apply search/filters
      });
    }
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
      if (cachedChats.isNotEmpty && mounted) {
        final peerUids = cachedChats
            .map((c) => c['peerUid'] as String?)
            .where((uid) => uid != null)
            .cast<String>()
            .toList();
        final cachedUsers = await HybridDbService.getUsers(peerUids);

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
      ChatsScreen.totalUnread =
          previews.fold(0, (s, c) => s + c.unreadCount);

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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status banner
            const ConnectionBanner(),
            
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Messages',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          _HeaderAction(
                            icon: _isSearching ? Icons.close_rounded : Icons.search_rounded, 
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _isSearching = !_isSearching;
                                if (!_isSearching) {
                                  _search = '';
                                  _applyFilters();
                                }
                              });
                              if (_isSearching) {
                                _searchFocusNode.requestFocus();
                              }
                            }
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Search Bar (Conditional)
                if (_isSearching) ...[
                  _buildSearch(),
                  const SizedBox(height: 16),
                ],

                // Filters
                _buildFilters(),
                ],
              ),
            ),
            
            // Offline indicator
            const OfflineIndicator(),
            
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                  : RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: _loadChats,
                      child: CustomScrollView(
                        slivers: [
                          // ── Stories Section ────────────────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: _buildStories(),
                            ),
                          ),

                          // ── Pinned Section ─────────────────────────────────
                          if (activeChats.any((c) => c.isPinned)) ...[
                            SliverToBoxAdapter(
                              child: _buildSectionLabel('PINNED'),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final pinnedChats = activeChats.where((c) => c.isPinned).toList();
                                  if (i >= pinnedChats.length) return null;
                                  return _buildChatCard(pinnedChats[i]);
                                },
                                childCount: activeChats.where((c) => c.isPinned).length,
                              ),
                            ),
                          ],

                          // ── Recent Section ─────────────────────────────────
                          SliverToBoxAdapter(
                            child: _buildSectionLabel('RECENT'),
                          ),
                          activeChats.isEmpty && !_loading
                              ? SliverFillRemaining(child: _buildEmpty())
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) {
                                      final recentChats = activeChats.where((c) => !c.isPinned).toList();
                                      if (i >= recentChats.length) return null;
                                      return _buildChatCard(recentChats[i]);
                                    },
                                    childCount: activeChats.where((c) => !c.isPinned).length,
                                  ),
                                ),
                          
                          // Bottom padding
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: _buildFAB(),
      ),
    );
  }

  Widget _buildSearch() {
    return NeoTextField(
      focusNode: _searchFocusNode,
      onChanged: _onSearch,
      hintText: 'Search conversations...',
      icon: Icons.search_rounded,
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildFilterChip('All', ChatFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('Unread', ChatFilter.unread),
          const SizedBox(width: 8),
          _buildFilterChip('Groups', ChatFilter.groups),
          const SizedBox(width: 8),
          _buildFilterChip('Archived', ChatFilter.archived),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, ChatFilter filter) {
    final isActive = _activeFilter == filter;
    final theme = Theme.of(context);
    final pageBg = NovynTheme.pageBg(context);

    return Expanded(
      child: GestureDetector(
         onTap: () => _setFilter(filter),
         child: NeoContainer(
           borderRadius: 14,
           distance: isActive ? 2 : 4,
           blur: isActive ? 4 : 8,
           isSunken: isActive,
           color: pageBg,
           child: Center(
             child: Text(
               label,
               style: TextStyle(
                 fontFamily: 'Outfit',
                 fontSize: 12,
                 fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                 color: isActive 
                     ? theme.colorScheme.primary 
                     : theme.colorScheme.onSurface.withOpacity(0.5),
               ),
             ),
           ),
         ),
       ),
    );
  }

  Widget _buildStories() {
    final isDecoy = context.read<SettingsService>().decoyMode;
    if (isDecoy) return const SizedBox.shrink();

    // Get unique peers from chats for stories
    final uniquePeers = <String, ChatPreview>{};
    for (final chat in _chats) {
      if (!uniquePeers.containsKey(chat.peerUid)) {
        uniquePeers[chat.peerUid] = chat;
      }
    }
    final storyPeers = uniquePeers.values.toList().take(6).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StoryAddButton(onTap: () {
            HapticFeedback.lightImpact();
            widget.onNavigateToPeople?.call();
          }),
          const SizedBox(width: 12),
          ...storyPeers.map((chat) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _StoryCard(
              name: chat.peer.name.split(' ').first, 
              color: chat.peer.avatarColor, 
              initials: chat.peer.initials,
              ringColors: chat.unreadCount > 0 ? [const Color(0xFF00C97A), const Color(0xFF7B6EF6)] : null,
              onTap: () => _openChat(chat),
            ),
          )).toList(),
          if (storyPeers.length < 3) ...[
            _StoryCard(
              name: 'Ananya', 
              color: const Color(0xFF7B6EF6), 
              initials: 'AN',
              onTap: () => _showSnackBar('Opening story for Ananya...'),
            ),
            const SizedBox(width: 12),
            _StoryCard(
              name: 'Rohit', 
              color: const Color(0xFFF97316), 
              initials: 'RK', 
              ringColors: const [Color(0xFFF97316), Color(0xFFEC4899)],
              onTap: () => _showSnackBar('Opening story for Rohit...'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: onSurface.withValues(alpha: 0.05))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: onSurface.withValues(alpha: 0.3),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: onSurface.withValues(alpha: 0.05))),
        ],
      ),
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
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
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

  Widget _buildFAB() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onNavigateToPeople?.call();
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00C97A),
              Color(0xFF00A862),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C97A).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Color(0xFF001F0F), size: 32),
      ),
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
    final onSurface = theme.colorScheme.onSurface;
    final hasUnread = preview.unreadCount > 0;
    final pageBg = NovynTheme.pageBg(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: NeoContainer(
          borderRadius: 24,
          distance: 4,
          blur: 8,
          color: pageBg,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with Online Indicator
              Stack(
                children: [
                  UserAvatar(
                    name: preview.peer.name,
                    photoUrl: preview.peer.photoUrl,
                    radius: 30,
                  ),
                  if (preview.peer.isOnline)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C97A),
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.surface, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            preview.peer.name,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(preview.lastTime),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview.lastMessage.isEmpty ? 'Start a conversation' : preview.lastMessage,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: onSurface.withOpacity(hasUnread ? 0.8 : 0.4),
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${preview.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
    );
  }
}

// ── Helper Widgets ──────────────────────────────────────────────────────────

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _HeaderAction({required this.icon, required this.onTap, this.active = false});

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
          color: active ? const Color(0xFF00C97A) : onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}



class _StoryCard extends StatelessWidget {
  final String name;
  final String initials;
  final Color color;
  final List<Color>? ringColors;
  final VoidCallback? onTap;

  const _StoryCard({
    required this.name, 
    required this.initials, 
    required this.color, 
    this.ringColors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final pageBg = NovynTheme.pageBg(context);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Column(
        children: [
          NeoContainer(
            borderRadius: 27,
            distance: 3.5,
            blur: 7,
            color: pageBg,
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StoryAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final pageBg = NovynTheme.pageBg(context);

    return Column(
      children: [
        NeoButton(
          onTap: onTap,
          borderRadius: 26,
          distance: 4,
          blur: 8,
          width: 52,
          height: 52,
          color: pageBg,
          child: Center(
            child: Icon(
              Icons.add_rounded, 
              color: onSurface.withOpacity(0.4),
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'New',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: onSurface.withOpacity(0.6),
          ),
        ),
      ],
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
