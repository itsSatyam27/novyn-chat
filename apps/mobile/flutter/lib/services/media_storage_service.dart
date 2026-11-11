import 'dart:async';
import 'dart:io';

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
  static final Set<String> _inFlight = <String>{};

  static Future<void> handleIncomingAttachment(
    Map<String, dynamic>? attachment,
    String messageId,
  ) async {
    if (attachment == null || messageId.isEmpty || _inFlight.contains(messageId)) return;
    final url = attachment['url']?.toString() ?? '';
    final name = attachment['name']?.toString() ?? 'Novyn media';
    final kind = attachment['kind']?.toString().toLowerCase() ?? '';
    if (url.isEmpty || !['image', 'video', 'audio', 'file'].contains(kind)) return;

    _inFlight.add(messageId);
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
      if (policy == 'photos' && kind != 'image') return;

      final file = await ApiService.downloadMedia(url, name);
      if (kind == 'image') {
        if (!await Gal.hasAccess()) {
          await Gal.requestAccess(toAlbum: true);
        }
        await Gal.putImage(file.path, album: 'Novyn');
      } else if (kind == 'video') {
        if (!await Gal.hasAccess()) {
          await Gal.requestAccess(toAlbum: true);
        }
        await Gal.putVideo(file.path, album: 'Novyn');
      }
      // Audio and documents remain in the in-app Novyn Downloads folder.
    } catch (_) {
      // Automatic downloads are best-effort. The original message remains
      // available and the user can always retry with its manual Download action.
    } finally {
      _inFlight.remove(messageId);
    }
  }

  static Future<File?> compressImage(
    List<int> bytes, {
    required String quality,
  }) async {
    // Implemented in ApiService's upload pipeline to keep compression optional
    // for non-image attachments and preserve the original MIME type.
    return null;
  }
}
