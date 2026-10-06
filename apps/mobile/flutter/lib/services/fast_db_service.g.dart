// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fast_db_service.dart';

// ignore_for_file: type=lint
class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, DriftMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
      'chat_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageTextMeta =
      const VerificationMeta('messageText');
  @override
  late final GeneratedColumn<String> messageText = GeneratedColumn<String>(
      'message_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isFromMeMeta =
      const VerificationMeta('isFromMe');
  @override
  late final GeneratedColumn<bool> isFromMe = GeneratedColumn<bool>(
      'is_from_me', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_from_me" IN (0, 1))'));
  static const VerificationMeta _replyToIdMeta =
      const VerificationMeta('replyToId');
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
      'reply_to_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _replyToTextMeta =
      const VerificationMeta('replyToText');
  @override
  late final GeneratedColumn<String> replyToText = GeneratedColumn<String>(
      'reply_to_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _replyToSenderMeta =
      const VerificationMeta('replyToSender');
  @override
  late final GeneratedColumn<String> replyToSender = GeneratedColumn<String>(
      'reply_to_sender', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _editedMeta = const VerificationMeta('edited');
  @override
  late final GeneratedColumn<bool> edited = GeneratedColumn<bool>(
      'edited', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("edited" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _reactionsJsonMeta =
      const VerificationMeta('reactionsJson');
  @override
  late final GeneratedColumn<String> reactionsJson = GeneratedColumn<String>(
      'reactions_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        chatId,
        messageText,
        senderId,
        createdAt,
        isFromMe,
        replyToId,
        replyToText,
        replyToSender,
        edited,
        reactionsJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(Insertable<DriftMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('message_text')) {
      context.handle(
          _messageTextMeta,
          messageText.isAcceptableOrUnknown(
              data['message_text']!, _messageTextMeta));
    } else if (isInserting) {
      context.missing(_messageTextMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_from_me')) {
      context.handle(_isFromMeMeta,
          isFromMe.isAcceptableOrUnknown(data['is_from_me']!, _isFromMeMeta));
    } else if (isInserting) {
      context.missing(_isFromMeMeta);
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
          _replyToIdMeta,
          replyToId.isAcceptableOrUnknown(
              data['reply_to_id']!, _replyToIdMeta));
    }
    if (data.containsKey('reply_to_text')) {
      context.handle(
          _replyToTextMeta,
          replyToText.isAcceptableOrUnknown(
              data['reply_to_text']!, _replyToTextMeta));
    }
    if (data.containsKey('reply_to_sender')) {
      context.handle(
          _replyToSenderMeta,
          replyToSender.isAcceptableOrUnknown(
              data['reply_to_sender']!, _replyToSenderMeta));
    }
    if (data.containsKey('edited')) {
      context.handle(_editedMeta,
          edited.isAcceptableOrUnknown(data['edited']!, _editedMeta));
    }
    if (data.containsKey('reactions_json')) {
      context.handle(
          _reactionsJsonMeta,
          reactionsJson.isAcceptableOrUnknown(
              data['reactions_json']!, _reactionsJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_id'])!,
      messageText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message_text'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isFromMe: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_from_me'])!,
      replyToId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reply_to_id']),
      replyToText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reply_to_text']),
      replyToSender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reply_to_sender']),
      edited: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}edited'])!,
      reactionsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reactions_json'])!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class DriftMessage extends DataClass implements Insertable<DriftMessage> {
  final String id;
  final String chatId;
  final String messageText;
  final String senderId;
  final DateTime createdAt;
  final bool isFromMe;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final bool edited;
  final String reactionsJson;
  const DriftMessage(
      {required this.id,
      required this.chatId,
      required this.messageText,
      required this.senderId,
      required this.createdAt,
      required this.isFromMe,
      this.replyToId,
      this.replyToText,
      this.replyToSender,
      required this.edited,
      required this.reactionsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['chat_id'] = Variable<String>(chatId);
    map['message_text'] = Variable<String>(messageText);
    map['sender_id'] = Variable<String>(senderId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_from_me'] = Variable<bool>(isFromMe);
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    if (!nullToAbsent || replyToText != null) {
      map['reply_to_text'] = Variable<String>(replyToText);
    }
    if (!nullToAbsent || replyToSender != null) {
      map['reply_to_sender'] = Variable<String>(replyToSender);
    }
    map['edited'] = Variable<bool>(edited);
    map['reactions_json'] = Variable<String>(reactionsJson);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      chatId: Value(chatId),
      messageText: Value(messageText),
      senderId: Value(senderId),
      createdAt: Value(createdAt),
      isFromMe: Value(isFromMe),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      replyToText: replyToText == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToText),
      replyToSender: replyToSender == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToSender),
      edited: Value(edited),
      reactionsJson: Value(reactionsJson),
    );
  }

  factory DriftMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftMessage(
      id: serializer.fromJson<String>(json['id']),
      chatId: serializer.fromJson<String>(json['chatId']),
      messageText: serializer.fromJson<String>(json['messageText']),
      senderId: serializer.fromJson<String>(json['senderId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isFromMe: serializer.fromJson<bool>(json['isFromMe']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      replyToText: serializer.fromJson<String?>(json['replyToText']),
      replyToSender: serializer.fromJson<String?>(json['replyToSender']),
      edited: serializer.fromJson<bool>(json['edited']),
      reactionsJson: serializer.fromJson<String>(json['reactionsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'chatId': serializer.toJson<String>(chatId),
      'messageText': serializer.toJson<String>(messageText),
      'senderId': serializer.toJson<String>(senderId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isFromMe': serializer.toJson<bool>(isFromMe),
      'replyToId': serializer.toJson<String?>(replyToId),
      'replyToText': serializer.toJson<String?>(replyToText),
      'replyToSender': serializer.toJson<String?>(replyToSender),
      'edited': serializer.toJson<bool>(edited),
      'reactionsJson': serializer.toJson<String>(reactionsJson),
    };
  }

  DriftMessage copyWith(
          {String? id,
          String? chatId,
          String? messageText,
          String? senderId,
          DateTime? createdAt,
          bool? isFromMe,
          Value<String?> replyToId = const Value.absent(),
          Value<String?> replyToText = const Value.absent(),
          Value<String?> replyToSender = const Value.absent(),
          bool? edited,
          String? reactionsJson}) =>
      DriftMessage(
        id: id ?? this.id,
        chatId: chatId ?? this.chatId,
        messageText: messageText ?? this.messageText,
        senderId: senderId ?? this.senderId,
        createdAt: createdAt ?? this.createdAt,
        isFromMe: isFromMe ?? this.isFromMe,
        replyToId: replyToId.present ? replyToId.value : this.replyToId,
        replyToText: replyToText.present ? replyToText.value : this.replyToText,
        replyToSender:
            replyToSender.present ? replyToSender.value : this.replyToSender,
        edited: edited ?? this.edited,
        reactionsJson: reactionsJson ?? this.reactionsJson,
      );
  DriftMessage copyWithCompanion(MessagesCompanion data) {
    return DriftMessage(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      messageText:
          data.messageText.present ? data.messageText.value : this.messageText,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isFromMe: data.isFromMe.present ? data.isFromMe.value : this.isFromMe,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      replyToText:
          data.replyToText.present ? data.replyToText.value : this.replyToText,
      replyToSender: data.replyToSender.present
          ? data.replyToSender.value
          : this.replyToSender,
      edited: data.edited.present ? data.edited.value : this.edited,
      reactionsJson: data.reactionsJson.present
          ? data.reactionsJson.value
          : this.reactionsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftMessage(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('messageText: $messageText, ')
          ..write('senderId: $senderId, ')
          ..write('createdAt: $createdAt, ')
          ..write('isFromMe: $isFromMe, ')
          ..write('replyToId: $replyToId, ')
          ..write('replyToText: $replyToText, ')
          ..write('replyToSender: $replyToSender, ')
          ..write('edited: $edited, ')
          ..write('reactionsJson: $reactionsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, chatId, messageText, senderId, createdAt,
      isFromMe, replyToId, replyToText, replyToSender, edited, reactionsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftMessage &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.messageText == this.messageText &&
          other.senderId == this.senderId &&
          other.createdAt == this.createdAt &&
          other.isFromMe == this.isFromMe &&
          other.replyToId == this.replyToId &&
          other.replyToText == this.replyToText &&
          other.replyToSender == this.replyToSender &&
          other.edited == this.edited &&
          other.reactionsJson == this.reactionsJson);
}

class MessagesCompanion extends UpdateCompanion<DriftMessage> {
  final Value<String> id;
  final Value<String> chatId;
  final Value<String> messageText;
  final Value<String> senderId;
  final Value<DateTime> createdAt;
  final Value<bool> isFromMe;
  final Value<String?> replyToId;
  final Value<String?> replyToText;
  final Value<String?> replyToSender;
  final Value<bool> edited;
  final Value<String> reactionsJson;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.messageText = const Value.absent(),
    this.senderId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isFromMe = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.replyToText = const Value.absent(),
    this.replyToSender = const Value.absent(),
    this.edited = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String chatId,
    required String messageText,
    required String senderId,
    required DateTime createdAt,
    required bool isFromMe,
    this.replyToId = const Value.absent(),
    this.replyToText = const Value.absent(),
    this.replyToSender = const Value.absent(),
    this.edited = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        chatId = Value(chatId),
        messageText = Value(messageText),
        senderId = Value(senderId),
        createdAt = Value(createdAt),
        isFromMe = Value(isFromMe);
  static Insertable<DriftMessage> custom({
    Expression<String>? id,
    Expression<String>? chatId,
    Expression<String>? messageText,
    Expression<String>? senderId,
    Expression<DateTime>? createdAt,
    Expression<bool>? isFromMe,
    Expression<String>? replyToId,
    Expression<String>? replyToText,
    Expression<String>? replyToSender,
    Expression<bool>? edited,
    Expression<String>? reactionsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (messageText != null) 'message_text': messageText,
      if (senderId != null) 'sender_id': senderId,
      if (createdAt != null) 'created_at': createdAt,
      if (isFromMe != null) 'is_from_me': isFromMe,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyToText != null) 'reply_to_text': replyToText,
      if (replyToSender != null) 'reply_to_sender': replyToSender,
      if (edited != null) 'edited': edited,
      if (reactionsJson != null) 'reactions_json': reactionsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith(
      {Value<String>? id,
      Value<String>? chatId,
      Value<String>? messageText,
      Value<String>? senderId,
      Value<DateTime>? createdAt,
      Value<bool>? isFromMe,
      Value<String?>? replyToId,
      Value<String?>? replyToText,
      Value<String?>? replyToSender,
      Value<bool>? edited,
      Value<String>? reactionsJson,
      Value<int>? rowid}) {
    return MessagesCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      messageText: messageText ?? this.messageText,
      senderId: senderId ?? this.senderId,
      createdAt: createdAt ?? this.createdAt,
      isFromMe: isFromMe ?? this.isFromMe,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSender: replyToSender ?? this.replyToSender,
      edited: edited ?? this.edited,
      reactionsJson: reactionsJson ?? this.reactionsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (messageText.present) {
      map['message_text'] = Variable<String>(messageText.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isFromMe.present) {
      map['is_from_me'] = Variable<bool>(isFromMe.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (replyToText.present) {
      map['reply_to_text'] = Variable<String>(replyToText.value);
    }
    if (replyToSender.present) {
      map['reply_to_sender'] = Variable<String>(replyToSender.value);
    }
    if (edited.present) {
      map['edited'] = Variable<bool>(edited.value);
    }
    if (reactionsJson.present) {
      map['reactions_json'] = Variable<String>(reactionsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('messageText: $messageText, ')
          ..write('senderId: $senderId, ')
          ..write('createdAt: $createdAt, ')
          ..write('isFromMe: $isFromMe, ')
          ..write('replyToId: $replyToId, ')
          ..write('replyToText: $replyToText, ')
          ..write('replyToSender: $replyToSender, ')
          ..write('edited: $edited, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatsTable extends Chats with TableInfo<$ChatsTable, DriftChat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<String> chatId = GeneratedColumn<String>(
      'chat_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _peerUidMeta =
      const VerificationMeta('peerUid');
  @override
  late final GeneratedColumn<String> peerUid = GeneratedColumn<String>(
      'peer_uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastMessageMeta =
      const VerificationMeta('lastMessage');
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
      'last_message', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastTimeMeta =
      const VerificationMeta('lastTime');
  @override
  late final GeneratedColumn<DateTime> lastTime = GeneratedColumn<DateTime>(
      'last_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _unreadCountMeta =
      const VerificationMeta('unreadCount');
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
      'unread_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isPinnedMeta =
      const VerificationMeta('isPinned');
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
      'is_pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        chatId,
        peerUid,
        lastMessage,
        lastTime,
        unreadCount,
        isPinned,
        isArchived
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chats';
  @override
  VerificationContext validateIntegrity(Insertable<DriftChat> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(_chatIdMeta,
          chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta));
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('peer_uid')) {
      context.handle(_peerUidMeta,
          peerUid.isAcceptableOrUnknown(data['peer_uid']!, _peerUidMeta));
    } else if (isInserting) {
      context.missing(_peerUidMeta);
    }
    if (data.containsKey('last_message')) {
      context.handle(
          _lastMessageMeta,
          lastMessage.isAcceptableOrUnknown(
              data['last_message']!, _lastMessageMeta));
    } else if (isInserting) {
      context.missing(_lastMessageMeta);
    }
    if (data.containsKey('last_time')) {
      context.handle(_lastTimeMeta,
          lastTime.isAcceptableOrUnknown(data['last_time']!, _lastTimeMeta));
    } else if (isInserting) {
      context.missing(_lastTimeMeta);
    }
    if (data.containsKey('unread_count')) {
      context.handle(
          _unreadCountMeta,
          unreadCount.isAcceptableOrUnknown(
              data['unread_count']!, _unreadCountMeta));
    }
    if (data.containsKey('is_pinned')) {
      context.handle(_isPinnedMeta,
          isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta));
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId};
  @override
  DriftChat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftChat(
      chatId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chat_id'])!,
      peerUid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}peer_uid'])!,
      lastMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_message'])!,
      lastTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_time'])!,
      unreadCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unread_count'])!,
      isPinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pinned'])!,
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
    );
  }

  @override
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }
}

class DriftChat extends DataClass implements Insertable<DriftChat> {
  final String chatId;
  final String peerUid;
  final String lastMessage;
  final DateTime lastTime;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  const DriftChat(
      {required this.chatId,
      required this.peerUid,
      required this.lastMessage,
      required this.lastTime,
      required this.unreadCount,
      required this.isPinned,
      required this.isArchived});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<String>(chatId);
    map['peer_uid'] = Variable<String>(peerUid);
    map['last_message'] = Variable<String>(lastMessage);
    map['last_time'] = Variable<DateTime>(lastTime);
    map['unread_count'] = Variable<int>(unreadCount);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  ChatsCompanion toCompanion(bool nullToAbsent) {
    return ChatsCompanion(
      chatId: Value(chatId),
      peerUid: Value(peerUid),
      lastMessage: Value(lastMessage),
      lastTime: Value(lastTime),
      unreadCount: Value(unreadCount),
      isPinned: Value(isPinned),
      isArchived: Value(isArchived),
    );
  }

  factory DriftChat.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftChat(
      chatId: serializer.fromJson<String>(json['chatId']),
      peerUid: serializer.fromJson<String>(json['peerUid']),
      lastMessage: serializer.fromJson<String>(json['lastMessage']),
      lastTime: serializer.fromJson<DateTime>(json['lastTime']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<String>(chatId),
      'peerUid': serializer.toJson<String>(peerUid),
      'lastMessage': serializer.toJson<String>(lastMessage),
      'lastTime': serializer.toJson<DateTime>(lastTime),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  DriftChat copyWith(
          {String? chatId,
          String? peerUid,
          String? lastMessage,
          DateTime? lastTime,
          int? unreadCount,
          bool? isPinned,
          bool? isArchived}) =>
      DriftChat(
        chatId: chatId ?? this.chatId,
        peerUid: peerUid ?? this.peerUid,
        lastMessage: lastMessage ?? this.lastMessage,
        lastTime: lastTime ?? this.lastTime,
        unreadCount: unreadCount ?? this.unreadCount,
        isPinned: isPinned ?? this.isPinned,
        isArchived: isArchived ?? this.isArchived,
      );
  DriftChat copyWithCompanion(ChatsCompanion data) {
    return DriftChat(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      peerUid: data.peerUid.present ? data.peerUid.value : this.peerUid,
      lastMessage:
          data.lastMessage.present ? data.lastMessage.value : this.lastMessage,
      lastTime: data.lastTime.present ? data.lastTime.value : this.lastTime,
      unreadCount:
          data.unreadCount.present ? data.unreadCount.value : this.unreadCount,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftChat(')
          ..write('chatId: $chatId, ')
          ..write('peerUid: $peerUid, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastTime: $lastTime, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chatId, peerUid, lastMessage, lastTime,
      unreadCount, isPinned, isArchived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftChat &&
          other.chatId == this.chatId &&
          other.peerUid == this.peerUid &&
          other.lastMessage == this.lastMessage &&
          other.lastTime == this.lastTime &&
          other.unreadCount == this.unreadCount &&
          other.isPinned == this.isPinned &&
          other.isArchived == this.isArchived);
}

class ChatsCompanion extends UpdateCompanion<DriftChat> {
  final Value<String> chatId;
  final Value<String> peerUid;
  final Value<String> lastMessage;
  final Value<DateTime> lastTime;
  final Value<int> unreadCount;
  final Value<bool> isPinned;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const ChatsCompanion({
    this.chatId = const Value.absent(),
    this.peerUid = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastTime = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatsCompanion.insert({
    required String chatId,
    required String peerUid,
    required String lastMessage,
    required DateTime lastTime,
    this.unreadCount = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : chatId = Value(chatId),
        peerUid = Value(peerUid),
        lastMessage = Value(lastMessage),
        lastTime = Value(lastTime);
  static Insertable<DriftChat> custom({
    Expression<String>? chatId,
    Expression<String>? peerUid,
    Expression<String>? lastMessage,
    Expression<DateTime>? lastTime,
    Expression<int>? unreadCount,
    Expression<bool>? isPinned,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (peerUid != null) 'peer_uid': peerUid,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastTime != null) 'last_time': lastTime,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatsCompanion copyWith(
      {Value<String>? chatId,
      Value<String>? peerUid,
      Value<String>? lastMessage,
      Value<DateTime>? lastTime,
      Value<int>? unreadCount,
      Value<bool>? isPinned,
      Value<bool>? isArchived,
      Value<int>? rowid}) {
    return ChatsCompanion(
      chatId: chatId ?? this.chatId,
      peerUid: peerUid ?? this.peerUid,
      lastMessage: lastMessage ?? this.lastMessage,
      lastTime: lastTime ?? this.lastTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<String>(chatId.value);
    }
    if (peerUid.present) {
      map['peer_uid'] = Variable<String>(peerUid.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (lastTime.present) {
      map['last_time'] = Variable<DateTime>(lastTime.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatsCompanion(')
          ..write('chatId: $chatId, ')
          ..write('peerUid: $peerUid, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastTime: $lastTime, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FastDatabase extends GeneratedDatabase {
  _$FastDatabase(QueryExecutor e) : super(e);
  $FastDatabaseManager get managers => $FastDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $ChatsTable chats = $ChatsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [messages, chats];
}

typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String id,
  required String chatId,
  required String messageText,
  required String senderId,
  required DateTime createdAt,
  required bool isFromMe,
  Value<String?> replyToId,
  Value<String?> replyToText,
  Value<String?> replyToSender,
  Value<bool> edited,
  Value<String> reactionsJson,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> id,
  Value<String> chatId,
  Value<String> messageText,
  Value<String> senderId,
  Value<DateTime> createdAt,
  Value<bool> isFromMe,
  Value<String?> replyToId,
  Value<String?> replyToText,
  Value<String?> replyToSender,
  Value<bool> edited,
  Value<String> reactionsJson,
  Value<int> rowid,
});

class $$MessagesTableFilterComposer
    extends Composer<_$FastDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get messageText => $composableBuilder(
      column: $table.messageText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFromMe => $composableBuilder(
      column: $table.isFromMe, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replyToText => $composableBuilder(
      column: $table.replyToText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get replyToSender => $composableBuilder(
      column: $table.replyToSender, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get edited => $composableBuilder(
      column: $table.edited, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson, builder: (column) => ColumnFilters(column));
}

class $$MessagesTableOrderingComposer
    extends Composer<_$FastDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get messageText => $composableBuilder(
      column: $table.messageText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFromMe => $composableBuilder(
      column: $table.isFromMe, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replyToId => $composableBuilder(
      column: $table.replyToId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replyToText => $composableBuilder(
      column: $table.replyToText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get replyToSender => $composableBuilder(
      column: $table.replyToSender,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get edited => $composableBuilder(
      column: $table.edited, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson,
      builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$FastDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get messageText => $composableBuilder(
      column: $table.messageText, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isFromMe =>
      $composableBuilder(column: $table.isFromMe, builder: (column) => column);

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<String> get replyToText => $composableBuilder(
      column: $table.replyToText, builder: (column) => column);

  GeneratedColumn<String> get replyToSender => $composableBuilder(
      column: $table.replyToSender, builder: (column) => column);

  GeneratedColumn<bool> get edited =>
      $composableBuilder(column: $table.edited, builder: (column) => column);

  GeneratedColumn<String> get reactionsJson => $composableBuilder(
      column: $table.reactionsJson, builder: (column) => column);
}

class $$MessagesTableTableManager extends RootTableManager<
    _$FastDatabase,
    $MessagesTable,
    DriftMessage,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (
      DriftMessage,
      BaseReferences<_$FastDatabase, $MessagesTable, DriftMessage>
    ),
    DriftMessage,
    PrefetchHooks Function()> {
  $$MessagesTableTableManager(_$FastDatabase db, $MessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> chatId = const Value.absent(),
            Value<String> messageText = const Value.absent(),
            Value<String> senderId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<bool> isFromMe = const Value.absent(),
            Value<String?> replyToId = const Value.absent(),
            Value<String?> replyToText = const Value.absent(),
            Value<String?> replyToSender = const Value.absent(),
            Value<bool> edited = const Value.absent(),
            Value<String> reactionsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion(
            id: id,
            chatId: chatId,
            messageText: messageText,
            senderId: senderId,
            createdAt: createdAt,
            isFromMe: isFromMe,
            replyToId: replyToId,
            replyToText: replyToText,
            replyToSender: replyToSender,
            edited: edited,
            reactionsJson: reactionsJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String chatId,
            required String messageText,
            required String senderId,
            required DateTime createdAt,
            required bool isFromMe,
            Value<String?> replyToId = const Value.absent(),
            Value<String?> replyToText = const Value.absent(),
            Value<String?> replyToSender = const Value.absent(),
            Value<bool> edited = const Value.absent(),
            Value<String> reactionsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesCompanion.insert(
            id: id,
            chatId: chatId,
            messageText: messageText,
            senderId: senderId,
            createdAt: createdAt,
            isFromMe: isFromMe,
            replyToId: replyToId,
            replyToText: replyToText,
            replyToSender: replyToSender,
            edited: edited,
            reactionsJson: reactionsJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableProcessedTableManager = ProcessedTableManager<
    _$FastDatabase,
    $MessagesTable,
    DriftMessage,
    $$MessagesTableFilterComposer,
    $$MessagesTableOrderingComposer,
    $$MessagesTableAnnotationComposer,
    $$MessagesTableCreateCompanionBuilder,
    $$MessagesTableUpdateCompanionBuilder,
    (
      DriftMessage,
      BaseReferences<_$FastDatabase, $MessagesTable, DriftMessage>
    ),
    DriftMessage,
    PrefetchHooks Function()>;
typedef $$ChatsTableCreateCompanionBuilder = ChatsCompanion Function({
  required String chatId,
  required String peerUid,
  required String lastMessage,
  required DateTime lastTime,
  Value<int> unreadCount,
  Value<bool> isPinned,
  Value<bool> isArchived,
  Value<int> rowid,
});
typedef $$ChatsTableUpdateCompanionBuilder = ChatsCompanion Function({
  Value<String> chatId,
  Value<String> peerUid,
  Value<String> lastMessage,
  Value<DateTime> lastTime,
  Value<int> unreadCount,
  Value<bool> isPinned,
  Value<bool> isArchived,
  Value<int> rowid,
});

class $$ChatsTableFilterComposer extends Composer<_$FastDatabase, $ChatsTable> {
  $$ChatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get peerUid => $composableBuilder(
      column: $table.peerUid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastTime => $composableBuilder(
      column: $table.lastTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));
}

class $$ChatsTableOrderingComposer
    extends Composer<_$FastDatabase, $ChatsTable> {
  $$ChatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chatId => $composableBuilder(
      column: $table.chatId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get peerUid => $composableBuilder(
      column: $table.peerUid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastTime => $composableBuilder(
      column: $table.lastTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPinned => $composableBuilder(
      column: $table.isPinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));
}

class $$ChatsTableAnnotationComposer
    extends Composer<_$FastDatabase, $ChatsTable> {
  $$ChatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<String> get peerUid =>
      $composableBuilder(column: $table.peerUid, builder: (column) => column);

  GeneratedColumn<String> get lastMessage => $composableBuilder(
      column: $table.lastMessage, builder: (column) => column);

  GeneratedColumn<DateTime> get lastTime =>
      $composableBuilder(column: $table.lastTime, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
      column: $table.unreadCount, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);
}

class $$ChatsTableTableManager extends RootTableManager<
    _$FastDatabase,
    $ChatsTable,
    DriftChat,
    $$ChatsTableFilterComposer,
    $$ChatsTableOrderingComposer,
    $$ChatsTableAnnotationComposer,
    $$ChatsTableCreateCompanionBuilder,
    $$ChatsTableUpdateCompanionBuilder,
    (DriftChat, BaseReferences<_$FastDatabase, $ChatsTable, DriftChat>),
    DriftChat,
    PrefetchHooks Function()> {
  $$ChatsTableTableManager(_$FastDatabase db, $ChatsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> chatId = const Value.absent(),
            Value<String> peerUid = const Value.absent(),
            Value<String> lastMessage = const Value.absent(),
            Value<DateTime> lastTime = const Value.absent(),
            Value<int> unreadCount = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatsCompanion(
            chatId: chatId,
            peerUid: peerUid,
            lastMessage: lastMessage,
            lastTime: lastTime,
            unreadCount: unreadCount,
            isPinned: isPinned,
            isArchived: isArchived,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String chatId,
            required String peerUid,
            required String lastMessage,
            required DateTime lastTime,
            Value<int> unreadCount = const Value.absent(),
            Value<bool> isPinned = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChatsCompanion.insert(
            chatId: chatId,
            peerUid: peerUid,
            lastMessage: lastMessage,
            lastTime: lastTime,
            unreadCount: unreadCount,
            isPinned: isPinned,
            isArchived: isArchived,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChatsTableProcessedTableManager = ProcessedTableManager<
    _$FastDatabase,
    $ChatsTable,
    DriftChat,
    $$ChatsTableFilterComposer,
    $$ChatsTableOrderingComposer,
    $$ChatsTableAnnotationComposer,
    $$ChatsTableCreateCompanionBuilder,
    $$ChatsTableUpdateCompanionBuilder,
    (DriftChat, BaseReferences<_$FastDatabase, $ChatsTable, DriftChat>),
    DriftChat,
    PrefetchHooks Function()>;

class $FastDatabaseManager {
  final _$FastDatabase _db;
  $FastDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db, _db.chats);
}
