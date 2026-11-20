import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Accessibility font-size default', () {
    test('uses Default (85%) when no preference has been saved', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();

      await settings.load();

      expect(settings.fontSize, 0.85);
    });

    test('allows Small to be smaller than Default', () async {
      SharedPreferences.setMockInitialValues({'font_size': 0.75});
      final settings = SettingsService();

      await settings.load();

      expect(settings.fontSize, 0.75);
      await settings.setFontSize(0.75);
      expect(settings.fontSize, 0.75);
    });

    test('preserves a font size explicitly saved by the user', () async {
      SharedPreferences.setMockInitialValues({'font_size': 1.0});
      final settings = SettingsService();

      await settings.load();

      expect(settings.fontSize, 1.0);
    });
  });
}
