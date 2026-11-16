import 'dart:async';
import 'package:flutter/services.dart';

/// Receives Novyn in-app profile links (`novyn://user/<username>`).
class ProfileDeepLinkService {
  ProfileDeepLinkService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.novyn/deep_links');
  static final StreamController<String> _links =
      StreamController<String>.broadcast();
  static Future<void>? _initialization;
  static String? _pendingLink;

  static void _publish(String raw) {
    if (_links.hasListener) {
      _links.add(raw);
    } else {
      _pendingLink = raw;
    }
  }

  static String? takePendingLink() {
    final value = _pendingLink;
    _pendingLink = null;
    return value;
  }

  static Stream<String> get links => _links.stream;

  static Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        _publish(call.arguments as String);
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null && initial.isNotEmpty) _publish(initial);
    } on PlatformException {
      // The Android platform channel may be unavailable in widget tests.
    } on MissingPluginException {
      // Non-Android platforms can still open profiles through the web UI.
    }
  }

  static String? usernameFromLink(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme == 'novyn' &&
          uri.host == 'user' &&
          uri.pathSegments.length == 1) {
        return _validUsername(uri.pathSegments.single);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  static String? _validUsername(String value) {
    final username = value.trim().replaceFirst(RegExp(r'^@'), '');
    if (username.isEmpty || username.length > 40 ||
        username.contains('/') || username.contains(String.fromCharCode(92))) {
      return null;
    }
    return username;
  }
}
