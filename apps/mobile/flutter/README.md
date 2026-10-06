# novyn

The Flutter client targets `https://novyn-live.onrender.com` in release builds.

## Backend configuration

Run against a local Android-emulator backend without changing source:

```bash
flutter run --dart-define=NOVYN_API_URL=http://10.0.2.2:3000
```

For a physical device, use your computer's LAN URL instead. A release APK can
target another backend with `flutter build apk --release --dart-define=NOVYN_API_URL=https://your-api.example.com`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
