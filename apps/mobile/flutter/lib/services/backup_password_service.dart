import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps backup and recovery passphrases encrypted by the platform keystore.
/// The password is device-local and is never uploaded in plaintext.
class BackupPasswordService {
  BackupPasswordService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false, migrateWithBackup: true),
  );

  static String _key(String username, {required bool identity}) {
    final account = username.trim().toLowerCase();
    if (account.isEmpty) {
      throw ArgumentError.value(username, 'username', 'Account is required.');
    }
    return 'novyn_backup_password_${identity ? 'identity' : 'chat'}_$account';
  }

  static Future<String?> read(
    String username, {
    bool identity = false,
  }) async {
    final value = await _storage.read(key: _key(username, identity: identity));
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> save(
    String username,
    String password, {
    bool identity = false,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'Password cannot be empty.');
    }
    await _storage.write(
      key: _key(username, identity: identity),
      value: password,
    );
  }

  static Future<void> forget(
    String username, {
    bool identity = false,
  }) async {
    await _storage.delete(key: _key(username, identity: identity));
  }
}
