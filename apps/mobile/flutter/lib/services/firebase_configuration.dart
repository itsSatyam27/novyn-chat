import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Use native Firebase registration or explicit public client build values.
/// Never supply service-account credentials to a client.
class FirebaseConfiguration {
  static FirebaseOptions? get options {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const values = [apiKey, appId, senderId, projectId];
    if (values.every((value) => value.isEmpty) &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return null;
    }
    if (values.any((value) => value.isEmpty)) {
      throw StateError(
        'Firebase is not configured. Supply FIREBASE_API_KEY, FIREBASE_APP_ID, '
        'FIREBASE_MESSAGING_SENDER_ID and FIREBASE_PROJECT_ID using --dart-define, '
        'or configure native Firebase platform files.',
      );
    }
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      authDomain: authDomain == '' ? null : authDomain,
      storageBucket: storageBucket == '' ? null : storageBucket,
      iosBundleId: iosBundleId == '' ? null : iosBundleId,
    );
  }
}
