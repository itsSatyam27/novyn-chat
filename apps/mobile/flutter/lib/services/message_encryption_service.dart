import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/export.dart' as pc;
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

/// Flutter E2EE compatible with the web client: P-256 ECDH + AES-GCM-256.
/// The private identity is stored only in platform secure storage.
class _EcdhIdentity {
  const _EcdhIdentity(this.privateKey, this.d, this.x, this.y);
  final pc.ECPrivateKey privateKey;
  final List<int> d;
  final List<int> x;
  final List<int> y;
}

class MessageEncryptionService {
  MessageEncryptionService({KeyReader? read, KeyWriter? write})
      : _read = read ?? ((key) => _storage.read(key: key)),
        _write = write ?? ((key, value) => _storage.write(key: key, value: value));

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateWithBackup: true,
    ),
  );
  final KeyReader _read;
  final KeyWriter _write;
  final _domain = pc.ECDomainParameters('secp256r1');
  final _aes = AesGcm.with256bits();
  final Map<String, _EcdhIdentity> _identities = {};
  final Map<String, Future<_EcdhIdentity>> _identityLoads = {};
  // One P-256 ECDH derivation per account identity and peer key, shared by
  // every message in that conversation.
  final Map<String, Future<SecretKey>> _sharedKeyLoads = {};

  String _account(String username) => username.trim().toLowerCase();

  /// Whether a stored encrypted message still contains a ciphertext placeholder.
  /// Successfully decrypted messages retain their encrypted envelope for reloads,
  /// but must not be decrypted again on every chat open.
  bool needsDecryption(Message message) {
    if (!message.isEncrypted ||
        message.ciphertext?.isNotEmpty != true ||
        message.iv?.isNotEmpty != true) {
      return false;
    }
    final text = message.text.trim();
    return text.isEmpty ||
        text == '?? Encrypted message' ||
        text == '🔒 Encrypted message';
  }

  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static List<int> _decodeB64url(String value) {
    final normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    return base64.decode(normalized.padRight((normalized.length + 3) ~/ 4 * 4, '='));
  }

  static List<int> _bigIntBytes(BigInt value, int length) {
    final hex = value.toRadixString(16).padLeft(length * 2, '0');
    if (hex.length > length * 2) throw const FormatException('Invalid P-256 key length.');
    return List<int>.generate(length, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
  }

  static BigInt _bytesBigInt(List<int> bytes) {
    if (bytes.length != 32) throw const FormatException('Invalid P-256 coordinate.');
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return BigInt.parse(hex, radix: 16);
  }

  pc.SecureRandom _secureRandom() {
    final source = Random.secure();
    final seed = Uint8List.fromList(List<int>.generate(32, (_) => source.nextInt(256)));
    return pc.FortunaRandom()..seed(pc.KeyParameter(seed));
  }

  Future<_EcdhIdentity> _identity(String username, {bool createIfMissing = true}) async {
    final account = _account(username);
    final cached = _identities[account];
    if (cached != null) return cached;
    final pending = _identityLoads[account];
    if (pending != null) return pending;

    final loading = () async {
      final storageKey = 'novyn_e2ee_identity_$account';
      final raw = await _read(storageKey);
      late final _EcdhIdentity identity;
      if (raw != null && raw.isNotEmpty) {
        try {
          final saved = jsonDecode(raw) as Map<String, dynamic>;
          final d = _decodeB64url(saved['d'] as String);
          final x = _decodeB64url(saved['x'] as String);
          final y = _decodeB64url(saved['y'] as String);
          if (d.length != 32 || x.length != 32 || y.length != 32) {
            throw const FormatException('Invalid P-256 identity length.');
          }
          final privateKey = pc.ECPrivateKey(_bytesBigInt(d), _domain);
          // Validate the stored public coordinates before trusting this identity.
          _domain.curve.createPoint(_bytesBigInt(x), _bytesBigInt(y));
          identity = _EcdhIdentity(privateKey, d, x, y);
        } catch (_) {
          throw StateError('Your secure message identity is damaged. Restore your Novyn backup before resetting it.');
        }
      } else {
        if (!createIfMissing) {
          throw StateError('This device has no saved Novyn message identity for this account. Sign in again to restore it before decrypting notifications.');
        }
        final generator = pc.ECKeyGenerator()
          ..init(pc.ParametersWithRandom(
            pc.ECKeyGeneratorParameters(_domain), _secureRandom()));
        final pair = generator.generateKeyPair();
        final privateKey = pair.privateKey as pc.ECPrivateKey;
        final publicKey = pair.publicKey as pc.ECPublicKey;
        final d = _bigIntBytes(privateKey.d!, 32);
        final x = _bigIntBytes(publicKey.Q!.x!.toBigInteger()!, 32);
        final y = _bigIntBytes(publicKey.Q!.y!.toBigInteger()!, 32);
        identity = _EcdhIdentity(privateKey, d, x, y);
        await _write(storageKey, jsonEncode({
          'd': _b64url(d), 'x': _b64url(x), 'y': _b64url(y),
        }));
      }
      _identities[account] = identity;
      return identity;
    }();

    _identityLoads[account] = loading;
    try {
      return await loading;
    } catch (_) {
      // Do not cache failed secure-storage reads: a later background retry
      // must be able to recover without replacing the account identity.
      _identityLoads.remove(account);
      rethrow;
    }
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

  Future<bool> hasLocalIdentity(String username) async {
    final raw = await _read('novyn_e2ee_identity_${_account(username)}');
    return raw != null && raw.isNotEmpty;
  }

  /// Encrypts this phone's E2EE identity for a browser's one-time pairing key.
  /// The server can relay this envelope but cannot decrypt the identity.
  Future<Map<String, dynamic>> exportIdentityForPairing(
    String username,
    String browserPublicKeyJwk,
  ) async {
    final identity = await _identity(username, createIfMissing: false);
    final shared = await _sharedKey(username, browserPublicKeyJwk,
        requireExistingIdentity: true);
    final random = Random.secure();
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final plaintext = utf8.encode(jsonEncode({
      'format': 'novyn-device-identity',
      'version': 1,
      'username': _account(username),
      'identity': {
        'd': _b64url(identity.d),
        'x': _b64url(identity.x),
        'y': _b64url(identity.y),
      },
    }));
    final box = await _aes.encrypt(plaintext, secretKey: shared, nonce: nonce);
    return {
      'senderPublicKey': await initializeIdentity(username),
      'iv': base64Encode(nonce),
      'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
    };
  }

  /// Creates an account-syncable identity backup. The server only receives
  /// this authenticated ciphertext; the recovery password never leaves device.
  Future<Map<String, dynamic>> exportIdentityRecoveryBackup(
      String username, String password) async {
    if (password.trim().length < 12) {
      throw const FormatException('Use a recovery password with at least 12 characters.');
    }
    final account = _account(username);
    final identity = await _identity(account);
    final publicKey = await initializeIdentity(account);
    final plaintext = jsonEncode({
      'username': account,
      'identity': {
        'd': _b64url(identity.d),
        'x': _b64url(identity.x),
        'y': _b64url(identity.y),
      },
    });
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 210000,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    return {
      'format': 'novyn-e2ee-identity',
      'version': 1,
      'iterations': 210000,
      'username': account,
      'publicKey': publicKey,
      'salt': base64Encode(salt),
      'iv': base64Encode(nonce),
      'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
    };
  }

  /// Restores the account's original ECDH identity from its encrypted cloud
  /// envelope and returns its public JWK for re-registration with friends.
  Future<String> restoreIdentityRecoveryBackup(
      Map<String, dynamic> backup, String username, String password) async {
    final account = _account(username);
    if (password.trim().length < 12 ||
        backup['format'] != 'novyn-e2ee-identity' ||
        backup['version'] != 1 ||
        backup['iterations'] != 210000 ||
        backup['username']?.toString().toLowerCase() != account) {
      throw const FormatException('This E2EE recovery backup is invalid or belongs to another account.');
    }
    final salt = base64Decode(backup['salt']?.toString() ?? '');
    final nonce = base64Decode(backup['iv']?.toString() ?? '');
    final ciphertext = base64Decode(backup['ciphertext']?.toString() ?? '');
    if (salt.length != 16 || nonce.length != 12 || ciphertext.length < 16) {
      throw const FormatException('The E2EE recovery backup is damaged.');
    }
    final opened = await compute(_openKeyFile, {
      'envelope': backup,
      'password': password,
    });
    if (opened['username']?.toString().toLowerCase() != account ||
        opened['identity'] is! Map) {
      throw const FormatException('The E2EE recovery backup contents are invalid.');
    }
    final rawIdentity = Map<String, dynamic>.from(opened['identity'] as Map);
    final d = _decodeB64url(rawIdentity['d']?.toString() ?? '');
    final x = _decodeB64url(rawIdentity['x']?.toString() ?? '');
    final y = _decodeB64url(rawIdentity['y']?.toString() ?? '');
    if (d.length != 32 || x.length != 32 || y.length != 32) {
      throw const FormatException('The E2EE recovery identity has invalid key material.');
    }
    final scalar = _bytesBigInt(d);
    if (scalar <= BigInt.zero || scalar >= _domain.n) {
      throw const FormatException('The E2EE recovery private key is invalid.');
    }
    final point = _domain.G * scalar;
    if (point == null ||
        point.x!.toBigInteger() != _bytesBigInt(x) ||
        point.y!.toBigInteger() != _bytesBigInt(y)) {
      throw const FormatException('The E2EE recovery key pair failed validation.');
    }

    final recovered = _EcdhIdentity(
      pc.ECPrivateKey(scalar, _domain),
      d,
      x,
      y,
    );
    final expectedPublicKey = jsonEncode({
      'kty': 'EC',
      'crv': 'P-256',
      'x': _b64url(x),
      'y': _b64url(y),
      'ext': true,
      'key_ops': <String>[],
    });
    final backupPublicKey = backup['publicKey']?.toString() ?? '';
    if (!samePublicKey(expectedPublicKey, backupPublicKey)) {
      throw const FormatException('The E2EE recovery public key does not match its private key.');
    }

    // Only replace the local identity after the password and key pair have
    // both been fully validated. Then evict stale in-memory identity caches.
    await _write('novyn_e2ee_identity_$account', jsonEncode({
      'd': _b64url(recovered.d),
      'x': _b64url(recovered.x),
      'y': _b64url(recovered.y),
    }));
    _identities.remove(account);
    _identityLoads.remove(account);
    _sharedKeyLoads.removeWhere((key, _) => key.startsWith('$account|'));
    final restoredPublicKey = await initializeIdentity(account);
    if (!samePublicKey(restoredPublicKey, backupPublicKey)) {
      throw StateError('The restored Novyn identity could not be verified.');
    }
    return restoredPublicKey;
  }

  Future<SecretKey> _sharedKey(
    String username,
    String peerPublicKeyJwk, {
    bool requireExistingIdentity = false,
  }) async {
    final account = _account(username);
    final identity = await _identity(
      account,
      createIfMissing: !requireExistingIdentity,
    );
    // Include the local identity's public coordinates so restoring a new
    // identity can never reuse a shared key derived from the previous one.
    final cacheKey = [
      account,
      _b64url(identity.x),
      _b64url(identity.y),
      peerPublicKeyJwk,
    ].join('|');
    final cached = _sharedKeyLoads[cacheKey];
    if (cached != null) return cached;

    final loading = _deriveSharedKey(identity, peerPublicKeyJwk);
    _sharedKeyLoads[cacheKey] = loading;
    try {
      return await loading;
    } catch (_) {
      if (identical(_sharedKeyLoads[cacheKey], loading)) {
        _sharedKeyLoads.remove(cacheKey);
      }
      rethrow;
    }
  }

  Future<SecretKey> _deriveSharedKey(
    _EcdhIdentity identity,
    String peerPublicKeyJwk,
  ) async {
    final decoded = jsonDecode(peerPublicKeyJwk);
    if (decoded is! Map ||
        decoded['kty'] != 'EC' ||
        decoded['crv'] != 'P-256' ||
        decoded['x'] is! String ||
        decoded['y'] is! String) {
      throw const FormatException('The contact has an invalid encryption key.');
    }
    final x = _decodeB64url(decoded['x'] as String);
    final y = _decodeB64url(decoded['y'] as String);
    final point = _domain.curve.createPoint(_bytesBigInt(x), _bytesBigInt(y));
    final peerKey = pc.ECPublicKey(point, _domain);
    final agreement = pc.ECDHBasicAgreement()..init(identity.privateKey);
    // WebCrypto deriveBits(P-256, 256) returns this same 32-byte big-endian X coordinate.
    final bytes = _bigIntBytes(agreement.calculateAgreement(peerKey), 32);
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
        // A background notification must never generate/replace the account's
        // E2EE identity if secure storage is temporarily unavailable.
        final key = await _sharedKey(account, peerPublicKey, requireExistingIdentity: true);
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

  /// Encrypts binary media with the same per-contact ECDH key used for messages.
  /// The returned ciphertext includes the 16-byte GCM authentication tag.
  Future<Map<String, dynamic>> encryptAttachmentBytes(
    Uint8List plaintext,
    String username,
    String peerPublicKeyJwk,
  ) async {
    if (plaintext.isEmpty) throw const FormatException('The selected attachment is empty.');
    if (peerPublicKeyJwk.isEmpty) throw const FormatException('The contact encryption key is unavailable.');
    final key = await _sharedKey(username, peerPublicKeyJwk);
    final box = await _aes.encrypt(plaintext, secretKey: key);
    return {
      'ciphertext': Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
      'iv': base64Encode(box.nonce),
      'senderPublicKey': await initializeIdentity(username),
    };
  }

  /// Decrypts an E2EE attachment for the sender or recipient using the
  /// corresponding peer public key. Authentication failures are surfaced.
  Future<Uint8List> decryptAttachmentBytes(
    Uint8List ciphertext,
    String username,
    String peerPublicKeyJwk,
    String ivBase64,
  ) async {
    if (ciphertext.length < 16) throw const FormatException('Encrypted attachment is damaged.');
    final nonce = base64Decode(ivBase64);
    if (nonce.length != 12) throw const FormatException('Encrypted attachment has an invalid nonce.');
    final bytes = ciphertext;
    final box = SecretBox(
      bytes.sublist(0, bytes.length - 16),
      nonce: nonce,
      mac: Mac(bytes.sublist(bytes.length - 16)),
    );
    final key = await _sharedKey(username, peerPublicKeyJwk, requireExistingIdentity: true);
    final clear = await _aes.decrypt(box, secretKey: key);
    return Uint8List.fromList(clear);
  }

  /// Encrypts using this Flutter device's ECDH identity and the peer's JWK.
  Future<Map<String, dynamic>?> encrypt(
      String text, String account, String peer, String publicKey,
      {String? accountPublicKey}) async {
    if (text.isEmpty || publicKey.isEmpty) return null;
    try {
      final key = await _sharedKey(account, publicKey);
      final box = await _aes.encrypt(utf8.encode(text), secretKey: key);
      final senderPublicKey = accountPublicKey ?? await initializeIdentity(account);
      return {
        'isEncrypted': true,
        'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
        'iv': base64Encode(box.nonce),
        'senderPublicKey': senderPublicKey,
      };
    } catch (error) {
      debugPrint('[NovynE2EE] Encryption failed: $error');
      return null;
    }
  }
}
