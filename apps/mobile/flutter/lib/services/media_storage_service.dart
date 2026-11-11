import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:gal/gal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Applies the user's media-download policy to newly received attachments.
/// Downloads are performed while Novyn is running; the OS may suspend this
/// work when the app is terminated or heavily background-restricted.
class MediaStorageService {
  MediaStorageService._();

  static const _wifiKey = 'auto_download_wifi';
  static const _mobileKey = 'auto_download_mobile';
  static const _queueKey = 'novyn_pending_media_downloads_v1';
  static final Set<String> _inFlight = <String>{};
  static bool _isDraining = false;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Resume queued downloads on connectivity changes and socket reconnects.
  /// This is a durable app-level queue, not an OS-scheduled background worker.
  static void watchConnectivity() {
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((_) {
      unawaited(drainPendingDownloads());
    });
    unawaited(drainPendingDownloads());
  }

  static Future<void> handleIncomingAttachment(
    Map<String, dynamic>? attachment,
    String messageId,
  ) async {
    if (attachment == null || messageId.isEmpty) return;
    final url = attachment['url']?.toString() ?? '';
    final name = attachment['name']?.toString() ?? 'Novyn media';
    final kind = attachment['kind']?.toString().toLowerCase() ?? '';
    if (url.isEmpty || !['image', 'video', 'audio', 'file'].contains(kind)) return;

    final prefs = await SharedPreferences.getInstance();
    final queue = _readQueue(prefs);
    if (queue.any((item) => item['id'] == messageId) ||
        _inFlight.contains(messageId)) return;
    queue.add({'id': messageId, 'url': url, 'name': name, 'kind': kind});
    await prefs.setString(_queueKey, jsonEncode(queue));
    await drainPendingDownloads();
  }

  static List<Map<String, dynamic>> _readQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> drainPendingDownloads() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final connections = await Connectivity().checkConnectivity();
      final onWifi = connections.contains(ConnectivityResult.wifi) ||
          connections.contains(ConnectivityResult.ethernet);
      final onMobile = connections.contains(ConnectivityResult.mobile);
      if (!onWifi && !onMobile) return;
      final policy = prefs.getString(onWifi ? _wifiKey : _mobileKey) ??
          (onWifi ? 'all' : 'photos');
      if (policy == 'none') return;

      final queue = _readQueue(prefs);
      final remaining = <Map<String, dynamic>>[];
      for (final item in queue) {
        final id = item['id']?.toString() ?? '';
        final kind = item['kind']?.toString() ?? '';
        if (id.isEmpty || _inFlight.contains(id)) continue;
        if (policy == 'photos' && kind != 'image') {
          remaining.add(item);
          continue;
        }
        _inFlight.add(id);
        try {
          final file = await ApiService.downloadMedia(
            item['url']?.toString() ?? '',
            item['name']?.toString() ?? 'Novyn media',
          );
          if (kind == 'image') {
            if (!await Gal.hasAccess()) await Gal.requestAccess(toAlbum: true);
            await Gal.putImage(file.path, album: 'Novyn');
          } else if (kind == 'video') {
            if (!await Gal.hasAccess()) await Gal.requestAccess(toAlbum: true);
            await Gal.putVideo(file.path, album: 'Novyn');
          }
          // Audio and documents remain in the app's Novyn Downloads folder.
        } catch (_) {
          // Retain failed work for the next network/app reconnect.
          remaining.add(item);
        } finally {
          _inFlight.remove(id);
        }
      }
      await prefs.setString(_queueKey, jsonEncode(remaining));
    } finally {
      _isDraining = false;
    }
  }

  static Future<bool> exportToDevice(File file, String kind) async {
    if (kind == 'image') {
      if (!await Gal.hasAccess()) await Gal.requestAccess(toAlbum: true);
      await Gal.putImage(file.path, album: 'Novyn');
      return true;
    }
    if (kind == 'video') {
      if (!await Gal.hasAccess()) await Gal.requestAccess(toAlbum: true);
      await Gal.putVideo(file.path, album: 'Novyn');
      return true;
    }
    // Documents/audio use Android/iOS system document picker so the user
    // chooses a public Files/Downloads destination rather than a private path.
    final savedPath = await FilePicker.platform.saveFile(
      fileName: file.uri.pathSegments.isEmpty ? 'Novyn download' : file.uri.pathSegments.last,
      bytes: await file.readAsBytes(),
    );
    return savedPath != null;
  }
}
