import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';
import 'security_service.dart';

enum HapticCategory { navigation, typing, chat, buttons, notifications, calls }

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
    if (settings == null || !settings.inAppVibration || !settings.hapticNotifications) return;

    final pattern = settings.vibrationPattern;
    if (pattern == 'none') return;

    final intensity = settings.hapticIntensity.clamp(0.0, 1.0);
    final amplitude = (70 + intensity * 185).round().clamp(1, 255).toInt();

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

  static Future<void> vibrate(
    NovynHapticType type, { HapticCategory category = HapticCategory.buttons }
  ) async {
    final settings = _settings;
    if (settings == null || !settings.inAppVibration) return;
    if (!settings.hapticCategoryEnabled(category.name)) return;

    final intensity = settings.hapticIntensity.clamp(0.0, 1.0);
    if (intensity <= 0) return;

    // Android's HapticFeedback channel follows the device-wide touch-feedback
    // switch. Use the app's vibrator channel for deliberate in-app haptics so
    // Novyn's own vibration toggle/intensity remain authoritative. Notification
    // vibration stays on its separate pattern and preference path.
    if (defaultTargetPlatform == TargetPlatform.android) {
      switch (type) {
        case NovynHapticType.light:
          await SecurityService.vibrate(
            duration: 12,
            amplitude: (65 * intensity).round().clamp(1, 255),
          );
          break;
        case NovynHapticType.medium:
          await SecurityService.vibrate(
            duration: 22,
            amplitude: (135 * intensity).round().clamp(1, 255),
          );
          break;
        case NovynHapticType.heavy:
          await SecurityService.vibrate(
            duration: 36,
            amplitude: (220 * intensity).round().clamp(1, 255),
          );
          break;
        case NovynHapticType.selection:
          await SecurityService.vibrate(
            duration: 8,
            amplitude: (55 * intensity).round().clamp(1, 255),
          );
          break;
        case NovynHapticType.success:
          await SecurityService.vibrate(
            duration: 18,
            amplitude: (110 * intensity).round().clamp(1, 255),
          );
          await Future.delayed(const Duration(milliseconds: 65));
          await SecurityService.vibrate(
            duration: 24,
            amplitude: (155 * intensity).round().clamp(1, 255),
          );
          break;
        case NovynHapticType.error:
          await SecurityService.vibrate(
            duration: 90,
            amplitude: (190 * intensity).round().clamp(1, 255),
          );
          break;
        case NovynHapticType.warning:
          await SecurityService.vibrate(
            duration: 28,
            amplitude: (150 * intensity).round().clamp(1, 255),
          );
          await Future.delayed(const Duration(milliseconds: 75));
          await SecurityService.vibrate(
            duration: 28,
            amplitude: (150 * intensity).round().clamp(1, 255),
          );
          break;
      }
      return;
    }

    // iOS and other platforms use native semantic haptic feedback.
    switch (type) {
      case NovynHapticType.light:
      case NovynHapticType.selection:
        await HapticFeedback.selectionClick();
        break;
      case NovynHapticType.medium:
        await HapticFeedback.mediumImpact();
        break;
      case NovynHapticType.heavy:
      case NovynHapticType.error:
        await HapticFeedback.heavyImpact();
        break;
      case NovynHapticType.success:
      case NovynHapticType.warning:
        await HapticFeedback.lightImpact();
        break;
    }
  }
}
