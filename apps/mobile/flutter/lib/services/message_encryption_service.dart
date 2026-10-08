import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/chat_models.dart';

typedef KeyReader = Future<String?> Function(String account);
typedef KeyWriter = Future<void> Function(String account, String value);

Future<Map<String, dynamic>> _openKeyFile(Map<String, dynamic> input) async {
  final envelope = input['envelope'] as Map;
  final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 210000, bits: 256)
      .deriveKey(secretKey: SecretKey(utf8.encode(input['password'] as String)), nonce: base64Decode(envelope['salt']));
  try {
    final plaintext = await AesGcm.with256bits().decrypt(
      MessageEncryptionService._box(envelope['ciphertext'], base64Decode(envelope['iv'])), secretKey: key);
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(plaintext)));
  } on SecretBoxAuthenticationError {
    throw const FormatException('Wrong transfer password or damaged key file.');
  }
}

/// Uses the same conversation AES-GCM keys as the original web browser.
/// Never registers a replacement identity and never sends keys to the server.
class MessageEncryptionService {
  MessageEncryptionService({KeyReader? read, KeyWriter? write})
      : _read = read ?? ((key) => _storage.read(key: key)),
        _write =
            write ?? ((key, value) => _storage.write(key: key, value: value));
  static const _storage = FlutterSecureStorage();
  final KeyReader _read;
  final KeyWriter _write;
  final _aes = AesGcm.with256bits();
  final Map<String, Map<String, dynamic>> _accounts = {};
  final Map<String, Future<Map<String, dynamic>>> _loading = {};
  String _account(String username) => username.trim().toLowerCase();
  Future<Map<String, dynamic>> _keys(String username) async {
    final account = _account(username);
    if (_accounts.containsKey(account)) return _accounts[account]!;
    return _loading.putIfAbsent(account, () async {
      final raw = await _read('novyn_message_keys_$account');
      final data = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw));
      return _accounts[account] = data;
    });
  }

  static bool samePublicKey(String a, String b) {
    try {
      final left = jsonDecode(a), right = jsonDecode(b);
      return left['kty'] == 'EC' &&
          right['kty'] == 'EC' &&
          left['crv'] == 'P-256' &&
          right['crv'] == 'P-256' &&
          left['x'] == right['x'] &&
          left['y'] == right['y'];
    } catch (_) {
      return false;
    }
  }

  Future<int> importKeys(String file, String password, String username) async {
    if (file.length > 2 * 1024 * 1024) {
      throw const FormatException('Key file is too large.');
    }
    final envelope = jsonDecode(file);
    if (envelope is! Map ||
        envelope['format'] != 'novyn-message-keys' ||
        envelope['version'] != 1 ||
        envelope['iterations'] != 210000) {
      throw const FormatException(
          'Choose a Novyn message key file exported from the web app.');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final iv = base64Decode(envelope['iv'] as String);
    if (salt.length != 16 || iv.length != 12) {
      throw const FormatException('Invalid key file.');
    }
    // Password derivation runs off the UI thread so the import dialog stays responsive.
    final data = await compute(_openKeyFile, {'envelope': envelope, 'password': password});
    if (data['username'] != _account(username)) {
      throw const FormatException(
          'This key file belongs to a different Novyn account.');
    }
    final identity = data['identity'] as String;
    if (!samePublicKey(identity, identity)) throw const FormatException('Invalid account message key.');
    final imported = data['keys'];
    if (imported is! List || imported.isEmpty || imported.length > 10000) {
      throw const FormatException('No message keys found.');
    }
    final merged = Map<String, dynamic>.from(await _keys(username));
    for (final entry in imported) {
      final peer = entry['username'] as String;
      final publicKey = entry['publicKey'] as String;
      final key = entry['key'] as String;
      if (peer.isEmpty ||
          peer != _account(peer) ||
          base64Decode(key).length != 32 ||
          !samePublicKey(publicKey, publicKey)) {
        throw const FormatException('Invalid conversation key.');
      }
      // Keep older generations for history when a contact changes devices.
      final versions = List<dynamic>.from(merged[peer] as List? ?? []);
      if (!versions.any(
          (v) => v['key'] == key && samePublicKey(v['publicKey'], publicKey))) {
        versions.add({'publicKey': publicKey, 'key': key, 'identity': identity});
      }
      merged[peer] = versions;
    }
    await _write(
        'novyn_message_keys_${_account(username)}', jsonEncode(merged));
    _accounts[_account(username)] = merged;
    return imported.length;
  }

  static SecretBox _box(String ciphertext, List<int> iv) {
    final bytes = base64Decode(ciphertext);
    if (iv.length != 12 || bytes.length < 16) {
      throw const FormatException('Invalid encrypted message.');
    }
    return SecretBox(bytes.sublist(0, bytes.length - 16),
        nonce: iv, mac: Mac(bytes.sublist(bytes.length - 16)));
  }

  Future<Message> decrypt(Message message, String account) async {
    if (!message.isEncrypted ||
        message.ciphertext == null ||
        message.iv == null) {
      return message;
    }
    final versions =
        (await _keys(account))[message.chatId.toLowerCase()] as List? ?? [];
    for (final entry in versions.reversed) {
      try {
        final bytes = await _aes.decrypt(
            _box(message.ciphertext!, base64Decode(message.iv!)),
            secretKey: SecretKey(base64Decode(entry['key'])));
        return message.copyWith(text: utf8.decode(bytes));
      } on SecretBoxAuthenticationError {
        continue;
      } on FormatException {
        continue;
      }
    }
    return message;
  }

  Future<Map<String, dynamic>?> encrypt(
      String text, String account, String peer, String publicKey, {String? accountPublicKey}) async {
    final versions = (await _keys(account))[peer.toLowerCase()] as List? ?? [];
    for (final entry in versions.reversed) {
      if (!samePublicKey(entry['publicKey'], publicKey)) continue;
      if (accountPublicKey != null && !samePublicKey(entry['identity'] ?? '', accountPublicKey)) continue;
      final box = await _aes.encrypt(utf8.encode(text),
          secretKey: SecretKey(base64Decode(entry['key'])));
      return {
        'isEncrypted': true,
        'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
        'iv': base64Encode(box.nonce)
      };
    }
    return null;
  }
}
