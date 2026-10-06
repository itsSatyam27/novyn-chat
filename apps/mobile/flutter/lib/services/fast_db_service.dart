import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/chat_models.dart' as models;

part 'fast_db_service.g.dart';

/// Fast SQLite database with indexes for instant queries

// ══════════════════════════════════════════════════════════════════════════
// TABLE DEFINITIONS
// ══════════════════════════════════════════════════════════════════════════

@DataClassName('DriftMessage')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get chatId => text()();
  TextColumn get messageText => text()();
  TextColumn get senderId => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isFromMe => boolean()();
  TextColumn get replyToId => text().nullable()();
  TextColumn get replyToText => text().nullable()();
  TextColumn get replyToSender => text().nullable()();
  BoolColumn get edited => boolean().withDefault(const Constant(false))();
  // Reactions stored as JSON: {"uid":"emoji"}
  TextColumn get reactionsJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DriftChat')
class Chats extends Table {
  TextColumn get chatId => text()();
  TextColumn get peerUid => text()();
  TextColumn get lastMessage => text()();
  DateTimeColumn get lastTime => dateTime()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {chatId};
}

// ══════════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════════

Map<String, String> _decodeReactions(String json) {
  try {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  } catch (_) {
    return {};
  }
}

String _encodeReactions(Map<String, String> reactions) {
  try {
    return jsonEncode(reactions);
  } catch (_) {
    return '{}';
  }
}

models.Message _toModel(DriftMessage dm) => models.Message(
  id: dm.id,
  chatId: dm.chatId,
  text: dm.messageText,
  senderId: dm.senderId,
  createdAt: dm.createdAt,
  isFromMe: dm.isFromMe,
  replyToId: dm.replyToId,
  replyToText: dm.replyToText,
  replyToSender: dm.replyToSender,
  edited: dm.edited,
  reactions: _decodeReactions(dm.reactionsJson),
);

MessagesCompanion _toCompanion(models.Message m) => MessagesCompanion.insert(
  id: m.id,
  chatId: m.chatId,
  messageText: m.text,
  senderId: m.senderId,
  createdAt: m.createdAt,
  isFromMe: m.isFromMe,
  replyToId: Value(m.replyToId),
  replyToText: Value(m.replyToText),
  replyToSender: Value(m.replyToSender),
  edited: Value(m.edited),
  reactionsJson: Value(_encodeReactions(m.reactions)),
);

// ══════════════════════════════════════════════════════════════════════════
// DATABASE CLASS
// ══════════════════════════════════════════════════════════════════════════

@DriftDatabase(tables: [Messages, Chats])
class FastDatabase extends _$FastDatabase {
  FastDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Add reactionsJson column to existing messages table
        await migrator.addColumn(messages, messages.reactionsJson);
      }
      if (from < 3) {
        // Add isPinned and isArchived to chats table
        await migrator.addColumn(chats, chats.isPinned);
        await migrator.addColumn(chats, chats.isArchived);
      }
    },
  );

  // ── MESSAGES ──────────────────────────────────────────────────────────────

  Future<List<models.Message>> getMessages(String chatId, {int limit = 50}) async {
    final rows = await (select(messages)
          ..where((m) => m.chatId.equals(chatId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_toModel).toList();
  }

  Future<List<models.Message>> getOlderMessages(String chatId, DateTime before, {int limit = 30}) async {
    final rows = await (select(messages)
          ..where((m) => m.chatId.equals(chatId) & m.createdAt.isSmallerThanValue(before))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)])
          ..limit(limit))
        .get();
    return rows.map(_toModel).toList();
  }

  Future<void> saveMessage(models.Message msg) async {
    await into(messages).insertOnConflictUpdate(_toCompanion(msg));
  }

  Future<void> saveMessages(List<models.Message> msgs) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(messages, msgs.map(_toCompanion).toList());
    });
  }

  Future<void> updateMessage(String messageId, models.Message updated) async {
    await (update(messages)..where((m) => m.id.equals(messageId)))
        .write(_toCompanion(updated));
  }

  Future<void> deleteMessage(String messageId) async {
    await (delete(messages)..where((m) => m.id.equals(messageId))).go();
  }

  Future<int> getMessageCount(String chatId) async {
    final count = countAll();
    final query = selectOnly(messages)
      ..addColumns([count])
      ..where(messages.chatId.equals(chatId));
    return await query.map((row) => row.read(count) ?? 0).getSingle();
  }

  // ── CHATS ─────────────────────────────────────────────────────────────────

  Future<List<DriftChat>> getChats() async {
    return (select(chats)..orderBy([(c) => OrderingTerm.desc(c.lastTime)])).get();
  }

  Future<void> saveChat(String chatId, String peerUid, String lastMessage, DateTime lastTime, int unreadCount, {bool isPinned = false, bool isArchived = false}) async {
    await into(chats).insertOnConflictUpdate(ChatsCompanion.insert(
      chatId: chatId,
      peerUid: peerUid,
      lastMessage: lastMessage,
      lastTime: lastTime,
      unreadCount: Value(unreadCount),
      isPinned: Value(isPinned),
      isArchived: Value(isArchived),
    ));
  }

  Future<void> updateChat(String chatId, {String? lastMessage, DateTime? lastTime, int? unreadCount, bool? isPinned, bool? isArchived}) async {
    final existing = await (select(chats)..where((c) => c.chatId.equals(chatId))).getSingleOrNull();
    if (existing != null) {
      await (update(chats)..where((c) => c.chatId.equals(chatId))).write(ChatsCompanion.insert(
        chatId: chatId,
        peerUid: existing.peerUid,
        lastMessage: lastMessage ?? existing.lastMessage,
        lastTime: lastTime ?? existing.lastTime,
        unreadCount: Value(unreadCount ?? existing.unreadCount),
        isPinned: Value(isPinned ?? existing.isPinned),
        isArchived: Value(isArchived ?? existing.isArchived),
      ));
    }
  }

  Future<void> deleteChat(String chatId) async {
    await (delete(chats)..where((c) => c.chatId.equals(chatId))).go();
    await (delete(messages)..where((m) => m.chatId.equals(chatId))).go();
  }

  // ── UTILITIES ─────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await delete(messages).go();
    await delete(chats).go();
  }

  Future<Map<String, int>> getStats() async {
    final msgCount = countAll();
    final chatCount = countAll();
    final msgTotal = await (selectOnly(messages)..addColumns([msgCount]))
        .map((r) => r.read(msgCount) ?? 0).getSingle();
    final chatTotal = await (selectOnly(chats)..addColumns([chatCount]))
        .map((r) => r.read(chatCount) ?? 0).getSingle();
    return {'messages': msgTotal, 'chats': chatTotal};
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CONNECTION
// ══════════════════════════════════════════════════════════════════════════

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'novyn_fast.db'));
    return NativeDatabase.createInBackground(file);
  });
}

// ══════════════════════════════════════════════════════════════════════════
// SINGLETON
// ══════════════════════════════════════════════════════════════════════════

class FastDbService {
  static FastDatabase? _db;

  static Future<FastDatabase> get database async {
    _db ??= FastDatabase();
    return _db!;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
