import 'package:flutter/material.dart';

import '../../models/chat_models.dart';
import '../../models/chat_preview.dart';
import '../../services/hybrid_db_service.dart';
import '../../theme/novyn_theme.dart';
import '../../widgets/user_avatar.dart';

class StarredMessagesScreen extends StatefulWidget {
  const StarredMessagesScreen({
    super.key,
    required this.chats,
    required this.onOpenChat,
  });

  final List<ChatPreview> chats;
  final ValueChanged<ChatPreview> onOpenChat;

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessageEntry {
  const _StarredMessageEntry({required this.chat, required this.message});
  final ChatPreview chat;
  final Message message;
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  bool _loading = true;
  List<_StarredMessageEntry> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadStarredMessages();
  }

  Future<void> _loadStarredMessages() async {
    try {
      final results = await Future.wait(
        widget.chats.take(40).map((chat) async {
          final messages = await HybridDbService.getMessages(
            chat.chatId,
            limit: 100,
          );
          return messages
              .where((message) => message.pinnedAt != null)
              .map((message) => _StarredMessageEntry(
                    chat: chat,
                    message: message,
                  ));
        }),
      );
      final items = results.expand((entries) => entries).toList()
        ..sort((a, b) => b.message.createdAt.compareTo(a.message.createdAt));
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (error) {
      debugPrint('[NovynStarredMessages] Could not load pinned messages: $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _previewText(Message message) {
    final value = message.text.trim();
    if (value.isNotEmpty && value != '🔒 Encrypted message') return value;
    if (message.attachment != null) return 'Attachment';
    if (message.isEncrypted) return 'Encrypted message';
    return 'Message';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        backgroundColor: NovynTheme.pageBg(context),
        elevation: 0,
        title: const Text(
          'Starred messages',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB77921).withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(23),
                          ),
                          child: const Icon(
                            Icons.star_outline_rounded,
                            color: Color(0xFFB77921),
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'No starred messages yet',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Pin a message inside any chat to keep it easy to find here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: colors.primary,
                  onRefresh: _loadStarredMessages,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final message = item.message;
                      return Material(
                        color: NovynTheme.cardBg(context),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            final selectedChat = item.chat;
                            final openChat = widget.onOpenChat;
                            Navigator.of(context).pop();
                            Future<void>.delayed(Duration.zero, () {
                              openChat(selectedChat);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                UserAvatar(
                                  name: item.chat.peer.name,
                                  photoUrl: item.chat.peer.photoUrl,
                                  radius: 22,
                                  fallbackColor: item.chat.peer.avatarColor,
                                  isOnline: item.chat.peer.isOnline,
                                  presence: item.chat.peer.status,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.chat.peer.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        _previewText(message),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          height: 1.35,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        message.createdAt.toLocal().toString().split('.').first,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant.withValues(alpha: .75),
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF4A51C),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
