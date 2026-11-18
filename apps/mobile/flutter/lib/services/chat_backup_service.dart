import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';

import 'local_db_service.dart';
import 'message_encryption_service.dart';

class ChatBackupService {
  static const _iterations = 210000;
  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  static Future<bool> exportBackup({
    required String username,
    required String password,
    required MessageEncryptionService encryption,
  }) async {
    if (password.length < 8) {
      throw const FormatException('Use a backup password with at least 8 characters.');
    }
    final data = await LocalDbService.exportChatBackupData();
    if (data['username']?.toString().toLowerCase() != username.trim().toLowerCase()) {
      throw const FormatException('The active local chat account does not match the signed-in account.');
    }
    data['messageKeys'] = await encryption.exportBackupKeys(username);
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(data)),
      secretKey: key,
      nonce: nonce,
    );
    final envelope = jsonEncode({
      'format': 'novyn-chat-backup',
      'version': 1,
      'iterations': _iterations,
      'username': username.trim().toLowerCase(),
      'salt': base64Encode(salt),
      'iv': base64Encode(nonce),
      'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
    });
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save encrypted Novyn chat backup',
      fileName: 'novyn-chat-backup.json',
      bytes: Uint8List.fromList(utf8.encode(envelope)),
    );
    return result != null;
  }

  static Future<Map<String, int>?> restoreBackup({
    required String username,
    required String password,
    required MessageEncryptionService encryption,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final bytes = picked.files.single.bytes;
    if (bytes == null || bytes.length > 100 * 1024 * 1024) {
      throw const FormatException('Backup file is missing or larger than 100 MB.');
    }
    final envelope = jsonDecode(utf8.decode(bytes));
    if (envelope is! Map ||
        envelope['format'] != 'novyn-chat-backup' ||
        envelope['version'] != 1 ||
        envelope['iterations'] != _iterations) {
      throw const FormatException('This is not a supported Novyn chat backup.');
    }
    if (envelope['username']?.toString().toLowerCase() != username.trim().toLowerCase()) {
      throw const FormatException('This backup belongs to a different Novyn account.');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['iv'] as String);
    final combined = base64Decode(envelope['ciphertext'] as String);
    if (salt.length != 16 || nonce.length != 12 || combined.length < 16) {
      throw const FormatException('The backup file is damaged.');
    }
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final secretBox = SecretBox(
      combined.sublist(0, combined.length - 16),
      nonce: nonce,
      mac: Mac(combined.sublist(combined.length - 16)),
    );
    List<int> plaintext;
    try {
      plaintext = await AesGcm.with256bits().decrypt(secretBox, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const FormatException('Incorrect backup password or damaged backup.');
    }
    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map) {
      throw const FormatException('The backup contents are invalid.');
    }
    if (await LocalDbService.getAccountScope() != username.trim().toLowerCase()) {
      throw const FormatException('Sign in to the same Novyn account before restoring this backup.');
    }
    final data = Map<String, dynamic>.from(decoded);
    final keyBackup = data['messageKeys'];
    var restoredKeys = 0;
    if (keyBackup is Map) {
      restoredKeys = await encryption.importBackupKeys(
        Map<String, dynamic>.from(keyBackup), username,
      );
    }
    final counts = await LocalDbService.restoreChatBackupData(data, username);
    counts['encryptionKeys'] = restoredKeys;
    return counts;
  }
}
