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
    final amplitude = (70 + intensity * 185).round().clamp(1, 255).toInt().toInt();

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

    // Android's framework HapticFeedback follows the device-wide touch-feedback
    // switch. Use a direct Vibrator effect instead, so the user's Novyn haptic
    // preferences remain in control even when system touch haptics are disabled.
    // Keep these pulses long/strong enough to be perceptible across common
    // Android vibration motors. Incoming-notification rhythms use their own
    // separate preference and pattern above.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final peakAmplitude = (90 + 165 * intensity)
          .round()
          .clamp(1, 255)
          .toInt();
      int scaledAmplitude(double strength) =>
          (peakAmplitude * strength).round().clamp(1, 255).toInt();

      switch (type) {
        case NovynHapticType.light:
          await SecurityService.vibrate(
            duration: 24,
            amplitude: scaledAmplitude(0.68),
          );
          break;
        case NovynHapticType.medium:
          await SecurityService.vibrate(
            duration: 36,
            amplitude: scaledAmplitude(0.84),
          );
          break;
        case NovynHapticType.heavy:
          await SecurityService.vibrate(
            duration: 56,
            amplitude: peakAmplitude,
          );
          break;
        case NovynHapticType.selection:
          await SecurityService.vibrate(
            duration: 20,
            amplitude: scaledAmplitude(0.52),
          );
          break;
        case NovynHapticType.success:
          await SecurityService.vibrate(
            duration: 24,
            amplitude: scaledAmplitude(0.68),
          );
          await Future.delayed(const Duration(milliseconds: 58));
          await SecurityService.vibrate(
            duration: 32,
            amplitude: scaledAmplitude(0.78),
          );
          break;
        case NovynHapticType.error:
          await SecurityService.vibrate(
            duration: 64,
            amplitude: scaledAmplitude(0.94),
          );
          break;
        case NovynHapticType.warning:
          await SecurityService.vibrate(
            duration: 26,
            amplitude: scaledAmplitude(0.76),
          );
          await Future.delayed(const Duration(milliseconds: 70));
          await SecurityService.vibrate(
            duration: 26,
            amplitude: scaledAmplitude(0.76),
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
