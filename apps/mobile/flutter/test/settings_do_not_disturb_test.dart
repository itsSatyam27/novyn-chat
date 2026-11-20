import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Do Not Disturb setting', () {
    test('defaults to off when no preference has been saved', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();

      await settings.load();

      expect(settings.doNotDisturbEnabled, isFalse);
    });

    test('persists changes and restores the saved value on load', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();

      await settings.load();
      await settings.setDoNotDisturbEnabled(true);

      expect(settings.doNotDisturbEnabled, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('do_not_disturb_enabled'), isTrue);

      final restoredSettings = SettingsService();
      await restoredSettings.load();
      expect(restoredSettings.doNotDisturbEnabled, isTrue);

      await restoredSettings.setDoNotDisturbEnabled(false);
      expect(restoredSettings.doNotDisturbEnabled, isFalse);
      expect(preferences.getBool('do_not_disturb_enabled'), isFalse);
    });
  });
}
