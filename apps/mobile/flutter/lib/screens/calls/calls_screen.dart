import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:novyn/services/haptic_service.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_db_service.dart';
import '../../services/socket_service.dart';
import '../../theme/novyn_theme.dart';
import '../../utils/presence_utils.dart';
import '../../utils/call_history_utils.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/novyn_page_route.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_ui.dart';
import '../../widgets/user_avatar.dart';
import '../calls/call_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> with WidgetsBindingObserver {
  static const _filters = ['All', 'Missed', 'Incoming', 'Outgoing'];

  List<_CallEntry> _calls = [];
  bool _loading = true;
  String _filter = 'All';
  String _search = '';
  String _callPrivacy = 'friends';
  Set<String> _favoriteUsernames = <String>{};
  Set<String> _readMissedCallIds = <String>{};
  // peer username (lowercase) -> millis of the newest call that was removed.
  Map<String, int> _dismissedAt = <String, int>{};
  String? _myUsername;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchOpen = false;
  int _callLoadGeneration = 0;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ApiService.callLogsRevision.removeListener(_handleCallLogsChanged);
    _callLoadGeneration++;
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiService.callLogsRevision.addListener(_handleCallLogsChanged);
    _init();
  }

  Future<void> _init() async {
    await _loadLocalPrefs();
    if (!mounted) return;
    await _loadCalls();
  }

  void _handleCallLogsChanged() {
    if (!mounted) return;
    unawaited(_loadCalls());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadCalls());
    }
  }

  // ── Local preferences (favourites + removed rows) ──────────────────────────

  String _favKey(String username) => 'novyn_call_favorites_${username.toLowerCase()}';
  String _dismissKey(String username) => 'novyn_call_dismissed_${username.toLowerCase()}';
  String _readMissedKey(String username) =>
      'novyn_missed_read_${username.toLowerCase()}';

  Future<void> _loadLocalPrefs() async {
    final username = context.read<AuthService>().user?.username;
    if (username == null) return;
    final prefs = await SharedPreferences.getInstance();
    var dismissed = <String, int>{};
    try {
      final raw = prefs.getString(_dismissKey(username));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          dismissed = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        }
      }
    } catch (error) {
      debugPrint('[NovynCalls] Could not read removed calls: $error');
    }
    if (!mounted) return;
    setState(() {
      _myUsername = username;
      _favoriteUsernames = (prefs.getStringList(_favKey(username)) ?? <String>[]).take(5).toSet();
      _readMissedCallIds = (prefs.getStringList(_readMissedKey(username)) ?? <String>[]).toSet();
      _dismissedAt = dismissed;
    });
  }

  Future<bool> _toggleFavorite(UserModel peer) async {
    final username = _myUsername ?? context.read<AuthService>().user?.username;
    if (username == null) return false;
    final next = Set<String>.from(_favoriteUsernames);
    final key = peer.username.toLowerCase();
    if (next.contains(key)) {
      next.remove(key);
    } else {
      if (next.length >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('You can add up to 5 quick call contacts only'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return false;
      }
      next.add(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey(username), next.toList());
    if (!mounted) return false;
    setState(() => _favoriteUsernames = next);
    return true;
  }

  Future<void> _saveDismissed(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissKey(username), jsonEncode(_dismissedAt));
  }

  Future<void> _markMissedCallsRead() async {
    final username = _myUsername ?? context.read<AuthService>().user?.username;
    if (username == null) return;
    final missedIds = _calls
        .expand((entry) => entry.history)
        .where((log) => log['status']?.toString().toLowerCase() == 'missed')
        .map(callLogStableId)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (missedIds.isEmpty) return;
    final next = {..._readMissedCallIds, ...missedIds};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _readMissedKey(username),
      next.toList()..sort(),
    );
    if (!mounted) return;
    setState(() => _readMissedCallIds = next);
  }


  int _logMillis(Map<String, dynamic> log) =>
      DateTime.tryParse(log['createdAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;

  /// Removes a person from the list. Only calls newer than this moment will
  /// bring them back, so a refresh no longer resurrects the row.
  Future<void> _dismissEntry(_CallEntry entry) async {
    final username = _myUsername ?? context.read<AuthService>().user?.username;
    if (username == null) return;
    final key = entry.peer.username.toLowerCase();
    final previous = _dismissedAt[key];
    final newest = entry.history.map(_logMillis).fold<int>(0, (a, b) => math.max(a, b));

    setState(() {
      _dismissedAt = {..._dismissedAt, key: newest};
      _calls = _calls.where((c) => c.peer.username.toLowerCase() != key).toList();
    });
    await _saveDismissed(username);
    if (!mounted) return;

    context.showNovynAlert(
      SnackBar(
        content: Text('Removed ${_displayName(entry.peer.name)} from calls'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final next = Map<String, int>.from(_dismissedAt);
            if (previous == null) {
              next.remove(key);
            } else {
              next[key] = previous;
            }
            if (!mounted) return;
            setState(() => _dismissedAt = next);
            await _saveDismissed(username);
            if (mounted) unawaited(_loadCalls());
          },
        ),
      ),
    );
  }

  // ── Dialogs / sheets ───────────────────────────────────────────────────────

  Future<void> _confirmClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear call history?'),
        content: const Text('This clears the call list from this device. It does not affect messages or contacts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NovynColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final username = _myUsername ?? context.read<AuthService>().user?.username;
      if (username != null) {
        try {
          await LocalDbService.clearCallLogs(username);
        } catch (error) {
          debugPrint('[NovynCalls] Could not clear local call history: $error');
        }
      }
      // Invalidate any in-flight sync so it cannot repaint the cleared list.
      _callLoadGeneration++;
      if (mounted) {
        setState(() {
          _calls = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _showCallPrivacy() async {
    final outer = context;
    var selected = _callPrivacy;
    var saving = false;
    const options = [
      ('everyone', 'Everyone', 'Anyone on Novyn can call you.', Icons.public_rounded),
      ('friends', 'Friends', 'Only accepted friends can call you.', Icons.people_alt_rounded),
      ('nobody', 'Nobody', 'Decline all incoming calls.', Icons.do_not_disturb_on_rounded),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) {
          final theme = Theme.of(context);
          final accent = theme.colorScheme.primary;

          Future<void> save() async {
            refresh(() => saving = true);
            try {
              final result = await outer.read<SocketService>().updateAccountSettings({'callPrivacy': selected});
              if (result['ok'] != true) {
                throw StateError(result['message']?.toString() ?? 'Could not update call privacy.');
              }
              if (!mounted) return;
              setState(() => _callPrivacy = selected);
              Navigator.pop(sheetContext);
              outer.showNovynAlert(const SnackBar(content: Text('Call privacy updated.')));
            } catch (error) {
              refresh(() => saving = false);
              if (mounted) {
                outer.showNovynAlert(SnackBar(
                  content: Text(error is StateError ? error.message.toString() : 'Could not update call privacy.'),
                ));
              }
            }
          }

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Who can call me?',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Control incoming calls',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13.5)),
                  const SizedBox(height: 14),
                  for (final o in options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: saving ? null : () => refresh(() => selected = o.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: selected == o.$1 ? accent.withValues(alpha: .08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected == o.$1 ? accent : theme.colorScheme.outlineVariant,
                                width: selected == o.$1 ? 2 : 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(o.$4, color: accent, size: 21),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(o.$2, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(o.$3,
                                          style: TextStyle(
                                              fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 150),
                                  opacity: selected == o.$1 ? 1 : 0,
                                  child: Icon(Icons.check_circle_rounded, color: accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: saving || selected == _callPrivacy ? null : save,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                          : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadCalls({bool showLoading = false}) async {
    final generation = ++_callLoadGeneration;
    if (showLoading && _calls.isEmpty && mounted) {
      setState(() => _loading = true);
    }

    final auth = context.read<AuthService>();
    final myUsername = auth.user?.username;
    if (myUsername == null) {
      if (mounted && generation == _callLoadGeneration) {
        setState(() => _loading = false);
      }
      return;
    }

    // Paint the last successful snapshot first (local Hive only).
    final cachedLogs = await LocalDbService.getCallLogs(myUsername);
    if (!mounted || generation != _callLoadGeneration) return;
    final cachedEntries = await _buildCallEntries(cachedLogs, myUsername, generation);
    if (!mounted || generation != _callLoadGeneration) return;
    setState(() {
      _calls = cachedEntries;
      _loading = false;
    });

    // Refresh in the background; a failed request leaves the list untouched.
    unawaited(_refreshCallHistory(myUsername, generation));
  }

  /// Pull-to-refresh: unlike [_loadCalls] this waits for the network sync, so
  /// the spinner stays until fresh data arrived.
  Future<void> _refresh() async {
    final username = _myUsername ?? context.read<AuthService>().user?.username;
    if (username == null) return;
    final generation = ++_callLoadGeneration;
    await _refreshCallHistory(username, generation);
  }

  Future<List<_CallEntry>> _buildCallEntries(
    List<Map<String, dynamic>> rawLogs,
    String myUsername,
    int generation,
  ) async {
    final entriesMap = <String, _CallEntry>{};
    final resolvedPeers = <String, UserModel>{};
    final contacts = context.read<SocketService>().contacts;

    for (final log in rawLogs) {
      final caller = log['callerId']?.toString() ?? '';
      final receiver = log['receiverId']?.toString() ?? '';
      final isOutgoing = caller.toLowerCase() == myUsername.toLowerCase();
      final peerUsername = isOutgoing ? receiver : caller;
      if (peerUsername.isEmpty) continue;
      final peerKey = peerUsername.toLowerCase();

      try {
        final parsed = DateTime.tryParse(log['createdAt']?.toString() ?? '');
        final createdAt = parsed == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : (parsed.isUtc ? parsed.toLocal() : parsed);

        // Hide rows the user removed (only newer calls bring them back).
        final cutoff = _dismissedAt[peerKey];
        if (cutoff != null && createdAt.millisecondsSinceEpoch <= cutoff) continue;

        final type = normalizeCallType(log['type']);
        final status = log['status']?.toString() ?? 'outgoing';
        final duration = (log['duration'] as num?)?.toInt() ?? 0;

        var peer = resolvedPeers[peerKey] ?? contacts.findUser(peerUsername);
        peer ??= await LocalDbService.getUser(peerUsername);
        if (!mounted || generation != _callLoadGeneration) return [];
        peer ??= UserModel(
          uid: peerUsername,
          name: peerUsername,
          username: peerUsername,
          email: '',
          bio: '',
          createdAt: createdAt,
        );
        resolvedPeers[peerKey] = peer;

        final entry = entriesMap[peerKey];
        if (entry == null) {
          entriesMap[peerKey] = _CallEntry(
            peer: peer,
            type: type,
            status: status,
            duration: duration,
            createdAt: createdAt,
            history: [log],
          );
        } else {
          final isLatest = createdAt.isAfter(entry.createdAt);
          entriesMap[peerKey] = entry.copyWith(
            type: isLatest ? type : null,
            status: isLatest ? status : null,
            duration: isLatest ? duration : null,
            createdAt: isLatest ? createdAt : null,
            history: [...entry.history, log],
          );
        }
      } catch (error) {
        debugPrint('[NovynCalls] Skipped malformed call log: $error');
      }
    }

    return entriesMap.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _refreshCallHistory(String username, int generation) async {
    final logsFuture = ApiService.getCallLogs();
    final profileFuture = ApiService.getSession();
    final rawLogs = await logsFuture;
    final profile = await profileFuture;
    if (!mounted || generation != _callLoadGeneration) return;

    if (rawLogs != null) {
      try {
        await LocalDbService.saveCallLogs(username, rawLogs);
      } catch (error) {
        debugPrint('[NovynCalls] Could not cache synced call history: $error');
      }
      if (!mounted || generation != _callLoadGeneration) return;
      // Read back the filtered snapshot so a previous local "Clear history"
      // watermark is respected by both the cache and the visible list.
      final visibleLogs = await LocalDbService.getCallLogs(username);
      final entries = await _buildCallEntries(visibleLogs, username, generation);
      if (!mounted || generation != _callLoadGeneration) return;
      setState(() {
        _calls = entries;
        _loading = false;
      });
    }

    final privacy = profile?['callPrivacy']?.toString();
    if (privacy != null &&
        ['everyone', 'friends', 'nobody'].contains(privacy) &&
        privacy != _callPrivacy &&
        mounted &&
        generation == _callLoadGeneration) {
      setState(() => _callPrivacy = privacy);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBackground = isDark ? NovynTheme.pageBg(context) : const Color(0xFFF3EFFA);
    final visible = _filteredCalls(); // computed once per build

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: SlidableAutoCloseBehavior(
          closeWhenOpened: true,
          closeWhenTapped: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            NovynHeader(
              title: 'Calls',
              titleSize: 36,
              titleWeight: FontWeight.w600,
              actions: [
                Semantics(
                  button: true,
                  label: _searchOpen ? 'Close search' : 'Search calls',
                  child: NovynIconButton(
                    icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                    size: 48,
                    radius: 16,
                    iconSize: 22,
                    onTap: _toggleSearch,
                  ),
                ),
                _buildMenu(theme),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _searchOpen
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Focus(
                        onKeyEvent: (_, event) {
                          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                            _toggleSearch();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: NovynSearchField(
                          hint: 'Search call history…',
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (!_searchOpen && _search.isEmpty && _filter == 'All') _buildQuickCall(),
            _buildFilterChips(),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: 6,
                      itemBuilder: (_, __) => NovynShimmer.callItem(),
                    )
                  : visible.isEmpty
                      ? _buildEmpty()
                      : _buildList(visible),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _search = '';
        _searchController.clear();
      }
    });
    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchOpen) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  Widget _buildMenu(ThemeData theme) {
    return PopupMenuButton<String>(
      tooltip: 'More call options',
      offset: const Offset(0, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      onSelected: (value) {
        if (value == 'privacy') _showCallPrivacy();
        if (value == 'clear') _confirmClearHistory();
        if (value == 'refresh') _refresh();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'privacy',
          height: 56,
          child: _CallMenuItem(
            icon: Icons.shield_outlined,
            title: 'Call privacy',
            subtitle: 'Manage who can call you',
          ),
        ),
        const PopupMenuItem(
          value: 'refresh',
          height: 56,
          child: _CallMenuItem(
            icon: Icons.refresh_rounded,
            title: 'Refresh',
            subtitle: 'Sync recent calls',
          ),
        ),
        if (_calls.isNotEmpty) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'clear',
            height: 56,
            child: _CallMenuItem(
              icon: Icons.delete_outline_rounded,
              title: 'Clear history',
              subtitle: 'Remove calls from this device',
              danger: true,
            ),
          ),
        ],
      ],
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.more_horiz_rounded, size: 24, color: theme.colorScheme.onSurface),
      ),
    );
  }

  // ── Quick call ─────────────────────────────────────────────────────────────

  Widget _buildQuickCall() {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final socketFriends = context.watch<SocketService>().contacts.friends;
    final byUsername = <String, UserModel>{};
    for (final entry in _calls) {
      byUsername.putIfAbsent(entry.peer.username.toLowerCase(), () => entry.peer);
    }
    for (final friend in socketFriends) {
      byUsername[friend.username.toLowerCase()] = friend;
    }
    final quickFriends = byUsername.values
        .where((peer) => _favoriteUsernames.contains(peer.username.toLowerCase()))
        .take(5)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    Widget contactSlot(UserModel peer) {
      return Semantics(
        button: true,
        label: 'Call ${_displayName(peer.name)}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(
            context,
            NovynPageRoute<void>(
              child: CallScreen(peer: peer, callType: 'voice'),
            ),
          ),
          onLongPress: () => _toggleFavorite(peer),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
                child: UserAvatar(
                  name: peer.name,
                  photoUrl: peer.photoUrl,
                  radius: 21,
                  showOnlineIndicator: false,
                ),
              ),
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  _displayName(peer.name).split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget addSlot() {
      return Semantics(
        button: true,
        label: 'Edit quick call contacts',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showQuickCallPicker,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(52, 52),
                painter: _QuickCallDashedCirclePainter(accent),
                child: Center(
                  child: Icon(Icons.add_rounded, size: 26, color: accent),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Add',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: accent, size: 19),
              const SizedBox(width: 8),
              Text(
                'Quick call',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.25,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${quickFriends.length}/5',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Edit quick call contacts',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                padding: EdgeInsets.zero,
                onPressed: _showQuickCallPicker,
                icon: Icon(Icons.edit_outlined, size: 18, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(5, (index) {
                Widget? slot;
                if (index < quickFriends.length) {
                  slot = contactSlot(quickFriends[index]);
                } else if (index == quickFriends.length &&
                    quickFriends.length < 5) {
                  slot = addSlot();
                }
                return Expanded(
                  child: slot == null
                      ? const SizedBox.shrink()
                      : Center(child: slot),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filters ────────────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final missedCount = countUnreadMissedCallLogs(
      _calls.expand((entry) => entry.history),
      _readMissedCallIds,
    );
    const icons = {
      'All': null,
      'Missed': Icons.call_missed_rounded,
      'Incoming': Icons.call_received_rounded,
      'Outgoing': Icons.call_made_rounded,
    };

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = _filters[index];
          final selected = _filter == option;
          final count = option == 'Missed' ? missedCount : 0;
          final fg = selected ? Colors.white : theme.colorScheme.onSurfaceVariant;
          return Semantics(
            button: true,
            selected: selected,
            label: option == 'Missed' && count > 0 ? 'Missed calls, $count' : '$option calls',
            child: GestureDetector(
              onTap: () {
                if (_filter == option) return;
                HapticService.vibrate(NovynHapticType.light, category: HapticCategory.calls);
                setState(() => _filter = option);
                if (option == 'Missed') unawaited(_markMissedCallsRead());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: selected
                      ? accent
                      : (isDark ? const Color(0xFF171426) : theme.colorScheme.surface),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? accent : accent.withValues(alpha: isDark ? .18 : .14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icons[option] != null) ...[
                      Icon(icons[option], size: 17, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      option,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 7),
                      Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : const Color(0xFFD92D2D),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: selected ? accent : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<_CallEntry> _filteredCalls() {
    var result = _calls;
    if (_filter != 'All') {
      final wanted = _filter.toLowerCase();
      result = result
          .map((call) {
            final matching = call.history.where((log) => log['status'] == wanted).toList();
            if (matching.isEmpty) return null;
            matching.sort((a, b) => _logMillis(b).compareTo(_logMillis(a)));
            final latest = matching.first;
            final parsedDate = DateTime.tryParse(latest['createdAt']?.toString() ?? '');
            return call.copyWith(
              type: normalizeCallType(latest['type'] ?? call.type),
              status: latest['status']?.toString() ?? call.status,
              duration: (latest['duration'] as num?)?.toInt() ?? 0,
              createdAt: parsedDate == null
                  ? call.createdAt
                  : (parsedDate.isUtc ? parsedDate.toLocal() : parsedDate),
              history: matching,
            );
          })
          .whereType<_CallEntry>()
          .toList();
    }
    if (_search.isNotEmpty) {
      result = result
          .where((call) =>
              call.peer.name.toLowerCase().contains(_search) ||
              call.peer.username.toLowerCase().contains(_search))
          .toList();
    }
    return result;
  }

  // ── Quick call picker (unchanged behaviour) ────────────────────────────────

  Future<void> _showQuickCallPicker() async {
    final friends = List<UserModel>.from(context.read<SocketService>().contacts.friends)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .72,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Quick call',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_favoriteUsernames.length}/5 selected',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _favoriteUsernames.length >= 5
                                  ? Theme.of(sheetContext).colorScheme.primary
                                  : Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text('${friends.length} friends',
                        style: TextStyle(color: Theme.of(sheetContext).colorScheme.onSurfaceVariant)),
                  ]),
                ),
                Expanded(
                  child: friends.isEmpty
                      ? const Center(child: Text('Your friends will appear here'))
                      : ListView.separated(
                          itemCount: friends.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                          itemBuilder: (context, index) {
                            final peer = friends[index];
                            final favorite = _favoriteUsernames.contains(peer.username.toLowerCase());
                            return ListTile(
                              leading: UserAvatar(name: peer.name, photoUrl: peer.photoUrl, radius: 23),
                              title: Text(_displayName(peer.name), style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('@${peer.username}'),
                              trailing: IconButton(
                                tooltip: favorite ? 'Remove from quick call' : 'Add to quick call',
                                onPressed: () async {
                                  await _toggleFavorite(peer);
                                  if (mounted) refresh(() {});
                                },
                                icon: Icon(
                                  favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: favorite
                                      ? const Color(0xFFFFB84D)
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  NovynPageRoute<void>(child: CallScreen(peer: peer, callType: 'voice')),
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
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────

  Widget _buildList(List<_CallEntry> calls) {
    final theme = Theme.of(context);
    final groups = _groupCallsByDay(calls);

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        children: [
          for (final group in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 12, 5, 10),
              child: Text(
                group.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.25,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < group.value.length; index++) ...[
                    _CallCard(
                      entry: group.value[index],
                      isFavorite: _favoriteUsernames.contains(group.value[index].peer.username.toLowerCase()),
                      onToggleFavorite: () => _toggleFavorite(group.value[index].peer),
                      onDismiss: () => _dismissEntry(group.value[index]),
                    ),
                    if (index != group.value.length - 1)
                      Divider(
                        height: 1,
                        indent: 78,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: .45),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, List<_CallEntry>> _groupCallsByDay(List<_CallEntry> calls) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final groups = <String, List<_CallEntry>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final call in calls) {
      final date = call.createdAt;
      final callDay = DateTime(date.year, date.month, date.day);
      final days = today.difference(callDay).inDays;
      final label = days == 0
          ? 'Today'
          : days == 1
              ? 'Yesterday'
              : days < 7
                  ? weekdays[date.weekday - 1]
                  : '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
      groups.putIfAbsent(label, () => <_CallEntry>[]).add(call);
    }
    return groups;
  }

  Widget _buildEmpty() {
    if (_search.isNotEmpty) {
      return NovynEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        description: 'Nothing matches\n“$_search”',
      );
    }
    switch (_filter) {
      case 'Missed':
        return const NovynEmptyState(
          icon: Icons.call_missed_rounded,
          title: 'No missed calls',
          description: 'You are all caught up',
        );
      case 'Incoming':
        return const NovynEmptyState(
          icon: Icons.call_received_rounded,
          title: 'No incoming calls',
          description: 'Calls you receive\nwill appear here',
        );
      case 'Outgoing':
        return const NovynEmptyState(
          icon: Icons.call_made_rounded,
          title: 'No outgoing calls',
          description: 'Calls you make\nwill appear here',
        );
    }
    return const NovynEmptyState(
      icon: Icons.call_rounded,
      title: 'No calls yet',
      description: 'Your call history will\nappear here',
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// "sushama pandey" -> "Sushama Pandey" (display only; data is untouched).
String _displayName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return raw;
  return trimmed
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _CallMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;

  const _CallMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? NovynColors.danger : Theme.of(context).colorScheme.primary;
    final color = danger ? NovynColors.danger : Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NovynText.body(13, color: color, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NovynText.body(10.5, color: NovynColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Call Entry Model ─────────────────────────────────────────────────────────
class _CallEntry {
  final UserModel peer;
  final String type; // 'voice' | 'video'
  final String status; // 'missed' | 'incoming' | 'outgoing'
  final int duration; // seconds
  final DateTime createdAt;
  final List<Map<String, dynamic>> history;

  int get count => history.length;

  const _CallEntry({
    required this.peer,
    required this.type,
    required this.status,
    required this.duration,
    required this.createdAt,
    this.history = const [],
  });

  _CallEntry copyWith({
    String? type,
    String? status,
    int? duration,
    DateTime? createdAt,
    List<Map<String, dynamic>>? history,
  }) {
    return _CallEntry(
      peer: peer,
      type: type ?? this.type,
      status: status ?? this.status,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      history: history ?? this.history,
    );
  }
}

String _formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final p = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $p';
}

String _formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return remaining > 0 ? '${minutes}m ${remaining}s' : '${minutes}m';
}

class _QuickCallDashedCirclePainter extends CustomPainter {
  final Color color;

  const _QuickCallDashedCirclePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final radius = size.shortestSide / 2 - stroke.strokeWidth / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );
    const dashCount = 24;
    const gapFraction = .42;
    final dashSweep = (math.pi * 2 / dashCount) * (1 - gapFraction);
    for (var index = 0; index < dashCount; index++) {
      final start = index * math.pi * 2 / dashCount;
      canvas.drawArc(rect, start, dashSweep, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _QuickCallDashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Call Card ────────────────────────────────────────────────────────────────
class _CallCard extends StatelessWidget {
  final _CallEntry entry;
  final VoidCallback onDismiss;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _CallCard({
    required this.entry,
    required this.onDismiss,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMissed = entry.status == 'missed';
    final isIncoming = entry.status == 'incoming';
    final isVideo = entry.type == 'video';
    final accent = theme.colorScheme.primary;

    // Colour-coded direction: missed red, incoming green, outgoing accent.
    final statusColor = isMissed
        ? const Color(0xFFD92D2D)
        : isIncoming
            ? const Color(0xFF15803D)
            : accent;
    final statusIcon = isMissed
        ? Icons.call_missed_rounded
        : isIncoming
            ? Icons.call_received_rounded
            : Icons.call_made_rounded;

    final name = _displayName(entry.peer.name);
    final subtitle =
        '${_formatTime(entry.createdAt)} · ${isVideo ? 'Video' : 'Voice'}${isMissed ? ' · Missed' : entry.duration > 0 ? ' · ${_formatDuration(entry.duration)}' : ''}';

    return Slidable(
      key: ValueKey('${entry.peer.username}_${entry.createdAt.millisecondsSinceEpoch}'),
      groupTag: 'calls',
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDismiss(),
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Remove',
          ),
        ],
      ),
      child: Builder(
        builder: (slidableContext) => TapRegion(
          onTapOutside: (_) => Slidable.of(slidableContext)?.close(),
          child: Semantics(
        button: true,
        label: '${isMissed ? 'Missed ' : isIncoming ? 'Incoming ' : 'Outgoing '}${isVideo ? 'video' : 'voice'} call, $name, ${_formatTime(entry.createdAt)}',
        child: Builder(
          builder: (cardContext) => InkWell(
            onTap: () {
              final slidable = Slidable.of(cardContext);
              if (slidable != null && slidable.animation.value > 0) {
                slidable.close();
                return;
              }
              _showHistory(context);
            },
            child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 14, top: 12, bottom: 12),
            child: Row(
              children: [
                PresenceIndicatorBar(
                  isOnline: entry.peer.isOnline,
                  status: entry.peer.status,
                  margin: const EdgeInsets.only(right: 10),
                ),
                GestureDetector(
                  onLongPress: onToggleFavorite,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        name: entry.peer.name,
                        photoUrl: entry.peer.photoUrl,
                        radius: 26,
                        showOnlineIndicator: false,
                        isOnline: entry.peer.isOnline,
                        presence: entry.peer.status,
                      ),
                      if (isFavorite)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                            child: const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB84D)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.3,
                                color: isMissed ? statusColor : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (entry.count > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '×${entry.count}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                height: 1.35,
                                color: isMissed ? statusColor : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: accent.withValues(alpha: .12),
                  shape: const CircleBorder(),
                  child: Semantics(
                    button: true,
                    label: '${isVideo ? 'Video' : 'Voice'} call $name',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticService.vibrate(NovynHapticType.light, category: HapticCategory.calls);
                        Navigator.push(
                          context,
                          NovynPageRoute<void>(
                            child: CallScreen(peer: entry.peer, callType: isVideo ? 'video' : 'voice'),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(
                          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                          color: accent,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
        ),
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    var favorite = isFavorite;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .62,
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => _CallHistorySheet(
          entry: entry,
          isFavorite: favorite,
          onToggleFavorite: () {
            onToggleFavorite();
            refresh(() => favorite = !favorite);
          },
          onCall: (type) {
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            NovynPageRoute<void>(child: CallScreen(peer: entry.peer, callType: type)),
          );
          },
        ),
      ),
    );
  }
}

// ── History sheet ────────────────────────────────────────────────────────────
class _CallHistorySheet extends StatelessWidget {
  final _CallEntry entry;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final void Function(String type) onCall;

  const _CallHistorySheet({
    required this.entry,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = colors.primary;
    final missedCount =
        entry.history.where((log) => log['status'] == 'missed').length;
    final outgoingCount =
        entry.history.where((log) => log['status'] == 'outgoing').length;
    final sheetHeight = MediaQuery.sizeOf(context).height * .62;

    Widget stat(String label, {bool danger = false}) {
      final color = danger ? const Color(0xFFD92D2D) : colors.onSurface;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: danger
              ? const Color(0xFFFDE7E7)
              : accent.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }

    Widget callAction({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      required bool primary,
    }) {
      final foreground = primary ? colors.onPrimary : accent;
      return Material(
        color: primary ? accent : accent.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: sheetHeight,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  UserAvatar(
                    name: entry.peer.name,
                    photoUrl: entry.peer.photoUrl,
                    radius: 32,
                    showOnlineIndicator: false,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(entry.peer.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${entry.peer.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: accent.withValues(alpha: .10),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onToggleFavorite,
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(
                          isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: accent,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  stat('${entry.count} calls'),
                  stat('$missedCount missed', danger: missedCount > 0),
                  stat('$outgoingCount outgoing'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: callAction(
                      icon: Icons.call_rounded,
                      label: 'Voice call',
                      onTap: () => onCall('voice'),
                      primary: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: callAction(
                      icon: Icons.videocam_rounded,
                      label: 'Video call',
                      onTap: () => onCall('video'),
                      primary: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'HISTORY',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: entry.history.isEmpty
                    ? Center(
                        child: Text(
                          'No call history yet',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: entry.history.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: colors.outlineVariant.withValues(alpha: .65),
                        ),
                        itemBuilder: (context, index) => _buildHistoryRow(
                          context,
                          entry.history[index],
                          accent,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryRow(
    BuildContext context,
    Map<String, dynamic> log,
    Color accent,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = (log['status'] ?? 'outgoing').toString().toLowerCase();
    final type = normalizeCallType(log['type']);
    final duration = (log['duration'] as num?)?.toInt() ?? 0;
    final parsed = DateTime.tryParse(log['createdAt']?.toString() ?? '');
    final createdAt = parsed == null
        ? DateTime.now()
        : (parsed.isUtc ? parsed.toLocal() : parsed);
    final isMissed = status == 'missed';
    final isIncoming = status == 'incoming';
    final color = isMissed
        ? const Color(0xFFD92D2D)
        : isIncoming
            ? accent
            : accent;
    final icon = isMissed
        ? Icons.call_missed_rounded
        : isIncoming
            ? Icons.call_received_rounded
            : Icons.call_made_rounded;
    final mediaLabel = type == 'video' ? 'video' : 'voice';
    final statusLabel = status.isEmpty
        ? 'Call'
        : status[0].toUpperCase() + status.substring(1);
    final label = '$statusLabel $mediaLabel call';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isMissed ? color : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFullTime(createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            duration > 0 ? _formatDuration(duration) : _formatTime(createdAt),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullTime(DateTime dt) {
    final date = '${dt.day}/${dt.month}/${dt.year}';
    return '$date · ${_formatTime(dt)}';
  }
}
