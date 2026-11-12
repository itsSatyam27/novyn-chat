import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_empty_state.dart';
import '../../widgets/novyn_ui.dart';
import '../../theme/novyn_theme.dart';
import '../calls/call_screen.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
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
          final peer = UserModel(
            uid:       peerUsername,
            name:      peerUsername,
            username:  peerUsername,
            email:     '',
            bio:       '',
            createdAt: DateTime.now(),
          );
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
    final missedCount = _calls.where((call) => call.status == 'missed').length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NovynHeader(
              title: 'Calls',
              subtitle: '${_calls.length} calls this week · $missedCount missed',
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'Call options',
                  icon: const Icon(Icons.more_horiz_rounded, size: 25),
                  onSelected: (value) {
                    if (value == 'privacy') _showCallPrivacy();
                    if (value == 'clear') _confirmClearHistory();
                    if (value == 'refresh') {
                      setState(() => _loading = true);
                      _loadCalls();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'privacy', child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.shield_outlined),
                      title: Text('Call privacy'),
                    )),
                    if (_calls.isNotEmpty)
                      const PopupMenuItem(value: 'clear', child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Clear history'),
                      )),
                    const PopupMenuItem(value: 'refresh', child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.refresh_rounded),
                      title: Text('Refresh'),
                    )),
                  ],
                ),
              ],
            ),
            NovynSearchField(
              hint: 'Search call history…',
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
            ),
            NovynChipRow(
              labels: const ['All', 'Missed', 'Incoming', 'Outgoing'],
              selected: const ['All', 'Missed', 'Incoming', 'Outgoing'].indexOf(_filter),
              onSelected: (index) => setState(() {
                _filter = const ['All', 'Missed', 'Incoming', 'Outgoing'][index];
              }),
            ),
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

  List<_CallEntry> _filteredCalls() {
    var result = _calls;
    switch (_filter) {
      case 'Missed':
        result = result.where((call) => call.status == 'missed').toList();
        break;
      case 'Incoming':
        result = result.where((call) => call.status == 'incoming').toList();
        break;
      case 'Outgoing':
        result = result.where((call) => call.status == 'outgoing').toList();
        break;
    }
    if (_search.isNotEmpty) {
      result = result.where((call) =>
        call.peer.name.toLowerCase().contains(_search) ||
        call.peer.username.toLowerCase().contains(_search)
      ).toList();
    }
    return result;
  }

  Widget _buildList() {
    final calls = _filteredCalls();
    final favoriteCalls = <UserModel>[];
    final favoriteSeen = <String>{};
    for (final entry in _calls) {
      final username = entry.peer.username.toLowerCase();
      if (_favoriteUsernames.contains(username) && favoriteSeen.add(username)) {
        favoriteCalls.add(entry.peer);
      }
    }
    final seenFavorites = <String>{};
    final uniqueFavorites = favoriteCalls.where((peer) => seenFavorites.add(peer.username.toLowerCase())).toList();
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _loadCalls,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
        children: [
          if (_search.isEmpty && _filter == 'All' && uniqueFavorites.isNotEmpty) ...[
            const NovynSectionLabel(
              'FAVORITES',
              icon: Icons.star_rounded,
              padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
            ),
            SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: uniqueFavorites.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final peer = uniqueFavorites[index];
                  return SizedBox(
                    width: 70,
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(peer: peer, callType: 'voice'))),
                              child: UserAvatar(name: peer.name, photoUrl: peer.photoUrl, radius: 27, showOnlineIndicator: true, isOnline: peer.isOnline, presence: peer.status),
                            ),
                            Positioned(
                              right: -4, bottom: -4,
                              child: Container(
                                width: 23, height: 23,
                                decoration: BoxDecoration(gradient: NovynGradients.selected(context), shape: BoxShape.circle, border: Border.all(color: NovynColors.bg, width: 2)),
                                child: const Icon(Icons.call_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(peer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: NovynText.body(11, color: NovynColors.textChip)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          NovynSectionLabel(
            _search.isNotEmpty || _filter != 'All' ? 'RESULTS' : 'RECENT CALLS',
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          ),
          for (final entry in calls)
            _CallCard(
              entry: entry,
              isFavorite: _favoriteUsernames.contains(entry.peer.username.toLowerCase()),
              onToggleFavorite: () => _toggleFavorite(entry.peer),
              onDismiss: () => setState(() => _calls.removeWhere((call) => call.peer.username == entry.peer.username)),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const NovynEmptyState(
      icon: Icons.call_rounded,
      title: 'No calls yet',
      description: 'Your call history will\nappear here',
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
  const _CallCard({required this.entry, required this.onDismiss, required this.isFavorite, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    final isMissed = entry.status == 'missed';
    final isIncoming = entry.status == 'incoming';
    final isVideo = entry.type == 'video';
    final statusColor = isMissed
        ? NovynColors.danger
        : isIncoming
            ? NovynColors.mint
            : const Color(0xFF79B8FF);
    final statusIcon = isMissed
        ? Icons.call_missed_rounded
        : isIncoming
            ? Icons.call_received_rounded
            : Icons.call_made_rounded;

    return Slidable(
      key: ValueKey(entry.createdAt.millisecondsSinceEpoch),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDismiss(),
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Dismiss',
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: NovynTheme.cardBg(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showHistory(context),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  UserAvatar(
                    name: entry.peer.name,
                    photoUrl: entry.peer.photoUrl,
                    radius: 27,
                    showOnlineIndicator: true,
                    isOnline: entry.peer.isOnline,
                    presence: entry.peer.status,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.peer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (entry.count > 1) ...[
                              const SizedBox(width: 5),
                              Text('(${entry.count})',
                                  style: NovynText.body(11, color: NovynColors.textMuted)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                _statusLabel(entry.type, entry.status),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NovynText.body(11.5, color: statusColor, weight: FontWeight.w500),
                              ),
                            ),
                            if (entry.duration > 0) ...[
                              Text(' · ', style: NovynText.body(11, color: NovynColors.textMuted)),
                              Text(_formatDuration(entry.duration),
                                  style: NovynText.body(11, color: NovynColors.textMuted)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatTime(entry.createdAt),
                          style: NovynText.body(10.5, color: NovynColors.timeMuted)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: isFavorite ? 'Remove favorite' : 'Add to favorites',
                            visualDensity: VisualDensity.compact,
                            onPressed: onToggleFavorite,
                            icon: Icon(isFavorite ? Icons.star_rounded : Icons.star_outline_rounded, color: isFavorite ? const Color(0xFFFFC857) : NovynColors.textMuted, size: 20),
                          ),
                          NovynIconButton(
                            icon: Icons.call_rounded,
                            primary: true,
                            size: 36,
                            radius: 12,
                            iconSize: 17,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CallScreen(peer: entry.peer, callType: 'voice'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 7),
                          NovynIconButton(
                            icon: Icons.videocam_rounded,
                            size: 36,
                            radius: 12,
                            iconSize: 17,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CallScreen(peer: entry.peer, callType: 'video'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

  String _statusLabel(String type, String status) {
    switch (status) {
      case 'missed':   return 'Missed $type call';
      case 'incoming': return 'Incoming $type call';
      case 'outgoing': return 'Outgoing $type call';
      default:         return status;
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final dtStart   = DateTime(dt.year,  dt.month,  dt.day);
    final daysDiff  = todayStart.difference(dtStart).inDays;

    if (daysDiff == 0) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final p = dt.hour < 12 ? 'AM' : 'PM';
      return '$h:$m $p';
    } else if (daysDiff == 1) {
      return 'Yesterday';
    } else if (daysDiff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}';
    }
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
                        fontWeight: FontWeight.bold,
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
                                fontWeight: FontWeight.w600,
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
