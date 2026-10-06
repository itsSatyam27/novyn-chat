import 'package:hive/hive.dart';

part 'chat_models.g.dart';

@HiveType(typeId: 0)
class Chat extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String lastMessage;
  @HiveField(3)
  final String time;
  @HiveField(4)
  final int unreadCount;
  @HiveField(5)
  final String avatarUrl;
  @HiveField(6)
  final bool isOnline;

  @HiveField(7)
  final bool isGroup;
  @HiveField(8)
  final List<String> memberIds;

  Chat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    required this.avatarUrl,
    this.isOnline = false,
    this.isGroup = false,
    this.memberIds = const [],
  });
}

@HiveType(typeId: 1)
class Message extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String text;
  @HiveField(2)
  final String time;
  @HiveField(3)
  final bool isFromMe;
  @HiveField(4)
  final String chatId;
  @HiveField(5)
  final String senderId;
  @HiveField(6)
  final DateTime createdAt;
  @HiveField(7)
  final Map<String, String> reactions;
  @HiveField(8)
  final String? replyToId;
  @HiveField(9)
  final String? replyToText;
  @HiveField(10)
  final String? replyToSender;
  @HiveField(11)
  final bool edited;

  Message({
    required this.id,
    required this.text,
    this.time = '',
    required this.isFromMe,
    this.chatId = '',
    this.senderId = '',
    DateTime? createdAt,
    Map<String, String>? reactions,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.edited = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       reactions = reactions ?? {};

  Message copyWith({
    String? id,
    String? text,
    bool? isFromMe,
    Map<String, String>? reactions,
    bool? edited,
  }) {
    return Message(
      id:            id ?? this.id,
      text:          text ?? this.text,
      time:          time,
      isFromMe:      isFromMe ?? this.isFromMe,
      chatId:        chatId,
      senderId:      senderId,
      createdAt:     createdAt,
      reactions:     reactions ?? this.reactions,
      replyToId:     replyToId,
      replyToText:   replyToText,
      replyToSender: replyToSender,
      edited:        edited ?? this.edited,
    );
  }
}
