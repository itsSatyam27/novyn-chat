import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/settings_service.dart';

void main() {
  test('Online preset exposes all audiences and signals', () {
    final p = SettingsService.smartPresenceDefaults('online');
    expect(p['presencePrivacy'], 'everyone');
    expect(p['discoverPrivacy'], 'everyone');
    expect(p['callsEnabled'], isTrue);
    expect(p['callPrivacy'], 'everyone');
    expect(p['messagePrivacy'], 'everyone');
    expect(p['notificationsEnabled'], isTrue);
  });
  test('Idle limits visibility to friends but leaves alerts on', () {
    final p = SettingsService.smartPresenceDefaults('idle');
    expect(p['presencePrivacy'], 'friends');
    expect(p['discoverPrivacy'], 'friends');
    expect(p['callsEnabled'], isTrue);
    expect(p['callPrivacy'], 'friends');
    expect(p['notificationsEnabled'], isTrue);
  });
  test('Busy blocks incoming calls and alerts but preserves messaging', () {
    final p = SettingsService.smartPresenceDefaults('busy');
    expect(p['callsEnabled'], isTrue);
    expect(p['callPrivacy'], 'nobody');
    expect(p['messagePrivacy'], 'friends');
    expect(p['notificationsEnabled'], isFalse);
    expect(p['readReceiptsEnabled'], isFalse);
  });
  test('Invisible hides presence and Discover while preserving messages', () {
    final p = SettingsService.smartPresenceDefaults('invisible');
    expect(p['presencePrivacy'], 'nobody');
    expect(p['discoverPrivacy'], 'nobody');
    expect(p['profilePhotoPrivacy'], 'nobody');
    expect(p['callsEnabled'], isFalse);
    expect(p['callPrivacy'], 'nobody');
    expect(p['messagePrivacy'], 'friends');
  });
  test('Away maps to Idle and local-only keys are excluded from server payload', () {
    expect(SettingsService.normalizeSmartPresenceMode('away'), 'idle');
    expect(SettingsService.presenceStatusForSmartMode('idle'), 'away');
    final p = SettingsService.smartPresenceServerFields({
      ...SettingsService.smartPresenceDefaults('busy'), 'inAppSoundsEnabled': false,
    });
    expect(p.containsKey('inAppSoundsEnabled'), isFalse);
  });
}
