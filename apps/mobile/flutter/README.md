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


## Android OTA updates (Shorebird)

Novyn uses Shorebird Code Push for Dart-code updates. The first Shorebird-enabled APK is a **new release** and must be installed by users; after that, compatible Dart changes can be delivered as patches in the background and applied on the next app launch.

The **Novyn Optimized ARM64 APK** workflow now creates an ARM64-only Shorebird release and publishes that APK as the direct GitHub release download. It runs on matching pushes to `main` and `phase-2`, and can also be started manually. The **Novyn Shorebird OTA** workflow can create a manual ARM64 release or publish a patch for an existing release.

### One-time setup

1. Install the Shorebird CLI from [the official guide](https://docs.shorebird.dev/getting-started/) and sign in with `shorebird login`.
2. From this directory, run `shorebird init`. Commit the generated `shorebird.yaml`, the corresponding `pubspec.yaml` asset entry, and `pubspec.lock`. Do not invent or copy an app ID from another project.
3. Create a Shorebird service-account API key (Developer role) or personal API key and add it to GitHub repository Actions secrets as `SHOREBIRD_TOKEN`.
4. Ensure the existing repository secrets `GOOGLE_SERVICES_JSON`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` are configured.

### Publish the first OTA-capable APK

Run **Novyn Optimized ARM64 APK** from **Actions** (or push a Flutter change to `main` / `phase-2`) and install the signed `Novyn-Android-ARM64.apk` from the generated GitHub Release. This is the ARM64-only Shorebird-enabled APK. For a manually created release instead, run **Novyn Shorebird OTA** with `release` and install the `novyn-shorebird-arm64-release-*` artifact.

### Publish a Dart patch

Run **Novyn Shorebird OTA** with `patch`, enter the exact Shorebird release version shown in the release workflow summary (for example `1.0.0-beta+1790000000`), and select `staging` for testing or `stable` for production. Patch builds must use the same Shorebird release as the installed APK.

**Limitations:** OTA patches cover Dart code and Dart dependencies. Native Android/plugin code, Gradle/build configuration, permissions, images, fonts, and other bundled assets still require a new signed APK. Never commit Shorebird API keys or signing credentials.
