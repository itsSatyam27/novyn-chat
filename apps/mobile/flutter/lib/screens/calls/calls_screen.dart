import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../services/friend_service.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/novyn_ui.dart';
import '../../theme/novyn_theme.dart';
import '../calls/call_screen.dart';
import 'package:novyn/services/haptic_service.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<_CallEntry> _calls = [];
  bool _loading = true;
  String _filter = 'All'; // All | Missed | Incoming | Outgoing
  String _search = '';
  String _callPrivacy = 'friends';
  Set<String> _favoriteUsernames = <String>{};
  String? _myUsername;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadCalls();
  }

  Future<void> _loadFavorites() async {
    final auth = context.read<AuthService>();
    final username = auth.user?.username;
    if (username == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _myUsername = username;
      _favoriteUsernames = (prefs.getStringList('novyn_call_favorites_${username.toLowerCase()}') ?? <String>{})
          .toSet();
    });
  }

  Future<void> _toggleFavorite(UserModel peer) async {
    final username = _myUsername ?? context.read<AuthService>().user?.username;
    if (username == null) return;
    final next = Set<String>.from(_favoriteUsernames);
    final key = peer.username.toLowerCase();
    if (!next.add(key)) next.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('novyn_call_favorites_${username.toLowerCase()}', next.toList());
    if (!mounted) return;
    setState(() => _favoriteUsernames = next);
  }

  Future<void> _confirmClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear call history?'),
        content: const Text('This clears the call list from this device. It does not affect messages or contacts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) setState(() => _calls = []);
  }

  Future<void> _showCallPrivacy() async {
    var selected = _callPrivacy;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Who can call me?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in const [
                ('everyone', 'Everyone', 'Anyone on Novyn can call you.'),
                ('friends', 'Friends', 'Only accepted friends can call you.'),
                ('nobody', 'Nobody', 'Decline all incoming calls.'),
              ])
                RadioListTile<String>(
                  value: option.$1,
                  groupValue: selected,
                  onChanged: (value) => refresh(() => selected = value!),
                  title: Text(option.$2),
                  subtitle: Text(option.$3),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  final result = await context.read<SocketService>().updateAccountSettings({'callPrivacy': selected});
                  if (result['ok'] != true) throw StateError(result['message']?.toString() ?? 'Could not update call privacy.');
                  if (!mounted) return;
                  setState(() => _callPrivacy = selected);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Call privacy updated.')));
                } catch (error) {
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(error is StateError ? error.message.toString() : 'Could not update call privacy.')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCalls() async {
    final auth = context.read<AuthService>();
    final myUsername = auth.user?.username;
    if (myUsername == null) {
      setState(() => _loading = false);
      return;
    }

    final results = await Future.wait([ApiService.getCallLogs(), ApiService.getSession()]);
    final rawLogs = results[0] as List<Map<String, dynamic>>;
    final profile = results[1] as Map<String, dynamic>?;
    if (!mounted) return;

    final entriesMap = <String, _CallEntry>{};
    final resolvedPeers = <String, UserModel>{};

    for (final log in rawLogs) {
      final isOutgoing = log['callerId'] == myUsername;
      final peerUsername = isOutgoing
          ? log['receiverId'] as String? ?? ''
          : log['callerId'] as String? ?? '';
      if (peerUsername.isEmpty) continue;

      try {
        final createdAt = () {
          final raw = log['createdAt']?.toString() ?? '';
          final parsed = DateTime.tryParse(raw);
          if (parsed == null) return DateTime.now();
          return parsed.isUtc ? parsed.toLocal() : parsed;
        }();

        final type   = log['type']   as String? ?? 'voice';
        final status = log['status'] as String? ?? 'outgoing';
        final duration = (log['duration'] as num?)?.toInt() ?? 0;

        var entry = entriesMap[peerUsername];
        if (entry == null) {
          // Build a minimal UserModel from the log data (no Firestore needed)
          final peerKey = peerUsername.toLowerCase();
          var peer = resolvedPeers[peerKey] ?? context.read<SocketService>().contacts.findUser(peerUsername);
          peer ??= await context.read<FriendService>().getUser(peerUsername);
          peer ??= UserModel(
            uid: peerUsername,
            name: peerUsername,
            username: peerUsername,
            email: '',
            bio: '',
            createdAt: DateTime.now(),
          );
          resolvedPeers[peerKey] = peer;
          entriesMap[peerUsername] = _CallEntry(
            peer:      peer,
            type:      type,
            status:    status,
            duration:  duration,
            createdAt: createdAt,
            history:   [log],
          );
        } else {
          if (createdAt.isAfter(entry.createdAt)) {
            entriesMap[peerUsername] = entry.copyWith(
              type:      type,
              status:    status,
              duration:  duration,
              createdAt: createdAt,
              history:   [...entry.history, log],
            );
          } else {
            entriesMap[peerUsername] =
                entry.copyWith(history: [...entry.history, log]);
          }
        }
      } catch (_) {}
    }

    final entries = entriesMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _calls   = entries;
      _callPrivacy = ['everyone', 'friends', 'nobody'].contains(profile?['callPrivacy']) ? profile!['callPrivacy'].toString() : _callPrivacy;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDark ? NovynTheme.pageBg(context) : const Color(0xFFF3EFFA);

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NovynHeader(
              title: 'Calls',
              titleSize: 36,
              titleWeight: FontWeight.w600,
              actions: [
                NovynIconButton(
                  icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  size: 48,
                  radius: 16,
                  iconSize: 22,
                  onTap: () {
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
                  },
                ),
                PopupMenuButton<String>(
                  tooltip: 'Call options',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.grid_view_rounded,
                      size: 21, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  offset: const Offset(0, 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 10,
                  onSelected: (value) {
                    if (value == 'privacy') _showCallPrivacy();
                    if (value == 'clear') _confirmClearHistory();
                    if (value == 'incoming' || value == 'outgoing') {
                      setState(() => _filter = value == 'incoming' ? 'Incoming' : 'Outgoing');
                    }
                    if (value == 'refresh') {
                      setState(() => _loading = true);
                      _loadCalls();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'incoming', child: Text('Incoming calls')),
                    const PopupMenuItem(value: 'outgoing', child: Text('Outgoing calls')),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'privacy',
                      height: 52,
                      child: _CallMenuItem(
                        icon: Icons.shield_outlined,
                        title: 'Call privacy',
                        subtitle: 'Manage who can call you',
                      ),
                    ),
                    if (_calls.isNotEmpty)
                      PopupMenuItem(
                        value: 'clear',
                        height: 52,
                        child: _CallMenuItem(
                          icon: Icons.delete_outline_rounded,
                          title: 'Clear history',
                          subtitle: 'Remove calls from this device',
                          danger: true,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'refresh',
                      height: 52,
                      child: _CallMenuItem(
                        icon: Icons.refresh_rounded,
                        title: 'Refresh',
                        subtitle: 'Sync recent calls',
                      ),
                    ),
                  ],
                ),
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
                            setState(() {
                              _searchOpen = false;
                              _search = '';
                              _searchController.clear();
                            });
                            _searchFocusNode.unfocus();
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
            _buildFilterCards(),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: 6,
                      itemBuilder: (_, __) => NovynShimmer.callItem(),
                    )
                  : _filteredCalls().isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCall() {
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
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK CALL',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.25,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 82,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final peer in quickFriends)
                  SizedBox(
                    width: 68,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallScreen(peer: peer, callType: 'voice'),
                        ),
                      ),
                      onLongPress: () => _toggleFavorite(peer),
                      child: Column(
                        children: [
                          UserAvatar(name: peer.name, photoUrl: peer.photoUrl, radius: 24),
                          const SizedBox(height: 6),
                          Text(
                            peer.name.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(
                  width: 68,
                  child: GestureDetector(
                    onTap: _showQuickCallPicker,
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: .48),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(Icons.add_rounded, size: 25,
                            color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 6),
                        Text('Add', style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCards() {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            for (final option in const ['All', 'Missed'])
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _filter = option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _filter == option
                          ? theme.colorScheme.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _filter == option
                            ? accent
                            : theme.colorScheme.onSurfaceVariant,
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

  List<_CallEntry> _filteredCalls() {
    var result = _calls;
    if (_filter != 'All') {
      result = result.map((call) {
        final matching = call.history
            .where((log) => log['status'] == _filter.toLowerCase())
            .toList();
        if (matching.isEmpty) return null;
        matching.sort((a, b) {
          final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        final latest = matching.first;
        final rawDate = latest['createdAt']?.toString() ?? '';
        final parsedDate = DateTime.tryParse(rawDate);
        return call.copyWith(
          type: latest['type']?.toString() ?? call.type,
          status: latest['status']?.toString() ?? call.status,
          duration: (latest['duration'] as num?)?.toInt() ?? 0,
          createdAt: parsedDate == null ? call.createdAt : (parsedDate.isUtc ? parsedDate.toLocal() : parsedDate),
          history: matching,
        );
      }).whereType<_CallEntry>().toList();
    }
    if (_search.isNotEmpty) {
      result = result.where((call) =>
        call.peer.name.toLowerCase().contains(_search) ||
        call.peer.username.toLowerCase().contains(_search)
      ).toList();
    }
    return result;
  }

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
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .72,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 38, height: 4, decoration: BoxDecoration(
                color: Theme.of(sheetContext).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(5),
              )),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(children: [
                  Expanded(child: Text('Add quick call',
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
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
                            title: Text(peer.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text('@${peer.username}'),
                            trailing: IconButton(
                              tooltip: favorite ? 'Remove from quick call' : 'Add to quick call',
                              onPressed: () => _toggleFavorite(peer),
                              icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: favorite ? const Color(0xFFFFB84D) : Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => CallScreen(peer: peer, callType: 'voice'),
                              ));
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

  Widget _buildList() {
    final calls = _filteredCalls();
    final groups = _groupCallsByDay(calls);

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _loadCalls,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          if (_search.isNotEmpty || _filter != 'All')
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Text('RESULTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                letterSpacing: 1.2, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          for (final group in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 12, 5, 10),
              child: Text(group.key.toUpperCase(), style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.25,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < group.value.length; index++) ...[
                    _CallCard(
                      entry: group.value[index],
                      isFavorite: _favoriteUsernames.contains(group.value[index].peer.username.toLowerCase()),
                      onToggleFavorite: () => _toggleFavorite(group.value[index].peer),
                      onDismiss: () => setState(() => _calls.removeWhere((call) =>
                        call.peer.username == group.value[index].peer.username)),
                    ),
                    if (index != group.value.length - 1)
                      Divider(height: 1, indent: 78, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45)),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Map<String, List<_CallEntry>> _groupCallsByDay(List<_CallEntry> calls) {
    final groups = <String, List<_CallEntry>>{};
    final now = DateTime.now();
    for (final call in calls) {
      final date = call.createdAt;
      final today = DateTime(now.year, now.month, now.day);
      final callDay = DateTime(date.year, date.month, date.day);
      final days = today.difference(callDay).inDays;
      final label = days == 0 ? 'Today' : days == 1 ? 'Yesterday' : days < 7 ? const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][date.weekday - 1] : date.day.toString().padLeft(2, '0') + ' ' + const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1] + ' ' + date.year.toString();
      groups.putIfAbsent(label, () => <_CallEntry>[]).add(call);
    }
    return groups;
  }

  Widget _buildEmpty() {
    return const NovynEmptyState(
      icon: Icons.call_rounded,
      title: 'No calls yet',
      description: 'Your call history will\nappear here',
    );
  }
}

class _CallSummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;
  const _CallSummaryTile({required this.icon, required this.label, required this.value, required this.tint, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final outline = selected ? tint.withValues(alpha: 0.75) : Theme.of(context).colorScheme.outlineVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? tint.withValues(alpha: 0.10) : NovynTheme.cardBg(context),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: outline, width: selected ? 1.4 : 1),
          ),
          child: Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: tint.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: tint, size: 17)),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.05)),
              const SizedBox(height: 3),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: NovynText.body(10, color: NovynColors.textMuted)),
            ])),
            if (selected) Icon(Icons.check_circle_rounded, color: tint, size: 15),
          ]),
        ),
      ),
    );
  }
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
    final color = danger ? NovynColors.danger : Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: (danger ? NovynColors.danger : Theme.of(context).colorScheme.primary).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: danger ? NovynColors.danger : Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NovynText.body(12.5, color: color, weight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: NovynText.body(10, color: NovynColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Call Entry Model ───────────────────────────────────────────────────────
class _CallEntry {
  final UserModel peer;
  final String type;    // 'voice' | 'video'
  final String status;  // 'missed' | 'incoming' | 'outgoing'
  final int duration;   // seconds
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

// ── Call Card ──────────────────────────────────────────────────────────────
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
    final isMissed = entry.status == 'missed';
    final isVideo = entry.type == 'video';
    final statusColor = isMissed
        ? const Color(0xFFD92D2D)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final statusIcon = isMissed
        ? Icons.call_missed_rounded
        : entry.status == 'incoming'
            ? Icons.call_received_rounded
            : Icons.call_made_rounded;
    final callColor = Theme.of(context).colorScheme.primary;

    return Slidable(
      key: ValueKey('${entry.peer.username}_${entry.createdAt.millisecondsSinceEpoch}'),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDismiss(),
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Dismiss',
            borderRadius: BorderRadius.circular(14),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showHistory(context),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              GestureDetector(
                onLongPress: onToggleFavorite,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      name: entry.peer.name,
                      photoUrl: entry.peer.photoUrl,
                      radius: 24,
                      showOnlineIndicator: true,
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
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
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
                    Text(
                      entry.peer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.3,
                        color: isMissed ? statusColor : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(statusIcon, size: 17, color: statusColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_formatTime(entry.createdAt)} · ${isVideo ? 'Video' : 'Voice'}${isMissed ? ' · Missed' : entry.duration > 0 ? ' · ${_formatDuration(entry.duration)}' : ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13.5,
                              height: 1.35,
                              color: isMissed ? statusColor : Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: callColor.withValues(alpha: .12),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticService.vibrate(NovynHapticType.light, category: HapticCategory.calls);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(peer: entry.peer, callType: isVideo ? 'video' : 'voice'),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      color: callColor,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CallHistorySheet(entry: entry),
    );
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
}

class _CallHistorySheet extends StatelessWidget {
  final _CallEntry entry;
  const _CallHistorySheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              UserAvatar(
                name: entry.peer.name,
                photoUrl: entry.peer.photoUrl,
                radius: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.peer.name,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Call History',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: entry.history.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
              itemBuilder: (context, index) {
                final log = entry.history[index];
                final type = log['type'] ?? 'voice';
                final status = log['status'] ?? 'outgoing';
                final duration = (log['duration'] as num?)?.toInt() ?? 0;
                final createdAt = () {
                  final raw = log['createdAt']?.toString() ?? '';
                  final parsed = DateTime.tryParse(raw);
                  if (parsed == null) return DateTime.now();
                  return parsed.isUtc ? parsed.toLocal() : parsed;
                }();

                final isMissed = status == 'missed';
                final isIncoming = status == 'incoming';
                final color = isMissed ? const Color(0xFFEF4444) : isIncoming ? const Color(0xFF10B981) : const Color(0xFF0EA5E9);
                final icon = isMissed ? Icons.call_missed_rounded : isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status[0].toUpperCase() + status.substring(1) + ' ' + type + ' call',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _formatFullTime(createdAt),
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (duration > 0)
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatFullTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour < 12 ? 'AM' : 'PM';
    final date = '${dt.day}/${dt.month}/${dt.year}';
    return '$date · $h:$m $p';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }
}
