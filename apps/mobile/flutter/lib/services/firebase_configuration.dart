import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client registrations for the same Firebase project as Novyn web.
/// Never supply service-account credentials to a client.
class FirebaseConfiguration {
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '846944364575-ch2k51u85q4jdi50hsbqrdl4m4jv6k8l.apps.googleusercontent.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBFSgWsxUTrBz2K5h6WTi_mwSjoEpo947c',
    appId: '1:846944364575:android:f41df84158160110498d2a',
    messagingSenderId: '846944364575',
    projectId: 'novyn-chat-app',
    storageBucket: 'novyn-chat-app.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB1SjYr_LOS4oJ1sE4_Aws4Jg6faayvHT0',
    appId: '1:846944364575:web:94fd318c693a337d498d2a',
    messagingSenderId: '846944364575',
    projectId: 'novyn-chat-app',
    authDomain: 'novyn-chat-app.firebaseapp.com',
    storageBucket: 'novyn-chat-app.firebasestorage.app',
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
