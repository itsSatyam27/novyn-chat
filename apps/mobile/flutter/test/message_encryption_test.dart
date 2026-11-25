import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:novyn/models/chat_models.dart';
import 'package:novyn/services/message_encryption_service.dart';

class _LegacyMessageAdapter extends TypeAdapter<Message> {
  @override
  int get typeId => 1;
  @override
  Message read(BinaryReader reader) => throw UnimplementedError();
  @override
  void write(BinaryWriter writer, Message message) {
    final fields = [message.id, message.text, message.time, message.isFromMe,
      message.chatId, message.senderId, message.createdAt, message.reactions,
      message.replyToId, message.replyToText, message.replyToSender, message.edited];
    writer.writeByte(fields.length);
    for (var index = 0; index < fields.length; index++) {
      writer.writeByte(index);
      writer.write(fields[index]);
    }
  }
}

void main() {
  test('existing 12-field Hive message records remain readable after upgrade', () async {
    final directory = await Directory.systemTemp.createTemp('novyn-legacy-messages-');
    Hive.init(directory.path);
    Hive.registerAdapter(_LegacyMessageAdapter(), override: true);
    final oldBox = await Hive.openBox<Message>('legacy');
    await oldBox.put('old', Message(id: 'old', text: 'Existing message', isFromMe: false));
    await oldBox.close();
    Hive.registerAdapter(MessageAdapter(), override: true);
    final upgraded = await Hive.openBox<Message>('legacy');
    final message = upgraded.get('old')!;
    expect(message.text, 'Existing message');
    expect(message.isEncrypted, isFalse);
    expect(message.ciphertext, isNull);
    await upgraded.close();
  });
  test('shared backend reaction lists do not crash history parsing', () {
    expect(Message.parseReactions({'❤️': ['alice', 'bob']}), {'alice': '❤️', 'bob': '❤️'});
    expect(Message.parseReactions({'alice': '👍'}), {'alice': '👍'});
  });
  final fixture = jsonDecode(
          File('test/fixtures/message_key_transfer.json').readAsStringSync())
      as Map;
  Message encrypted(Map raw) => Message(
      id: 'history-1',
      text: '🔒 Encrypted message',
      isFromMe: false,
      chatId: 'interop-bob',
      isEncrypted: true,
      ciphertext: raw['ciphertext'],
      iv: raw['iv']);
  test(
      'imports WebCrypto keys, decrypts history and keeps envelope for later reload',
      () async {
    final storage = <String, String>{};
    final service = MessageEncryptionService(
        read: (key) async => storage[key],
        write: (key, value) async {
          storage[key] = value;
        });
    final message = encrypted(fixture['messages'][0]);
    expect((await service.decrypt(message, 'interop-alice')).needsMessageKey,
        isTrue);
    expect(
        await service.importKeys(
            fixture['file'], fixture['password'], 'Interop-Alice'),
        1);
    for (final raw in fixture['messages']) {
      final decrypted = await service.decrypt(encrypted(raw), 'interop-alice');
      expect(decrypted.text, raw['text']);
      expect(decrypted.ciphertext, raw['ciphertext']);
      expect(decrypted.copyWith(edited: true).iv, raw['iv']);
      expect(decrypted.needsMessageKey, isFalse);
    }
    final restarted = MessageEncryptionService(
        read: (key) async => storage[key], write: (_, __) async {});
    expect((await restarted.decrypt(message, 'interop-alice')).text,
        fixture['messages'][0]['text']);
    expect(
        (await restarted.decrypt(message, 'another-account')).needsMessageKey,
        isTrue);
    final tampered = Map<String, dynamic>.from(fixture['messages'][0]);
    final bytes = base64Decode(tampered['ciphertext']);
    bytes[0] ^= 1;
    tampered['ciphertext'] = base64Encode(bytes);
    expect(
        (await restarted.decrypt(encrypted(tampered), 'interop-alice'))
            .needsMessageKey,
        isTrue);
    final aliceStorage = <String, String>{};
    final bobStorage = <String, String>{};
    final alice = MessageEncryptionService(
      read: (key) async => aliceStorage[key],
      write: (key, value) async { aliceStorage[key] = value; },
    );
    final bob = MessageEncryptionService(
      read: (key) async => bobStorage[key],
      write: (key, value) async { bobStorage[key] = value; },
    );
    final alicePublicKey = await alice.initializeIdentity('alice');
    final bobPublicKey = await bob.initializeIdentity('bob');
    final outgoing = await alice.encrypt(
      'Android → web test', 'alice', 'bob', bobPublicKey,
    );
    expect(outgoing, isNotNull);
    expect(outgoing!['isEncrypted'], isTrue);
    expect(outgoing['senderPublicKey'], alicePublicKey);
    expect(jsonDecode(outgoing['senderPublicKey'] as String)['crv'], 'P-256');
    final incoming = Message(
      id: 'round-trip',
      text: '🔒 Encrypted message',
      isFromMe: false,
      isEncrypted: true,
      ciphertext: outgoing['ciphertext'] as String,
      iv: outgoing['iv'] as String,
      senderPublicKey: alicePublicKey,
    );
    final roundTrip = await bob.decrypt(incoming, 'bob', alicePublicKey);
    expect(roundTrip.text, 'Android → web test');
    expect(roundTrip.needsMessageKey, isFalse);

    // The Android FCM background handler uses strict decryption so a missing
    // local key is diagnosed rather than silently mistaken for a bad payload.
    final notificationPreview = await bob.decryptForNotification(
      incoming,
      'bob',
      alicePublicKey,
    );
    expect(notificationPreview.text, 'Android → web test');
    expect(notificationPreview.needsMessageKey, isFalse);

    final noLocalIdentity = MessageEncryptionService(
      read: (_) async => null,
      write: (_, __) async {},
    );
    await expectLater(
      noLocalIdentity.decryptForNotification(
        incoming,
        'bob',
        alicePublicKey,
      ),
      throwsStateError,
    );
    expect(
      await alice.encrypt('message', 'alice', 'bob', '{}'),
      isNull,
    );
    expect(
        (await restarted.decrypt(
                Message(id: 'plain', text: 'hii', isFromMe: true),
                'interop-alice'))
            .text,
        'hii');
  });
  test('only encrypted ciphertext placeholders need decryption', () {
    final service = MessageEncryptionService(
      read: (_) async => null,
      write: (_, __) async {},
    );
    final encryptedMessage = Message(
      id: 'placeholder',
      text: '🔒 Encrypted message',
      isFromMe: false,
      chatId: 'peer',
      isEncrypted: true,
      ciphertext: base64Encode(List<int>.filled(16, 1)),
      iv: base64Encode(List<int>.filled(12, 2)),
    );
    expect(service.needsDecryption(encryptedMessage), isTrue);
    expect(
      service.needsDecryption(
        encryptedMessage.copyWith(text: '?? Encrypted message'),
      ),
      isTrue,
    );
    expect(
      service.needsDecryption(encryptedMessage.copyWith(text: 'Hello there')),
      isFalse,
    );
    expect(
      service.needsDecryption(
        Message(id: 'plain', text: 'Hello there', isFromMe: false),
      ),
      isFalse,
    );
  });

  test('wrong password, wrong account and unsupported format never store keys',
      () async {
    var writes = 0;
    final service = MessageEncryptionService(
        read: (_) async => null,
        write: (_, __) async {
          writes++;
        });
    await expectLater(
        service.importKeys(fixture['file'], 'wrong-password', 'interop-alice'),
        throwsFormatException);
    await expectLater(
        service.importKeys(
            fixture['file'], fixture['password'], 'other-account'),
        throwsFormatException);
    await expectLater(
        service.importKeys('{}', fixture['password'], 'interop-alice'),
        throwsFormatException);
    expect(writes, 0);
  });

  test('P-256 identity survives service recreation and rejects another account or tampered payloads', () async {
    final aliceStorage = <String, String>{};
    final bobStorage = <String, String>{};
    final malloryStorage = <String, String>{};

    MessageEncryptionService service(Map<String, String> storage) =>
        MessageEncryptionService(
          read: (key) async => storage[key],
          write: (key, value) async { storage[key] = value; },
        );

    final alice = service(aliceStorage);
    final bob = service(bobStorage);
    final alicePublicKey = await alice.initializeIdentity('Alice');
    final bobPublicKey = await bob.initializeIdentity('Bob');

    // A fresh service instance simulates an app restart on the same device.
    final restartedAlice = service(aliceStorage);
    expect(await restartedAlice.initializeIdentity('alice'), alicePublicKey);

    final encrypted = await restartedAlice.encrypt(
      'Private Android message', 'alice', 'bob', bobPublicKey,
    );
    expect(encrypted, isNotNull);
    expect(encrypted!['isEncrypted'], isTrue);
    expect(encrypted['ciphertext'], isNot('Private Android message'));
    expect(encrypted['senderPublicKey'], alicePublicKey);

    final envelope = Message(
      id: 'interop-restart',
      text: '🔒 Encrypted message',
      isFromMe: false,
      chatId: 'alice',
      isEncrypted: true,
      ciphertext: encrypted['ciphertext'] as String,
      iv: encrypted['iv'] as String,
      senderPublicKey: alicePublicKey,
    );

    expect(
      (await bob.decrypt(envelope, 'bob', alicePublicKey)).text,
      'Private Android message',
    );

    final mallory = service(malloryStorage);
    await mallory.initializeIdentity('mallory');
    expect(
      (await mallory.decrypt(envelope, 'mallory', alicePublicKey)).needsMessageKey,
      isTrue,
    );

    final tamperedCiphertext = base64Decode(encrypted['ciphertext'] as String);
    tamperedCiphertext[tamperedCiphertext.length ~/ 2] ^= 0x01;
    final tampered = Message(
      id: 'tampered',
      text: '🔒 Encrypted message',
      isFromMe: false,
      chatId: 'alice',
      isEncrypted: true,
      ciphertext: base64Encode(tamperedCiphertext),
      iv: encrypted['iv'] as String,
      senderPublicKey: alicePublicKey,
    );
    expect((await bob.decrypt(tampered, 'bob', alicePublicKey)).needsMessageKey, isTrue);
  });

  test('encrypted account recovery backup restores the same E2EE identity on a fresh device', () async {
    final originalStorage = <String, String>{};
    final restoredStorage = <String, String>{};

    MessageEncryptionService service(Map<String, String> storage) =>
        MessageEncryptionService(
          read: (key) async => storage[key],
          write: (key, value) async { storage[key] = value; },
        );

    final original = service(originalStorage);
    final originalPublicKey = await original.initializeIdentity('recover-me');
    const recoveryPassword = 'a-long-recovery-password-2026';
    final cloudEnvelope = await original.exportIdentityRecoveryBackup(
      'recover-me',
      recoveryPassword,
    );

    // The new service has no local identity, just like a cleared/reinstalled app.
    final restored = service(restoredStorage);
    expect(await restored.hasLocalIdentity('recover-me'), isFalse);
    final restoredPublicKey = await restored.restoreIdentityRecoveryBackup(
      cloudEnvelope,
      'recover-me',
      recoveryPassword,
    );
    expect(restoredPublicKey, originalPublicKey);
    expect(await restored.hasLocalIdentity('recover-me'), isTrue);

    final restarted = service(restoredStorage);
    expect(await restarted.initializeIdentity('recover-me'), originalPublicKey);

    await expectLater(
      restored.restoreIdentityRecoveryBackup(
        cloudEnvelope,
        'recover-me',
        'incorrect-recovery-password',
      ),
      throwsFormatException,
    );
    await expectLater(
      restored.exportIdentityRecoveryBackup('recover-me', 'too-short'),
      throwsFormatException,
    );
  });
}
