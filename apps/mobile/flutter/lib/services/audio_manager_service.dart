import 'package:flutter/services.dart';

/// Android call audio routing, including Bluetooth communication devices.
class AudioManagerService {
  static const _channel = MethodChannel('com.example.novyn/audio');
  static const _routeEvents = EventChannel('com.example.novyn/audio_routes');

  static Stream<List<Map<String, dynamic>>> get routeChanges =>
      _routeEvents.receiveBroadcastStream().map((event) {
        final values = (event as List).cast<Map>();
        return values.map((value) => Map<String, dynamic>.from(value)).toList();
      });

  static Future<void> startCallMode() async {
    try {
      await _channel.invokeMethod('startCallMode');
    } on PlatformException catch (_) {}
  }

  /// Select a communication output by the route ID reported by Android.
  static Future<bool> setAudioRoute(String routeId) async {
    try {
      return await _channel.invokeMethod<bool>(
            'setAudioRoute',
            {'routeId': routeId},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAvailableRoutes() async {
    try {
      final values = await _channel.invokeListMethod<dynamic>('getAudioRoutes');
      return (values ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  static Future<void> setSpeakerphoneOn(bool enable) async {
    await setAudioRoute(enable ? 'speaker' : 'earpiece');
  }

  static Future<void> setMicMute(bool mute) async {
    try {
      await _channel.invokeMethod('setMicMute', {'mute': mute});
    } on PlatformException catch (_) {}
  }

  static Future<void> resetMode() async {
    try {
      await _channel.invokeMethod('resetMode');
    } on PlatformException catch (_) {}
  }
}
