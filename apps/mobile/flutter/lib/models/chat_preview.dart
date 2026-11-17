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

  // Server-backed metadata for the latest conversation message. These fields
  // let the Chats home screen show real receipts rather than guessing from
  // local socket state.
  final String lastMessageId;
  final String lastMessageFrom;
  final DateTime? lastMessageDeliveredAt;
  final DateTime? lastMessageSeenAt;

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
    this.lastMessageId = '',
    this.lastMessageFrom = '',
    this.lastMessageDeliveredAt,
    this.lastMessageSeenAt,
  });

  String get lastMessageStatus {
    if (lastMessageSeenAt != null) return 'seen';
    if (lastMessageDeliveredAt != null) return 'delivered';
    return lastMessageId.isEmpty ? '' : 'sent';
  }

  ChatPreview copyWith({
    UserModel? peer,
    String? lastMessage,
    DateTime? lastTime,
    int? unreadCount,
    bool? isPinned,
    bool? isArchived,
    bool? isGroup,
    String? lastMessageId,
    String? lastMessageFrom,
    DateTime? lastMessageDeliveredAt,
    DateTime? lastMessageSeenAt,
  }) {
    return ChatPreview(
      chatId: chatId,
      peerUid: peerUid,
      peer: peer ?? this.peer,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime: lastTime ?? this.lastTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isGroup: isGroup ?? this.isGroup,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageFrom: lastMessageFrom ?? this.lastMessageFrom,
      lastMessageDeliveredAt:
          lastMessageDeliveredAt ?? this.lastMessageDeliveredAt,
      lastMessageSeenAt: lastMessageSeenAt ?? this.lastMessageSeenAt,
    );
  }
}
