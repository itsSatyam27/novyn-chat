import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/message_encryption_service.dart';

void main() {
  test('E2EE attachment bytes round-trip between contact identities and reject tampering', () async {
    final aliceStorage = <String, String>{};
    final bobStorage = <String, String>{};
    MessageEncryptionService service(Map<String, String> storage) =>
        MessageEncryptionService(
          read: (key) async => storage[key],
          write: (key, value) async { storage[key] = value; },
        );
    final alice = service(aliceStorage);
    final bob = service(bobStorage);
    final alicePublicKey = await alice.initializeIdentity('alice');
    final bobPublicKey = await bob.initializeIdentity('bob');
    final original = Uint8List.fromList(
      List<int>.generate(4096, (index) => (index * 37) % 256),
    );

    final encrypted = await alice.encryptAttachmentBytes(
      original, 'alice', bobPublicKey,
    );
    final ciphertext = encrypted['ciphertext'] as Uint8List;
    expect(ciphertext, isNot(equals(original)));
    expect(ciphertext.length, original.length + 16);
    expect(encrypted['senderPublicKey'], alicePublicKey);

    final decryptedByBob = await bob.decryptAttachmentBytes(
      ciphertext, 'bob', alicePublicKey, encrypted['iv'] as String,
    );
    expect(decryptedByBob, orderedEquals(original));

    final decryptedByAlice = await alice.decryptAttachmentBytes(
      ciphertext, 'alice', bobPublicKey, encrypted['iv'] as String,
    );
    expect(decryptedByAlice, orderedEquals(original));

    final tampered = Uint8List.fromList(ciphertext);
    tampered[12] = tampered[12] ^ 0x01;
    await expectLater(
      bob.decryptAttachmentBytes(
        tampered, 'bob', alicePublicKey, encrypted['iv'] as String,
      ),
      throwsA(anything),
    );
  });
}
