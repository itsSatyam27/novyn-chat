import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SecurityService {
  static const _channel = MethodChannel('com.example.novyn/security');

  /// Toggle FLAG_SECURE on Android (Screenshot protection & App Switcher blur)
  static Future<void> setSafeMode(bool enable) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('setSafeMode', {'enable': enable});
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to set safe mode: ${e.message}');
    }
  }

  /// Toggle app icon between Novyn and "Calculator" alias
  static Future<void> setStealthIcon(bool enable) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('setStealthIcon', {'enable': enable});
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to set stealth icon: ${e.message}');
    }
  }

  /// Trigger a hardware-level vibration (bypasses some system haptic blocks)
  static Future<void> vibrate({int duration = 50}) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('vibrate', {'duration': duration});
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to trigger native vibration: ${e.message}');
    }
  }
}
