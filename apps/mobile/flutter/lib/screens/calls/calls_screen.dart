import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../services/hybrid_db_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/novyn_shimmer.dart';
import '../../widgets/novyn_empty_state.dart';
import '../calls/call_screen.dart';
import '../chats/chat_detail_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<_CallEntry> _calls = [];
  bool _loading = true;
  String _filter = 'All'; // 'All' | 'Missed' | 'Video'

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    final auth = context.read<AuthService>();
    final myUsername = auth.user?.username;
    if (myUsername == null) {
      setState(() => _loading = false);
      return;
    }

    final rawLogs = await ApiService.getCallLogs();
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
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calls',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      setState(() => _loading = true);
                      _loadCalls();
                    },
                  ),
                ],
              ),
            ),
            // ── Filter chips ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: ['All', 'Missed', 'Video'].map((label) {
                  final selected = _filter == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: _loading
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: 8,
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
    switch (_filter) {
      case 'Missed':
        return _calls.where((c) => c.status == 'missed').toList();
      case 'Video':
        return _calls.where((c) => c.type == 'video').toList();
      default:
        return _calls;
    }
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: _filteredCalls().length,
      itemBuilder: (context, i) => _CallCard(entry: _filteredCalls()[i]),
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
  const _CallCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isMissed = entry.status == 'missed';
    final isIncoming = entry.status == 'incoming';
    final isVideo = entry.type == 'video';

    final statusColor = isMissed
        ? const Color(0xFFEF4444)
        : isIncoming
            ? const Color(0xFF10B981)
            : const Color(0xFF0EA5E9);

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
            onPressed: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete feature coming soon')),
              );
            },
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Delete',
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showHistory(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              UserAvatar(
                name: entry.peer.name,
                photoUrl: entry.peer.photoUrl,
                radius: 27,
                showOnlineIndicator: true,
                isOnline: entry.peer.isOnline,
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.peer.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (entry.count > 1) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${entry.count})',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel(entry.type, entry.status),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (entry.duration > 0) ...[
                          const Text(
                            ' · ',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          Text(
                            _formatDuration(entry.duration),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Right side: time + call back button
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(entry.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallScreen(
                            peer:     entry.peer,
                            callType: entry.type,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isVideo
                            ? const Color(0xFF7C6FF7).withValues(alpha: 0.1)
                            : const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        size: 18,
                        color: isVideo
                            ? const Color(0xFF7C6FF7)
                            : const Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                ],
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
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Call History',
                      style: TextStyle(
                        fontFamily: 'Inter',
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
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _formatFullTime(createdAt),
                              style: TextStyle(
                                fontFamily: 'Inter',
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
                            fontFamily: 'Inter',
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
