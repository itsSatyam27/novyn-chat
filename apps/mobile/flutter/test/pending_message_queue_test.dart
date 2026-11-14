import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:novyn/models/chat_models.dart';
import 'package:novyn/models/user_model.dart';
import 'package:novyn/services/local_db_service.dart';
import 'package:novyn/services/sync_service.dart';

void main() {
  test('outbox persists retries and remains isolated by account', () async {
    final directory = await Directory.systemTemp.createTemp('novyn-outbox-');
    Hive.init(directory.path);
    Hive.registerAdapter(MessageAdapter());
    Hive.registerAdapter(UserModelAdapter());

    final sync = SyncService();
    await LocalDbService.activateAccount('alice');
    await sync.activateAccount('alice');

    final queuedAt = DateTime.utc(2026, 11, 15, 3);
    final pending = PendingMessage(
      accountId: 'alice',
      tempId: 'tmp-alice-1',
      text: 'Offline message',
      receiverId: 'bob',
      chatId: 'bob',
      createdAt: queuedAt,
      replyToId: 'reply-1',
      replyToText: 'Earlier message',
      replyToSender: 'bob',
    );
    await sync.addPendingMessage(pending);
    expect(sync.pendingMessages, hasLength(1));

    // Re-read the durable Hive snapshot as if the app's in-memory service
    // had been recreated after a process restart.
    await sync.loadPendingMessages();
    expect(sync.pendingMessages.single.tempId, 'tmp-alice-1');
    expect(sync.pendingMessages.single.text, 'Offline message');

    // Logout clears in-memory data but keeps the durable account-scoped queue.
    await sync.deactivateAccount();
    expect(sync.pendingMessages, isEmpty);
    await LocalDbService.activateAccount('alice');
    await sync.activateAccount('alice');
    expect(sync.pendingMessages.single.tempId, 'tmp-alice-1');

    await sync.flushPendingMessages((_) async {
      throw TimeoutException('network timeout');
    });
    expect(sync.pendingMessages, hasLength(1));
    expect(sync.pendingMessages.single.attemptCount, 1);

    // Switching the active Hive namespace must not expose Alice's outbox to Bob.
    await LocalDbService.activateAccount('bob');
    await sync.activateAccount('bob');
    expect(sync.pendingMessages, isEmpty);

    await LocalDbService.activateAccount('alice');
    await sync.activateAccount('alice');
    expect(sync.pendingMessages, hasLength(1));
    expect(sync.pendingMessages.single.accountId, 'alice');

    final sent = <String>[];
    await sync.flushPendingMessages((message) async {
      sent.add(message.tempId);
    });
    expect(sent, ['tmp-alice-1']);
    expect(sync.pendingMessages, isEmpty);

    final rejected = PendingMessage(
      accountId: 'alice',
      tempId: 'tmp-alice-rejected',
      text: 'Blocked message',
      receiverId: 'blocked-user',
      chatId: 'blocked-user',
      createdAt: queuedAt.add(const Duration(seconds: 1)),
    );
    await sync.addPendingMessage(rejected);

    String? rejectionReason;
    await sync.flushPendingMessages(
      (_) async => throw const PendingMessageRejectedException('blocked'),
      onRejected: (_, reason) => rejectionReason = reason,
    );
    expect(rejectionReason, 'blocked');
    expect(sync.pendingMessages, isEmpty);

    await LocalDbService.close();
    await directory.delete(recursive: true);
  });

  test('pending message JSON round-trips and rejects malformed records', () {
    final pending = PendingMessage(
      accountId: 'alice',
      tempId: 'tmp-1',
      text: 'hello',
      receiverId: 'bob',
      chatId: 'bob',
      createdAt: DateTime.utc(2026, 11, 15),
      isGroup: true,
      attachment: {'kind': 'image', 'url': 'https://example.invalid/file'},
      attemptCount: 2,
      lastError: 'temporary network failure',
    );
    final decoded = PendingMessage.fromJson(pending.toJson());
    expect(decoded.accountId, 'alice');
    expect(decoded.isGroup, isTrue);
    expect(decoded.attachment?['kind'], 'image');
    expect(decoded.attemptCount, 2);
    expect(decoded.lastError, 'temporary network failure');
    expect(
      () => PendingMessage.fromJson({'tempId': 'missing-owner'}),
      throwsFormatException,
    );
  });
}
