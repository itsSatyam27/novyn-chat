# Android App Links for Novyn profiles

The Android manifest registers `https://novyn.app/user/*` for package
`com.example.novyn`. Android will only verify and automatically open those
links after the website publishes a matching Digital Asset Links document.

## Get the production signing fingerprint

Use the certificate that actually signs the APK distributed to users. The
repository stores the release keystore in GitHub Actions secrets, so its
fingerprint is intentionally not committed to source.

For a local copy of the same release keystore:

```sh
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > novyn-release.jks
keytool -list -v -keystore novyn-release.jks \
  -alias "$ANDROID_KEY_ALIAS" \
  -storepass "$ANDROID_KEYSTORE_PASSWORD" | grep -i 'SHA256:'
rm -f novyn-release.jks
```

Do not commit the keystore, passwords, or private key. Only the SHA-256
certificate fingerprint is public. When distributing through Google Play with
Play App Signing enabled, use the **App signing certificate** fingerprint
from Play Console rather than the upload-key fingerprint.

## Publish Digital Asset Links

Create `.well-known/assetlinks.json` in the Firebase Hosting public directory
with the exact fingerprint from the production signing certificate:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.novyn",
      "sha256_cert_fingerprints": [
        "REPLACE_WITH_PRODUCTION_SHA256_FINGERPRINT"
      ]
    }
  }
]
```

Replace the placeholder with the colon-separated SHA-256 fingerprint. Never
publish a placeholder or a debug-key fingerprint for a production APK.

After deploying Firebase Hosting, verify that
`https://novyn.app/.well-known/assetlinks.json` returns the JSON document
with HTTP 200 and `Content-Type: application/json`. Then install the matching
signed APK and verify Android reports the host as verified, for example with:

```sh
adb shell pm get-app-links com.example.novyn
```

The app-link manifest and Flutter deep-link handler are already in place in
this branch. Until the real certificate fingerprint is published at that URL,
Android may offer the app as an unverified handler or keep the link in the
browser; automatic verified opening is not complete.
