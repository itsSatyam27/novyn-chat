import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

/// Reusable avatar widget with Hive disk caching for instant loads
class UserAvatar extends StatefulWidget {
  final String name;
  final String photoUrl; // base64 string or empty
  final double radius;
  final Color? fallbackColor;
  final bool showOnlineIndicator;
  final bool isOnline;
  final String? presence;
  final double borderWidth;
  final Color? borderColor;

  const UserAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.radius = 24,
    this.fallbackColor,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.presence,
    this.borderWidth = 0,
    this.borderColor,
  });

  // Static method to initialize cache (call in main.dart)
  static Future<void> initCache() async {
    await _UserAvatarState.initCache();
  }

  // Clear all avatar cache (e.g., on logout)
  static Future<void> clearAllCache() async {
    await _UserAvatarState.initCache();
    await _UserAvatarState._avatarCache?.clear();
  }

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Uint8List? _cachedImage;
  static Box? _avatarCache;
  int _loadGeneration = 0;

  // Initialize cache box (call once in app startup)
  static Future<void> initCache() async {
    if (_avatarCache == null || !_avatarCache!.isOpen) {
      _avatarCache = await Hive.openBox('avatar_cache');
    }
  }

  @override
  void initState() {
    super.initState();
    // Remote avatar URLs are protected by the current Novyn session. Retry
    // when the app restores or rotates that session, even if the URL is stable.
    ApiService.sessionRevision.addListener(_handleSessionRevision);
    _loadImage();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      // Never leave the previous person's photo visible while a new URL loads.
      setState(() => _cachedImage = null);
      _loadImage(forceNetwork: true);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    ApiService.sessionRevision.removeListener(_handleSessionRevision);
    super.dispose();
  }

  void _handleSessionRevision() {
    final source = widget.photoUrl;
    if (source.startsWith('https://') || source.startsWith('http://')) {
      _loadImage(forceNetwork: true);
    }
  }

  Future<void> _loadImage({bool forceNetwork = false}) async {
    final generation = ++_loadGeneration;
    final photoUrl = widget.photoUrl;
    bool isCurrentLoad() =>
        mounted && generation == _loadGeneration && widget.photoUrl == photoUrl;

    if (photoUrl.isEmpty) {
      if (mounted) setState(() => _cachedImage = null);
      return;
    }

    try {
      await _UserAvatarState.initCache();
      if (!isCurrentLoad()) return;

      // Hash the complete URL: using only its first 20 characters made every
      // photo on the same Novyn host collide in the avatar cache.
      final cacheKey = 'avatar_' + photoUrl.hashCode.toString();
      final cached = _avatarCache?.get(cacheKey);
      Uint8List? cachedBytes;
      if (cached != null && cached is List) {
        cachedBytes = Uint8List.fromList(cached.cast<int>());
        if (isCurrentLoad()) {
          setState(() => _cachedImage = cachedBytes);
        }
        if (!forceNetwork) return;
      }

      // Protected Novyn media URLs require the viewer's current session cookie.
      // Restore the cookie jar before the first request; a widget can otherwise
      // make an anonymous request during app startup and never retry that URL.
      if (photoUrl.startsWith('https://') ||
          photoUrl.startsWith('http://')) {
        await ApiService.initializeSessionStorage();
        if (!isCurrentLoad()) return;

        final imageUri = Uri.tryParse(photoUrl);
        final backendUri = Uri.tryParse(ApiService.baseUrl);
        final isNovynMedia = imageUri != null &&
            backendUri != null &&
            imageUri.host.toLowerCase() == backendUri.host.toLowerCase();

        http.Response? response;
        for (var attempt = 0; attempt < 3; attempt++) {
          if (!isCurrentLoad()) return;
          try {
            response = await http.get(
              Uri.parse(photoUrl),
              headers: ApiService.imageHeaders,
            ).timeout(const Duration(seconds: 20));
          } catch (_) {
            if (attempt == 2) break;
            await Future<void>.delayed(
              Duration(milliseconds: 500 * (attempt + 1)),
            );
            continue;
          }

          if (!isCurrentLoad()) return;

          // A rotated/expired access cookie is recoverable. Refresh it once,
          // then retry with the newly persisted cookie pair. A 403 is a real
          // media-permission denial and must not be bypassed.
          if (response.statusCode == 401 && isNovynMedia && attempt == 0) {
            final refreshed = await ApiService.refreshSessionStatus()
                .timeout(const Duration(seconds: 12), onTimeout: () => null);
            if (!isCurrentLoad()) return;
            if (refreshed == 200) {
              await ApiService.initializeSessionStorage();
              continue;
            }
          }

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            break;
          }

          if (response.statusCode >= 500 && attempt < 2) {
            await Future<void>.delayed(
              Duration(milliseconds: 500 * (attempt + 1)),
            );
            continue;
          }
          break;
        }

        if (!isCurrentLoad()) return;
        if (response?.statusCode == 200 &&
            response!.bodyBytes.isNotEmpty) {
          final bytes = response.bodyBytes;
          await _avatarCache?.put(cacheKey, bytes.toList());
          if (isCurrentLoad()) setState(() => _cachedImage = bytes);
          return;
        }

        // Keep an existing cached image on transient transport/server errors,
        // but respect an authenticated 403 when the owner has hidden the photo.
        if (response?.statusCode == 403 ||
            (response?.statusCode == 401 && cachedBytes == null)) {
          if (isCurrentLoad()) setState(() => _cachedImage = null);
        } else if (cachedBytes == null && isCurrentLoad()) {
          setState(() => _cachedImage = null);
        }
        return;
      }

      // Decode legacy base64 avatars and cache them.
      final decoded = _safeBase64Decode(photoUrl);
      if (decoded.isNotEmpty) {
        await _avatarCache?.put(cacheKey, decoded.toList());
        if (isCurrentLoad()) setState(() => _cachedImage = decoded);
      } else if (isCurrentLoad()) {
        setState(() => _cachedImage = null);
      }
    } catch (_) {
      if (isCurrentLoad() && _cachedImage == null) {
        setState(() => _cachedImage = null);
      }
    }
  }

  /// Safely decode base64 — returns empty bytes on any error
  static Uint8List _safeBase64Decode(String data) {
    try {
      return base64Decode(data);
    } catch (_) {
      return Uint8List(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty
        ? widget.name.substring(0, 1).toUpperCase()
        : '?';
    final color = widget.fallbackColor ?? Theme.of(context).colorScheme.primary;
    final hasPhoto = _cachedImage != null && _cachedImage!.isNotEmpty;

    Widget avatar = Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasPhoto ? Colors.transparent : color.withValues(alpha: 0.12),
        border: widget.borderWidth > 0
            ? Border.all(
                color: widget.borderColor ?? Colors.white,
                width: widget.borderWidth)
            : null,
        image: hasPhoto
            ? DecorationImage(
                image: MemoryImage(_cachedImage!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasPhoto
          ? null
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.bold,
                  fontSize: widget.radius * 0.75,
                  color: color,
                ),
              ),
            ),
    );

    if (!widget.showOnlineIndicator) return avatar;

    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            key: const ValueKey('avatar-presence'),
            width: widget.radius * 0.55,
            height: widget.radius * 0.55,
            decoration: BoxDecoration(
              color: !widget.isOnline
                  ? const Color(0xFF64748B)
                  : switch (widget.presence?.trim().toLowerCase()) {
                      'away' => const Color(0xFFF59E0B),
                      'busy' || 'dnd' => const Color(0xFFEC4899),
                      'invisible' || 'offline' => const Color(0xFF64748B),
                      _ => const Color(0xFF10B981),
                    },
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
