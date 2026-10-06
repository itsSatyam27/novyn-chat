import 'package:flutter/services.dart';
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

  static Future<void> vibrate(NovynHapticType type) async {
    if (_settings == null || !_settings!.inAppVibration) return;

    final intensity = _settings!.hapticIntensity;
    
    // Scale haptic type based on intensity if possible
    // (Intensity 0.0-1.0)
    
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
          // Native hardware vibrate for max resonance
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
