import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges active-call state and Android's native Picture-in-Picture mode.
class CallPlatformService {
  CallPlatformService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.novyn/call_pip');

  static ValueChanged<bool>? _pipListener;
  static bool _handlerInstalled = false;
  static bool _callActive = false;

  static bool get isCallActive => _callActive;

  static void setPipListener(ValueChanged<bool>? listener) {
    _pipListener = listener;
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final arguments = Map<String, dynamic>.from(call.arguments as Map);
        _pipListener?.call(arguments['isInPip'] == true);
      }
    });
  }

  static Future<void> setCallActive(bool active) async {
    _callActive = active;
    try {
      await _channel.invokeMethod<void>(
        'setCallActive',
        <String, Object>{'active': active},
      );
    } on PlatformException catch (error) {
      debugPrint('[CallPlatformService] PiP state update failed: $error');
    } on MissingPluginException {
      // Non-Android platforms do not register the native PiP channel.
    }
  }
}
