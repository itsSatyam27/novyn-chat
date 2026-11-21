import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notification tone defaults to the tone shown as selected', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.load();

    expect(settings.notificationTone, 'Drift');
  });

  test('preview and incoming message playback share the same tone assets', () {
    expect(SettingsService.messageToneAsset('Drift'), 'audio/notification.mp3');
    expect(SettingsService.messageToneAsset('Pulse'), 'audio/message_sent.mp3');
    expect(SettingsService.messageToneAsset('Glass'), 'audio/ringtone.mp3');
    expect(SettingsService.messageToneAsset('Echo'), 'audio/call_ring.mp3');
    expect(SettingsService.messageToneAsset('unknown'), 'audio/notification.mp3');
  });
}
