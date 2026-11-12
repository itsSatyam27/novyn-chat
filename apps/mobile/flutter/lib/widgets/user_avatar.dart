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

  // Initialize cache box (call once in app startup)
  static Future<void> initCache() async {
    if (_avatarCache == null || !_avatarCache!.isOpen) {
      _avatarCache = await Hive.openBox('avatar_cache');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if photoUrl changed
    if (oldWidget.photoUrl != widget.photoUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.photoUrl.isEmpty) {
      setState(() => _cachedImage = null);
      return;
    }

    try {
      // Ensure cache is initialized
      await _UserAvatarState.initCache();

      // Hash the complete URL: using only its first 20 characters made every
      // photo on the same Novyn host collide in the avatar cache.
      final cacheKey = 'avatar_${widget.photoUrl.hashCode}';

      // 1. Try to load from Hive cache (instant)
      final cached = _avatarCache?.get(cacheKey);
      if (cached != null && cached is List) {
        final bytes = Uint8List.fromList(cached.cast<int>());
        if (mounted) {
          setState(() => _cachedImage = bytes);
        }
        return;
      }

      // 2. Protected Novyn media URLs require the signed-in session cookie.
      // Fetch them with authenticated headers rather than treating them as base64.
      if (widget.photoUrl.startsWith('https://') ||
          widget.photoUrl.startsWith('http://')) {
        final response = await http.get(
          Uri.parse(widget.photoUrl),
          headers: ApiService.imageHeaders,
        ).timeout(const Duration(seconds: 20));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final bytes = response.bodyBytes;
          await _avatarCache?.put(cacheKey, bytes.toList());
          if (mounted) setState(() => _cachedImage = bytes);
          return;
        }
        if (mounted) setState(() => _cachedImage = null);
        return;
      }

      // 3. Decode legacy base64 avatars and cache them.
      final decoded = _safeBase64Decode(widget.photoUrl);
      if (decoded.isNotEmpty) {
        // Save to cache for next time (async, don't await)
        _avatarCache?.put(cacheKey, decoded.toList());
        if (mounted) {
          setState(() => _cachedImage = decoded);
        }
      } else {
        if (mounted) {
          setState(() => _cachedImage = null);
        }
      }
    } catch (e) {
      if (mounted) {
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
