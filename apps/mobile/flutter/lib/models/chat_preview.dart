import '../models/user_model.dart';

class ChatPreview {
  final String chatId;
  final String peerUid;
  final UserModel peer;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final bool isGroup;

  const ChatPreview({
    required this.chatId,
    required this.peerUid,
    required this.peer,
    required this.lastMessage,
    required this.lastTime,
    required this.unreadCount,
    this.isPinned = false,
    this.isArchived = false,
    this.isGroup = false,
  });

  ChatPreview copyWith({
    String? lastMessage,
    DateTime? lastTime,
    int? unreadCount,
    bool? isPinned,
    bool? isArchived,
    bool? isGroup,
  }) {
    return ChatPreview(
      chatId:      chatId,
      peerUid:     peerUid,
      peer:        peer,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime:    lastTime ?? this.lastTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned:    isPinned ?? this.isPinned,
      isArchived:  isArchived ?? this.isArchived,
      isGroup:     isGroup ?? this.isGroup,
    );
  }
}
