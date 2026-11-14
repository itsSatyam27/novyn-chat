import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/settings_service.dart';

void main() {
  group('Quick Toggle preferences', () {
    test('recommended defaults contain four supported shortcuts', () {
      expect(SettingsService.defaultQuickToggleIds, hasLength(4));
      expect(
        SettingsService.defaultQuickToggleIds.every(
          SettingsService.supportedQuickToggleIds.contains,
        ),
        isTrue,
      );
    });

    test('sanitizing removes unknown and duplicate IDs and caps at four', () {
      final result = SettingsService.sanitizeQuickToggleIds([
        'app_lock',
        'read_receipts',
        'app_lock',
        'not_a_real_toggle',
        'do_not_disturb',
        'in_app_sounds',
        'group_notifications',
      ]);

      expect(
        result,
        equals([
          'app_lock',
          'read_receipts',
          'do_not_disturb',
          'in_app_sounds',
        ]),
      );
      expect(result.length, lessThanOrEqualTo(SettingsService.maxQuickToggles));
    });

    test('sanitizing preserves the selected order', () {
      expect(
        SettingsService.sanitizeQuickToggleIds([
          'group_notifications',
          'in_app_vibration',
          'app_lock',
        ]),
        equals([
          'group_notifications',
          'in_app_vibration',
          'app_lock',
        ]),
      );
    });
  });
}
