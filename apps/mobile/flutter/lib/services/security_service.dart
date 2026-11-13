import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SecurityService {
  static const _channel = MethodChannel('com.example.novyn/security');

  /// Toggle FLAG_SECURE on Android (Screenshot protection & App Switcher blur)
  static Future<void> setSafeMode(bool enable) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('setSafeMode', {'enable': enable});
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

  /// Play a custom vibration waveform on Android.
  static Future<void> vibratePattern({
    required List<int> timings,
    required List<int> amplitudes,
  }) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('vibratePattern', {
          'timings': timings,
          'amplitudes': amplitudes,
        });
      } else {
        await HapticFeedback.mediumImpact();
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to trigger vibration pattern: ${e.message}');
    }
  }

  /// Trigger a hardware-level vibration (bypasses some system haptic blocks)
  static Future<void> vibrate({int duration = 50, int amplitude = 255}) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('vibrate', {
          'duration': duration.clamp(1, 5000),
          'amplitude': amplitude.clamp(1, 255),
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to trigger native vibration: ${e.message}');
    }
  }
}
