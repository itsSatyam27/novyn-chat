import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart';
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

/// Flutter E2EE compatible with the web client:
/// ECDH P-256 -> raw 256-bit shared secret -> AES-GCM-256.
/// The private identity is stored only in Android/iOS secure storage.
class MessageEncryptionService {
  MessageEncryptionService({KeyReader? read, KeyWriter? write})
      : _read = read ?? ((key) => _storage.read(key: key)),
        _write = write ?? ((key, value) => _storage.write(key: key, value: value));

  static const _storage = FlutterSecureStorage();
  final KeyReader _read;
  final KeyWriter _write;
  final _domain = ECDomainParameters('secp256r1');
  final _aes = AesGcm.with256bits();
  final Map<String, EcKeyPairData> _identities = {};
  final Map<String, Future<EcKeyPairData>> _identityLoads = {};
  final Map<String, List<dynamic>> _legacyKeys = {};

  String _account(String username) => username.trim().toLowerCase();

  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static List<int> _decodeB64url(String value) {
    final normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    return base64.decode(normalized.padRight((normalized.length + 3) ~/ 4 * 4, '='));
  }

  Future<EcKeyPairData> _identity(String username) async {
    final account = _account(username);
    final cached = _identities[account];
    if (cached != null) return cached;
    return _identityLoads.putIfAbsent(account, () async {
      final storageKey = 'novyn_e2ee_identity_$account';
      final raw = await _read(storageKey);
      EcKeyPairData identity;
      if (raw != null && raw.isNotEmpty) {
        try {
          final saved = jsonDecode(raw) as Map<String, dynamic>;
          identity = EcKeyPairData(
            d: _decodeB64url(saved['d'] as String),
            x: _decodeB64url(saved['x'] as String),
            y: _decodeB64url(saved['y'] as String),
            type: KeyPairType.p256,
          );
        } catch (_) {
          // Never silently replace a damaged identity: doing so would make
          // previously encrypted messages permanently unreadable.
          throw StateError('Your secure message identity is damaged. Restore your Novyn backup before resetting it.');
        }
      } else {
        final generated = await _ecdh.newKeyPair();
        identity = await generated.extract();
        await _write(storageKey, jsonEncode({
          'd': _b64url(identity.d),
          'x': _b64url(identity.x),
          'y': _b64url(identity.y),
        }));
      }
      _identities[account] = identity;
      return identity;
    });
  }

  /// Creates/loads this account's stable Flutter identity and returns its public JWK.
  Future<String> initializeIdentity(String username) async {
    final identity = await _identity(username);
    return jsonEncode({
      'kty': 'EC',
      'crv': 'P-256',
      'x': _b64url(identity.x),
      'y': _b64url(identity.y),
      'ext': true,
      'key_ops': <String>[],
    });
  }

  Future<SecretKey> _sharedKey(String username, String peerPublicKeyJwk) async {
    final identity = await _identity(username);
    final decoded = jsonDecode(peerPublicKeyJwk);
    if (decoded is! Map ||
        decoded['kty'] != 'EC' ||
        decoded['crv'] != 'P-256' ||
        decoded['x'] is! String ||
        decoded['y'] is! String) {
      throw const FormatException('The contact has an invalid encryption key.');
    }
    final peerKey = EcPublicKey(
      x: _decodeB64url(decoded['x'] as String),
      y: _decodeB64url(decoded['y'] as String),
      type: KeyPairType.p256,
    );
    final shared = await _ecdh.sharedSecretKey(
      keyPair: identity,
      remotePublicKey: peerKey,
    );
    final bytes = await shared.extractBytes();
    if (bytes.length != 32) {
      throw StateError('Could not derive a valid message encryption key.');
    }
    return SecretKey(bytes);
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
      throw const FormatException('Choose a Novyn message key file exported from the web app.');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final iv = base64Decode(envelope['iv'] as String);
    if (salt.length != 16 || iv.length != 12) {
      throw const FormatException('Invalid key file.');
    }
    final data = await compute(_openKeyFile, {'envelope': envelope, 'password': password});
    if (data['username'] != _account(username)) {
      throw const FormatException('This key file belongs to a different Novyn account.');
    }
    final identity = data['identity'] as String;
    if (!samePublicKey(identity, identity)) throw const FormatException('Invalid account message key.');
    final imported = data['keys'];
    if (imported is! List || imported.isEmpty || imported.length > 10000) {
      throw const FormatException('No message keys found.');
    }
    final merged = Map<String, dynamic>.from(await _readLegacyKeys(username));
    for (final rawEntry in imported) {
      final entry = Map<String, dynamic>.from(rawEntry as Map);
      final peer = entry['username'] as String;
      final publicKey = entry['publicKey'] as String;
      final key = entry['key'] as String;
      if (peer.isEmpty || peer != _account(peer) ||
          base64Decode(key).length != 32 ||
          !samePublicKey(publicKey, publicKey)) {
        throw const FormatException('Invalid conversation key.');
      }
      final versions = List<dynamic>.from(merged[peer] as List? ?? []);
      if (!versions.any((v) => v['key'] == key && samePublicKey(v['publicKey'], publicKey))) {
        versions.add({'publicKey': publicKey, 'key': key, 'identity': identity});
      }
      merged[peer] = versions;
    }
    await _write('novyn_message_keys_${_account(username)}', jsonEncode(merged));
    _legacyKeys[_account(username)] = merged.entries.expand((e) => e.value as List).toList();
    return imported.length;
  }

  Future<Map<String, dynamic>> _readLegacyKeys(String username) async {
    final account = _account(username);
    final raw = await _read('novyn_message_keys_$account');
    return raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<Map<String, dynamic>> exportBackupKeys(String username) async {
    final keys = await _readLegacyKeys(username);
    return {'username': _account(username), 'keys': jsonDecode(jsonEncode(keys))};
  }

  Future<int> importBackupKeys(Map<String, dynamic> backup, String username) async {
    final account = _account(username);
    if (backup['username']?.toString().toLowerCase() != account) {
      throw const FormatException('Backup encryption keys belong to a different account.');
    }
    final raw = backup['keys'];
    if (raw is! Map || raw.length > 10000) {
      throw const FormatException('Invalid conversation key backup.');
    }
    final merged = await _readLegacyKeys(account);
    var imported = 0;
    for (final entry in raw.entries) {
      final peer = entry.key.toString();
      if (peer.isEmpty || peer != _account(peer) || entry.value is! List) {
        throw const FormatException('Invalid conversation key entry.');
      }
      final versions = List<dynamic>.from(merged[peer] as List? ?? []);
      for (final rawVersion in entry.value as List) {
        if (rawVersion is! Map) throw const FormatException('Invalid conversation key version.');
        final version = Map<String, dynamic>.from(rawVersion);
        final publicKey = version['publicKey']?.toString() ?? '';
        final identity = version['identity']?.toString() ?? '';
        final key = version['key']?.toString() ?? '';
        if (!samePublicKey(publicKey, publicKey) ||
            !samePublicKey(identity, identity) ||
            base64Decode(key).length != 32) {
          throw const FormatException('Invalid conversation key material.');
        }
        if (!versions.any((existing) => existing['key'] == key &&
            samePublicKey(existing['publicKey']?.toString() ?? '', publicKey))) {
          versions.add(version);
          imported++;
        }
      }
      merged[peer] = versions;
    }
    await _write('novyn_message_keys_$account', jsonEncode(merged));
    return imported;
  }

  static SecretBox _box(String ciphertext, List<int> iv) {
    final bytes = base64Decode(ciphertext);
    if (iv.length != 12 || bytes.length < 16) {
      throw const FormatException('Invalid encrypted message.');
    }
    return SecretBox(bytes.sublist(0, bytes.length - 16),
        nonce: iv, mac: Mac(bytes.sublist(bytes.length - 16)));
  }

  /// Decrypts new ECDH messages; legacy imported AES keys remain readable.
  Future<Message> decrypt(Message message, String account, [String? peerPublicKey]) async {
    if (!message.isEncrypted || message.ciphertext == null || message.iv == null) {
      return message;
    }
    if (peerPublicKey != null && peerPublicKey.isNotEmpty) {
      try {
        final key = await _sharedKey(account, peerPublicKey);
        final bytes = await _aes.decrypt(
          _box(message.ciphertext!, base64Decode(message.iv!)),
          secretKey: key,
        );
        return message.copyWith(text: utf8.decode(bytes));
      } on SecretBoxAuthenticationError {
        // Try the legacy imported-key format below for older conversations.
      } on FormatException {
        // Invalid/unsupported key; try the legacy imported-key format.
      } catch (_) {
        // Keep the encrypted placeholder if no compatible key is available.
      }
    }
    final legacy = await _readLegacyKeys(account);
    final versions = legacy[message.chatId.toLowerCase()] as List? ?? [];
    for (final entry in versions.reversed) {
      try {
        final bytes = await _aes.decrypt(
          _box(message.ciphertext!, base64Decode(message.iv!)),
          secretKey: SecretKey(base64Decode(entry['key'])),
        );
        return message.copyWith(text: utf8.decode(bytes));
      } on SecretBoxAuthenticationError {
        continue;
      } on FormatException {
        continue;
      }
    }
    return message;
  }

  /// Encrypts using this Flutter device's ECDH identity and the peer's JWK.
  Future<Map<String, dynamic>?> encrypt(
      String text, String account, String peer, String publicKey,
      {String? accountPublicKey}) async {
    if (text.isEmpty || publicKey.isEmpty) return null;
    try {
      final key = await _sharedKey(account, publicKey);
      final box = await _aes.encrypt(utf8.encode(text), secretKey: key);
      return {
        'isEncrypted': true,
        'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
        'iv': base64Encode(box.nonce),
      };
    } catch (error) {
      debugPrint('[NovynE2EE] Encryption failed: $error');
      return null;
    }
  }
}
