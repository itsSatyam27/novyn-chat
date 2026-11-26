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
    final currentKey = _key(username, identity: identity);
    final value = await _storage.read(key: currentKey);
    if (value != null && value.isNotEmpty) return value;

    // Migrate passwords saved by the original daily-backup implementation.
    // That version used this key only for automatic backups.
    if (!identity) {
      final account = username.trim().toLowerCase();
      final legacyKey = 'novyn_daily_backup_password_$account';
      final legacyValue = await _storage.read(key: legacyKey);
      if (legacyValue != null && legacyValue.isNotEmpty) {
        await _storage.write(key: currentKey, value: legacyValue);
        await _storage.delete(key: legacyKey);
        return legacyValue;
      }
    }
    return null;
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
