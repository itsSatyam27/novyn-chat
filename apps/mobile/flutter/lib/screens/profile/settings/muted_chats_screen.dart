import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/haptic_service.dart';

import '../../../services/friend_service.dart';
import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';
import '../../../widgets/novyn_alert.dart';
import '../../../widgets/novyn_toast.dart';

class MutedChatsScreen extends StatefulWidget {
  const MutedChatsScreen({super.key});

  static Future<int> countMutedChats(SocketService socket) async {
    try {
      final result = await socket.fetchAccountSettings();
      final settings = result['settings'];
      final values = settings is Map ? settings['mutedChats'] : null;
      return values is List ? values.length : 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  State<MutedChatsScreen> createState() => _MutedChatsScreenState();
}

class _MutedChatEntry {
  const _MutedChatEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isGroup,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isGroup;
}

class _MutedChatsScreenState extends State<MutedChatsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<_MutedChatEntry> _mutedChats = <_MutedChatEntry>[];

  String _storageKey(String id) => 'novyn_mute_${id.trim().toLowerCase()}';

  Future<void> initLoad() async {
    if (mounted) setState(() => _loading = true);
    final socket = context.read<SocketService>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    try {
      final remote = await socket.fetchAccountSettings();
      final remoteSettings = remote['settings'] is Map
          ? Map<String, dynamic>.from(remote['settings'] as Map)
          : <String, dynamic>{};
      final values = remoteSettings['mutedChats'];
      if (remote['ok'] == true && values is List) {
        final ids = values
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        final entries = await Future.wait(ids.map((id) async {
          final isGroup = id.startsWith('grp_');
          if (isGroup) {
            try {
              final group = await socket.getGroupInfo(id);
              final name = group['name']?.toString().trim();
              return _MutedChatEntry(
                id: id,
                title: name?.isNotEmpty == true ? name! : 'Group chat',
                subtitle: 'Group conversation',
                isGroup: true,
              );
            } catch (_) {
              return _MutedChatEntry(
                id: id,
                title: 'Group chat',
                subtitle: id,
                isGroup: true,
              );
            }
          }

          try {
            final peer = await context.read<FriendService>().getUser(id);
            return _MutedChatEntry(
              id: id,
              title: peer?.name.trim().isNotEmpty == true ? peer!.name.trim() : id,
              subtitle: '@$id',
              isGroup: false,
            );
          } catch (_) {
            return _MutedChatEntry(
              id: id,
              title: id,
              subtitle: 'Novyn contact',
              isGroup: false,
            );
          }
        }));

        for (final id in ids) {
          await prefs.setBool(_storageKey(id), true);
        }
        if (!mounted) return;
        setState(() {
          _mutedChats = entries;
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // Use the local cache when offline; server state wins when available.
    }

    final fallback = <_MutedChatEntry>[];
    for (final chat in socket.conversations) {
      final id = chat.isGroup
          ? (chat.peer.uid.isNotEmpty ? chat.peer.uid : chat.chatId)
          : chat.peer.username;
      if (prefs.getBool(_storageKey(id)) != true) continue;
      fallback.add(_MutedChatEntry(
        id: id,
        title: chat.peer.name.trim().isNotEmpty ? chat.peer.name.trim() : id,
        subtitle: chat.isGroup ? 'Group conversation' : '@${chat.peer.username}',
        isGroup: chat.isGroup,
      ));
    }

    if (!mounted) return;
    setState(() {
      _mutedChats = fallback;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    initLoad();
  }

  Future<void> _unmute(_MutedChatEntry chat) async {
    if (_saving) return;
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    try {
      final result = await context.read<SocketService>().setMute(
            chat.id,
            muted: false,
            isGroup: chat.isGroup,
          );
      if (result['ok'] != true) {
        throw StateError(result['message']?.toString() ??
            'The server did not confirm this mute change.');
      }
      await prefs.setBool(_storageKey(chat.id), false);
      if (!mounted) return;
      setState(() {
        _mutedChats.removeWhere(
          (item) => item.id.toLowerCase() == chat.id.toLowerCase(),
        );
      });
      NovynToast.show(context, 'Notifications unmuted');
    } catch (error) {
      if (mounted) {
        context.showNovynAlert(
          SnackBar(content: Text('Could not unmute this chat: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: const Text('Muted chats'),
        backgroundColor: NovynTheme.pageBg(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: initLoad,
              child: _mutedChats.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(28, 90, 28, 32),
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 42, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No muted chats',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Chats you mute will appear here. You can unmute them anytime.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                      itemCount: _mutedChats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final chat = _mutedChats[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1C2E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2C2844)
                                  : const Color(0xFFEDE9F6),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: scheme.primaryContainer,
                              child: chat.isGroup
                                  ? Icon(Icons.groups_rounded,
                                      color: scheme.onPrimaryContainer)
                                  : Text(
                                      chat.title.trim().isEmpty
                                          ? '?'
                                          : chat.title.trim()[0].toUpperCase(),
                                      style: TextStyle(
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                            title: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(chat.subtitle),
                            trailing: TextButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      HapticService.vibrate(
                                          NovynHapticType.selection);
                                      _unmute(chat);
                                    },
                              child: const Text('Unmute'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
