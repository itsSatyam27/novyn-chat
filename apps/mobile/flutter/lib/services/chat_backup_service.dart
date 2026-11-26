import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import 'local_db_service.dart';
import 'message_encryption_service.dart';

class ChatBackupService {
  static const _iterations = 210000;
  static const _maxBackupBytes = 100 * 1024 * 1024;
  // The JSON envelope base64-encodes media, then the AES ciphertext is
  // base64-encoded too. Keep raw media below 45 MB to stay under the 100 MB
  // Drive/file envelope limit after both expansions and metadata.
  static const _maxMediaBytes = 45 * 1024 * 1024;
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
    final envelope = await createEncryptedBackup(
      username: username,
      password: password,
      encryption: encryption,
    );
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save encrypted Novyn chat backup',
      fileName: 'novyn-chat-backup.json',
      bytes: envelope,
    );
    return result != null;
  }

  static Future<Uint8List> createEncryptedBackup({
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
    await _includeMedia(data);
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
    if (utf8.encode(envelope).length > _maxBackupBytes) {
      throw const FormatException(
        'This backup is larger than 100 MB. Remove some media and try again.',
      );
    }
    return Uint8List.fromList(utf8.encode(envelope));
  }

  static Future<void> _includeMedia(Map<String, dynamic> data) async {
    final messages = data['messages'];
    if (messages is! List) return;
    final mediaFiles = <String, dynamic>{};
    var totalBytes = 0;
    for (final raw in messages) {
      if (raw is! Map || raw['attachment'] is! Map) continue;
      final message = Map<String, dynamic>.from(raw);
      final attachment = Map<String, dynamic>.from(message['attachment'] as Map);
      final messageId = message['id']?.toString() ?? '';
      if (messageId.isEmpty) continue;
      final filename = attachment['name']?.toString() ?? 'attachment';
      Uint8List bytes;
      final cachedPath = attachment['backupLocalPath']?.toString() ?? '';
      if (cachedPath.isNotEmpty && await File(cachedPath).exists()) {
        bytes = await File(cachedPath).readAsBytes();
      } else {
        final url = attachment['url']?.toString() ?? '';
        if (url.isEmpty) continue;
        bytes = await ApiService.downloadMediaBytes(url);
      }
      totalBytes += bytes.length;
      if (totalBytes > _maxMediaBytes) {
        throw const FormatException(
          'Chat media exceeds the 45 MB backup limit. Back up fewer or smaller media files.',
        );
      }
      mediaFiles[messageId] = {
        'name': filename,
        'mime': attachment['mime']?.toString() ?? 'application/octet-stream',
        'bytes': base64Encode(bytes),
      };
    }
    data['mediaFiles'] = mediaFiles;
  }

  static Future<Uint8List?> pickBackupFileBytes() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final bytes = picked.files.single.bytes;
    if (bytes == null || bytes.isEmpty || bytes.length > _maxBackupBytes) {
      throw const FormatException('Backup file is missing or larger than 100 MB.');
    }
    return bytes;
  }

  static Future<Map<String, int>?> restoreBackup({
    required String username,
    required String password,
    required MessageEncryptionService encryption,
  }) async {
    final bytes = await pickBackupFileBytes();
    if (bytes == null) return null;
    return restoreBackupBytes(
      bytes: bytes,
      username: username,
      password: password,
      encryption: encryption,
    );
  }

  static Future<Map<String, int>> restoreBackupBytes({
    required Uint8List bytes,
    required String username,
    required String password,
    required MessageEncryptionService encryption,
  }) async {
    if (bytes.length > 100 * 1024 * 1024) {
      throw const FormatException('Backup file is larger than 100 MB.');
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
    final restoredMedia = await _restoreMedia(data, username);
    final counts = await LocalDbService.restoreChatBackupData(data, username);
    counts['encryptionKeys'] = restoredKeys;
    counts['mediaFiles'] = restoredMedia;
    return counts;
  }

  static Future<int> _restoreMedia(
    Map<String, dynamic> data,
    String username,
  ) async {
    final rawMedia = data['mediaFiles'];
    final rawMessages = data['messages'];
    if (rawMedia == null) return 0;
    if (rawMedia is! Map || rawMessages is! List || rawMedia.length > 200000) {
      throw const FormatException('The backup media index is invalid.');
    }
    final mediaRoot = await getApplicationDocumentsDirectory();
    final accountDir = Directory('${mediaRoot.path}/Novyn Backups/${_safeName(username)}');
    await accountDir.create(recursive: true);
    var totalBytes = 0;
    var restoredFiles = 0;
    for (var index = 0; index < rawMessages.length; index++) {
      final raw = rawMessages[index];
      if (raw is! Map || raw['id'] == null || raw['attachment'] is! Map) continue;
      final message = Map<String, dynamic>.from(raw);
      final id = message['id'].toString();
      final fileEntry = rawMedia[id];
      if (fileEntry is! Map || fileEntry['bytes'] is! String) continue;
      final bytes = base64Decode(fileEntry['bytes'] as String);
      totalBytes += bytes.length;
      if (totalBytes > _maxMediaBytes) {
        throw const FormatException('The backup contains more than 45 MB of media.');
      }
      final attachment = Map<String, dynamic>.from(message['attachment'] as Map);
      final name = _safeName(fileEntry['name']?.toString() ?? 'attachment');
      final target = File('${accountDir.path}/${_safeName(id)}_$name');
      await target.writeAsBytes(bytes, flush: true);
      attachment['backupLocalPath'] = target.path;
      message['attachment'] = attachment;
      rawMessages[index] = message;
      restoredFiles++;
    }
    return restoredFiles;
  }

  static String _safeName(String value) => value
      .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
}
