import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/haptic_service.dart';

import '../../../models/chat_preview.dart';
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

class _MutedChatsScreenState extends State<MutedChatsScreen> {
  bool _loading = true;
  bool _saving = false;
  List<ChatPreview> _mutedChats = <ChatPreview>[];

  String _muteId(ChatPreview chat) =>
      chat.isGroup ? (chat.peer.uid.isNotEmpty ? chat.peer.uid : chat.chatId) : chat.peer.username;

  String _storageKey(ChatPreview chat) =>
      'novyn_mute_${_muteId(chat).trim().toLowerCase()}';

  @override
  void initState() {
    super.initState();
    _loadMutedChats();
  }

  Future<void> _loadMutedChats() async {
    if (mounted) setState(() => _loading = true);
    final socket = context.read<SocketService>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final remote = await socket.fetchAccountSettings();
    final remoteSettings = remote['settings'] is Map
        ? Map<String, dynamic>.from(remote['settings'] as Map)
        : <String, dynamic>{};
    final remoteIds = (remoteSettings['mutedChats'] is List
            ? remoteSettings['mutedChats'] as List
            : const <dynamic>[])
        .map((value) => value.toString().trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();

    final chats = socket.conversations;
    final muted = <ChatPreview>[];
    for (final chat in chats) {
      final id = _muteId(chat).trim().toLowerCase();
      if (id.isEmpty) continue;
      final isMuted = remote['ok'] == true
          ? remoteIds.contains(id)
          : (prefs.getBool(_storageKey(chat)) ?? false);
      await prefs.setBool(_storageKey(chat), isMuted);
      if (isMuted) muted.add(chat);
    }

    if (!mounted) return;
    setState(() {
      _mutedChats = muted;
      _loading = false;
    });
  }

  Future<void> _unmute(ChatPreview chat) async {
    if (_saving) return;
    setState(() => _saving = true);
    final id = _muteId(chat);
    final prefs = await SharedPreferences.getInstance();
    try {
      final result = await context.read<SocketService>().setMute(
            id,
            muted: false,
            isGroup: chat.isGroup,
          );
      if (result['ok'] != true) {
        throw StateError(result['message']?.toString() ??
            'The server did not confirm this mute change.');
      }
      await prefs.setBool(_storageKey(chat), false);
      if (!mounted) return;
      setState(() {
        _mutedChats.removeWhere((item) =>
            _muteId(item).toLowerCase() == id.toLowerCase());
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
              onRefresh: _loadMutedChats,
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
                        final title = chat.peer.name.trim().isNotEmpty
                            ? chat.peer.name.trim()
                            : chat.peer.username;
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1C2E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2C2844) : const Color(0xFFEDE9F6),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: chat.peer.avatarColor.withValues(alpha: .16),
                              child: chat.isGroup
                                  ? Icon(Icons.groups_rounded, color: chat.peer.avatarColor)
                                  : Text(
                                      chat.peer.initials,
                                      style: TextStyle(
                                        color: chat.peer.avatarColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(chat.isGroup ? 'Group conversation' : '@${chat.peer.username}'),
                            trailing: TextButton(
                              onPressed: _saving ? null : () {
                                HapticService.vibrate(NovynHapticType.selection);
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
