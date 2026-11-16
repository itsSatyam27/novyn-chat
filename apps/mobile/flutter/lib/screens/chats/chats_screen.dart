import 'dart:async';
import '../../widgets/novyn_alert.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/socket_service.dart';
import '../../services/hybrid_db_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/novyn_page_route.dart';
import '../../theme/novyn_theme.dart';
import '../../widgets/novyn_ui.dart';
import '../../models/chat_preview.dart';
import 'chat_detail_screen.dart';
import '../people/create_group_screen.dart';
import '../security/app_lock_screen.dart';
import '../profile/settings/chat_settings_screen.dart';
import 'starred_messages_screen.dart';
import '../../widgets/chat_overflow_menu.dart';
import 'package:share_plus/share_plus.dart';
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

class _ChatsScreenState extends State<ChatsScreen> with WidgetsBindingObserver {
  static const _newChatFabIdleDelay = Duration(seconds: 5);
  Timer? _newChatFabTimer;
  bool _showNewChatFab = true;
  bool? _homeTabIsActive;
  List<ChatPreview> _chats = [];
  List<ChatPreview> _filtered = [];
  bool _loading = true;
  bool _isSearchVisible = false;
  Set<String> _pinnedChatUsernames = <String>{};
  Set<String> _hiddenChatUsernames = <String>{};
  Set<String> _archivedChatUsernames = <String>{};
  Set<String> _lockedChatUsernames = <String>{};
  bool _showingArchivedChats = false;
  bool _showingLockedChats = false;
  bool _selectionMode = false;
  final Set<String> _selectedChatIds = <String>{};
  String? _hiddenChatsOwner;
  bool _pinPreferencesLoaded = false;
  String? _pinPreferencesOwner;
  String _search = '';
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'all';
  AuthService? _authService;
  String? _observedUsername;
  int _loadGeneration = 0;
  List<ChatPreview> _lastSocketConversations = const [];
  bool _topChatsPreloadStarted = false;

  // Static cache moved to ChatsScreen widget class

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Observe auth transitions so a screen created before session restoration
    // can hydrate the account's local chats immediately after login.
    _authService = context.read<AuthService>();
    _observedUsername =
        _authService!.user?.username.trim().toLowerCase();
    _authService!.addListener(_handleAuthChanged);
    final initialUsername = _observedUsername;
    if (initialUsername != null && initialUsername.isNotEmpty) {
      _loadPinnedChatPreferences(initialUsername);
      _loadHiddenChatPreferences(initialUsername);
      _loadArchiveAndLockPreferences(initialUsername);
    }

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
    _lastSocketConversations = const [];
    _topChatsPreloadStarted = false;

    if (username == null || username.isEmpty) {
      ChatsScreen.resetAccountCache();
      setState(() {
        _pinnedChatUsernames = <String>{};
        _hiddenChatUsernames = <String>{};
        _archivedChatUsernames = <String>{};
        _lockedChatUsernames = <String>{};
        _showingArchivedChats = false;
        _showingLockedChats = false;
        _selectionMode = false;
        _selectedChatIds.clear();
        _hiddenChatsOwner = null;
        _pinPreferencesLoaded = false;
        _pinPreferencesOwner = null;
        _chats = [];
        _filtered = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _pinnedChatUsernames = <String>{};
      _hiddenChatUsernames = <String>{};
      _archivedChatUsernames = <String>{};
      _lockedChatUsernames = <String>{};
      _showingArchivedChats = false;
      _showingLockedChats = false;
      _selectionMode = false;
      _selectedChatIds.clear();
      _hiddenChatsOwner = null;
      _pinPreferencesLoaded = false;
      _pinPreferencesOwner = null;
      _chats = [];
      _filtered = [];
      _loading = true;
    });
    _loadPinnedChatPreferences(username);
    _loadHiddenChatPreferences(username);
    _loadArchiveAndLockPreferences(username);
    // Non-silent load first restores this account's username-scoped local DB.
    // The authenticated friend_list event will replace it with server state.
    _loadChats();
  }

  String _pinnedPreferenceKey(String username) =>
      'novyn_pinned_${username.trim().toLowerCase()}';

  Future<void> _loadPinnedChatPreferences(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_pinnedPreferenceKey(username)) ?? [];
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username.trim().toLowerCase()) {
        return;
      }

      setState(() {
        _pinnedChatUsernames = stored
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .take(5)
            .toSet();
        _pinPreferencesLoaded = true;
        _pinPreferencesOwner = username.trim().toLowerCase();
        _chats = _withPinnedPreferences(_chats);
      });
      ChatsScreen.cachedChats = List<ChatPreview>.from(_chats);
      ChatsScreen.cachedChatsOwner = username.trim().toLowerCase();
      _applyFilters();
    } catch (error) {
      debugPrint('Could not load pinned chats: $error');
    }
  }

  String _archivedChatsPreferenceKey(String username) =>
      'novyn_archived_${username.trim().toLowerCase()}';

  String _lockedChatsPreferenceKey(String username) =>
      'novyn_locked_chats_${username.trim().toLowerCase()}';

  Future<void> _loadArchiveAndLockPreferences(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final archived = prefs.getStringList(_archivedChatsPreferenceKey(username)) ?? [];
      final locked = prefs.getStringList(_lockedChatsPreferenceKey(username)) ?? [];
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username.trim().toLowerCase()) {
        return;
      }
      setState(() {
        _archivedChatUsernames = archived
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet();
        _lockedChatUsernames = locked
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet();
        _chats = _withPinnedPreferences(_chats);
      });
      ChatsScreen.cachedChats = List<ChatPreview>.from(_chats);
      ChatsScreen.cachedChatsOwner = username.trim().toLowerCase();
      _applyFilters();
    } catch (error) {
      debugPrint('Could not load archived/locked chats: $error');
    }
  }

  Future<void> _toggleArchiveChat(ChatPreview chat) async {
    final account = context.read<AuthService>().user?.username.trim().toLowerCase();
    final peer = chat.peer.username.trim().toLowerCase();
    if (account == null || account.isEmpty || peer.isEmpty) return;

    final next = Set<String>.from(_archivedChatUsernames);
    final archived = !next.contains(peer);
    if (archived) {
      next.add(peer);
    } else {
      next.remove(peer);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
        _archivedChatsPreferenceKey(account),
        next.toList(),
      );
      if (!saved) throw StateError('Could not save archive preference.');
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() != account) {
        return;
      }
      final updated = _chats.map((item) => item.peer.username.trim().toLowerCase() == peer
          ? item.copyWith(isArchived: archived)
          : item).toList();
      setState(() {
        _archivedChatUsernames = next;
        _chats = _withPinnedPreferences(updated);
      });
      ChatsScreen.cachedChats = List<ChatPreview>.from(_chats);
      ChatsScreen.cachedChatsOwner = account;
      await HybridDbService.saveChat(chat.copyWith(isArchived: archived));
      _applyFilters();
      _showNovynAlert(archived ? 'Chat archived' : 'Chat unarchived');
    } catch (error) {
      _showNovynAlert('Could not update archive: $error');
    }
  }

  Future<void> _toggleLockedChat(ChatPreview chat) async {
    final settings = context.read<SettingsService>();
    if (!settings.appLockEnabled ||
        settings.appLockPin == null ||
        settings.appLockPin!.isEmpty) {
      _showNovynAlert('Enable App Lock and set a secure PIN in Settings → Security & Privacy before locking chats.');
      return;
    }

    final account = context.read<AuthService>().user?.username.trim().toLowerCase();
    final peer = chat.peer.username.trim().toLowerCase();
    if (account == null || account.isEmpty || peer.isEmpty) return;
    final next = Set<String>.from(_lockedChatUsernames);
    final locked = !next.contains(peer);
    if (!locked && !_showingLockedChats) {
      if (!await _requireChatUnlock() || !mounted) return;
    }
    if (locked) {
      next.add(peer);
    } else {
      next.remove(peer);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
        _lockedChatsPreferenceKey(account),
        next.toList(),
      );
      if (!saved) throw StateError('Could not save chat lock preference.');
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() != account) {
        return;
      }
      setState(() => _lockedChatUsernames = next);
      _applyFilters();
      _showNovynAlert(locked ? 'Chat locked' : 'Chat unlocked');
    } catch (error) {
      _showNovynAlert('Could not update chat lock: $error');
    }
  }

  String _hiddenChatsPreferenceKey(String username) =>
      'novyn_hidden_chats_${username.trim().toLowerCase()}';

  Future<void> _loadHiddenChatPreferences(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_hiddenChatsPreferenceKey(username)) ?? [];
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username.trim().toLowerCase()) {
        return;
      }
      setState(() {
        _hiddenChatUsernames = stored
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet();
        _hiddenChatsOwner = username.trim().toLowerCase();
      });
      _applyFilters();
    } catch (error) {
      debugPrint('Could not load hidden chats: $error');
    }
  }

  Future<void> _hideChatLocally(ChatPreview chat) async {
    final username =
        context.read<AuthService>().user?.username.trim().toLowerCase();
    final peerUsername = chat.peer.username.trim().toLowerCase();
    if (username == null || username.isEmpty || peerUsername.isEmpty) {
      _showNovynAlert('Could not delete this chat.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final next = Set<String>.from(
        prefs.getStringList(_hiddenChatsPreferenceKey(username)) ??
            _hiddenChatUsernames,
      )..add(peerUsername);
      final saved = await prefs.setStringList(
        _hiddenChatsPreferenceKey(username),
        next.toList(),
      );
      if (!saved) throw StateError('Could not save the deleted chat.');

      // Remove only this device's cached conversation. The server-side
      // friendship and the other person's chat history remain untouched.
      await HybridDbService.deleteChat(chat.peer.username);
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username) {
        return;
      }

      final updated = _chats
          .where((item) =>
              item.peer.username.trim().toLowerCase() != peerUsername)
          .toList();
      setState(() {
        _hiddenChatUsernames = next;
        _hiddenChatsOwner = username;
        _chats = updated;
      });
      ChatsScreen.cachedChats = List<ChatPreview>.from(updated);
      ChatsScreen.cachedChatsOwner = username;
      ChatsScreen.totalUnread =
          updated.fold(0, (total, item) => total + item.unreadCount);
      _applyFilters();
      _showNovynAlert('Chat deleted. Friend is still in your contacts.');
    } catch (error) {
      _showNovynAlert('Could not delete chat: ${error.toString()}');
    }
  }

  Future<void> _unhideChatsWithNewMessages(
    List<ChatPreview> conversations,
  ) async {
    final username =
        context.read<AuthService>().user?.username.trim().toLowerCase();
    if (username == null || username.isEmpty ||
        _hiddenChatsOwner != username || _hiddenChatUsernames.isEmpty) {
      return;
    }
    final previousByPeer = {
      for (final chat in _lastSocketConversations)
        chat.peer.username.trim().toLowerCase(): chat,
    };
    final newlyMessaged = <String>{};
    for (final chat in conversations) {
      final peer = chat.peer.username.trim().toLowerCase();
      final previous = previousByPeer[peer];
      if (_hiddenChatUsernames.contains(peer) && previous != null &&
          chat.lastTime.isAfter(previous.lastTime)) {
        newlyMessaged.add(peer);
      }
    }
    if (newlyMessaged.isEmpty) return;

    final next = Set<String>.from(_hiddenChatUsernames)
      ..removeAll(newlyMessaged);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _hiddenChatsPreferenceKey(username),
        next.toList(),
      );
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username) return;
      setState(() => _hiddenChatUsernames = next);
      _applyFilters();
    } catch (error) {
      debugPrint('Could not restore chat after a new message: $error');
    }
  }

  List<ChatPreview> _withPinnedPreferences(
    List<ChatPreview> chats, {
    Set<String>? pinnedUsernames,
  }) {
    final pins = pinnedUsernames ?? _pinnedChatUsernames;
    final previews = chats
        .map((chat) {
          final peer = chat.peer.username.trim().toLowerCase();
          return chat.copyWith(
            isPinned: pins.contains(peer),
            isArchived: _archivedChatUsernames.contains(peer),
          );
        })
        .toList();
    previews.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.lastTime.compareTo(a.lastTime);
    });
    return previews;
  }

  Future<void> _togglePinChat(ChatPreview chat) async {
    final username =
        context.read<AuthService>().user?.username.trim().toLowerCase();
    final peerUsername = chat.peer.username.trim().toLowerCase();
    if (username == null || username.isEmpty || peerUsername.isEmpty) {
      _showNovynAlert('Could not update this chat pin.');
      return;
    }

    if (!_pinPreferencesLoaded || _pinPreferencesOwner != username) {
      await _loadPinnedChatPreferences(username);
    }
    if (!_pinPreferencesLoaded || _pinPreferencesOwner != username) {
      _showNovynAlert('Pinned chats are still loading. Please try again.');
      return;
    }

    final shouldPin = !_pinnedChatUsernames.contains(peerUsername);
    final next = Set<String>.from(_pinnedChatUsernames);
    if (shouldPin) {
      if (next.length >= 5) {
        _showNovynAlert('You can pin up to 5 chats. Unpin one to add another.');
        return;
      }
      next.add(peerUsername);
    } else {
      next.remove(peerUsername);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final orderedPins = next.toList();
      final saved = await prefs.setStringList(
        _pinnedPreferenceKey(username),
        orderedPins,
      );
      if (!saved) throw StateError('Could not save your pinned chats.');
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username) {
        return;
      }

      final updated = _withPinnedPreferences(
        _chats,
        pinnedUsernames: next,
      );
      setState(() {
        _pinnedChatUsernames = next;
        _chats = updated;
      });
      ChatsScreen.cachedChats = List<ChatPreview>.from(updated);
      ChatsScreen.cachedChatsOwner = username;
      ChatsScreen.totalUnread =
          updated.fold(0, (total, item) => total + item.unreadCount);
      _applyFilters();

      // Keep the local chat databases in step with the account preference.
      final updatedChat = chat.copyWith(isPinned: shouldPin);
      await HybridDbService.saveChat(updatedChat);
      if (!mounted) return;

      HapticService.vibrate(
        NovynHapticType.selection,
        category: HapticCategory.chat,
      );
      _showNovynAlert(
        shouldPin ? '${chat.peer.name} pinned' : '${chat.peer.name} unpinned',
      );
    } catch (error) {
      if (mounted) {
        _showNovynAlert('Could not update pin: ${error.toString()}');
      }
    }
  }

  bool _sameConversationReferences(
    List<ChatPreview> previous,
    List<ChatPreview> next,
  ) {
    if (identical(previous, next)) return true;
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      if (!identical(previous[index], next[index])) return false;
    }
    return true;
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

    final conversations = socket.conversations;
    unawaited(_unhideChatsWithNewMessages(conversations));
    if (_sameConversationReferences(_lastSocketConversations, conversations)) {
      return;
    }
    _lastSocketConversations = List<ChatPreview>.from(conversations);

    // A completed server snapshot supersedes any in-flight cache hydration.
    // This prevents an older local read from overwriting fresh conversations.
    _loadGeneration++;
    final previews = _withPinnedPreferences(
      List<ChatPreview>.from(conversations),
    );
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
            isPinned: _pinnedChatUsernames.contains(
              peer.username.trim().toLowerCase(),
            ),
            isArchived: chat['isArchived'] == true,
            isGroup: chat['isGroup'] == true,
          ));
        }
        if (previews.isNotEmpty && mounted) {
          final orderedPreviews = _withPinnedPreferences(previews);
          setState(() {
            _chats = orderedPreviews;
            _loading = false;
          });
          _applyFilters();
          ChatsScreen.cachedChats = orderedPreviews;
          ChatsScreen.cachedChatsOwner = myUsername.toLowerCase();
          ChatsScreen.totalUnread =
              orderedPreviews.fold(0, (s, c) => s + c.unreadCount);
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
      _lastSocketConversations = List<ChatPreview>.from(conversations);
      final previews = _withPinnedPreferences(
        List<ChatPreview>.from(conversations),
      );
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isActive = TickerMode.of(context);
    if (_homeTabIsActive == isActive) return;
    _homeTabIsActive = isActive;
    if (isActive && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _showNewChatFab = true;
      _scheduleNewChatFabHide();
    } else {
      _newChatFabTimer?.cancel();
    }
  }

  void _scheduleNewChatFabHide() {
    _newChatFabTimer?.cancel();
    if (_homeTabIsActive != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _newChatFabTimer = Timer(_newChatFabIdleDelay, () {
      if (!mounted || _homeTabIsActive != true) return;
      if (_showNewChatFab) setState(() => _showNewChatFab = false);
    });
  }

  void _revealNewChatFab() {
    if (_homeTabIsActive != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (!_showNewChatFab && mounted) {
      setState(() => _showNewChatFab = true);
    }
    _scheduleNewChatFabHide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _revealNewChatFab();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _newChatFabTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newChatFabTimer?.cancel();
    _authService?.removeListener(_handleAuthChanged);
    try {
      context.read<SocketService>().removeListener(_handleSocketUpdate);
    } catch (_) {}
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _requireChatUnlock() async {
    final settings = context.read<SettingsService>();
    if (!settings.appLockEnabled ||
        settings.appLockPin == null ||
        settings.appLockPin!.isEmpty) {
      _showNovynAlert('Chat Lock needs App Lock enabled with a secure PIN.');
      return false;
    }
    final unlocked = await Navigator.of(context).push<bool>(
      NovynPageRoute<bool>(
        child: AppLockScreen(
          onUnlocked: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    return unlocked == true && mounted;
  }

  Future<void> _showArchivedChats() async {
    _searchController.clear();
    _search = '';
    _searchFocusNode.unfocus();
    setState(() {
      _showingArchivedChats = true;
      _showingLockedChats = false;
      _selectionMode = false;
      _selectedChatIds.clear();
      _selectedTab = 'all';
      _isSearchVisible = false;
    });
    _applyFilters();
  }

  Future<void> _showLockedChats() async {
    if (_lockedChatUsernames.isEmpty) {
      _showNovynAlert('No locked chats yet. Lock a conversation from its chat menu.');
      return;
    }
    if (!await _requireChatUnlock() || !mounted) return;
    _searchController.clear();
    _search = '';
    _searchFocusNode.unfocus();
    setState(() {
      _showingLockedChats = true;
      _showingArchivedChats = false;
      _selectionMode = false;
      _selectedChatIds.clear();
      _selectedTab = 'all';
      _isSearchVisible = false;
    });
    _applyFilters();
  }

  void _returnToAllChats() {
    setState(() {
      _showingArchivedChats = false;
      _showingLockedChats = false;
      _selectionMode = false;
      _selectedChatIds.clear();
      _selectedTab = 'all';
    });
    _applyFilters();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedChatIds.clear();
      _showingArchivedChats = false;
      _showingLockedChats = false;
    });
    _applyFilters();
  }

  void _toggleChatSelection(ChatPreview chat) {
    setState(() {
      if (!_selectionMode) _selectionMode = true;
      if (!_selectedChatIds.add(chat.chatId)) {
        _selectedChatIds.remove(chat.chatId);
      }
    });
  }

  void _selectAllVisibleChats() {
    setState(() {
      _selectedChatIds
        ..clear()
        ..addAll(_filtered.map((chat) => chat.chatId));
    });
  }

  Future<void> _archiveSelectedChats() async {
    final account = context.read<AuthService>().user?.username.trim().toLowerCase();
    if (account == null || account.isEmpty || _selectedChatIds.isEmpty) return;
    final selected = _chats.where((chat) => _selectedChatIds.contains(chat.chatId)).toList();
    final next = Set<String>.from(_archivedChatUsernames);
    for (final chat in selected) {
      next.add(chat.peer.username.trim().toLowerCase());
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
        _archivedChatsPreferenceKey(account),
        next.toList(),
      );
      if (!saved) throw StateError('Could not save archived chats.');
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() != account) {
        return;
      }
      final updated = _chats.map((chat) {
        final archived = next.contains(chat.peer.username.trim().toLowerCase());
        return chat.copyWith(isArchived: archived);
      }).toList();
      setState(() {
        _archivedChatUsernames = next;
        _chats = _withPinnedPreferences(updated);
        _selectionMode = false;
        _selectedChatIds.clear();
      });
      ChatsScreen.cachedChats = List<ChatPreview>.from(_chats);
      ChatsScreen.cachedChatsOwner = account;
      await Future.wait(selected.map(
        (chat) => HybridDbService.saveChat(chat.copyWith(isArchived: true)),
      ));
      _applyFilters();
      _showNovynAlert('${selected.length} chat${selected.length == 1 ? '' : 's'} archived');
    } catch (error) {
      _showNovynAlert('Could not archive selected chats: $error');
    }
  }

  Future<void> _markAllChatsRead() async {
    try {
      final result = await context.read<SocketService>().markAllConversationsAsRead();
      if (result['ok'] != true) {
        _showNovynAlert(result['message']?.toString() ?? 'Could not mark chats as read.');
        return;
      }
      if (!mounted) return;
      final updated = _chats
          .map((chat) => chat.copyWith(unreadCount: 0))
          .toList();
      setState(() {
        _chats = updated;
        _filtered = _filtered
            .map((chat) => chat.copyWith(unreadCount: 0))
            .toList();
      });
      ChatsScreen.cachedChats = List<ChatPreview>.from(updated);
      ChatsScreen.totalUnread = 0;
      _showNovynAlert('All chats marked as read');
    } catch (error) {
      _showNovynAlert('Could not mark chats as read: $error');
    }
  }

  Future<void> _inviteFriends() async {
    final username = context.read<AuthService>().user?.username.trim() ?? '';
    final invite = [
      'Join me on Novyn!',
      if (username.isNotEmpty) 'Find me as @$username.',
      'https://itssatyam27.github.io/novyn-chat/',
    ].join(' ');
    try {
      await Share.share(invite, subject: 'Join me on Novyn');
    } catch (error) {
      _showNovynAlert('Could not open the share sheet: $error');
    }
  }

  Future<void> _openStarredMessages() async {
    await Navigator.of(context).push<void>(
      NovynPageRoute<void>(
        child: StarredMessagesScreen(
          chats: List<ChatPreview>.from(_chats),
          onOpenChat: _openChat,
        ),
      ),
    );
  }

  void _openCreateGroup() {
    final myUid = context.read<AuthService>().user?.username;
    if (myUid == null || myUid.isEmpty) return;
    Navigator.push(
      context,
      NovynPageRoute<void>(
        child: CreateGroupScreen(myUid: myUid),
      ),
    );
  }

  void _openChatSettings() {
    Navigator.push(
      context,
      NovynPageRoute<void>(child: const ChatSettingsScreen()),
    );
  }

  void _openChat(ChatPreview chat) async {
    await Navigator.of(context).push<void>(
      NovynPageRoute<void>(
        child: ChatDetailScreen(
          peer: chat.peer,
          isGroup: chat.isGroup,
          chatLockAlreadyVerified: _showingLockedChats,
        ),
      ),
    );
    // The socket listener keeps this screen's conversation snapshot current
    // while the chat route is open; reopening both local databases is redundant.
  }

  void _showNovynAlert(String message) {
    if (!mounted) return;
    final lower = message.toLowerCase();
    NovynAlert.show(
      context,
      message,
      isError: lower.startsWith('could not') || lower.contains('still loading'),
      title: lower.contains('pinned') ? 'Chat updated' : null,
      icon: lower.contains('pinned') ? Icons.push_pin_rounded : null,
    );
  }

  void _applyFilters() {
    final settings = context.read<SettingsService>();
    final blockedUids = settings.blockedUids;
    final isDecoy = settings.decoyMode;

    final next = isDecoy
        ? <ChatPreview>[]
        : _chats.where((chat) {
            final peer = chat.peer.username.trim().toLowerCase();
            final isArchived = _archivedChatUsernames.contains(peer) || chat.isArchived;
            final isLocked = _lockedChatUsernames.contains(peer);
            if (_showingArchivedChats) {
              if (!isArchived) return false;
            } else if (_showingLockedChats) {
              if (!isLocked) return false;
            } else if (isArchived || isLocked) {
              return false;
            }
            if (blockedUids.contains(chat.peerUid) ||
                _hiddenChatUsernames.contains(peer)) {
              return false;
            }
            if (_search.isEmpty) return true;
            final query = _search.trim().toLowerCase();
            return chat.peer.name.toLowerCase().contains(query) ||
                peer.contains(query);
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

    final pageBackground = NovynTheme.pageBg(context);
    final canShowNewChatFab = _showNewChatFab && !_selectionMode &&
        !_showingArchivedChats && !_showingLockedChats;

    return Scaffold(
      backgroundColor: pageBackground,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _revealNewChatFab(),
        child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_selectionMode || _showingArchivedChats || _showingLockedChats) ...[
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(17),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: _selectionMode ? _toggleSelectionMode : _returnToAllChats,
                        child: const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(Icons.arrow_back_rounded, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _selectionMode
                          ? 'Select chats'
                          : _showingArchivedChats
                              ? 'Archived chats'
                              : _showingLockedChats
                                  ? 'Locked chats'
                                  : 'Chats',
                      maxLines: 1,
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
                  if (_selectionMode)
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(17),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: _selectAllVisibleChats,
                        child: const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(Icons.select_all_rounded, size: 23),
                        ),
                      ),
                    )
                  else
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(17),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: () {
                          setState(() => _isSearchVisible = !_isSearchVisible);
                          if (_isSearchVisible) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _searchFocusNode.requestFocus();
                            });
                          } else {
                            _searchFocusNode.unfocus();
                            _searchController.clear();
                            _onSearch('');
                          }
                        },
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(
                            _isSearchVisible
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 23,
                          ),
                        ),
                      ),
                    ),
                  if (!_selectionMode && !_showingArchivedChats && !_showingLockedChats) ...[
                    const SizedBox(width: 8),
                    ChatOverflowMenu(
                      archivedCount: _archivedChatUsernames.length,
                      lockedCount: _lockedChatUsernames.length,
                      onCreateGroup: _openCreateGroup,
                      onInviteFriends: _inviteFriends,
                      onArchivedChats: _showArchivedChats,
                      onLockedChats: _showLockedChats,
                      onStarredMessages: _openStarredMessages,
                      onSelectChats: _toggleSelectionMode,
                      onMarkAllRead: _markAllChatsRead,
                      onChatSettings: _openChatSettings,
                    ),
                  ],
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
            if (!_selectionMode && !_showingArchivedChats && !_showingLockedChats)
              _buildFilterCards(),
            if (_selectionMode) _buildSelectionToolbar(),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary))
                  : RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: _loadChats,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollStartNotification ||
                              notification is ScrollUpdateNotification ||
                              notification is UserScrollNotification) {
                            _revealNewChatFab();
                          }
                          return false;
                        },
                        child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (pinnedChats.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _buildSectionLabel('PINNED'),
                            ),
                            _buildChatGroupSliver(pinnedChats),
                          ],
                          if (recentChats.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _buildSectionLabel('ALL CHATS'),
                            ),
                            _buildChatGroupSliver(recentChats),
                          ],
                          if (activeChats.isEmpty)
                            SliverFillRemaining(child: _buildEmpty()),
                          const SliverToBoxAdapter(child: SizedBox(height: 112)),
                        ],
                      ),
                      ),
                    ),
            ),
          ],
        ),
        ),
      ),
      floatingActionButton: AnimatedSlide(
        offset: canShowNewChatFab ? Offset.zero : const Offset(1.35, 0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: canShowNewChatFab ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !canShowNewChatFab,
            child: Padding(
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.edit_rounded, size: 27),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSelectionToolbar() {
    final selectedCount = _selectedChatIds.length;
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: selectedCount == 0 ? null : _archiveSelectedChats,
            child: const Text('Archive'),
          ),
          TextButton(
            onPressed: _toggleSelectionMode,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCards() {
    const filters = [
      ('all', 'All'),
      ('unread', 'Unread'),
      ('groups', 'Groups'),
      ('favorites', 'Favourites'),
    ];
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          for (final item in filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _selectTab(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selectedTab == item.$1
                        ? colors.primary
                        : colors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _selectedTab == item.$1
                          ? Colors.white
                          : colors.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
                onChanged: _onSearch,
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
                  hintText: 'Search chats ya messages',
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
                    _onSearch('');
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 18, 10),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _showChatOptions(
    ChatPreview chat,
    BuildContext tileContext,
  ) async {
    final settings = context.read<SettingsService>();
    final socket = context.read<SocketService>();
    final isFavorite = settings.favoriteChatIds.contains(chat.chatId);
    final isLocked = _lockedChatUsernames.contains(chat.peer.username.trim().toLowerCase());
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tileBox = tileContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (tileBox == null || overlayBox == null ||
        !tileBox.hasSize || !overlayBox.hasSize) {
      return;
    }

    final tileTopLeft =
        tileBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final tileCenterY = tileTopLeft.dy + tileBox.size.height / 2;
    final menuHeight = (overlayBox.size.height - 24)
        .clamp(240.0, 460.0)
        .toDouble();
    final maxMenuTop = (overlayBox.size.height - menuHeight - 12)
        .clamp(12.0, double.infinity)
        .toDouble();
    final menuTop = (tileCenterY - menuHeight / 2)
        .clamp(12.0, maxMenuTop)
        .toDouble();
    final anchorRect = Rect.fromLTWH(
      overlayBox.size.width - 8,
      menuTop,
      1,
      1,
    );
    final position = RelativeRect.fromRect(
      anchorRect,
      Offset.zero & overlayBox.size,
    );

    PopupMenuItem<String> option(
      IconData icon,
      String label,
      String value, {
      Color? color,
    }) {
      final foreground = color ?? colors.onSurface;
      return PopupMenuItem<String>(
        value: value,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color ?? colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final action = await showMenu<String>(
      context: context,
      position: position,
      popUpAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 180),
        reverseDuration: Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      elevation: 14,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 46,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  chat.peer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (chat.isGroup)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'GROUP',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .7,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        option(
          chat.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          chat.isPinned ? 'Unpin chat' : 'Pin chat',
          'pin',
          color: chat.isPinned ? colors.primary : null,
        ),
        option(Icons.notifications_off_outlined, 'Mute notifications', 'mute'),
        option(
          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          isFavorite ? 'Remove from favorites' : 'Add to favorites',
          'favorite',
          color: isFavorite ? const Color(0xFFFFB300) : null,
        ),
        if (chat.unreadCount > 0)
          option(
            Icons.mark_chat_read_outlined,
            'Mark as read',
            'read',
          ),
        option(
          chat.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
          chat.isArchived ? 'Unarchive chat' : 'Archive chat',
          'archive',
        ),
        option(
          isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
          isLocked ? 'Unlock chat' : 'Lock chat',
          'lock',
          color: isLocked ? colors.primary : null,
        ),
        const PopupMenuDivider(height: 1),
        if (!chat.isGroup)
          option(
            Icons.block_outlined,
            'Block user',
            'block',
            color: colors.error,
          ),
        option(
          Icons.cleaning_services_outlined,
          'Clear chat',
          'clear',
          color: colors.error,
        ),
        option(
          chat.isGroup ? Icons.logout_rounded : Icons.delete_outline_rounded,
          chat.isGroup ? 'Exit group' : 'Delete chat',
          'delete',
          color: colors.error,
        ),
      ],
    );
    if (!mounted || action == null) return;

    // Only expose actions that the mobile client can currently execute safely.
    switch (action) {
      case 'pin':
        await _togglePinChat(chat);
        break;
      case 'favorite':
        await settings.toggleFavoriteChat(chat.chatId);
        break;
      case 'mute':
        try {
          socket.setMute(chat.peer.username, muted: true);
          _showNovynAlert('Notifications muted');
        } catch (error) {
          _showNovynAlert(error.toString());
        }
        break;
      case 'read':
        try {
          final result = await socket.markConversationAsRead(
            chat.isGroup ? chat.peer.uid : chat.peer.username,
            isGroup: chat.isGroup,
          );
          if (result['ok'] != true) {
            _showNovynAlert(result['message']?.toString() ?? 'Could not mark this chat as read.');
            break;
          }
          final updated = _chats.map((item) => item.chatId == chat.chatId
              ? item.copyWith(unreadCount: 0)
              : item).toList();
          setState(() {
            _chats = updated;
            _filtered = _filtered.map((item) => item.chatId == chat.chatId
                ? item.copyWith(unreadCount: 0)
                : item).toList();
          });
          ChatsScreen.cachedChats = List<ChatPreview>.from(updated);
          ChatsScreen.totalUnread = updated.fold(0, (total, item) => total + item.unreadCount);
          _showNovynAlert('Chat marked as read');
        } catch (error) {
          _showNovynAlert('Could not mark chat as read: $error');
        }
        break;
      case 'archive':
        await _toggleArchiveChat(chat);
        break;
      case 'lock':
        await _toggleLockedChat(chat);
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
            _showNovynAlert('Chat cleared');
            await _loadChats(silent: true);
          } catch (error) {
            _showNovynAlert(error.toString());
          }
        }
        break;
      case 'delete':
        if (chat.isGroup) {
          _showNovynAlert('Exit group is not yet supported in the mobile client.');
          break;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete chat?'),
            content: Text('Remove this conversation from your chat list? ${chat.peer.name} will remain your friend, and new messages will bring the chat back.'),
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
          await _hideChatLocally(chat);
        }
        break;
      case 'block':
        _showNovynAlert('Blocking is managed from Contacts and Security settings.');
        break;
    }
  }

  Widget _buildChatGroupSliver(List<ChatPreview> chats) {
    if (chats.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? theme.colorScheme.surface : Colors.white;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: .07)
        : const Color(0xFFF0ECF6);

    // Build chat rows lazily. The previous Column eagerly created every row
    // inside one SliverToBoxAdapter, which made large inboxes expensive to lay
    // out and paint before the user had even scrolled to them.
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final isFirst = index == 0;
            final isLast = index == chats.length - 1;
            return ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: isFirst ? const Radius.circular(34) : Radius.zero,
                bottom: isLast ? const Radius.circular(34) : Radius.zero,
              ),
              child: Material(
                color: cardColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildChatCard(chats[index]),
                    if (!isLast)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 0,
                        endIndent: 0,
                        color: dividerColor,
                      ),
                  ],
                ),
              ),
            );
          },
          childCount: chats.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
        ),
      ),
    );
  }

  Widget _buildChatCard(ChatPreview preview) {
    final selected = _selectedChatIds.contains(preview.chatId);
    return _ChatCard(
      preview: preview,
      isFavorite: context.watch<SettingsService>().favoriteChatIds.contains(preview.chatId),
      isSelected: selected,
      selectionMode: _selectionMode,
      onOptions: _selectionMode ? null : (tileContext) => _showChatOptions(preview, tileContext),
      onTap: () {
        if (_selectionMode) {
          _toggleChatSelection(preview);
        } else {
          _openChat(preview);
        }
      },
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
          if (i == 0 && !_topChatsPreloadStarted) {
            _topChatsPreloadStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_preloadTopChats());
            });
          }

          return RepaintBoundary(
            child: _ChatCard(
              preview: _filtered[i],
              isSelected: _selectedChatIds.contains(_filtered[i].chatId),
              selectionMode: _selectionMode,
              onOptions: _selectionMode ? null : (tileContext) => _showChatOptions(_filtered[i], tileContext),
              onTap: () {
                if (_selectionMode) {
                  _toggleChatSelection(_filtered[i]);
                } else {
                  _openChat(_filtered[i]);
                }
              },
            ),
          );
        },
      ),
    );
  }

  // Pre-load top 3 chats for instant opening (WhatsApp optimization)
  Future<void> _preloadTopChats() async {
    final chatIds = _filtered.take(3).map((chat) => chat.chatId).toList();
    for (final chatId in chatIds) {
      if (!mounted) return;
      await HybridDbService.getMessages(chatId, limit: 20);
    }
  }

  Widget _buildEmpty() {
    if (_showingArchivedChats) {
      return const NovynEmptyState(
        icon: Icons.archive_outlined,
        title: 'No archived chats',
        description: 'Chats you archive will appear here.',
      );
    }
    if (_showingLockedChats) {
      return const NovynEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'No locked chats',
        description: 'Lock a conversation from its chat menu to keep it protected.',
      );
    }
    if (_selectionMode) {
      return const NovynEmptyState(
        icon: Icons.check_box_outlined,
        title: 'No chats to select',
        description: 'There are no conversations in this view.',
      );
    }
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
                  Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.05)),
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
  final bool isSelected;
  final bool selectionMode;
  final ValueChanged<BuildContext>? onOptions;

  const _ChatCard({
    required this.preview,
    required this.onTap,
    this.isFavorite = false,
    this.isSelected = false,
    this.selectionMode = false,
    this.onOptions,
  });

  // Keep contact and chat-list avatars visually consistent. People always
  // use UserAvatar so both profile photos and the soft pastel initials fallback
  // match the Contacts screen. Photo-less group chats keep their group icon.
  static const List<Color> _avatarPalette = [
    Color(0xFF6D4CF5),
    Color(0xFFC03F72),
    Color(0xFF287A70),
    Color(0xFFB85A0A),
    Color(0xFF2865E8),
    Color(0xFF8054C9),
  ];

  Color _avatarColor() {
    final value = preview.peer.username.isNotEmpty
        ? preview.peer.username
        : preview.peer.name;
    final index = value.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
        _avatarPalette.length;
    return _avatarPalette[index];
  }

  Widget _buildAvatar(BuildContext context) {
    final color = _avatarColor();

    if (!preview.isGroup || preview.peer.photoUrl.isNotEmpty) {
      final displayName = preview.peer.name.trim().isNotEmpty
          ? preview.peer.name.trim()
          : preview.peer.username.trim();
      return UserAvatar(
        name: displayName,
        photoUrl: preview.peer.photoUrl.trim(),
        radius: 26,
        fallbackColor: color,
        showOnlineIndicator: !preview.isGroup && preview.peer.isOnline,
        isOnline: preview.peer.isOnline,
        presence: preview.peer.status,
      );
    }

    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.groups_rounded, color: Colors.white, size: 27),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasUnread = preview.unreadCount > 0;
    final titleColor = colors.onSurface;
    final metaColor = colors.onSurfaceVariant;

    return InkWell(
      onTap: () {
        HapticService.vibrate(
          NovynHapticType.light,
          category: HapticCategory.chat,
        );
        onTap();
      },
      onLongPress: onOptions == null ? null : () => onOptions!(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            if (selectionMode) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 23,
                height: 23,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded, color: colors.onPrimary, size: 17)
                    : null,
              ),
            ],
            _buildAvatar(context),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          preview.peer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -.25,
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (preview.isPinned) ...[
                        const SizedBox(width: 5),
                        Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                      ],
                      if (isFavorite) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFB300),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    preview.lastMessage.isEmpty
                        ? 'Tap to chat'
                        : preview.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14.5,
                      color: hasUnread ? titleColor : metaColor,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatTime(
                      preview.lastTime,
                      context.watch<SettingsService>().timeFormat,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12.5,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                      color: hasUnread ? colors.primary : metaColor,
                    ),
                  ),
                  if (hasUnread) ...[
                    const SizedBox(height: 7),
                    Container(
                      width: 23,
                      height: 23,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        preview.unreadCount > 99
                            ? '99+'
                            : '${preview.unreadCount}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
                fontWeight: FontWeight.w500,
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
