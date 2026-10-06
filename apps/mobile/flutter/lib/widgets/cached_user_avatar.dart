import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';

/// Optimized avatar widget with Hive disk caching for instant loads
class CachedUserAvatar extends StatefulWidget {
  final String name;
  final String photoUrl; // base64 string or empty
  final String userId; // For cache key
  final double radius;
  final Color? fallbackColor;
  final bool showOnlineIndicator;
  final bool isOnline;
  final double borderWidth;
  final Color? borderColor;

  const CachedUserAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.userId,
    this.radius = 24,
    this.fallbackColor,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.borderWidth = 0,
    this.borderColor,
  });

  @override
  State<CachedUserAvatar> createState() => _CachedUserAvatarState();
}

class _CachedUserAvatarState extends State<CachedUserAvatar> {
  Uint8List? _cachedImage;
  bool _isLoading = false;
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
  void didUpdateWidget(CachedUserAvatar oldWidget) {
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

    setState(() => _isLoading = true);

    try {
      // Ensure cache is initialized
      await initCache();

      final cacheKey = '${widget.userId}_avatar';

      // 1. Try to load from Hive cache (instant)
      final cached = _avatarCache?.get(cacheKey);
      if (cached != null && cached is List) {
        final bytes = Uint8List.fromList(cached.cast<int>());
        if (mounted) {
          setState(() {
            _cachedImage = bytes;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Decode base64 and cache it
      final decoded = _safeBase64Decode(widget.photoUrl);
      if (decoded.isNotEmpty) {
        // Save to cache for next time
        await _avatarCache?.put(cacheKey, decoded.toList());
        if (mounted) {
          setState(() {
            _cachedImage = decoded;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cachedImage = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedImage = null;
          _isLoading = false;
        });
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
    final color = widget.fallbackColor ?? const Color(0xFF7C6FF7);
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
          : _isLoading
              ? Center(
                  child: SizedBox(
                    width: widget.radius * 0.8,
                    height: widget.radius * 0.8,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontFamily: 'Inter',
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
        if (widget.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: widget.radius * 0.45,
              height: widget.radius * 0.45,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  // Clear cache for a specific user (e.g., when they update profile picture)
  static Future<void> clearCache(String userId) async {
    await initCache();
    await _avatarCache?.delete('${userId}_avatar');
  }

  // Clear all avatar cache (e.g., on logout)
  static Future<void> clearAllCache() async {
    await initCache();
    await _avatarCache?.clear();
  }
}
