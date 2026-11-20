import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stealth Mode setting', () {
    test('defaults to off when no preference has been saved', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();

      await settings.load();

      expect(settings.stealthModeEnabled, isFalse);
    });

    test('persists changes and restores the saved value on load', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();

      await settings.load();
      await settings.setStealthMode(true);

      expect(settings.stealthModeEnabled, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('stealth_mode_enabled'), isTrue);

      final restoredSettings = SettingsService();
      await restoredSettings.load();
      expect(restoredSettings.stealthModeEnabled, isTrue);

      await restoredSettings.setStealthMode(false);
      expect(restoredSettings.stealthModeEnabled, isFalse);
      expect(preferences.getBool('stealth_mode_enabled'), isFalse);
    });
  });
}
