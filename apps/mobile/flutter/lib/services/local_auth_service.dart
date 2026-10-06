import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

class LocalAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate({String reason = 'Authenticate to access Novyn'}) async {
    try {
      // Check what is actually available
      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      debugPrint('Available Biometrics: $availableBiometrics');

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Novyn Secure Node',
          ),
          IOSAuthMessages(
            localizedFallbackTitle: 'Enter PIN',
          ),
        ],
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Auth Error: ${e.code} - ${e.message}');
      return false;
    }
  }
}
