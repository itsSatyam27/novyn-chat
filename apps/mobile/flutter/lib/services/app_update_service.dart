import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

const String _releasesApi =
    'https://api.github.com/repos/itsSatyam27/novyn-chat/releases/latest';
const String _arm64ApkName = 'Novyn-Android-ARM64.apk';
const String _updateTaskName = 'novyn_periodic_update_check';
const String _lastNotifiedBuildKey = 'novyn_last_notified_update_build';

@pragma('vm:entry-point')
void novynUpdateCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    ui.DartPluginRegistrant.ensureInitialized();
    if (task != _updateTaskName) return true;
    try {
      await AppUpdateService.instance.checkForUpdates(
        notifyIfAvailable: true,
        isBackgroundCheck: true,
      );
      return true;
    } catch (error) {
      debugPrint('[NovynUpdates] Background check failed: ' + error.toString());
      return false;
    }
  });
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.build,
    required this.url,
    required this.sha256,
    required this.size,
  });

  final int build;
  final String url;
  final String sha256;
  final int size;

  String get key => build.toString() + ':' + sha256;
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.installedBuild,
    required this.buildNumber,
    required this.release,
    required this.upToDate,
    this.message,
  });

  final int installedBuild;
  final String buildNumber;
  final AppUpdateInfo? release;
  final bool upToDate;
  final String? message;
}

class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();
  static const String displayVersion = 'Beta v1.0';

  static const Duration backgroundCheckFrequency = Duration(hours: 12);

  AppUpdateInfo? _currentRelease;
  Future<void>? _downloadFuture;
  String? _activeDownloadKey;
  bool isDownloading = false;
  double downloadProgress = 0;
  int downloadedBytes = 0;
  int expectedBytes = 0;
  bool hasPartialDownload = false;
  String? downloadedApkPath;
  String? downloadError;

  static Future<void> initializeBackgroundChecks() async {
    await Workmanager().initialize(
      novynUpdateCallbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    await Workmanager().registerPeriodicTask(
      'novyn-periodic-update-check',
      _updateTaskName,
      frequency: backgroundCheckFrequency,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<AppUpdateCheckResult> checkForUpdates({
    bool notifyIfAvailable = false,
    bool isBackgroundCheck = false,
  }) async {
    final installedInfo = await PackageInfo.fromPlatform();
    final installedBuild = int.tryParse(installedInfo.buildNumber) ?? 0;
    final response = await http
        .get(
          Uri.parse(_releasesApi),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Novyn-Android-Updater',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 404) {
      return AppUpdateCheckResult(
        installedBuild: installedBuild,
        buildNumber: installedInfo.buildNumber,
        release: null,
        upToDate: false,
        message: 'No public Android release is available yet.',
      );
    }
    if (response.statusCode != 200) {
      throw const FormatException('Update service is unavailable.');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['draft'] == true) {
      throw const FormatException('The latest release metadata is invalid.');
    }
    final tag = (decoded['tag_name'] ?? '').toString();
    final match = RegExp(r'^novyn-arm64-build-(\d+)(?:-\d+)*
      throw const FormatException(
        'The latest release is not a supported ARM64 build.',
      );
    }
    final build = int.parse(match.group(1)!);
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('Release assets are missing.');
    }

    Map? asset;
    for (final item in assets) {
      if (item is Map && item['name'] == _arm64ApkName) {
        asset = item;
        break;
      }
    }
    if (asset == null) {
      throw const FormatException('The ARM64 APK is missing.');
    }

    final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
    final digest = (asset['digest'] ?? '').toString();
    final size = int.tryParse((asset['size'] ?? '').toString());
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.contains('/itsSatyam27/novyn-chat/releases/download/') ||
        !url.path.endsWith('/' + _arm64ApkName) ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size == null ||
        size < 10 * 1024 * 1024 ||
        size > 100 * 1024 * 1024) {
      throw const FormatException('ARM64 APK metadata failed validation.');
    }

    if (build <= installedBuild) {
      return AppUpdateCheckResult(
        installedBuild: installedBuild,
        buildNumber: installedInfo.buildNumber,
        release: null,
        upToDate: true,
        message: 'You are up to date. Novyn is running the latest ARM64 release.',
      );
    }

    final release = AppUpdateInfo(
      build: build,
      url: url.toString(),
      sha256: digest.substring(7).toLowerCase(),
      size: size,
    );
    await prepareForUpdate(release);
    if (notifyIfAvailable) {
      await _notifyIfNewBuild(release, isBackgroundCheck: isBackgroundCheck);
    }
    return AppUpdateCheckResult(
      installedBuild: installedBuild,
      buildNumber: installedInfo.buildNumber,
      release: release,
      upToDate: false,
      message: 'A new ARM64 update is available.',
    );
  }

  Future<void> _notifyIfNewBuild(AppUpdateInfo release, {required bool isBackgroundCheck}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastNotified = prefs.getInt(_lastNotifiedBuildKey) ?? 0;
    if (release.build <= lastNotified) return;

    // Persist first so foreground/resume and WorkManager checks do not race
    // and show duplicate alerts for the same release.
    await prefs.setInt(_lastNotifiedBuildKey, release.build);
    try {
      if (isBackgroundCheck) {
        await _showBackgroundUpdateNotification();
      } else {
        await NotificationService.showAppUpdateAvailable();
      }
    } catch (error) {
      await prefs.setInt(_lastNotifiedBuildKey, lastNotified);
      debugPrint('[NovynUpdates] Could not show update notification: ' + error.toString());
    }
  }


  Future<void> _showBackgroundUpdateNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_app_updates',
        'App updates',
        description: 'Notifications when a new Novyn version is available',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await plugin.show(
      781205,
      'A new Novyn version is available',
      'Tap to open About Novyn and check for updates.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription: 'Notifications when a new Novyn version is available',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  Future<void> prepareForUpdate(AppUpdateInfo release) async {
    final runningDownload = _downloadFuture;
    if (runningDownload != null && _activeDownloadKey != release.key) {
      await runningDownload;
    }
    _currentRelease = release;
    final key = release.key;
    if (_activeDownloadKey == key &&
        (isDownloading || downloadedApkPath != null || hasPartialDownload)) {
      return;
    }

    _activeDownloadKey = key;
    isDownloading = false;
    downloadProgress = 0;
    downloadedBytes = 0;
    expectedBytes = release.size;
    hasPartialDownload = false;
    downloadedApkPath = null;
    downloadError = null;

    final directory = await getApplicationSupportDirectory();
    final completeFile = _completeFile(directory.path, release);
    final partialFile = _partialFile(directory.path, release);

    if (await completeFile.exists()) {
      final length = await completeFile.length();
      if (length == release.size) {
        final digest = await sha256.bind(completeFile.openRead()).first;
        if (digest.toString() == release.sha256) {
          downloadedApkPath = completeFile.path;
          downloadedBytes = length;
          downloadProgress = 1;
          notifyListeners();
          return;
        }
      }
      await completeFile.delete();
    }

    if (await partialFile.exists()) {
      final length = await partialFile.length();
      if (length > release.size) {
        await partialFile.delete();
      } else if (length > 0) {
        downloadedBytes = length;
        downloadProgress = length / release.size;
        hasPartialDownload = true;
      }
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    final release = _currentRelease;
    if (release == null || downloadedApkPath != null) return;
    final running = _downloadFuture;
    if (running != null) {
      await running;
      return;
    }

    final task = _performDownload(release);
    _downloadFuture = task;
    try {
      await task;
    } finally {
      if (identical(_downloadFuture, task)) {
        _downloadFuture = null;
      }
    }
  }

  Future<void> _performDownload(AppUpdateInfo release) async {
    isDownloading = true;
    downloadError = null;
    expectedBytes = release.size;
    notifyListeners();

    final client = http.Client();
    File? partialFile;

    try {
      final directory = await getApplicationSupportDirectory();
      final partial = _partialFile(directory.path, release);
      final complete = _completeFile(directory.path, release);
      partialFile = partial;

      var offset = await partial.exists() ? await partial.length() : 0;
      if (offset > release.size) {
        await partial.delete();
        offset = 0;
      }

      if (offset == release.size) {
        await _verifyAndFinalize(partial, complete, release);
        return;
      }

      final request = http.Request('GET', Uri.parse(release.url));
      if (offset > 0) {
        request.headers['Range'] = 'bytes=' + offset.toString() + '-';
      }
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (offset > 0 && response.statusCode == 206) {
        final contentRange = response.headers['content-range'] ?? '';
        final rangeMatch = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(contentRange);
        if (rangeMatch == null ||
            int.parse(rangeMatch.group(1)!) != offset ||
            int.parse(rangeMatch.group(3)!) != release.size) {
          throw const FormatException('The server returned an invalid resume range.');
        }
      } else if (response.statusCode == 200) {
        // Some CDNs ignore Range. Start clean rather than appending the full
        // file to an existing partial APK.
        offset = 0;
        await partial.writeAsBytes(const <int>[], flush: true);
      } else {
        throw FormatException(
          'APK download returned HTTP ' + response.statusCode.toString() + '.',
        );
      }

      final sink = await partial.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          await sink.writeFrom(chunk);
          received += chunk.length;
          downloadedBytes = received;
          downloadProgress = (received / release.size).clamp(0.0, 1.0).toDouble();
          hasPartialDownload = received > 0;
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      await _verifyAndFinalize(partial, complete, release);
    } catch (error) {
      final partial = partialFile;
      final length = partial != null && await partial.exists() ? await partial.length() : 0;
      downloadedBytes = length;
      downloadProgress = release.size == 0 ? 0.0 : (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError = length > 0
          ? 'Download paused. Your progress is saved; tap Resume download to continue.'
          : 'Download failed. Check your connection and try again.';
      debugPrint('[NovynUpdates] Download error: ' + error.toString());
    } finally {
      client.close();
      isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _verifyAndFinalize(
    File partialFile,
    File completeFile,
    AppUpdateInfo release,
  ) async {
    final length = await partialFile.length();
    if (length != release.size) {
      downloadedBytes = length;
      downloadProgress = (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError =
          'Download paused. Your progress is saved; tap Resume download to continue.';
      return;
    }

    final digest = await sha256.bind(partialFile.openRead()).first;
    if (digest.toString() != release.sha256) {
      await partialFile.delete();
      downloadedBytes = 0;
      downloadProgress = 0;
      hasPartialDownload = false;
      downloadError = 'APK checksum verification failed. Please download it again.';
      return;
    }

    if (await completeFile.exists()) {
      await completeFile.delete();
    }
    final savedFile = await partialFile.rename(completeFile.path);
    downloadedApkPath = savedFile.path;
    downloadedBytes = release.size;
    downloadProgress = 1;
    hasPartialDownload = false;
    downloadError = null;
  }

  File _partialFile(String directory, AppUpdateInfo release) {
    return File(
      directory +
          '/novyn-arm64-' +
          release.build.toString() +
          '-' +
          release.sha256.substring(0, 12) +
          '.apk.part',
    );
  }

  File _completeFile(String directory, AppUpdateInfo release) {
    // MainActivity's installer accepts this exact verified APK filename.
    return File(directory + '/' + _arm64ApkName);
  }
}
)
        .firstMatch(tag);
    if (match == null) {
      throw const FormatException(
        'The latest release is not a supported ARM64 build.',
      );
    }
    final build = int.parse(match.group(1)!);
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('Release assets are missing.');
    }

    Map? asset;
    for (final item in assets) {
      if (item is Map && item['name'] == _arm64ApkName) {
        asset = item;
        break;
      }
    }
    if (asset == null) {
      throw const FormatException('The ARM64 APK is missing.');
    }

    final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
    final digest = (asset['digest'] ?? '').toString();
    final size = int.tryParse((asset['size'] ?? '').toString());
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.contains('/itsSatyam27/novyn-chat/releases/download/') ||
        !url.path.endsWith('/' + _arm64ApkName) ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size == null ||
        size < 10 * 1024 * 1024 ||
        size > 100 * 1024 * 1024) {
      throw const FormatException('ARM64 APK metadata failed validation.');
    }

    if (build <= installedBuild) {
      return AppUpdateCheckResult(
        installedBuild: installedBuild,
        buildNumber: installedInfo.buildNumber,
        release: null,
        upToDate: true,
        message: 'You are up to date. Novyn is running the latest ARM64 release.',
      );
    }

    final release = AppUpdateInfo(
      build: build,
      url: url.toString(),
      sha256: digest.substring(7).toLowerCase(),
      size: size,
    );
    await prepareForUpdate(release);
    if (notifyIfAvailable) {
      await _notifyIfNewBuild(release, isBackgroundCheck: isBackgroundCheck);
    }
    return AppUpdateCheckResult(
      installedBuild: installedBuild,
      buildNumber: installedInfo.buildNumber,
      release: release,
      upToDate: false,
      message: 'A new ARM64 update is available.',
    );
  }

  Future<void> _notifyIfNewBuild(AppUpdateInfo release, {required bool isBackgroundCheck}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastNotified = prefs.getInt(_lastNotifiedBuildKey) ?? 0;
    if (release.build <= lastNotified) return;

    // Persist first so foreground/resume and WorkManager checks do not race
    // and show duplicate alerts for the same release.
    await prefs.setInt(_lastNotifiedBuildKey, release.build);
    try {
      if (isBackgroundCheck) {
        await _showBackgroundUpdateNotification();
      } else {
        await NotificationService.showAppUpdateAvailable();
      }
    } catch (error) {
      await prefs.setInt(_lastNotifiedBuildKey, lastNotified);
      debugPrint('[NovynUpdates] Could not show update notification: ' + error.toString());
    }
  }


  Future<void> _showBackgroundUpdateNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_app_updates',
        'App updates',
        description: 'Notifications when a new Novyn version is available',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await plugin.show(
      781205,
      'A new Novyn version is available',
      'Tap to open About Novyn and check for updates.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription: 'Notifications when a new Novyn version is available',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  Future<void> prepareForUpdate(AppUpdateInfo release) async {
    final runningDownload = _downloadFuture;
    if (runningDownload != null && _activeDownloadKey != release.key) {
      await runningDownload;
    }
    _currentRelease = release;
    final key = release.key;
    if (_activeDownloadKey == key &&
        (isDownloading || downloadedApkPath != null || hasPartialDownload)) {
      return;
    }

    _activeDownloadKey = key;
    isDownloading = false;
    downloadProgress = 0;
    downloadedBytes = 0;
    expectedBytes = release.size;
    hasPartialDownload = false;
    downloadedApkPath = null;
    downloadError = null;

    final directory = await getApplicationSupportDirectory();
    final completeFile = _completeFile(directory.path, release);
    final partialFile = _partialFile(directory.path, release);

    if (await completeFile.exists()) {
      final length = await completeFile.length();
      if (length == release.size) {
        final digest = await sha256.bind(completeFile.openRead()).first;
        if (digest.toString() == release.sha256) {
          downloadedApkPath = completeFile.path;
          downloadedBytes = length;
          downloadProgress = 1;
          notifyListeners();
          return;
        }
      }
      await completeFile.delete();
    }

    if (await partialFile.exists()) {
      final length = await partialFile.length();
      if (length > release.size) {
        await partialFile.delete();
      } else if (length > 0) {
        downloadedBytes = length;
        downloadProgress = length / release.size;
        hasPartialDownload = true;
      }
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    final release = _currentRelease;
    if (release == null || downloadedApkPath != null) return;
    final running = _downloadFuture;
    if (running != null) {
      await running;
      return;
    }

    final task = _performDownload(release);
    _downloadFuture = task;
    try {
      await task;
    } finally {
      if (identical(_downloadFuture, task)) {
        _downloadFuture = null;
      }
    }
  }

  Future<void> _performDownload(AppUpdateInfo release) async {
    isDownloading = true;
    downloadError = null;
    expectedBytes = release.size;
    notifyListeners();

    final client = http.Client();
    File? partialFile;

    try {
      final directory = await getApplicationSupportDirectory();
      final partial = _partialFile(directory.path, release);
      final complete = _completeFile(directory.path, release);
      partialFile = partial;

      var offset = await partial.exists() ? await partial.length() : 0;
      if (offset > release.size) {
        await partial.delete();
        offset = 0;
      }

      if (offset == release.size) {
        await _verifyAndFinalize(partial, complete, release);
        return;
      }

      final request = http.Request('GET', Uri.parse(release.url));
      if (offset > 0) {
        request.headers['Range'] = 'bytes=' + offset.toString() + '-';
      }
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (offset > 0 && response.statusCode == 206) {
        final contentRange = response.headers['content-range'] ?? '';
        final rangeMatch = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(contentRange);
        if (rangeMatch == null ||
            int.parse(rangeMatch.group(1)!) != offset ||
            int.parse(rangeMatch.group(3)!) != release.size) {
          throw const FormatException('The server returned an invalid resume range.');
        }
      } else if (response.statusCode == 200) {
        // Some CDNs ignore Range. Start clean rather than appending the full
        // file to an existing partial APK.
        offset = 0;
        await partial.writeAsBytes(const <int>[], flush: true);
      } else {
        throw FormatException(
          'APK download returned HTTP ' + response.statusCode.toString() + '.',
        );
      }

      final sink = await partial.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          await sink.writeFrom(chunk);
          received += chunk.length;
          downloadedBytes = received;
          downloadProgress = (received / release.size).clamp(0.0, 1.0).toDouble();
          hasPartialDownload = received > 0;
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      await _verifyAndFinalize(partial, complete, release);
    } catch (error) {
      final partial = partialFile;
      final length = partial != null && await partial.exists() ? await partial.length() : 0;
      downloadedBytes = length;
      downloadProgress = release.size == 0 ? 0.0 : (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError = length > 0
          ? 'Download paused. Your progress is saved; tap Resume download to continue.'
          : 'Download failed. Check your connection and try again.';
      debugPrint('[NovynUpdates] Download error: ' + error.toString());
    } finally {
      client.close();
      isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _verifyAndFinalize(
    File partialFile,
    File completeFile,
    AppUpdateInfo release,
  ) async {
    final length = await partialFile.length();
    if (length != release.size) {
      downloadedBytes = length;
      downloadProgress = (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError =
          'Download paused. Your progress is saved; tap Resume download to continue.';
      return;
    }

    final digest = await sha256.bind(partialFile.openRead()).first;
    if (digest.toString() != release.sha256) {
      await partialFile.delete();
      downloadedBytes = 0;
      downloadProgress = 0;
      hasPartialDownload = false;
      downloadError = 'APK checksum verification failed. Please download it again.';
      return;
    }

    if (await completeFile.exists()) {
      await completeFile.delete();
    }
    final savedFile = await partialFile.rename(completeFile.path);
    downloadedApkPath = savedFile.path;
    downloadedBytes = release.size;
    downloadProgress = 1;
    hasPartialDownload = false;
    downloadError = null;
  }

  File _partialFile(String directory, AppUpdateInfo release) {
    return File(
      directory +
          '/novyn-arm64-' +
          release.build.toString() +
          '-' +
          release.sha256.substring(0, 12) +
          '.apk.part',
    );
  }

  File _completeFile(String directory, AppUpdateInfo release) {
    // MainActivity's installer accepts this exact verified APK filename.
    return File(directory + '/' + _arm64ApkName);
  }
}
).firstMatch(tag);
    if (match == null) {
      throw const FormatException(
        'The latest release is not a supported ARM64 build.',
      );
    }
    final build = int.parse(match.group(1)!);
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('Release assets are missing.');
    }

    Map? asset;
    for (final item in assets) {
      if (item is Map && item['name'] == _arm64ApkName) {
        asset = item;
        break;
      }
    }
    if (asset == null) {
      throw const FormatException('The ARM64 APK is missing.');
    }

    final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
    final digest = (asset['digest'] ?? '').toString();
    final size = int.tryParse((asset['size'] ?? '').toString());
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.contains('/itsSatyam27/novyn-chat/releases/download/') ||
        !url.path.endsWith('/' + _arm64ApkName) ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size == null ||
        size < 10 * 1024 * 1024 ||
        size > 100 * 1024 * 1024) {
      throw const FormatException('ARM64 APK metadata failed validation.');
    }

    if (build <= installedBuild) {
      return AppUpdateCheckResult(
        installedBuild: installedBuild,
        buildNumber: installedInfo.buildNumber,
        release: null,
        upToDate: true,
        message: 'You are up to date. Novyn is running the latest ARM64 release.',
      );
    }

    final release = AppUpdateInfo(
      build: build,
      url: url.toString(),
      sha256: digest.substring(7).toLowerCase(),
      size: size,
    );
    await prepareForUpdate(release);
    if (notifyIfAvailable) {
      await _notifyIfNewBuild(release, isBackgroundCheck: isBackgroundCheck);
    }
    return AppUpdateCheckResult(
      installedBuild: installedBuild,
      buildNumber: installedInfo.buildNumber,
      release: release,
      upToDate: false,
      message: 'A new ARM64 update is available.',
    );
  }

  Future<void> _notifyIfNewBuild(AppUpdateInfo release, {required bool isBackgroundCheck}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastNotified = prefs.getInt(_lastNotifiedBuildKey) ?? 0;
    if (release.build <= lastNotified) return;

    // Persist first so foreground/resume and WorkManager checks do not race
    // and show duplicate alerts for the same release.
    await prefs.setInt(_lastNotifiedBuildKey, release.build);
    try {
      if (isBackgroundCheck) {
        await _showBackgroundUpdateNotification();
      } else {
        await NotificationService.showAppUpdateAvailable();
      }
    } catch (error) {
      await prefs.setInt(_lastNotifiedBuildKey, lastNotified);
      debugPrint('[NovynUpdates] Could not show update notification: ' + error.toString());
    }
  }


  Future<void> _showBackgroundUpdateNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_app_updates',
        'App updates',
        description: 'Notifications when a new Novyn version is available',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await plugin.show(
      781205,
      'A new Novyn version is available',
      'Tap to open About Novyn and check for updates.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription: 'Notifications when a new Novyn version is available',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  Future<void> prepareForUpdate(AppUpdateInfo release) async {
    final runningDownload = _downloadFuture;
    if (runningDownload != null && _activeDownloadKey != release.key) {
      await runningDownload;
    }
    _currentRelease = release;
    final key = release.key;
    if (_activeDownloadKey == key &&
        (isDownloading || downloadedApkPath != null || hasPartialDownload)) {
      return;
    }

    _activeDownloadKey = key;
    isDownloading = false;
    downloadProgress = 0;
    downloadedBytes = 0;
    expectedBytes = release.size;
    hasPartialDownload = false;
    downloadedApkPath = null;
    downloadError = null;

    final directory = await getApplicationSupportDirectory();
    final completeFile = _completeFile(directory.path, release);
    final partialFile = _partialFile(directory.path, release);

    if (await completeFile.exists()) {
      final length = await completeFile.length();
      if (length == release.size) {
        final digest = await sha256.bind(completeFile.openRead()).first;
        if (digest.toString() == release.sha256) {
          downloadedApkPath = completeFile.path;
          downloadedBytes = length;
          downloadProgress = 1;
          notifyListeners();
          return;
        }
      }
      await completeFile.delete();
    }

    if (await partialFile.exists()) {
      final length = await partialFile.length();
      if (length > release.size) {
        await partialFile.delete();
      } else if (length > 0) {
        downloadedBytes = length;
        downloadProgress = length / release.size;
        hasPartialDownload = true;
      }
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    final release = _currentRelease;
    if (release == null || downloadedApkPath != null) return;
    final running = _downloadFuture;
    if (running != null) {
      await running;
      return;
    }

    final task = _performDownload(release);
    _downloadFuture = task;
    try {
      await task;
    } finally {
      if (identical(_downloadFuture, task)) {
        _downloadFuture = null;
      }
    }
  }

  Future<void> _performDownload(AppUpdateInfo release) async {
    isDownloading = true;
    downloadError = null;
    expectedBytes = release.size;
    notifyListeners();

    final client = http.Client();
    File? partialFile;

    try {
      final directory = await getApplicationSupportDirectory();
      final partial = _partialFile(directory.path, release);
      final complete = _completeFile(directory.path, release);
      partialFile = partial;

      var offset = await partial.exists() ? await partial.length() : 0;
      if (offset > release.size) {
        await partial.delete();
        offset = 0;
      }

      if (offset == release.size) {
        await _verifyAndFinalize(partial, complete, release);
        return;
      }

      final request = http.Request('GET', Uri.parse(release.url));
      if (offset > 0) {
        request.headers['Range'] = 'bytes=' + offset.toString() + '-';
      }
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (offset > 0 && response.statusCode == 206) {
        final contentRange = response.headers['content-range'] ?? '';
        final rangeMatch = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(contentRange);
        if (rangeMatch == null ||
            int.parse(rangeMatch.group(1)!) != offset ||
            int.parse(rangeMatch.group(3)!) != release.size) {
          throw const FormatException('The server returned an invalid resume range.');
        }
      } else if (response.statusCode == 200) {
        // Some CDNs ignore Range. Start clean rather than appending the full
        // file to an existing partial APK.
        offset = 0;
        await partial.writeAsBytes(const <int>[], flush: true);
      } else {
        throw FormatException(
          'APK download returned HTTP ' + response.statusCode.toString() + '.',
        );
      }

      final sink = await partial.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          await sink.writeFrom(chunk);
          received += chunk.length;
          downloadedBytes = received;
          downloadProgress = (received / release.size).clamp(0.0, 1.0).toDouble();
          hasPartialDownload = received > 0;
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      await _verifyAndFinalize(partial, complete, release);
    } catch (error) {
      final partial = partialFile;
      final length = partial != null && await partial.exists() ? await partial.length() : 0;
      downloadedBytes = length;
      downloadProgress = release.size == 0 ? 0.0 : (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError = length > 0
          ? 'Download paused. Your progress is saved; tap Resume download to continue.'
          : 'Download failed. Check your connection and try again.';
      debugPrint('[NovynUpdates] Download error: ' + error.toString());
    } finally {
      client.close();
      isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _verifyAndFinalize(
    File partialFile,
    File completeFile,
    AppUpdateInfo release,
  ) async {
    final length = await partialFile.length();
    if (length != release.size) {
      downloadedBytes = length;
      downloadProgress = (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError =
          'Download paused. Your progress is saved; tap Resume download to continue.';
      return;
    }

    final digest = await sha256.bind(partialFile.openRead()).first;
    if (digest.toString() != release.sha256) {
      await partialFile.delete();
      downloadedBytes = 0;
      downloadProgress = 0;
      hasPartialDownload = false;
      downloadError = 'APK checksum verification failed. Please download it again.';
      return;
    }

    if (await completeFile.exists()) {
      await completeFile.delete();
    }
    final savedFile = await partialFile.rename(completeFile.path);
    downloadedApkPath = savedFile.path;
    downloadedBytes = release.size;
    downloadProgress = 1;
    hasPartialDownload = false;
    downloadError = null;
  }

  File _partialFile(String directory, AppUpdateInfo release) {
    return File(
      directory +
          '/novyn-arm64-' +
          release.build.toString() +
          '-' +
          release.sha256.substring(0, 12) +
          '.apk.part',
    );
  }

  File _completeFile(String directory, AppUpdateInfo release) {
    // MainActivity's installer accepts this exact verified APK filename.
    return File(directory + '/' + _arm64ApkName);
  }
}
)
        .firstMatch(tag);
    if (match == null) {
      throw const FormatException(
        'The latest release is not a supported ARM64 build.',
      );
    }
    final build = int.parse(match.group(1)!);
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('Release assets are missing.');
    }

    Map? asset;
    for (final item in assets) {
      if (item is Map && item['name'] == _arm64ApkName) {
        asset = item;
        break;
      }
    }
    if (asset == null) {
      throw const FormatException('The ARM64 APK is missing.');
    }

    final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
    final digest = (asset['digest'] ?? '').toString();
    final size = int.tryParse((asset['size'] ?? '').toString());
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.contains('/itsSatyam27/novyn-chat/releases/download/') ||
        !url.path.endsWith('/' + _arm64ApkName) ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size == null ||
        size < 10 * 1024 * 1024 ||
        size > 100 * 1024 * 1024) {
      throw const FormatException('ARM64 APK metadata failed validation.');
    }

    if (build <= installedBuild) {
      return AppUpdateCheckResult(
        installedBuild: installedBuild,
        buildNumber: installedInfo.buildNumber,
        release: null,
        upToDate: true,
        message: 'You are up to date. Novyn is running the latest ARM64 release.',
      );
    }

    final release = AppUpdateInfo(
      build: build,
      url: url.toString(),
      sha256: digest.substring(7).toLowerCase(),
      size: size,
    );
    await prepareForUpdate(release);
    if (notifyIfAvailable) {
      await _notifyIfNewBuild(release, isBackgroundCheck: isBackgroundCheck);
    }
    return AppUpdateCheckResult(
      installedBuild: installedBuild,
      buildNumber: installedInfo.buildNumber,
      release: release,
      upToDate: false,
      message: 'A new ARM64 update is available.',
    );
  }

  Future<void> _notifyIfNewBuild(AppUpdateInfo release, {required bool isBackgroundCheck}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastNotified = prefs.getInt(_lastNotifiedBuildKey) ?? 0;
    if (release.build <= lastNotified) return;

    // Persist first so foreground/resume and WorkManager checks do not race
    // and show duplicate alerts for the same release.
    await prefs.setInt(_lastNotifiedBuildKey, release.build);
    try {
      if (isBackgroundCheck) {
        await _showBackgroundUpdateNotification();
      } else {
        await NotificationService.showAppUpdateAvailable();
      }
    } catch (error) {
      await prefs.setInt(_lastNotifiedBuildKey, lastNotified);
      debugPrint('[NovynUpdates] Could not show update notification: ' + error.toString());
    }
  }


  Future<void> _showBackgroundUpdateNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_app_updates',
        'App updates',
        description: 'Notifications when a new Novyn version is available',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await plugin.show(
      781205,
      'A new Novyn version is available',
      'Tap to open About Novyn and check for updates.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription: 'Notifications when a new Novyn version is available',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  Future<void> prepareForUpdate(AppUpdateInfo release) async {
    final runningDownload = _downloadFuture;
    if (runningDownload != null && _activeDownloadKey != release.key) {
      await runningDownload;
    }
    _currentRelease = release;
    final key = release.key;
    if (_activeDownloadKey == key &&
        (isDownloading || downloadedApkPath != null || hasPartialDownload)) {
      return;
    }

    _activeDownloadKey = key;
    isDownloading = false;
    downloadProgress = 0;
    downloadedBytes = 0;
    expectedBytes = release.size;
    hasPartialDownload = false;
    downloadedApkPath = null;
    downloadError = null;

    final directory = await getApplicationSupportDirectory();
    final completeFile = _completeFile(directory.path, release);
    final partialFile = _partialFile(directory.path, release);

    if (await completeFile.exists()) {
      final length = await completeFile.length();
      if (length == release.size) {
        final digest = await sha256.bind(completeFile.openRead()).first;
        if (digest.toString() == release.sha256) {
          downloadedApkPath = completeFile.path;
          downloadedBytes = length;
          downloadProgress = 1;
          notifyListeners();
          return;
        }
      }
      await completeFile.delete();
    }

    if (await partialFile.exists()) {
      final length = await partialFile.length();
      if (length > release.size) {
        await partialFile.delete();
      } else if (length > 0) {
        downloadedBytes = length;
        downloadProgress = length / release.size;
        hasPartialDownload = true;
      }
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    final release = _currentRelease;
    if (release == null || downloadedApkPath != null) return;
    final running = _downloadFuture;
    if (running != null) {
      await running;
      return;
    }

    final task = _performDownload(release);
    _downloadFuture = task;
    try {
      await task;
    } finally {
      if (identical(_downloadFuture, task)) {
        _downloadFuture = null;
      }
    }
  }

  Future<void> _performDownload(AppUpdateInfo release) async {
    isDownloading = true;
    downloadError = null;
    expectedBytes = release.size;
    notifyListeners();

    final client = http.Client();
    File? partialFile;

    try {
      final directory = await getApplicationSupportDirectory();
      final partial = _partialFile(directory.path, release);
      final complete = _completeFile(directory.path, release);
      partialFile = partial;

      var offset = await partial.exists() ? await partial.length() : 0;
      if (offset > release.size) {
        await partial.delete();
        offset = 0;
      }

      if (offset == release.size) {
        await _verifyAndFinalize(partial, complete, release);
        return;
      }

      final request = http.Request('GET', Uri.parse(release.url));
      if (offset > 0) {
        request.headers['Range'] = 'bytes=' + offset.toString() + '-';
      }
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (offset > 0 && response.statusCode == 206) {
        final contentRange = response.headers['content-range'] ?? '';
        final rangeMatch = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(contentRange);
        if (rangeMatch == null ||
            int.parse(rangeMatch.group(1)!) != offset ||
            int.parse(rangeMatch.group(3)!) != release.size) {
          throw const FormatException('The server returned an invalid resume range.');
        }
      } else if (response.statusCode == 200) {
        // Some CDNs ignore Range. Start clean rather than appending the full
        // file to an existing partial APK.
        offset = 0;
        await partial.writeAsBytes(const <int>[], flush: true);
      } else {
        throw FormatException(
          'APK download returned HTTP ' + response.statusCode.toString() + '.',
        );
      }

      final sink = await partial.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          await sink.writeFrom(chunk);
          received += chunk.length;
          downloadedBytes = received;
          downloadProgress = (received / release.size).clamp(0.0, 1.0).toDouble();
          hasPartialDownload = received > 0;
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      await _verifyAndFinalize(partial, complete, release);
    } catch (error) {
      final partial = partialFile;
      final length = partial != null && await partial.exists() ? await partial.length() : 0;
      downloadedBytes = length;
      downloadProgress = release.size == 0 ? 0.0 : (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError = length > 0
          ? 'Download paused. Your progress is saved; tap Resume download to continue.'
          : 'Download failed. Check your connection and try again.';
      debugPrint('[NovynUpdates] Download error: ' + error.toString());
    } finally {
      client.close();
      isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _verifyAndFinalize(
    File partialFile,
    File completeFile,
    AppUpdateInfo release,
  ) async {
    final length = await partialFile.length();
    if (length != release.size) {
      downloadedBytes = length;
      downloadProgress = (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError =
          'Download paused. Your progress is saved; tap Resume download to continue.';
      return;
    }

    final digest = await sha256.bind(partialFile.openRead()).first;
    if (digest.toString() != release.sha256) {
      await partialFile.delete();
      downloadedBytes = 0;
      downloadProgress = 0;
      hasPartialDownload = false;
      downloadError = 'APK checksum verification failed. Please download it again.';
      return;
    }

    if (await completeFile.exists()) {
      await completeFile.delete();
    }
    final savedFile = await partialFile.rename(completeFile.path);
    downloadedApkPath = savedFile.path;
    downloadedBytes = release.size;
    downloadProgress = 1;
    hasPartialDownload = false;
    downloadError = null;
  }

  File _partialFile(String directory, AppUpdateInfo release) {
    return File(
      directory +
          '/novyn-arm64-' +
          release.build.toString() +
          '-' +
          release.sha256.substring(0, 12) +
          '.apk.part',
    );
  }

  File _completeFile(String directory, AppUpdateInfo release) {
    // MainActivity's installer accepts this exact verified APK filename.
    return File(directory + '/' + _arm64ApkName);
  }
}
).firstMatch(tag);
    if (match == null) {
      throw const FormatException(
        'The latest release is not a supported ARM64 build.',
      );
    }
    final build = int.parse(match.group(1)!);
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('Release assets are missing.');
    }

    Map? asset;
    for (final item in assets) {
      if (item is Map && item['name'] == _arm64ApkName) {
        asset = item;
        break;
      }
    }
    if (asset == null) {
      throw const FormatException('The ARM64 APK is missing.');
    }

    final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
    final digest = (asset['digest'] ?? '').toString();
    final size = int.tryParse((asset['size'] ?? '').toString());
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.contains('/itsSatyam27/novyn-chat/releases/download/') ||
        !url.path.endsWith('/' + _arm64ApkName) ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size == null ||
        size < 10 * 1024 * 1024 ||
        size > 100 * 1024 * 1024) {
      throw const FormatException('ARM64 APK metadata failed validation.');
    }

    if (build <= installedBuild) {
      return AppUpdateCheckResult(
        installedBuild: installedBuild,
        buildNumber: installedInfo.buildNumber,
        release: null,
        upToDate: true,
        message: 'You are up to date. Novyn is running the latest ARM64 release.',
      );
    }

    final release = AppUpdateInfo(
      build: build,
      url: url.toString(),
      sha256: digest.substring(7).toLowerCase(),
      size: size,
    );
    await prepareForUpdate(release);
    if (notifyIfAvailable) {
      await _notifyIfNewBuild(release, isBackgroundCheck: isBackgroundCheck);
    }
    return AppUpdateCheckResult(
      installedBuild: installedBuild,
      buildNumber: installedInfo.buildNumber,
      release: release,
      upToDate: false,
      message: 'A new ARM64 update is available.',
    );
  }

  Future<void> _notifyIfNewBuild(AppUpdateInfo release, {required bool isBackgroundCheck}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastNotified = prefs.getInt(_lastNotifiedBuildKey) ?? 0;
    if (release.build <= lastNotified) return;

    // Persist first so foreground/resume and WorkManager checks do not race
    // and show duplicate alerts for the same release.
    await prefs.setInt(_lastNotifiedBuildKey, release.build);
    try {
      if (isBackgroundCheck) {
        await _showBackgroundUpdateNotification();
      } else {
        await NotificationService.showAppUpdateAvailable();
      }
    } catch (error) {
      await prefs.setInt(_lastNotifiedBuildKey, lastNotified);
      debugPrint('[NovynUpdates] Could not show update notification: ' + error.toString());
    }
  }


  Future<void> _showBackgroundUpdateNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_app_updates',
        'App updates',
        description: 'Notifications when a new Novyn version is available',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await plugin.show(
      781205,
      'A new Novyn version is available',
      'Tap to open About Novyn and check for updates.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription: 'Notifications when a new Novyn version is available',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  Future<void> prepareForUpdate(AppUpdateInfo release) async {
    final runningDownload = _downloadFuture;
    if (runningDownload != null && _activeDownloadKey != release.key) {
      await runningDownload;
    }
    _currentRelease = release;
    final key = release.key;
    if (_activeDownloadKey == key &&
        (isDownloading || downloadedApkPath != null || hasPartialDownload)) {
      return;
    }

    _activeDownloadKey = key;
    isDownloading = false;
    downloadProgress = 0;
    downloadedBytes = 0;
    expectedBytes = release.size;
    hasPartialDownload = false;
    downloadedApkPath = null;
    downloadError = null;

    final directory = await getApplicationSupportDirectory();
    final completeFile = _completeFile(directory.path, release);
    final partialFile = _partialFile(directory.path, release);

    if (await completeFile.exists()) {
      final length = await completeFile.length();
      if (length == release.size) {
        final digest = await sha256.bind(completeFile.openRead()).first;
        if (digest.toString() == release.sha256) {
          downloadedApkPath = completeFile.path;
          downloadedBytes = length;
          downloadProgress = 1;
          notifyListeners();
          return;
        }
      }
      await completeFile.delete();
    }

    if (await partialFile.exists()) {
      final length = await partialFile.length();
      if (length > release.size) {
        await partialFile.delete();
      } else if (length > 0) {
        downloadedBytes = length;
        downloadProgress = length / release.size;
        hasPartialDownload = true;
      }
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    final release = _currentRelease;
    if (release == null || downloadedApkPath != null) return;
    final running = _downloadFuture;
    if (running != null) {
      await running;
      return;
    }

    final task = _performDownload(release);
    _downloadFuture = task;
    try {
      await task;
    } finally {
      if (identical(_downloadFuture, task)) {
        _downloadFuture = null;
      }
    }
  }

  Future<void> _performDownload(AppUpdateInfo release) async {
    isDownloading = true;
    downloadError = null;
    expectedBytes = release.size;
    notifyListeners();

    final client = http.Client();
    File? partialFile;

    try {
      final directory = await getApplicationSupportDirectory();
      final partial = _partialFile(directory.path, release);
      final complete = _completeFile(directory.path, release);
      partialFile = partial;

      var offset = await partial.exists() ? await partial.length() : 0;
      if (offset > release.size) {
        await partial.delete();
        offset = 0;
      }

      if (offset == release.size) {
        await _verifyAndFinalize(partial, complete, release);
        return;
      }

      final request = http.Request('GET', Uri.parse(release.url));
      if (offset > 0) {
        request.headers['Range'] = 'bytes=' + offset.toString() + '-';
      }
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (offset > 0 && response.statusCode == 206) {
        final contentRange = response.headers['content-range'] ?? '';
        final rangeMatch = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(contentRange);
        if (rangeMatch == null ||
            int.parse(rangeMatch.group(1)!) != offset ||
            int.parse(rangeMatch.group(3)!) != release.size) {
          throw const FormatException('The server returned an invalid resume range.');
        }
      } else if (response.statusCode == 200) {
        // Some CDNs ignore Range. Start clean rather than appending the full
        // file to an existing partial APK.
        offset = 0;
        await partial.writeAsBytes(const <int>[], flush: true);
      } else {
        throw FormatException(
          'APK download returned HTTP ' + response.statusCode.toString() + '.',
        );
      }

      final sink = await partial.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          await sink.writeFrom(chunk);
          received += chunk.length;
          downloadedBytes = received;
          downloadProgress = (received / release.size).clamp(0.0, 1.0).toDouble();
          hasPartialDownload = received > 0;
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      await _verifyAndFinalize(partial, complete, release);
    } catch (error) {
      final partial = partialFile;
      final length = partial != null && await partial.exists() ? await partial.length() : 0;
      downloadedBytes = length;
      downloadProgress = release.size == 0 ? 0.0 : (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError = length > 0
          ? 'Download paused. Your progress is saved; tap Resume download to continue.'
          : 'Download failed. Check your connection and try again.';
      debugPrint('[NovynUpdates] Download error: ' + error.toString());
    } finally {
      client.close();
      isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _verifyAndFinalize(
    File partialFile,
    File completeFile,
    AppUpdateInfo release,
  ) async {
    final length = await partialFile.length();
    if (length != release.size) {
      downloadedBytes = length;
      downloadProgress = (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError =
          'Download paused. Your progress is saved; tap Resume download to continue.';
      return;
    }

    final digest = await sha256.bind(partialFile.openRead()).first;
    if (digest.toString() != release.sha256) {
      await partialFile.delete();
      downloadedBytes = 0;
      downloadProgress = 0;
      hasPartialDownload = false;
      downloadError = 'APK checksum verification failed. Please download it again.';
      return;
    }

    if (await completeFile.exists()) {
      await completeFile.delete();
    }
    final savedFile = await partialFile.rename(completeFile.path);
    downloadedApkPath = savedFile.path;
    downloadedBytes = release.size;
    downloadProgress = 1;
    hasPartialDownload = false;
    downloadError = null;
  }

  File _partialFile(String directory, AppUpdateInfo release) {
    return File(
      directory +
          '/novyn-arm64-' +
          release.build.toString() +
          '-' +
          release.sha256.substring(0, 12) +
          '.apk.part',
    );
  }

  File _completeFile(String directory, AppUpdateInfo release) {
    // MainActivity's installer accepts this exact verified APK filename.
    return File(directory + '/' + _arm64ApkName);
  }
}
)
        .firstMatch(tag);
    if (match == null) {
      throw const FormatException(
        'The latest release is not a supported ARM64 build.',
      );
    }
    final build = int.parse(match.group(1)!);
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('Release assets are missing.');
    }

    Map? asset;
    for (final item in assets) {
      if (item is Map && item['name'] == _arm64ApkName) {
        asset = item;
        break;
      }
    }
    if (asset == null) {
      throw const FormatException('The ARM64 APK is missing.');
    }

    final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
    final digest = (asset['digest'] ?? '').toString();
    final size = int.tryParse((asset['size'] ?? '').toString());
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.contains('/itsSatyam27/novyn-chat/releases/download/') ||
        !url.path.endsWith('/' + _arm64ApkName) ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size == null ||
        size < 10 * 1024 * 1024 ||
        size > 100 * 1024 * 1024) {
      throw const FormatException('ARM64 APK metadata failed validation.');
    }

    if (build <= installedBuild) {
      return AppUpdateCheckResult(
        installedBuild: installedBuild,
        buildNumber: installedInfo.buildNumber,
        release: null,
        upToDate: true,
        message: 'You are up to date. Novyn is running the latest ARM64 release.',
      );
    }

    final release = AppUpdateInfo(
      build: build,
      url: url.toString(),
      sha256: digest.substring(7).toLowerCase(),
      size: size,
    );
    await prepareForUpdate(release);
    if (notifyIfAvailable) {
      await _notifyIfNewBuild(release, isBackgroundCheck: isBackgroundCheck);
    }
    return AppUpdateCheckResult(
      installedBuild: installedBuild,
      buildNumber: installedInfo.buildNumber,
      release: release,
      upToDate: false,
      message: 'A new ARM64 update is available.',
    );
  }

  Future<void> _notifyIfNewBuild(AppUpdateInfo release, {required bool isBackgroundCheck}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastNotified = prefs.getInt(_lastNotifiedBuildKey) ?? 0;
    if (release.build <= lastNotified) return;

    // Persist first so foreground/resume and WorkManager checks do not race
    // and show duplicate alerts for the same release.
    await prefs.setInt(_lastNotifiedBuildKey, release.build);
    try {
      if (isBackgroundCheck) {
        await _showBackgroundUpdateNotification();
      } else {
        await NotificationService.showAppUpdateAvailable();
      }
    } catch (error) {
      await prefs.setInt(_lastNotifiedBuildKey, lastNotified);
      debugPrint('[NovynUpdates] Could not show update notification: ' + error.toString());
    }
  }


  Future<void> _showBackgroundUpdateNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_app_updates',
        'App updates',
        description: 'Notifications when a new Novyn version is available',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await plugin.show(
      781205,
      'A new Novyn version is available',
      'Tap to open About Novyn and check for updates.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription: 'Notifications when a new Novyn version is available',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  Future<void> prepareForUpdate(AppUpdateInfo release) async {
    final runningDownload = _downloadFuture;
    if (runningDownload != null && _activeDownloadKey != release.key) {
      await runningDownload;
    }
    _currentRelease = release;
    final key = release.key;
    if (_activeDownloadKey == key &&
        (isDownloading || downloadedApkPath != null || hasPartialDownload)) {
      return;
    }

    _activeDownloadKey = key;
    isDownloading = false;
    downloadProgress = 0;
    downloadedBytes = 0;
    expectedBytes = release.size;
    hasPartialDownload = false;
    downloadedApkPath = null;
    downloadError = null;

    final directory = await getApplicationSupportDirectory();
    final completeFile = _completeFile(directory.path, release);
    final partialFile = _partialFile(directory.path, release);

    if (await completeFile.exists()) {
      final length = await completeFile.length();
      if (length == release.size) {
        final digest = await sha256.bind(completeFile.openRead()).first;
        if (digest.toString() == release.sha256) {
          downloadedApkPath = completeFile.path;
          downloadedBytes = length;
          downloadProgress = 1;
          notifyListeners();
          return;
        }
      }
      await completeFile.delete();
    }

    if (await partialFile.exists()) {
      final length = await partialFile.length();
      if (length > release.size) {
        await partialFile.delete();
      } else if (length > 0) {
        downloadedBytes = length;
        downloadProgress = length / release.size;
        hasPartialDownload = true;
      }
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    final release = _currentRelease;
    if (release == null || downloadedApkPath != null) return;
    final running = _downloadFuture;
    if (running != null) {
      await running;
      return;
    }

    final task = _performDownload(release);
    _downloadFuture = task;
    try {
      await task;
    } finally {
      if (identical(_downloadFuture, task)) {
        _downloadFuture = null;
      }
    }
  }

  Future<void> _performDownload(AppUpdateInfo release) async {
    isDownloading = true;
    downloadError = null;
    expectedBytes = release.size;
    notifyListeners();

    final client = http.Client();
    File? partialFile;

    try {
      final directory = await getApplicationSupportDirectory();
      final partial = _partialFile(directory.path, release);
      final complete = _completeFile(directory.path, release);
      partialFile = partial;

      var offset = await partial.exists() ? await partial.length() : 0;
      if (offset > release.size) {
        await partial.delete();
        offset = 0;
      }

      if (offset == release.size) {
        await _verifyAndFinalize(partial, complete, release);
        return;
      }

      final request = http.Request('GET', Uri.parse(release.url));
      if (offset > 0) {
        request.headers['Range'] = 'bytes=' + offset.toString() + '-';
      }
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (offset > 0 && response.statusCode == 206) {
        final contentRange = response.headers['content-range'] ?? '';
        final rangeMatch = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(contentRange);
        if (rangeMatch == null ||
            int.parse(rangeMatch.group(1)!) != offset ||
            int.parse(rangeMatch.group(3)!) != release.size) {
          throw const FormatException('The server returned an invalid resume range.');
        }
      } else if (response.statusCode == 200) {
        // Some CDNs ignore Range. Start clean rather than appending the full
        // file to an existing partial APK.
        offset = 0;
        await partial.writeAsBytes(const <int>[], flush: true);
      } else {
        throw FormatException(
          'APK download returned HTTP ' + response.statusCode.toString() + '.',
        );
      }

      final sink = await partial.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          await sink.writeFrom(chunk);
          received += chunk.length;
          downloadedBytes = received;
          downloadProgress = (received / release.size).clamp(0.0, 1.0).toDouble();
          hasPartialDownload = received > 0;
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      await _verifyAndFinalize(partial, complete, release);
    } catch (error) {
      final partial = partialFile;
      final length = partial != null && await partial.exists() ? await partial.length() : 0;
      downloadedBytes = length;
      downloadProgress = release.size == 0 ? 0.0 : (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError = length > 0
          ? 'Download paused. Your progress is saved; tap Resume download to continue.'
          : 'Download failed. Check your connection and try again.';
      debugPrint('[NovynUpdates] Download error: ' + error.toString());
    } finally {
      client.close();
      isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _verifyAndFinalize(
    File partialFile,
    File completeFile,
    AppUpdateInfo release,
  ) async {
    final length = await partialFile.length();
    if (length != release.size) {
      downloadedBytes = length;
      downloadProgress = (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError =
          'Download paused. Your progress is saved; tap Resume download to continue.';
      return;
    }

    final digest = await sha256.bind(partialFile.openRead()).first;
    if (digest.toString() != release.sha256) {
      await partialFile.delete();
      downloadedBytes = 0;
      downloadProgress = 0;
      hasPartialDownload = false;
      downloadError = 'APK checksum verification failed. Please download it again.';
      return;
    }

    if (await completeFile.exists()) {
      await completeFile.delete();
    }
    final savedFile = await partialFile.rename(completeFile.path);
    downloadedApkPath = savedFile.path;
    downloadedBytes = release.size;
    downloadProgress = 1;
    hasPartialDownload = false;
    downloadError = null;
  }

  File _partialFile(String directory, AppUpdateInfo release) {
    return File(
      directory +
          '/novyn-arm64-' +
          release.build.toString() +
          '-' +
          release.sha256.substring(0, 12) +
          '.apk.part',
    );
  }

  File _completeFile(String directory, AppUpdateInfo release) {
    // MainActivity's installer accepts this exact verified APK filename.
    return File(directory + '/' + _arm64ApkName);
  }
}
).firstMatch(tag);
    if (match == null) {
      throw const FormatException(
        'The latest release is not a supported ARM64 build.',
      );
    }
    final build = int.parse(match.group(1)!);
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('Release assets are missing.');
    }

    Map? asset;
    for (final item in assets) {
      if (item is Map && item['name'] == _arm64ApkName) {
        asset = item;
        break;
      }
    }
    if (asset == null) {
      throw const FormatException('The ARM64 APK is missing.');
    }

    final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
    final digest = (asset['digest'] ?? '').toString();
    final size = int.tryParse((asset['size'] ?? '').toString());
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.contains('/itsSatyam27/novyn-chat/releases/download/') ||
        !url.path.endsWith('/' + _arm64ApkName) ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size == null ||
        size < 10 * 1024 * 1024 ||
        size > 100 * 1024 * 1024) {
      throw const FormatException('ARM64 APK metadata failed validation.');
    }

    if (build <= installedBuild) {
      return AppUpdateCheckResult(
        installedBuild: installedBuild,
        buildNumber: installedInfo.buildNumber,
        release: null,
        upToDate: true,
        message: 'You are up to date. Novyn is running the latest ARM64 release.',
      );
    }

    final release = AppUpdateInfo(
      build: build,
      url: url.toString(),
      sha256: digest.substring(7).toLowerCase(),
      size: size,
    );
    await prepareForUpdate(release);
    if (notifyIfAvailable) {
      await _notifyIfNewBuild(release, isBackgroundCheck: isBackgroundCheck);
    }
    return AppUpdateCheckResult(
      installedBuild: installedBuild,
      buildNumber: installedInfo.buildNumber,
      release: release,
      upToDate: false,
      message: 'A new ARM64 update is available.',
    );
  }

  Future<void> _notifyIfNewBuild(AppUpdateInfo release, {required bool isBackgroundCheck}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastNotified = prefs.getInt(_lastNotifiedBuildKey) ?? 0;
    if (release.build <= lastNotified) return;

    // Persist first so foreground/resume and WorkManager checks do not race
    // and show duplicate alerts for the same release.
    await prefs.setInt(_lastNotifiedBuildKey, release.build);
    try {
      if (isBackgroundCheck) {
        await _showBackgroundUpdateNotification();
      } else {
        await NotificationService.showAppUpdateAvailable();
      }
    } catch (error) {
      await prefs.setInt(_lastNotifiedBuildKey, lastNotified);
      debugPrint('[NovynUpdates] Could not show update notification: ' + error.toString());
    }
  }


  Future<void> _showBackgroundUpdateNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_app_updates',
        'App updates',
        description: 'Notifications when a new Novyn version is available',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await plugin.show(
      781205,
      'A new Novyn version is available',
      'Tap to open About Novyn and check for updates.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription: 'Notifications when a new Novyn version is available',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  Future<void> prepareForUpdate(AppUpdateInfo release) async {
    final runningDownload = _downloadFuture;
    if (runningDownload != null && _activeDownloadKey != release.key) {
      await runningDownload;
    }
    _currentRelease = release;
    final key = release.key;
    if (_activeDownloadKey == key &&
        (isDownloading || downloadedApkPath != null || hasPartialDownload)) {
      return;
    }

    _activeDownloadKey = key;
    isDownloading = false;
    downloadProgress = 0;
    downloadedBytes = 0;
    expectedBytes = release.size;
    hasPartialDownload = false;
    downloadedApkPath = null;
    downloadError = null;

    final directory = await getApplicationSupportDirectory();
    final completeFile = _completeFile(directory.path, release);
    final partialFile = _partialFile(directory.path, release);

    if (await completeFile.exists()) {
      final length = await completeFile.length();
      if (length == release.size) {
        final digest = await sha256.bind(completeFile.openRead()).first;
        if (digest.toString() == release.sha256) {
          downloadedApkPath = completeFile.path;
          downloadedBytes = length;
          downloadProgress = 1;
          notifyListeners();
          return;
        }
      }
      await completeFile.delete();
    }

    if (await partialFile.exists()) {
      final length = await partialFile.length();
      if (length > release.size) {
        await partialFile.delete();
      } else if (length > 0) {
        downloadedBytes = length;
        downloadProgress = length / release.size;
        hasPartialDownload = true;
      }
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    final release = _currentRelease;
    if (release == null || downloadedApkPath != null) return;
    final running = _downloadFuture;
    if (running != null) {
      await running;
      return;
    }

    final task = _performDownload(release);
    _downloadFuture = task;
    try {
      await task;
    } finally {
      if (identical(_downloadFuture, task)) {
        _downloadFuture = null;
      }
    }
  }

  Future<void> _performDownload(AppUpdateInfo release) async {
    isDownloading = true;
    downloadError = null;
    expectedBytes = release.size;
    notifyListeners();

    final client = http.Client();
    File? partialFile;

    try {
      final directory = await getApplicationSupportDirectory();
      final partial = _partialFile(directory.path, release);
      final complete = _completeFile(directory.path, release);
      partialFile = partial;

      var offset = await partial.exists() ? await partial.length() : 0;
      if (offset > release.size) {
        await partial.delete();
        offset = 0;
      }

      if (offset == release.size) {
        await _verifyAndFinalize(partial, complete, release);
        return;
      }

      final request = http.Request('GET', Uri.parse(release.url));
      if (offset > 0) {
        request.headers['Range'] = 'bytes=' + offset.toString() + '-';
      }
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (offset > 0 && response.statusCode == 206) {
        final contentRange = response.headers['content-range'] ?? '';
        final rangeMatch = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(contentRange);
        if (rangeMatch == null ||
            int.parse(rangeMatch.group(1)!) != offset ||
            int.parse(rangeMatch.group(3)!) != release.size) {
          throw const FormatException('The server returned an invalid resume range.');
        }
      } else if (response.statusCode == 200) {
        // Some CDNs ignore Range. Start clean rather than appending the full
        // file to an existing partial APK.
        offset = 0;
        await partial.writeAsBytes(const <int>[], flush: true);
      } else {
        throw FormatException(
          'APK download returned HTTP ' + response.statusCode.toString() + '.',
        );
      }

      final sink = await partial.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          await sink.writeFrom(chunk);
          received += chunk.length;
          downloadedBytes = received;
          downloadProgress = (received / release.size).clamp(0.0, 1.0).toDouble();
          hasPartialDownload = received > 0;
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      await _verifyAndFinalize(partial, complete, release);
    } catch (error) {
      final partial = partialFile;
      final length = partial != null && await partial.exists() ? await partial.length() : 0;
      downloadedBytes = length;
      downloadProgress = release.size == 0 ? 0.0 : (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError = length > 0
          ? 'Download paused. Your progress is saved; tap Resume download to continue.'
          : 'Download failed. Check your connection and try again.';
      debugPrint('[NovynUpdates] Download error: ' + error.toString());
    } finally {
      client.close();
      isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _verifyAndFinalize(
    File partialFile,
    File completeFile,
    AppUpdateInfo release,
  ) async {
    final length = await partialFile.length();
    if (length != release.size) {
      downloadedBytes = length;
      downloadProgress = (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError =
          'Download paused. Your progress is saved; tap Resume download to continue.';
      return;
    }

    final digest = await sha256.bind(partialFile.openRead()).first;
    if (digest.toString() != release.sha256) {
      await partialFile.delete();
      downloadedBytes = 0;
      downloadProgress = 0;
      hasPartialDownload = false;
      downloadError = 'APK checksum verification failed. Please download it again.';
      return;
    }

    if (await completeFile.exists()) {
      await completeFile.delete();
    }
    final savedFile = await partialFile.rename(completeFile.path);
    downloadedApkPath = savedFile.path;
    downloadedBytes = release.size;
    downloadProgress = 1;
    hasPartialDownload = false;
    downloadError = null;
  }

  File _partialFile(String directory, AppUpdateInfo release) {
    return File(
      directory +
          '/novyn-arm64-' +
          release.build.toString() +
          '-' +
          release.sha256.substring(0, 12) +
          '.apk.part',
    );
  }

  File _completeFile(String directory, AppUpdateInfo release) {
    // MainActivity's installer accepts this exact verified APK filename.
    return File(directory + '/' + _arm64ApkName);
  }
}
)
        .firstMatch(tag);
    if (match == null) {
      throw const FormatException(
        'The latest release is not a supported ARM64 build.',
      );
    }
    final build = int.parse(match.group(1)!);
    final assets = decoded['assets'];
    if (assets is! List) {
      throw const FormatException('Release assets are missing.');
    }

    Map? asset;
    for (final item in assets) {
      if (item is Map && item['name'] == _arm64ApkName) {
        asset = item;
        break;
      }
    }
    if (asset == null) {
      throw const FormatException('The ARM64 APK is missing.');
    }

    final url = Uri.tryParse((asset['browser_download_url'] ?? '').toString());
    final digest = (asset['digest'] ?? '').toString();
    final size = int.tryParse((asset['size'] ?? '').toString());
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        !url.path.contains('/itsSatyam27/novyn-chat/releases/download/') ||
        !url.path.endsWith('/' + _arm64ApkName) ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size == null ||
        size < 10 * 1024 * 1024 ||
        size > 100 * 1024 * 1024) {
      throw const FormatException('ARM64 APK metadata failed validation.');
    }

    if (build <= installedBuild) {
      return AppUpdateCheckResult(
        installedBuild: installedBuild,
        buildNumber: installedInfo.buildNumber,
        release: null,
        upToDate: true,
        message: 'You are up to date. Novyn is running the latest ARM64 release.',
      );
    }

    final release = AppUpdateInfo(
      build: build,
      url: url.toString(),
      sha256: digest.substring(7).toLowerCase(),
      size: size,
    );
    await prepareForUpdate(release);
    if (notifyIfAvailable) {
      await _notifyIfNewBuild(release, isBackgroundCheck: isBackgroundCheck);
    }
    return AppUpdateCheckResult(
      installedBuild: installedBuild,
      buildNumber: installedInfo.buildNumber,
      release: release,
      upToDate: false,
      message: 'A new ARM64 update is available.',
    );
  }

  Future<void> _notifyIfNewBuild(AppUpdateInfo release, {required bool isBackgroundCheck}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lastNotified = prefs.getInt(_lastNotifiedBuildKey) ?? 0;
    if (release.build <= lastNotified) return;

    // Persist first so foreground/resume and WorkManager checks do not race
    // and show duplicate alerts for the same release.
    await prefs.setInt(_lastNotifiedBuildKey, release.build);
    try {
      if (isBackgroundCheck) {
        await _showBackgroundUpdateNotification();
      } else {
        await NotificationService.showAppUpdateAvailable();
      }
    } catch (error) {
      await prefs.setInt(_lastNotifiedBuildKey, lastNotified);
      debugPrint('[NovynUpdates] Could not show update notification: ' + error.toString());
    }
  }


  Future<void> _showBackgroundUpdateNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/novyn_wings_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'novyn_app_updates',
        'App updates',
        description: 'Notifications when a new Novyn version is available',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await plugin.show(
      781205,
      'A new Novyn version is available',
      'Tap to open About Novyn and check for updates.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'novyn_app_updates',
          'App updates',
          channelDescription: 'Notifications when a new Novyn version is available',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/novyn_wings_icon',
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'app_update',
    );
  }

  Future<void> prepareForUpdate(AppUpdateInfo release) async {
    final runningDownload = _downloadFuture;
    if (runningDownload != null && _activeDownloadKey != release.key) {
      await runningDownload;
    }
    _currentRelease = release;
    final key = release.key;
    if (_activeDownloadKey == key &&
        (isDownloading || downloadedApkPath != null || hasPartialDownload)) {
      return;
    }

    _activeDownloadKey = key;
    isDownloading = false;
    downloadProgress = 0;
    downloadedBytes = 0;
    expectedBytes = release.size;
    hasPartialDownload = false;
    downloadedApkPath = null;
    downloadError = null;

    final directory = await getApplicationSupportDirectory();
    final completeFile = _completeFile(directory.path, release);
    final partialFile = _partialFile(directory.path, release);

    if (await completeFile.exists()) {
      final length = await completeFile.length();
      if (length == release.size) {
        final digest = await sha256.bind(completeFile.openRead()).first;
        if (digest.toString() == release.sha256) {
          downloadedApkPath = completeFile.path;
          downloadedBytes = length;
          downloadProgress = 1;
          notifyListeners();
          return;
        }
      }
      await completeFile.delete();
    }

    if (await partialFile.exists()) {
      final length = await partialFile.length();
      if (length > release.size) {
        await partialFile.delete();
      } else if (length > 0) {
        downloadedBytes = length;
        downloadProgress = length / release.size;
        hasPartialDownload = true;
      }
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    final release = _currentRelease;
    if (release == null || downloadedApkPath != null) return;
    final running = _downloadFuture;
    if (running != null) {
      await running;
      return;
    }

    final task = _performDownload(release);
    _downloadFuture = task;
    try {
      await task;
    } finally {
      if (identical(_downloadFuture, task)) {
        _downloadFuture = null;
      }
    }
  }

  Future<void> _performDownload(AppUpdateInfo release) async {
    isDownloading = true;
    downloadError = null;
    expectedBytes = release.size;
    notifyListeners();

    final client = http.Client();
    File? partialFile;

    try {
      final directory = await getApplicationSupportDirectory();
      final partial = _partialFile(directory.path, release);
      final complete = _completeFile(directory.path, release);
      partialFile = partial;

      var offset = await partial.exists() ? await partial.length() : 0;
      if (offset > release.size) {
        await partial.delete();
        offset = 0;
      }

      if (offset == release.size) {
        await _verifyAndFinalize(partial, complete, release);
        return;
      }

      final request = http.Request('GET', Uri.parse(release.url));
      if (offset > 0) {
        request.headers['Range'] = 'bytes=' + offset.toString() + '-';
      }
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (offset > 0 && response.statusCode == 206) {
        final contentRange = response.headers['content-range'] ?? '';
        final rangeMatch = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
            .firstMatch(contentRange);
        if (rangeMatch == null ||
            int.parse(rangeMatch.group(1)!) != offset ||
            int.parse(rangeMatch.group(3)!) != release.size) {
          throw const FormatException('The server returned an invalid resume range.');
        }
      } else if (response.statusCode == 200) {
        // Some CDNs ignore Range. Start clean rather than appending the full
        // file to an existing partial APK.
        offset = 0;
        await partial.writeAsBytes(const <int>[], flush: true);
      } else {
        throw FormatException(
          'APK download returned HTTP ' + response.statusCode.toString() + '.',
        );
      }

      final sink = await partial.open(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var received = offset;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          await sink.writeFrom(chunk);
          received += chunk.length;
          downloadedBytes = received;
          downloadProgress = (received / release.size).clamp(0.0, 1.0).toDouble();
          hasPartialDownload = received > 0;
          notifyListeners();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      await _verifyAndFinalize(partial, complete, release);
    } catch (error) {
      final partial = partialFile;
      final length = partial != null && await partial.exists() ? await partial.length() : 0;
      downloadedBytes = length;
      downloadProgress = release.size == 0 ? 0.0 : (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError = length > 0
          ? 'Download paused. Your progress is saved; tap Resume download to continue.'
          : 'Download failed. Check your connection and try again.';
      debugPrint('[NovynUpdates] Download error: ' + error.toString());
    } finally {
      client.close();
      isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _verifyAndFinalize(
    File partialFile,
    File completeFile,
    AppUpdateInfo release,
  ) async {
    final length = await partialFile.length();
    if (length != release.size) {
      downloadedBytes = length;
      downloadProgress = (length / release.size).clamp(0.0, 1.0).toDouble();
      hasPartialDownload = length > 0;
      downloadError =
          'Download paused. Your progress is saved; tap Resume download to continue.';
      return;
    }

    final digest = await sha256.bind(partialFile.openRead()).first;
    if (digest.toString() != release.sha256) {
      await partialFile.delete();
      downloadedBytes = 0;
      downloadProgress = 0;
      hasPartialDownload = false;
      downloadError = 'APK checksum verification failed. Please download it again.';
      return;
    }

    if (await completeFile.exists()) {
      await completeFile.delete();
    }
    final savedFile = await partialFile.rename(completeFile.path);
    downloadedApkPath = savedFile.path;
    downloadedBytes = release.size;
    downloadProgress = 1;
    hasPartialDownload = false;
    downloadError = null;
  }

  File _partialFile(String directory, AppUpdateInfo release) {
    return File(
      directory +
          '/novyn-arm64-' +
          release.build.toString() +
          '-' +
          release.sha256.substring(0, 12) +
          '.apk.part',
    );
  }

  File _completeFile(String directory, AppUpdateInfo release) {
    // MainActivity's installer accepts this exact verified APK filename.
    return File(directory + '/' + _arm64ApkName);
  }
}
