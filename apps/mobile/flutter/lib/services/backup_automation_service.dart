import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'chat_backup_service.dart';
import 'backup_password_service.dart';
import 'backup_progress.dart';
import 'google_drive_backup_service.dart';
import 'message_encryption_service.dart';

/// Daily Drive backups are attempted after app launch/resume and whenever the
/// active network changes. Android and iOS may suspend terminated apps, so this
/// intentionally never promises an exact wall-clock background time.
class BackupAutomationService {
  BackupAutomationService._();

  static const _enabledKey = 'novyn_daily_backup_enabled_v1';
  static const _accountKey = 'novyn_daily_backup_account_v1';
  static const _lastSuccessKey = 'novyn_daily_backup_last_success_v1';
  static const _networkPreferenceKey = 'novyn_daily_backup_network_v1';
  static const wifiOnly = 'wifi';
  static const mobileDataOnly = 'mobile';
  static const wifiAndMobileData = 'both';

  static final ValueNotifier<BackupProgress?> progress =
      ValueNotifier<BackupProgress?>(null);
  static bool _running = false;
  static bool _cancelRequested = false;

  static Future<String> networkPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_networkPreferenceKey);
    return switch (value) {
      mobileDataOnly => mobileDataOnly,
      wifiAndMobileData => wifiAndMobileData,
      _ => wifiOnly,
    };
  }

  static Future<void> setNetworkPreference(String preference) async {
    if (![wifiOnly, mobileDataOnly, wifiAndMobileData].contains(preference)) {
      throw ArgumentError.value(preference, 'preference', 'Unsupported backup network preference.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_networkPreferenceKey, preference);
  }

  /// True only when the current link satisfies the user's selected backup
  /// network. VPN/other-only states are not considered an internet transport.
  @visibleForTesting
  static bool isNetworkAllowed(
    List<ConnectivityResult> connections,
    String preference,
  ) {
    final hasWifi = connections.contains(ConnectivityResult.wifi);
    final hasMobile = connections.contains(ConnectivityResult.mobile);
    final hasEthernet = connections.contains(ConnectivityResult.ethernet);
    return switch (preference) {
      mobileDataOnly => hasMobile,
      wifiAndMobileData => hasWifi || hasMobile || hasEthernet,
      _ => hasWifi,
    };
  }

  static Future<bool> isEnabled({String? username}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_enabledKey) != true) return false;
    final owner = username?.trim().toLowerCase();
    return owner == null || owner.isEmpty || prefs.getString(_accountKey) == owner;
  }

  static Future<DateTime?> lastSuccessfulBackup({String? username}) async {
    final prefs = await SharedPreferences.getInstance();
    final owner = username?.trim().toLowerCase();
    if (owner != null && owner.isNotEmpty && prefs.getString(_accountKey) != owner) return null;
    final raw = prefs.getString(_lastSuccessKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  static void cancelActiveBackup() {
    if (_running) _cancelRequested = true;
  }

  static void _checkCancelled() {
    if (_cancelRequested) throw const BackupCancelledException();
  }

  static void _report(
    String stage,
    int percent, {
    bool completed = false,
    bool cancelled = false,
    bool failed = false,
  }) {
    final boundedPercent = percent.clamp(0, 100).toInt();
    final previous = progress.value;
    // A large chat can contain thousands of messages and uploads stream in
    // 64 KB chunks. Throttle UI/tray refreshes to meaningful 2% changes while
    // always publishing stage transitions and terminal states.
    if (!completed &&
        previous != null &&
        !previous.completed &&
        previous.stage == stage &&
        boundedPercent - previous.percent < 2) {
      return;
    }
    progress.value = BackupProgress(
      stage: stage,
      percent: boundedPercent,
      completed: completed,
      cancelled: cancelled,
      failed: failed,
    );
  }

  static Future<T> _runTracked<T>(Future<T> Function() action) async {
    if (_running) throw StateError('A backup is already running.');
    _running = true;
    _cancelRequested = false;
    progress.value = null;
    try {
      return await action();
    } on BackupCancelledException {
      _report('Backup cancelled', 0, completed: true, cancelled: true);
      rethrow;
    } catch (error) {
      _report('Backup failed: $error', 0, completed: true, failed: true);
      rethrow;
    } finally {
      _running = false;
      _cancelRequested = false;
    }
  }

  static Future<DateTime> _createAndUpload({
    required String username,
    required String password,
    required MessageEncryptionService encryption,
    required bool interactiveDriveSignIn,
  }) async {
    final owner = username.trim().toLowerCase();
    if (owner.isEmpty || password.length < 8) {
      throw const FormatException('Enter a valid account and backup password.');
    }
    _checkCancelled();
    _report('Preparing encrypted backup', 3);
    final bytes = await ChatBackupService.createEncryptedBackup(
      username: owner,
      password: password,
      encryption: encryption,
      checkCancelled: _checkCancelled,
      onProgress: _report,
    );
    _checkCancelled();
    _report('Connecting to Google Drive', 84);
    await GoogleDriveBackupService.save(
      bytes,
      interactive: interactiveDriveSignIn,
      checkCancelled: _checkCancelled,
      onProgress: (sent, total) {
        _checkCancelled();
        final fraction = total <= 0 ? 0.0 : sent / total;
        _report('Uploading encrypted backup', 84 + (fraction * 14).round());
      },
    );
    _checkCancelled();
    await BackupPasswordService.save(owner, password);
    final now = DateTime.now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountKey, owner);
    await prefs.setString(_lastSuccessKey, now.toIso8601String());
    return now.toLocal();
  }

  /// Creates the first encrypted Drive backup interactively before enabling
  /// the daily schedule.
  static Future<DateTime> enableDaily({
    required String username,
    required String password,
    required MessageEncryptionService encryption,
  }) {
    return _runTracked(() async {
      final savedAt = await _createAndUpload(
        username: username,
        password: password,
        encryption: encryption,
        interactiveDriveSignIn: true,
      );
      _checkCancelled();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);
      _report('Daily backup enabled', 100, completed: true);
      return savedAt;
    });
  }

  /// A one-off, user-requested Drive backup. It ignores the scheduled interval
  /// and network preference because the user explicitly tapped Backup now.
  static Future<DateTime> backupNow({
    required String username,
    required String password,
    required MessageEncryptionService encryption,
  }) {
    return _runTracked(() async {
      final savedAt = await _createAndUpload(
        username: username,
        password: password,
        encryption: encryption,
        interactiveDriveSignIn: true,
      );
      _report('Backup saved to Google Drive', 100, completed: true);
      return savedAt;
    });
  }

  static Future<void> disableDaily({String? username}) async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(_accountKey) ?? '';
    final requestedOwner = username?.trim().toLowerCase();
    if (requestedOwner != null && requestedOwner.isNotEmpty && owner != requestedOwner) return;
    await prefs.setBool(_enabledKey, false);
    // Keep the saved backup passphrase: disabling the schedule must not make
    // existing encrypted backups unrecoverable or force the user to re-enter it.
  }

  /// Called after session recovery at launch/resume. Runs at most once per
  /// 24-hour interval and silently skips when offline or Drive auth expired.
  static Future<void> runIfDue({
    required String username,
    required MessageEncryptionService encryption,
  }) async {
    if (_running) return;
    try {
      await _runTracked(() => _runIfDue(
        username: username,
        encryption: encryption,
      ));
    } catch (error) {
      // A later resume/reconnect retries without blocking chat startup.
      debugPrint('[NovynBackup] Daily backup deferred: $error');
    }
  }

  static Future<void> _runIfDue({
    required String username,
    required MessageEncryptionService encryption,
  }) async {
    final owner = username.trim().toLowerCase();
    if (owner.isEmpty || !ApiService.hasAccessSessionCookie) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_enabledKey) != true ||
        prefs.getString(_accountKey) != owner) return;
    final last = DateTime.tryParse(prefs.getString(_lastSuccessKey) ?? '');
    if (last != null && DateTime.now().toUtc().difference(last) < const Duration(hours: 24)) return;
    final connections = await Connectivity().checkConnectivity();
    final preference = await networkPreference();
    if (!isNetworkAllowed(connections, preference)) return;
    final password = await BackupPasswordService.read(owner);
    if (password == null || password.length < 8) return;
    await _createAndUpload(
      username: owner,
      password: password,
      encryption: encryption,
      interactiveDriveSignIn: false,
    );
    _checkCancelled();
    debugPrint('[NovynBackup] Daily encrypted Drive backup completed.');
    _report('Automatic backup complete', 100, completed: true);
  }
}
