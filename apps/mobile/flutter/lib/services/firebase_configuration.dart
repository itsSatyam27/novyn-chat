import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client registrations for the same Firebase project as Novyn web.
/// Never supply service-account credentials to a client.
class FirebaseConfiguration {
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '587953743769-tajofk7f23b5su5r7d0j5it5ifjfc5l9.apps.googleusercontent.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBpRhzVX4Xd_ievPOCuHNXJV6yxW_rwUXA',
    appId: '1:587953743769:android:95c552c6b290c2d2da5508',
    messagingSenderId: '587953743769',
    projectId: 'chat-novyn',
    storageBucket: 'chat-novyn.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyByU_NRvExuP6wnxhGqipTanvbMRwPUjYY',
    appId: '1:587953743769:web:96777c7f3a208772da5508',
    messagingSenderId: '587953743769',
    projectId: 'chat-novyn',
    authDomain: 'chat-novyn.firebaseapp.com',
    storageBucket: 'chat-novyn.firebasestorage.app',
  );

  static FirebaseOptions? get options {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const values = [apiKey, appId, senderId, projectId];
    if (values.every((value) => value.isEmpty)) {
      if (kIsWeb) return web;
      if (defaultTargetPlatform == TargetPlatform.android) return android;
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        return null;
      }
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
