import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/socket_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/novyn_toast.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String fallbackName;
  final VoidCallback? onSharedMedia;
  final VoidCallback? onWallpaper;
  final VoidCallback? onLeft;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.fallbackName,
    this.onSharedMedia,
    this.onWallpaper,
    this.onLeft,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  Map<String, dynamic>? _group;
  bool _loading = true;
  bool _busy = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _currentGroup(SocketService socket) {
    final live = socket.latestGroupInfo;
    if (live != null && live['id']?.toString() == widget.groupId) return live;
    return _group ?? <String, dynamic>{};
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final group = await context.read<SocketService>().getGroupInfo(widget.groupId);
      if (mounted) setState(() => _group = group);
    } catch (error) {
      if (mounted) _showMessage(error is StateError ? error.message : 'Could not load group information.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(Object message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toString()), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _runGroupAction(
    Future<Map<String, dynamic>> Function() action, {
    String successMessage = 'Group updated',
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      if (result['ok'] != true) {
        _showMessage(result['message']?.toString() ?? 'Could not update this group.');
        return;
      }
      final updated = result['group'];
      if (updated is Map) {
        setState(() => _group = Map<String, dynamic>.from(updated));
      } else {
        await _load();
      }
      if (mounted) NovynToast.show(context, successMessage);
    } catch (error) {
      if (mounted) _showMessage(error is StateError ? error.message : 'Group update failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMembers(SocketService socket, List<Map<String, dynamic>> members) async {
    final existing = members.map((m) => (m['username'] ?? '').toString().toLowerCase()).toSet();
    final friends = socket.contacts.friends
        .where((user) => !existing.contains(user.username.toLowerCase()))
        .toList();
    if (friends.isEmpty) {
      _showMessage('No eligible friends to add right now.');
      return;
    }

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final picked = <String>{};
        var query = '';
        return StatefulBuilder(
          builder: (context, refresh) {
            final filtered = friends.where((user) =>
              user.name.toLowerCase().contains(query) ||
              user.username.toLowerCase().contains(query)).toList();
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * .78,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 38, height: 4, decoration: BoxDecoration(color: scheme.onSurfaceVariant.withValues(alpha: .35), borderRadius: BorderRadius.circular(8))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Add members', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('Select friends to invite to this group', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ])),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        onChanged: (value) => refresh(() => query = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search friends',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                        ? Center(child: Text('No matching friends', style: TextStyle(color: scheme.onSurfaceVariant)))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: scheme.outlineVariant.withValues(alpha: .45)),
                            itemBuilder: (_, index) {
                              final user = filtered[index];
                              final checked = picked.contains(user.username);
                              return ListTile(
                                onTap: () => refresh(() => checked ? picked.remove(user.username) : picked.add(user.username)),
                                leading: UserAvatar(name: user.name, photoUrl: user.photoUrl, radius: 21),
                                title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('@${user.username}'),
                                trailing: Checkbox(value: checked, onChanged: (_) => refresh(() => checked ? picked.remove(user.username) : picked.add(user.username))),
                              );
                            },
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: picked.isEmpty ? null : () => Navigator.pop(context, picked.toList()),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(picked.isEmpty ? 'Select friends' : 'Add ${picked.length} member${picked.length == 1 ? '' : 's'}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await _runGroupAction(
      () => socket.addGroupMembers(widget.groupId, selected),
      successMessage: 'Members added',
    );
  }

  Future<void> _leaveGroup(SocketService socket) async {
    final confirmed = await _confirm(
      title: 'Leave this group?',
      message: 'You will stop receiving messages from this group. If you are the owner, ownership will pass to another member.',
      action: 'Leave group',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await socket.leaveGroup(widget.groupId);
      if (result['ok'] != true) {
        _showMessage(result['message']?.toString() ?? 'Could not leave this group.');
        return;
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onLeft?.call();
    } catch (error) {
      if (mounted) _showMessage(error is StateError ? error.message : 'Could not leave this group.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _memberAction(
    SocketService socket,
    Map<String, dynamic> member,
    String action,
  ) async {
    final username = member['username']?.toString() ?? '';
    final isAdmin = member['isAdmin'] == true || member['role'] == 'admin';
    if (action == 'remove') {
      final confirmed = await _confirm(
        title: 'Remove @$username?',
        message: 'This person will no longer be able to access this group.',
        action: 'Remove member',
      );
      if (!confirmed || !mounted) return;
      await _runGroupAction(
        () => socket.removeGroupMember(widget.groupId, username),
        successMessage: 'Member removed',
      );
    } else {
      final nextRole = isAdmin ? 'member' : 'admin';
      await _runGroupAction(
        () => socket.setGroupMemberRole(widget.groupId, username, role: nextRole),
        successMessage: nextRole == 'admin' ? 'Admin role granted' : 'Admin role removed',
      );
    }
  }

  String _dateLabel(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Date unavailable';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final group = _currentGroup(socket);
    final scheme = Theme.of(context).colorScheme;
    final members = (group['members'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final me = group['me'] is Map
        ? Map<String, dynamic>.from(group['me'] as Map)
        : <String, dynamic>{};
    final isOwner = me['isOwner'] == true || me['role'] == 'owner';
    final isAdmin = me['isAdmin'] == true || isOwner;
    final name = group['name']?.toString().trim().isNotEmpty == true
        ? group['name'].toString()
        : widget.fallbackName;
    final owner = group['owner']?.toString().trim() ?? '';
    final filtered = members.where((member) {
      final username = member['username']?.toString() ?? '';
      final display = member['displayName']?.toString() ?? '';
      return username.toLowerCase().contains(_search) ||
          display.toLowerCase().contains(_search);
    }).toList();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group info',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              '${members.length} members',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copy group ID',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.groupId));
              if (context.mounted) NovynToast.show(context, 'Group ID copied');
            },
            icon: const Icon(Icons.copy_rounded),
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (value) {
              if (value == 'leave') _leaveGroup(socket);
              if (value == 'refresh') _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh_rounded),
                  title: Text('Refresh info'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Leave group'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading && group.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // Profile-style group cover, matching Contact Info.
                  Container(
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: .65),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: .08),
                          blurRadius: 26,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 150,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 94,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFE9E3FA),
                                        Color.lerp(
                                          scheme.primaryContainer,
                                          const Color(0xFFF2EEFC),
                                          .35,
                                        )!,
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(27),
                                    ),
                                  ),
                                  child: CustomPaint(
                                    painter: _GroupCoverRingsPainter(
                                      color: scheme.primary.withValues(alpha: .12),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 43,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: scheme.surfaceContainerLow,
                                      border: Border.all(
                                        color: scheme.outlineVariant,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: scheme.shadow.withValues(alpha: .16),
                                          blurRadius: 18,
                                          offset: const Offset(0, 7),
                                        ),
                                      ],
                                    ),
                                    child: Hero(
                                      tag: 'group_avatar_${widget.groupId}',
                                      child: UserAvatar(
                                        name: name,
                                        photoUrl: group['avatarId']?.toString() ?? '',
                                        radius: 48,
                                        showOnlineIndicator: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 23,
                            letterSpacing: -.45,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: widget.groupId),
                            );
                            if (context.mounted) {
                              NovynToast.show(context, 'Group ID copied');
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: .72),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: scheme.outlineVariant.withValues(alpha: .55),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tag_rounded,
                                  size: 15,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 190),
                                  child: Text(
                                    widget.groupId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      color: scheme.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          alignment: WrapAlignment.center,
                          children: [
                            _MetaPill(
                              icon: Icons.groups_rounded,
                              label: '${members.length} members',
                            ),
                            _MetaPill(
                              icon: Icons.calendar_today_rounded,
                              label: 'Created ${_dateLabel(group['createdAt'])}',
                            ),
                            if (owner.isNotEmpty)
                              _MetaPill(
                                icon: Icons.workspace_premium_rounded,
                                label: 'Owner @$owner',
                              ),
                            if (isOwner)
                              const _MetaPill(
                                icon: Icons.verified_user_rounded,
                                label: 'You are owner',
                              )
                            else if (isAdmin)
                              const _MetaPill(
                                icon: Icons.shield_rounded,
                                label: 'You are admin',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Group-specific details presented in the same card style
                  // as the About section on Contact Info.
                  const _GroupSectionTitle(title: 'ABOUT GROUP'),
                  _GroupInfoCard(
                    child: Column(
                      children: [
                        _GroupDetailRow(
                          icon: Icons.workspace_premium_outlined,
                          label: 'Created by',
                          value: owner.isEmpty ? 'Not available' : '@$owner',
                        ),
                        Divider(
                          height: 18,
                          color: scheme.outlineVariant.withValues(alpha: .5),
                        ),
                        _GroupDetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Created on',
                          value: _dateLabel(group['createdAt']),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Existing shortcuts retain their original callbacks.
                  if (widget.onSharedMedia != null || widget.onWallpaper != null) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final tileWidth = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (widget.onSharedMedia != null)
                              SizedBox(
                                width: tileWidth,
                                child: _GroupFeatureTile(
                                  icon: Icons.image_outlined,
                                  title: 'Shared media',
                                  subtitle: 'Photos, videos and files',
                                  tint: const Color(0xFFE4F1FC),
                                  accent: const Color(0xFF347DBB),
                                  onTap: widget.onSharedMedia!,
                                ),
                              ),
                            if (widget.onWallpaper != null)
                              SizedBox(
                                width: tileWidth,
                                child: _GroupFeatureTile(
                                  icon: Icons.palette_outlined,
                                  title: 'Chat wallpaper',
                                  subtitle: 'Personalise this chat',
                                  tint: const Color(0xFFFCE8F1),
                                  accent: const Color(0xFFC92B72),
                                  onTap: widget.onWallpaper!,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Group members retain search and admin controls.
                  Row(
                    children: [
                      const Expanded(
                        child: _GroupSectionHeading(title: 'MEMBERS'),
                      ),
                      Text(
                        '${members.length} people',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => _addMembers(socket, members),
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 17,
                          ),
                          label: const Text('Add'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (value) => setState(
                      () => _search = value.trim().toLowerCase(),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Find a member',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: .65),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: .65),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.primary,
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: .7),
                      ),
                    ),
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                members.isEmpty
                                    ? 'No group members found.'
                                    : 'No members match your search.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (var index = 0; index < filtered.length; index++) ...[
                                if (index > 0)
                                  Divider(
                                    height: 1,
                                    indent: 72,
                                    color: scheme.outlineVariant.withValues(alpha: .5),
                                  ),
                                _GroupMemberTile(
                                  member: filtered[index],
                                  isMe: (filtered[index]['username']
                                              ?.toString()
                                              .toLowerCase() ??
                                          '') ==
                                      (socket.myUsername ?? '').toLowerCase(),
                                  canManage: isAdmin &&
                                      (filtered[index]['isOwner'] != true) &&
                                      (filtered[index]['username']
                                              ?.toString()
                                              .toLowerCase() !=
                                          (socket.myUsername ?? '').toLowerCase()),
                                  canChangeRole: isOwner &&
                                      (filtered[index]['isOwner'] != true) &&
                                      (filtered[index]['username']
                                              ?.toString()
                                              .toLowerCase() !=
                                          (socket.myUsername ?? '').toLowerCase()),
                                  onAction: (action) => _memberAction(
                                    socket,
                                    filtered[index],
                                    action,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 28),

                  // Same red danger-zone treatment as Contact Info.
                  const _GroupSectionHeading(
                    title: 'DANGER ZONE',
                    danger: true,
                  ),
                  _GroupDangerCard(
                    child: _GroupDangerTile(
                      icon: Icons.logout_rounded,
                      title: 'Leave group',
                      subtitle: 'You will no longer receive group messages',
                      onTap: _busy ? null : () => _leaveGroup(socket),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ],
              ),
            ),
    );
  }
}

class _GroupMemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool isMe;
  final bool canManage;
  final bool canChangeRole;
  final ValueChanged<String> onAction;

  const _GroupMemberTile({
    required this.member,
    required this.isMe,
    required this.canManage,
    required this.canChangeRole,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final username = member['username']?.toString() ?? '';
    final displayName = member['displayName']?.toString().trim() ?? '';
    final name = displayName.isEmpty ? username : displayName;
    final role = member['role']?.toString() ?? 'member';
    final online = member['online'] == true;
    final presence = member['presence']?.toString() ?? (online ? 'online' : 'offline');
    final canShowMenu = canManage || canChangeRole;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      leading: Stack(
        children: [
          UserAvatar(name: name, photoUrl: member['avatarId']?.toString() ?? '', radius: 22),
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: 11, height: 11,
              decoration: BoxDecoration(
                color: online ? const Color(0xFF10B981) : scheme.outline,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surfaceContainerLow, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Row(children: [
        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        if (isMe) ...[const SizedBox(width: 6), Text('(you)', style: TextStyle(fontSize: 10, color: scheme.primary, fontWeight: FontWeight.w700))],
      ]),
      subtitle: Text('@$username · ${online ? 'Online' : presence == 'offline' ? 'Offline' : presence}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (role == 'owner' || role == 'admin')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .11), borderRadius: BorderRadius.circular(20)),
            child: Text(role.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .4, color: scheme.primary)),
          ),
        if (canShowMenu)
          PopupMenuButton<String>(
            tooltip: 'Member actions',
            onSelected: onAction,
            itemBuilder: (_) => [
              if (canChangeRole)
                PopupMenuItem(value: role == 'admin' ? 'demote' : 'promote', child: ListTile(
                  dense: true,
                  leading: Icon(role == 'admin' ? Icons.shield_outlined : Icons.shield_rounded),
                  title: Text(role == 'admin' ? 'Remove admin' : 'Make admin'),
                )),
              if (canManage && (role != 'admin' || canChangeRole))
                const PopupMenuItem(value: 'remove', child: ListTile(dense: true, leading: Icon(Icons.person_remove_alt_1_rounded), title: Text('Remove member'))),
            ],
          ),
      ]),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: scheme.primary),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _GroupFeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  const _GroupFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 126),
          padding: const EdgeInsets.fromLTRB(7, 14, 7, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: accent, size: 27),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.25,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
}

class _GroupSectionTitle extends StatelessWidget {
  final String title;
  const _GroupSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            letterSpacing: 1.15,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _GroupInfoCard extends StatelessWidget {
  final Widget child;
  const _GroupInfoCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7),
          ),
        ),
        child: child,
      );
}

class _GroupDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _GroupDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupSectionHeading extends StatelessWidget {
  final String title;
  final bool danger;
  const _GroupSectionHeading({
    required this.title,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            letterSpacing: 1.15,
            fontWeight: FontWeight.w900,
            color: danger
                ? const Color(0xFFC52D25)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

class _GroupDangerCard extends StatelessWidget {
  final Widget child;
  const _GroupDangerCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.error.withValues(alpha: .28),
        ),
      ),
      child: child,
    );
  }
}

class _GroupDangerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _GroupDangerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE8E8),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: const Color(0xFFC52D25), size: 25),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.error,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCoverRingsPainter extends CustomPainter {
  const _GroupCoverRingsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final maxRadius = size.width * .56;
    for (var index = 1; index <= 5; index++) {
      canvas.drawCircle(center, maxRadius * index / 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GroupCoverRingsPainter oldDelegate) =>
      oldDelegate.color != color;
}
