import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification preferences', () {
    test('category preferences default on and quiet hours default off', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      for (final key in SettingsService.notificationPreferenceStorageKeys.keys) {
        expect(
          settings.notificationPreference(key),
          key == 'quietHoursEnabled' ? isFalse : isTrue,
          reason: key,
        );
      }
      expect(settings.quietHoursStart, '22:00');
      expect(settings.quietHoursEnd, '07:00');
    });

    test('category preferences and quiet hours schedule persist across reloads',
        () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      await settings.setNotificationPreference('groupMessagesEnabled', false);
      await settings.setNotificationPreference('quietHoursEnabled', true);
      await settings.setQuietHoursSchedule(
        start: '23:15',
        end: '06:45',
        offsetMinutes: 330,
      );

      final restored = SettingsService();
      await restored.load();

      expect(restored.notificationPreference('groupMessagesEnabled'), isFalse);
      expect(restored.notificationPreference('quietHoursEnabled'), isTrue);
      expect(restored.quietHoursStart, '23:15');
      expect(restored.quietHoursEnd, '06:45');
      expect(restored.quietHoursOffsetMinutes, 330);
      expect(
        restored.notificationPreferencesPayload()['quietHoursOffsetMinutes'],
        330,
      );
    });

    test('quiet hours rejects invalid time values', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.load();

      await expectLater(
        settings.setQuietHoursSchedule(start: '25:00'),
        throwsArgumentError,
      );
      await expectLater(
        settings.setQuietHoursSchedule(end: '07.30'),
        throwsArgumentError,
      );
    });
  });
}
