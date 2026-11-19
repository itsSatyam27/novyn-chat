# Mello Mobile

Fresh Flutter client for Mello. This app lives beside the legacy Novyn clients so the old implementation remains available as migration reference.

## Build locally

From this directory:

```bash
flutter create --platforms=android --org com.mello.chat --project-name mello .
flutter pub get
flutter build apk --release --target-platform=android-arm64
```

The generated Android platform folder is intentionally created by Flutter tooling rather than copied from the legacy Novyn app.

## GitHub Actions

The `Mello Android APK` workflow builds this app on pushes to `phase-2` and on manual dispatch. Download the APK from the workflow run's Artifacts section.

The initial build is a development/testing APK. Firebase, production signing, and Shorebird are not configured yet.
