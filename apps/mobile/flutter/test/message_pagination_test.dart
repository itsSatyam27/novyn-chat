import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/models/chat_models.dart';
import 'package:novyn/services/fast_db_service.dart';
import 'package:novyn/utils/message_pagination.dart';

void main() {
  group('message timeline ordering', () {
    final sameTime = DateTime(2026, 11, 15, 10);
    Message message(String id, DateTime createdAt) => Message(
          id: id,
          text: id,
          chatId: 'peer',
          senderId: 'peer',
          isFromMe: false,
          createdAt: createdAt,
        );

    test('latest page uses chronological order and deterministic ID ties', () {
      final items = [
        message('newest', sameTime.add(const Duration(hours: 2))),
        message('id-c', sameTime),
        message('oldest', sameTime.subtract(const Duration(hours: 1))),
        message('id-a', sameTime),
        message('id-b', sameTime),
      ];
      expect(latestMessagesPage(items, limit: 3).map((m) => m.id).toList(),
          ['id-b', 'id-c', 'newest']);
    });

    test('composite cursor includes earlier IDs sharing its timestamp', () {
      final items = [
        message('id-a', sameTime),
        message('id-b', sameTime),
        message('id-c', sameTime),
        message('older', sameTime.subtract(const Duration(minutes: 1))),
        message('newer', sameTime.add(const Duration(minutes: 1))),
      ];
      final older = items.where((m) =>
          isMessageBeforeCursor(m, sameTime, beforeId: 'id-c'));
      expect(latestMessagesPage(older).map((m) => m.id).toList(),
          ['older', 'id-a', 'id-b']);
    });

    test('legacy timestamp-only cursor remains exclusive', () {
      final items = [
        message('same-time', sameTime),
        message('older', sameTime.subtract(const Duration(minutes: 1))),
      ];
      expect(items.where((m) => isMessageBeforeCursor(m, sameTime)).map((m) => m.id),
          ['older']);
    });
  });

  group('SQLite message page queries', () {
    late FastDatabase database;

    setUp(() async {
      database = FastDatabase.forTesting(NativeDatabase.memory());
      await database.customSelect('SELECT 1').get();
    });

    tearDown(() async => database.close());

    Future<void> insert(String id, DateTime createdAt) async {
      await database.into(database.messages).insert(MessagesCompanion.insert(
            id: id,
            chatId: 'peer',
            messageText: id,
            senderId: 'peer',
            createdAt: createdAt,
            isFromMe: false,
          ));
    }

    test('latest query returns newest N rows in ascending timeline order', () async {
      final time = DateTime(2026, 11, 15, 10);
      await insert('old', time.subtract(const Duration(hours: 2)));
      await insert('tie-a', time);
      await insert('tie-b', time);
      await insert('tie-c', time);
      await insert('new', time.add(const Duration(hours: 1)));

      final rows = await database.getMessages('peer', limit: 3);
      expect(rows.map((row) => row.id).toList(), ['tie-b', 'tie-c', 'new']);
    });

    test('older query uses timestamp plus ID cursor and fetches nearest older rows', () async {
      final time = DateTime(2026, 11, 15, 10);
      await insert('old', time.subtract(const Duration(hours: 1)));
      await insert('tie-a', time);
      await insert('tie-b', time);
      await insert('tie-c', time);
      await insert('new', time.add(const Duration(hours: 1)));

      final rows = await database.getOlderMessages(
        'peer', time, beforeId: 'tie-c', limit: 2,
      );
      expect(rows.map((row) => row.id).toList(), ['tie-a', 'tie-b']);
    });

    test('composite chat/time/ID SQLite index is created', () async {
      final indexes = await database.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_messages_chat_created_id'",
      ).get();
      expect(indexes, isNotEmpty);
    });
  });
}
