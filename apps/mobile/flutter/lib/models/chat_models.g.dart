// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatAdapter extends TypeAdapter<Chat> {
  @override
  final int typeId = 0;

  @override
  Chat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Chat(
      id: fields[0] as String,
      name: fields[1] as String,
      lastMessage: fields[2] as String,
      time: fields[3] as String,
      unreadCount: fields[4] as int,
      avatarUrl: fields[5] as String,
      isOnline: fields[6] as bool,
      isGroup: fields[7] as bool,
      memberIds: (fields[8] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Chat obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.lastMessage)
      ..writeByte(3)
      ..write(obj.time)
      ..writeByte(4)
      ..write(obj.unreadCount)
      ..writeByte(5)
      ..write(obj.avatarUrl)
      ..writeByte(6)
      ..write(obj.isOnline)
      ..writeByte(7)
      ..write(obj.isGroup)
      ..writeByte(8)
      ..write(obj.memberIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 1;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      id: fields[0] as String,
      text: fields[1] as String,
      time: fields[2] as String,
      isFromMe: fields[3] as bool,
      chatId: fields[4] as String,
      senderId: fields[5] as String,
      createdAt: fields[6] as DateTime?,
      reactions: (fields[7] as Map?)?.cast<String, String>(),
      replyToId: fields[8] as String?,
      replyToText: fields[9] as String?,
      replyToSender: fields[10] as String?,
      edited: fields[11] as bool,
      isEncrypted: fields[12] as bool? ?? false,
      ciphertext: fields[13] as String?,
      iv: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.time)
      ..writeByte(3)
      ..write(obj.isFromMe)
      ..writeByte(4)
      ..write(obj.chatId)
      ..writeByte(5)
      ..write(obj.senderId)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.reactions)
      ..writeByte(8)
      ..write(obj.replyToId)
      ..writeByte(9)
      ..write(obj.replyToText)
      ..writeByte(10)
      ..write(obj.replyToSender)
      ..writeByte(11)
      ..write(obj.edited)
      ..writeByte(12)
      ..write(obj.isEncrypted)
      ..writeByte(13)
      ..write(obj.ciphertext)
      ..writeByte(14)
      ..write(obj.iv);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
