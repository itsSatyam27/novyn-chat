# Obfuscated Android release symbols

Novyn's distributed Android builds use Dart obfuscation. The matching Dart symbol
maps are needed to make obfuscated crash stack traces readable. Never commit
plain symbol maps or attach them to a public GitHub Release.

## One-time repository setup

1. Generate a strong passphrase on a trusted local machine:

   ```sh
   openssl rand -base64 48
   ```

2. Save it in a password manager and keep a separate offline recovery copy.
3. Add it as the GitHub Actions repository secret
   `DEBUG_SYMBOLS_PASSPHRASE` under **Settings → Secrets and variables → Actions**.
4. Do not commit the passphrase, paste it into an issue/PR, or put it in a
   repository variable. It must remain an Actions secret.

The ARM64 release workflow and both Shorebird patch workflows fail closed if
this secret is absent. This avoids distributing an obfuscated build while
silently losing the only matching symbol maps.

## Where the symbol maps go

Each release/patch workflow creates a unique archive, encrypts it with GPG
symmetric AES-256, and uploads only the encrypted `.gpg` file as a GitHub
Actions artifact. The plaintext archive and build symbol directory are removed
from the runner after encryption. Symbols are not attached to the public APK
release.

GitHub Actions artifacts expire after 90 days. Download each encrypted symbols
artifact before it expires and keep the encrypted copy with the corresponding
APK/patch release in secure backup storage. Do not delete or overwrite old
release/patch maps: Android Shorebird patches replace the app's Dart code, so
crashes from patched code need that patch's own symbols.

## Decrypt and symbolicate a crash

Keep the passphrase in a local file readable only by your account (for example,
`chmod 600 ~/.config/novyn/symbols.pass`). Download the matching encrypted
artifact, then extract it without creating an unencrypted archive file:

```sh
mkdir -p ./novyn-symbols
gpg --batch --pinentry-mode loopback \
  --passphrase-file "$HOME/.config/novyn/symbols.pass" \
  --decrypt novyn-symbols-<release-or-patch-id>.tar.gz.gpg \
  | tar -xz -C ./novyn-symbols
```

Use the `.symbols` file for the exact release or patch that generated the
crash. For an ARM64 Dart stack trace:

```sh
flutter symbolize \
  --input=stacktrace.txt \
  --debug-info=./novyn-symbols/app.android-arm64.symbols
```

Never upload decrypted maps to the public repository or public release page.
