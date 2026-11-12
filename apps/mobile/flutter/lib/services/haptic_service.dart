import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';
import 'security_service.dart';

enum NovynHapticType {
  light,
  medium,
  heavy,
  selection,
  success,
  error,
  warning,
}

class HapticService {
  static SettingsService? _settings;

  static void init(SettingsService settings) {
    _settings = settings;
  }

  /// Plays the exact notification rhythm selected in Sound & Vibration.
  static Future<void> vibrateNotification() async {
    final settings = _settings;
    if (settings == null || !settings.inAppVibration) return;

    final pattern = settings.vibrationPattern;
    if (pattern == 'none') return;

    final intensity = settings.hapticIntensity.clamp(0.0, 1.0);
    final amplitude = (70 + intensity * 185).round().clamp(1, 255);

    // Each entry is a duration in milliseconds. A zero amplitude is a pause.
    // The patterns are intentionally distinct in both pulse count and spacing.
    final List<int> timings;
    final List<int> amplitudes;

    switch (pattern) {
      case 'staccato':
        timings = [0, 28, 58, 28, 58, 28];
        amplitudes = [0, amplitude, 0, amplitude, 0, amplitude];
        break;
      case 'heartbeat':
        timings = [0, 48, 95, 112];
        amplitudes = [0, amplitude, 0, amplitude];
        break;
      case 'standard':
      default:
        timings = [0, 75];
        amplitudes = [0, amplitude];
        break;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await SecurityService.vibratePattern(
        timings: timings,
        amplitudes: amplitudes,
      );
      return;
    }

    // iOS and other platforms: approximate the same pulse rhythm with
    // native haptic impacts, preserving the pauses between pulses.
    for (var i = 0; i < timings.length; i++) {
      final duration = timings[i];
      if (amplitudes[i] > 0) {
        if (duration >= 90) {
          await HapticFeedback.heavyImpact();
        } else if (duration >= 45) {
          await HapticFeedback.mediumImpact();
        } else {
          await HapticFeedback.lightImpact();
        }
      } else if (duration > 0) {
        await Future.delayed(Duration(milliseconds: duration));
      }
    }
  }

  static Future<void> vibrate(NovynHapticType type) async {
    if (_settings == null || !_settings!.inAppVibration) return;

    final intensity = _settings!.hapticIntensity;

    switch (type) {
      case NovynHapticType.light:
        if (intensity < 0.3) {
          await HapticFeedback.selectionClick();
        } else {
          await HapticFeedback.lightImpact();
        }
        break;
      case NovynHapticType.medium:
        if (intensity < 0.4) {
          await HapticFeedback.lightImpact();
        } else {
          await HapticFeedback.mediumImpact();
        }
        break;
      case NovynHapticType.heavy:
        if (intensity < 0.3) {
          await HapticFeedback.lightImpact();
        } else if (intensity < 0.6) {
          await HapticFeedback.mediumImpact();
        } else {
          await SecurityService.vibrate(duration: 80);
        }
        break;
      case NovynHapticType.selection:
        await HapticFeedback.selectionClick();
        break;
      case NovynHapticType.success:
        if (intensity < 0.5) {
          await HapticFeedback.selectionClick();
        } else {
          await SecurityService.vibrate(duration: 30);
          await Future.delayed(const Duration(milliseconds: 80));
          await HapticFeedback.lightImpact();
        }
        break;
      case NovynHapticType.error:
        await SecurityService.vibrate(duration: 150);
        break;
      case NovynHapticType.warning:
        await SecurityService.vibrate(duration: 50);
        await Future.delayed(const Duration(milliseconds: 100));
        await SecurityService.vibrate(duration: 50);
        break;
    }
  }
}
