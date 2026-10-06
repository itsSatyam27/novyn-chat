import 'package:flutter/services.dart';

/// Wraps Android's AudioManager via a MethodChannel.
class AudioManagerService {
  static const _channel = MethodChannel('com.example.novyn/audio');

  /// Call ONCE when the call screen opens.
  /// Sets MODE_IN_COMMUNICATION + earpiece as default.
  static Future<void> startCallMode() async {
    try {
      await _channel.invokeMethod('startCallMode');
    } on PlatformException catch (_) {}
  }

  /// Toggle earpiece ↔ loudspeaker — no mode change, no audio pause.
  static Future<void> setSpeakerphoneOn(bool enable) async {
    try {
      await _channel.invokeMethod('setSpeakerphoneOn', {'enable': enable});
    } on PlatformException catch (_) {}
  }

  /// Mute/unmute the microphone at AudioManager level.
  /// Works during ringing before WebRTC peer connection exists.
  static Future<void> setMicMute(bool mute) async {
    try {
      await _channel.invokeMethod('setMicMute', {'mute': mute});
    } on PlatformException catch (_) {}
  }

  /// Call when the call ends — restores normal audio mode.
  static Future<void> resetMode() async {
    try {
      await _channel.invokeMethod('resetMode');
    } on PlatformException catch (_) {}
  }
}
