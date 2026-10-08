import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
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
    final outgoing = await restarted.encrypt('Android → web test',
        'interop-alice', 'interop-bob', fixture['peerPublicKey']);
    expect(outgoing, isNotNull);
    final ciphertext = base64Decode(outgoing!['ciphertext']);
    final plaintext = await AesGcm.with256bits().decrypt(
        SecretBox(ciphertext.sublist(0, ciphertext.length - 16),
            nonce: base64Decode(outgoing['iv']),
            mac: Mac(ciphertext.sublist(ciphertext.length - 16))),
        secretKey: SecretKey(base64Decode(fixture['sharedKey'])));
    expect(utf8.decode(plaintext), 'Android → web test');
    expect(
        await restarted.encrypt(
            'message', 'interop-alice', 'interop-bob', '{}'),
        isNull);
    expect(
        (await restarted.decrypt(
                Message(id: 'plain', text: 'hii', isFromMe: true),
                'interop-alice'))
            .text,
        'hii');
  }, timeout: const Timeout(Duration(minutes: 2)));
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
  }, timeout: const Timeout(Duration(minutes: 2)));
}
