import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invalid persisted theme index safely falls back to light mode', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 999});

    final settings = SettingsService();
    await settings.load();

    expect(settings.themeMode, ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('theme_mode'), ThemeMode.light.index);
  });

  test('clearAll resets every runtime preference to defaults', () async {
    SharedPreferences.setMockInitialValues({
      'notifications_on': false,
      'message_preview': false,
      'chat_link_previews': false,
      'read_receipts': false,
      'online_status': false,
      'chat_time_format': '24h',
      'call_ringtone': 'Custom',
      'accessibility_high_contrast': true,
      'accessibility_reduce_motion': true,
      'do_not_disturb_enabled': true,
      'stealth_mode_enabled': true,
    });

    final settings = SettingsService();
    await settings.load();

    await settings.setCallRingtone('Custom');
    await settings.setCustomNotificationPath('/tmp/custom-tone.mp3');
    await settings.setCustomRingtonePath('/tmp/custom-call.mp3');
    await settings.setHighContrast(true);
    await settings.setReduceMotion(true);
    await settings.setDoNotDisturbEnabled(true);
    await settings.setHapticCategory('navigation', false);
    await settings.setMessageVolume(0.2);
    await settings.setCallVolume(0.3);

    await settings.clearAll();

    expect(settings.notificationsOn, isTrue);
    expect(settings.messagePreview, isTrue);
    expect(settings.chatLinkPreviews, isTrue);
    expect(settings.readReceipts, isTrue);
    expect(settings.onlineStatus, isTrue);
    expect(settings.timeFormat, '12h');
    expect(settings.callRingtone, 'Binary');
    expect(settings.customNotificationPath, isNull);
    expect(settings.customRingtonePath, isNull);
    expect(settings.highContrast, isFalse);
    expect(settings.reduceMotion, isFalse);
    expect(settings.doNotDisturbEnabled, isFalse);
    expect(settings.hapticNavigation, isTrue);
    expect(settings.messageVolume, 0.8);
    expect(settings.callVolume, 0.85);
    expect(settings.stealthModeEnabled, isFalse);
    expect(settings.hideNotificationContent, isFalse);
    expect(settings.activeSmartPresenceMode, 'online');
  });


  test('clearAll resets notification categories and quiet-hours schedule', () async {
    SharedPreferences.setMockInitialValues({
      'notification_direct_messages': false,
      'notification_group_messages': false,
      'notification_quiet_hours_enabled': true,
      'notification_quiet_hours_start': '01:30',
      'notification_quiet_hours_end': '05:45',
      'notification_quiet_hours_offset': 330,
    });

    final settings = SettingsService();
    await settings.load();
    await settings.clearAll();

    expect(settings.notificationPreference('directMessagesEnabled'), isTrue);
    expect(settings.notificationPreference('groupMessagesEnabled'), isTrue);
    expect(settings.notificationPreference('quietHoursEnabled'), isFalse);
    expect(settings.quietHoursStart, '22:00');
    expect(settings.quietHoursEnd, '07:00');
    expect(settings.quietHoursOffsetMinutes, 0);
  });

  test('clearAll removes persisted preferences instead of leaving stale values', () async {
    SharedPreferences.setMockInitialValues({
      'call_ringtone': 'Custom',
      'accessibility_high_contrast': true,
      'do_not_disturb_enabled': true,
    });

    final settings = SettingsService();
    await settings.load();
    await settings.clearAll();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('call_ringtone'), isNull);
    expect(prefs.getBool('accessibility_high_contrast'), isNull);
    expect(prefs.getBool('do_not_disturb_enabled'), isNull);
  });
}
