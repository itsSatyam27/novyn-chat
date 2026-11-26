import 'dart:async';
import 'dart:convert';
import '../../widgets/novyn_alert.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/socket_service.dart';
import '../../services/hybrid_db_service.dart';
import '../../services/notification_service.dart';
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
import '../../widgets/novyn_header_actions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:novyn/services/haptic_service.dart';
import '../../utils/presence_utils.dart';

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
  bool _hiddenChatSyncInFlight = false;
  Future<void>? _hiddenPreferencesLoadFuture;
  String? _hiddenPreferencesLoadOwner;
  bool _hasPendingHiddenChatChanges = false;

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
      _loadArchiveAndLockPreferences(initialUsername);
    }

    // Never hydrate from a previous signed-in account's in-memory previews.
    final owner = _observedUsername;
    if (owner == null || ChatsScreen.cachedChatsOwner != owner) {
      ChatsScreen.resetAccountCache();
    }
    // Load the local deletion tombstones before exposing cached rows. This is
    // a local preferences read only; the server snapshot still refreshes later.
    if (ChatsScreen.cachedChats != null && owner != null &&
        ChatsScreen.cachedChatsOwner == owner) {
      _restoreCachedChatsAfterHiddenPreferences(owner);
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

  Future<void> _restoreCachedChatsAfterHiddenPreferences(String username) async {
    await _loadHiddenChatPreferences(username);
    if (!mounted ||
        context.read<AuthService>().user?.username.trim().toLowerCase() != username) {
      return;
    }
    final cached = ChatsScreen.cachedChats;
    if (cached != null && ChatsScreen.cachedChatsOwner == username) {
      final previews = _withPinnedPreferences(List<ChatPreview>.from(cached));
      setState(() {
        _chats = previews;
        _loading = false;
      });
      _applyFilters();
    }
    await _loadChats(silent: true);
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
      final archived = (prefs.getStringList(_archivedChatsPreferenceKey(username)) ?? [])
          .map((value) => value.trim().toLowerCase()).where((value) => value.isNotEmpty).toSet();
      final locked = (prefs.getStringList(_lockedChatsPreferenceKey(username)) ?? [])
          .map((value) => value.trim().toLowerCase()).where((value) => value.isNotEmpty).toSet();
      // Resolve legacy overlap deterministically: Archive wins.
      locked.removeAll(archived);
      await prefs.setStringList(_archivedChatsPreferenceKey(username), archived.toList());
      await prefs.setStringList(_lockedChatsPreferenceKey(username), locked.toList());
      if (!mounted || context.read<AuthService>().user?.username.trim().toLowerCase() != username.trim().toLowerCase()) return;
      setState(() {
        _archivedChatUsernames = archived;
        _lockedChatUsernames = locked;
        _chats = _withPinnedPreferences(_chats.map((chat) {
          final peer = chat.peer.username.trim().toLowerCase();
          return locked.contains(peer) && chat.isArchived ? chat.copyWith(isArchived: false) : chat;
        }).toList());
      });
      for (final peer in archived) {
        NotificationService.setChatArchivedForNotifications(peer, true);
      }
      for (final peer in locked) {
        NotificationService.setChatArchivedForNotifications(peer, false);
      }
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
    final nextArchived = Set<String>.from(_archivedChatUsernames);
    final archived = !(nextArchived.contains(peer) || chat.isArchived);
    final nextLocked = Set<String>.from(_lockedChatUsernames);
    if (archived) { nextArchived.add(peer); nextLocked.remove(peer); } else { nextArchived.remove(peer); }
    try {
      final prefs = await SharedPreferences.getInstance();
      final a = await prefs.setStringList(_archivedChatsPreferenceKey(account), nextArchived.toList());
      final l = await prefs.setStringList(_lockedChatsPreferenceKey(account), nextLocked.toList());
      if (!a || !l) throw StateError('Could not save chat privacy preferences.');
      if (!mounted || context.read<AuthService>().user?.username.trim().toLowerCase() != account) return;
      final updated = _chats.map((item) => item.peer.username.trim().toLowerCase() == peer
          ? item.copyWith(isArchived: archived) : item).toList();
      setState(() { _archivedChatUsernames = nextArchived; _lockedChatUsernames = nextLocked; _chats = _withPinnedPreferences(updated); });
      NotificationService.setChatArchivedForNotifications(peer, archived);
      ChatsScreen.cachedChats = List<ChatPreview>.from(_chats);
      ChatsScreen.cachedChatsOwner = account;
      await HybridDbService.saveChat(chat.copyWith(isArchived: archived));
      _applyFilters();
      _showNovynAlert(archived ? 'Chat archived' : 'Chat unarchived');
    } catch (error) { _showNovynAlert('Could not update archive: $error'); }
  }

  Future<void> _toggleLockedChat(ChatPreview chat) async {
    final settings = context.read<SettingsService>();
    if (!settings.appLockEnabled || settings.appLockPin == null ||
        settings.appLockPin!.isEmpty || !settings.secureStorageAvailable) {
      _showNovynAlert('Enable App Lock, set a secure PIN and make sure secure storage is available before locking chats.');
      return;
    }
    final account = context.read<AuthService>().user?.username.trim().toLowerCase();
    final peer = chat.peer.username.trim().toLowerCase();
    if (account == null || account.isEmpty || peer.isEmpty) return;
    final nextLocked = Set<String>.from(_lockedChatUsernames);
    final locked = !nextLocked.contains(peer);
    if (!locked && !_showingLockedChats) { if (!await _requireChatUnlock() || !mounted) return; }
    final nextArchived = Set<String>.from(_archivedChatUsernames);
    if (locked) { nextLocked.add(peer); nextArchived.remove(peer); } else { nextLocked.remove(peer); }
    try {
      final prefs = await SharedPreferences.getInstance();
      final l = await prefs.setStringList(_lockedChatsPreferenceKey(account), nextLocked.toList());
      final a = await prefs.setStringList(_archivedChatsPreferenceKey(account), nextArchived.toList());
      if (!l || !a) throw StateError('Could not save chat privacy preferences.');
      if (!mounted || context.read<AuthService>().user?.username.trim().toLowerCase() != account) return;
      final updated = _chats.map((item) => item.peer.username.trim().toLowerCase() == peer
          ? item.copyWith(isArchived: false) : item).toList();
      setState(() { _lockedChatUsernames = nextLocked; _archivedChatUsernames = nextArchived; _chats = _withPinnedPreferences(updated); });
      NotificationService.setChatArchivedForNotifications(peer, false);
      ChatsScreen.cachedChats = List<ChatPreview>.from(_chats);
      ChatsScreen.cachedChatsOwner = account;
      await HybridDbService.saveChat(chat.copyWith(isArchived: false));
      _applyFilters();
      _showNovynAlert(locked ? 'Chat locked' : 'Chat unlocked');
    } catch (error) { _showNovynAlert('Could not update chat lock: $error'); }
  }

  String _hiddenChatsPreferenceKey(String username) =>
      'novyn_hidden_chats_${username.trim().toLowerCase()}';

  String _hiddenChatChangesPreferenceKey(String username) =>
      'novyn_hidden_chat_changes_${username.trim().toLowerCase()}';

  String _hiddenChatMigrationPreferenceKey(String username) =>
      'novyn_hidden_chat_migrated_${username.trim().toLowerCase()}';

  Future<void> _queueHiddenChatChange(
    String username,
    String peerUsername,
    bool hidden,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _hiddenChatChangesPreferenceKey(username);
    final pending = prefs.getStringList(key) ?? <String>[];
    final normalizedPeer = peerUsername.trim().toLowerCase();
    pending.removeWhere((raw) {
      try {
        final item = jsonDecode(raw);
        return item is Map &&
            item['username']?.toString().toLowerCase() == normalizedPeer;
      } catch (_) {
        return false;
      }
    });
    pending.add(jsonEncode({'username': normalizedPeer, 'hidden': hidden}));
    await prefs.setStringList(key, pending);
    _hasPendingHiddenChatChanges = true;
  }

  Future<void> _syncHiddenChatChangesWithServer(String username) async {
    if (_hiddenChatSyncInFlight) return;
    final socket = context.read<SocketService>();
    if (!socket.isAuthenticated || !socket.hasLoadedConversations ||
        socket.myUsername?.toLowerCase() != username.toLowerCase()) {
      return;
    }

    _hiddenChatSyncInFlight = true;
    try {
      if (_hiddenChatsOwner != username) {
        await _loadHiddenChatPreferences(username);
      }
      final prefs = await SharedPreferences.getInstance();
      final changesKey = _hiddenChatChangesPreferenceKey(username);
      final pending = prefs.getStringList(changesKey) ?? <String>[];
      _hasPendingHiddenChatChanges = pending.isNotEmpty;
      final remaining = <String>[];
      for (final raw in pending) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          final peer = decoded['username']?.toString().trim().toLowerCase() ?? '';
          final hidden = decoded['hidden'] == true;
          if (peer.isEmpty || !(await socket.setChatHidden(peer, hidden))) {
            remaining.add(raw);
          }
        } catch (_) {
          remaining.add(raw);
        }
      }
      await prefs.setStringList(changesKey, remaining);
      _hasPendingHiddenChatChanges = remaining.isNotEmpty;
      if (remaining.isNotEmpty) return;

      // Once queued offline changes have reached the server, its account-level
      // set is authoritative and can hydrate this device (and future devices).
      final remote = socket.hiddenChatUsernames;
      await prefs.setStringList(_hiddenChatsPreferenceKey(username), remote.toList());
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() != username) {
        return;
      }
      setState(() {
        _hiddenChatUsernames = remote;
        _hiddenChatsOwner = username;
      });
      _applyFilters();
    } catch (error) {
      debugPrint('Could not sync hidden chats: $error');
    } finally {
      _hiddenChatSyncInFlight = false;
    }
  }

  Future<void> _loadHiddenChatPreferences(String username) {
    final normalizedUsername = username.trim().toLowerCase();
    if (_hiddenChatsOwner == normalizedUsername) return Future<void>.value();
    final pending = _hiddenPreferencesLoadFuture;
    if (pending != null && _hiddenPreferencesLoadOwner == normalizedUsername) {
      return pending;
    }

    _hiddenPreferencesLoadOwner = normalizedUsername;
    late final Future<void> tracked;
    tracked = _loadHiddenChatPreferencesInternal(normalizedUsername).whenComplete(() {
      if (identical(_hiddenPreferencesLoadFuture, tracked)) {
        _hiddenPreferencesLoadFuture = null;
        _hiddenPreferencesLoadOwner = null;
      }
    });
    _hiddenPreferencesLoadFuture = tracked;
    return tracked;
  }

  Future<void> _loadHiddenChatPreferencesInternal(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_hiddenChatsPreferenceKey(username)) ?? [];
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username.trim().toLowerCase()) {
        return;
      }
      final normalized = stored
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet();
      // Migrate existing device-only deletions once so older installs retain
      // their hidden chats after the account-level cloud state is introduced.
      final migrationKey = _hiddenChatMigrationPreferenceKey(username);
      if (!(prefs.getBool(migrationKey) ?? false)) {
        for (final peer in normalized) {
          await _queueHiddenChatChange(username, peer, true);
        }
        await prefs.setBool(migrationKey, true);
      }
      _hasPendingHiddenChatChanges =
          (prefs.getStringList(_hiddenChatChangesPreferenceKey(username)) ?? [])
              .isNotEmpty;
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username.trim().toLowerCase()) {
        return;
      }
      setState(() {
        _hiddenChatUsernames = normalized;
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
      await _queueHiddenChatChange(username, peerUsername, true);
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
      unawaited(_syncHiddenChatChangesWithServer(username));
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
      for (final peer in newlyMessaged) {
        await _queueHiddenChatChange(username, peer, false);
      }
      if (!mounted ||
          context.read<AuthService>().user?.username.trim().toLowerCase() !=
              username) {
        return;
      }
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
    final owner = context
        .read<AuthService>()
        .user
        ?.username
        .trim()
        .toLowerCase();
    if (owner == null || owner.isEmpty) return;
    final socket = context.read<SocketService>();

    // A reconnect can authenticate before its fresh friend-list snapshot is
    // fully parsed/decrypted. Process the hidden-chat tombstones independently
    // of hasLoadedConversations so they can immediately filter the cached UI.
    if (!socket.isAuthenticated ||
        socket.myUsername?.trim().toLowerCase() != owner) {
      return;
    }

    if (_hiddenChatsOwner != owner) {
      unawaited(_loadHiddenChatPreferences(owner).then((_) {
        if (mounted &&
            _hiddenChatsOwner == owner &&
            context.read<AuthService>().user?.username.trim().toLowerCase() ==
                owner) {
          _handleSocketUpdate();
        }
      }));
      return;
    }

    // Apply remote account-level deletions even when the conversation objects
    // themselves are unchanged. A hidden_chats_updated event often changes
    // only this set; returning early on identical conversation references
    // used to leave the deleted row visible until the next friend-list update.
    final remoteHidden = socket.hiddenChatUsernames;
    // Keep local, not-yet-acknowledged changes visible while also applying
    // deletions made on another device. Local pending operations are reconciled
    // with the server immediately after its first conversation snapshot.
    final effectiveHidden = Set<String>.from(remoteHidden);
    if (_hasPendingHiddenChatChanges) {
      effectiveHidden.addAll(_hiddenChatUsernames);
    }
    final hiddenChanged =
        effectiveHidden.length != _hiddenChatUsernames.length ||
        !effectiveHidden.containsAll(_hiddenChatUsernames);
    if (hiddenChanged) {
      _hiddenChatUsernames = effectiveHidden;
      _hiddenChatsOwner = owner;
      _applyFilters();
    }
    if (!_hasPendingHiddenChatChanges) {
      unawaited(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _hiddenChatsPreferenceKey(owner),
          remoteHidden.toList(),
        );
      }());
    }

    // Never treat the previous connection's conversation cache as the new
    // server snapshot. Hidden state above is still applied while this is false.
    if (!socket.hasLoadedConversations) return;

    final conversations = socket.conversations;
    unawaited(
      _unhideChatsWithNewMessages(conversations)
          .then((_) => _syncHiddenChatChangesWithServer(owner)),
    );
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

    // Resolve local deletion state before reading/rendering cached chat rows.
    // This never waits for network or server authentication.
    if (_hiddenChatsOwner != myUsername.toLowerCase()) {
      await _loadHiddenChatPreferences(myUsername.toLowerCase());
    }
    if (!mounted || generation != _loadGeneration ||
        context.read<AuthService>().user?.username != myUsername) {
      return;
    }

    // 1. Load from local cache first (instant)
    if (!silent) {
      final cachedChats = await HybridDbService.getChats();
      if (!mounted || generation != _loadGeneration ||
          context.read<AuthService>().user?.username != myUsername) {
        return;
      }
      if (cachedChats.isNotEmpty && mounted) {
        final peerUids = cachedChats
            .map((c) => c['peerUid'] as String?)
            .where((uid) => uid != null)
            .cast<String>()
            .toList();
        final cachedUsers = await HybridDbService.getUsers(peerUids);
        if (!mounted || generation != _loadGeneration ||
            context.read<AuthService>().user?.username != myUsername) {
          return;
        }

        final previews = <ChatPreview>[];
        for (final chat in cachedChats) {
          final peerUid = chat['peerUid'] as String?;
          if (peerUid == null) continue;
          final lastTime =
              DateTime.tryParse(chat['lastTime'] ?? '') ?? DateTime(2000);
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
            lastMessageId: chat['lastMessageId']?.toString() ?? '',
            lastMessageFrom: chat['lastMessageFrom']?.toString() ?? '',
            lastMessageDeliveredAt: DateTime.tryParse(
              chat['lastMessageDeliveredAt']?.toString() ?? '',
            ),
            lastMessageSeenAt: DateTime.tryParse(
              chat['lastMessageSeenAt']?.toString() ?? '',
            ),
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
        settings.appLockPin!.isEmpty ||
        !settings.secureStorageAvailable) {
      _showNovynAlert('Chat Lock needs App Lock enabled, a secure PIN and available secure storage.');
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
    final nextArchived = Set<String>.from(_archivedChatUsernames);
    final nextLocked = Set<String>.from(_lockedChatUsernames);
    for (final chat in selected) { final peer = chat.peer.username.trim().toLowerCase(); nextArchived.add(peer); nextLocked.remove(peer); }
    try {
      final prefs = await SharedPreferences.getInstance();
      final a = await prefs.setStringList(_archivedChatsPreferenceKey(account), nextArchived.toList());
      final l = await prefs.setStringList(_lockedChatsPreferenceKey(account), nextLocked.toList());
      if (!a || !l) throw StateError('Could not save archived chats.');
      if (!mounted || context.read<AuthService>().user?.username.trim().toLowerCase() != account) return;
      final peers = selected.map((chat) => chat.peer.username.trim().toLowerCase()).toSet();
      final updated = _chats.map((chat) => peers.contains(chat.peer.username.trim().toLowerCase())
          ? chat.copyWith(isArchived: true) : chat).toList();
      setState(() { _archivedChatUsernames = nextArchived; _lockedChatUsernames = nextLocked; _chats = _withPinnedPreferences(updated); _selectionMode = false; _selectedChatIds.clear(); });
      for (final peer in peers) { NotificationService.setChatArchivedForNotifications(peer, true); }
      ChatsScreen.cachedChats = List<ChatPreview>.from(_chats);
      ChatsScreen.cachedChatsOwner = account;
      await Future.wait(selected.map((chat) => HybridDbService.saveChat(chat.copyWith(isArchived: true))));
      _applyFilters();
      _showNovynAlert('${selected.length} chat${selected.length == 1 ? '' : 's'} archived');
    } catch (error) { _showNovynAlert('Could not archive selected chats: $error'); }
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
      'https://chat-novyn.web.app',
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

    final pageBackground = Theme.of(context).brightness == Brightness.dark
        ? NovynTheme.pageBg(context)
        : const Color(0xFFF3EFFA);
    final canShowNewChatFab = _showNewChatFab && !_selectionMode &&
        !_showingArchivedChats && !_showingLockedChats;

    return WillPopScope(
      onWillPop: () async {
        if (_selectionMode || _showingArchivedChats || _showingLockedChats) {
          if (_selectionMode) {
            _toggleSelectionMode();
          } else {
            _returnToAllChats();
          }
          return false;
        }
        return true;
      },
      child: Scaffold(
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
                    child: (_selectionMode || _showingArchivedChats || _showingLockedChats)
                        ? Text(
                            _selectionMode
                                ? 'Select chats'
                                : _showingArchivedChats
                                    ? 'Archived chats'
                                    : 'Locked chats',
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 36,
                              height: 1.12,
                              letterSpacing: -1.25,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          )
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              label: 'Novyn',
                              image: true,
                              child: Image.asset(
                                'assets/images/novyn-wordmark.png',
                                width: 98,
                                height: 46,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
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
                    NovynHeaderActions(
                      searchVisible: _isSearchVisible,
                      onSearchTap: () {
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
                      trailingAction: (_showingArchivedChats || _showingLockedChats)
                          ? null
                          : ChatOverflowMenu(
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
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          for (final item in filters)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _selectTab(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selectedTab == item.$1
                        ? primary
                        : (isDark ? const Color(0xFF201B36) : Colors.white),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: _selectedTab == item.$1
                          ? primary
                          : (isDark ? Colors.white10 : const Color(0xFFEAE6F7)),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedTab == item.$1
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
                      fontWeight: _selectedTab == item.$1 ? FontWeight.w700 : FontWeight.w600,
                      color: _selectedTab == item.$1
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF2D2942)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    if (_search.trim().isNotEmpty) {
      return NovynEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No chats found',
        description: 'No conversations match "${_search.trim()}".',
      );
    }

    switch (_selectedTab) {
      case 'unread':
        return NovynEmptyState(
          illustration: NovynEmptyIllustrations.speechBubblesCheck(isDark: isDark),
          title: 'You’re all caught up',
          description: 'No unread messages right now. New ones will appear here',
        );
      case 'groups':
        return NovynEmptyState(
          illustration: NovynEmptyIllustrations.peopleGroupPlus(isDark: isDark),
          title: 'No groups yet',
          description: 'Create a group to chat with several buddies at once',
          buttonLabel: 'Create group',
          buttonIcon: Icons.add_rounded,
          onButtonTap: _openCreateGroup,
        );
      case 'favorites':
        return NovynEmptyState(
          illustration: NovynEmptyIllustrations.speechBubblesStar(isDark: isDark),
          title: 'No favourite chats',
          description: 'Long-press a chat and tap the star to keep it here',
          buttonLabel: 'See all chats',
          isSecondaryButton: true,
          onButtonTap: () => _selectTab('all'),
        );
      case 'all':
      default:
        return NovynEmptyState(
          illustration: NovynEmptyIllustrations.speechBubblesDots(isDark: isDark),
          title: 'No chats yet',
          description: 'Say hi to a buddy and your first conversation will show up here',
          buttonLabel: 'Start a chat',
          buttonIcon: Icons.edit_outlined,
          onButtonTap: () {
            widget.onNavigateToPeople?.call();
          },
        );
    }
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
        showOnlineIndicator: false,
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
    final typingKey = (preview.isGroup ? preview.peerUid : preview.peer.username)
        .trim()
        .toLowerCase();
    final typingUsers = typingKey.isNotEmpty
        ? context.select<SocketService, String>(
            (service) => service.typingUsersSignature(typingKey),
          )
        : '';
    final isTyping = typingUsers.isNotEmpty;
    final typingNames = isTyping ? typingUsers.split('\u0000') : const <String>[];
    final typingPreview = !preview.isGroup
        ? 'Typing…'
        : typingNames.length == 1
            ? '${typingNames.first} is typing…'
            : typingNames.length == 2
                ? '${typingNames[0]} and ${typingNames[1]} are typing…'
                : '${typingNames.first} and ${typingNames.length - 1} others are typing…';
    final titleColor = colors.onSurface;
    final metaColor = colors.onSurfaceVariant;
    final currentUsername = context.read<SocketService>().myUsername
        ?.trim()
        .toLowerCase() ?? '';
    final showOutgoingReceipt = !isTyping &&
        !preview.isGroup &&
        preview.lastMessageId.isNotEmpty &&
        currentUsername.isNotEmpty &&
        preview.lastMessageFrom.trim().toLowerCase() == currentUsername;
    final receiptSeen = preview.lastMessageSeenAt != null;
    final receiptDelivered = preview.lastMessageDeliveredAt != null;

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
        padding: const EdgeInsets.only(left: 10, right: 16, top: 13, bottom: 13),
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
            if (!preview.isGroup)
              PresenceIndicatorBar(
                isOnline: preview.peer.isOnline,
                status: preview.peer.status,
                margin: const EdgeInsets.only(right: 10),
              )
            else
              const SizedBox(width: 13.5),
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
                  Row(
                    children: [
                      if (showOutgoingReceipt) ...[
                        Icon(
                          receiptSeen || receiptDelivered
                              ? Icons.done_all_rounded
                              : Icons.check_rounded,
                          size: 17,
                          color: receiptSeen
                              ? const Color(0xFF2998E8)
                              : metaColor,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          isTyping
                              ? typingPreview
                              : preview.lastMessage.isEmpty
                                  ? 'Tap to chat'
                                  : preview.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14.5,
                            color: isTyping
                                ? colors.primary
                                : hasUnread
                                    ? titleColor
                                    : metaColor,
                            fontWeight: isTyping || hasUnread
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
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
                  if (preview.lastMessage.trim().isNotEmpty)
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
