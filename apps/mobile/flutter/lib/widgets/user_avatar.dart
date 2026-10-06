import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';

/// Reusable avatar widget with Hive disk caching for instant loads
class UserAvatar extends StatefulWidget {
  final String name;
  final String photoUrl; // base64 string or empty
  final double radius;
  final Color? fallbackColor;
  final bool showOnlineIndicator;
  final bool isOnline;
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

      // Use photoUrl hash as cache key (first 20 chars for uniqueness)
      final cacheKey = widget.photoUrl.length > 20
          ? widget.photoUrl.substring(0, 20)
          : widget.photoUrl;

      // 1. Try to load from Hive cache (instant)
      final cached = _avatarCache?.get(cacheKey);
      if (cached != null && cached is List) {
        final bytes = Uint8List.fromList(cached.cast<int>());
        if (mounted) {
          setState(() => _cachedImage = bytes);
        }
        return;
      }

      // 2. Decode base64 and cache it
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
}

