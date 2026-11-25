
# Running Novyn after the security fixes

## Local development

Application code lives in `apps/web`, `apps/api`, and `apps/mobile`.
Run npm commands from the repository root. Keep Render's root directory unset,
build with `npm ci --include=dev && npm run build`, and start with `npm start`.
The web output is `apps/web/dist`. Static hosting must publish that directory.
The shared `.env` remains at the repository root. Default local storage is now
`apps/api/runtime/data` and `apps/api/runtime/uploads`. Existing explicit
`DATA_DIR` and `UPLOADS_DIR` settings continue to take precedence; persistent
production volume paths do not need to change.

After the Flutter move, run `npm run flutter:get` to regenerate local package
metadata. Open Android Studio at `apps/mobile/capacitor/android` for Capacitor
or `apps/mobile/flutter/android` for Flutter. The Flutter iOS project is in
`apps/mobile/flutter/ios`; iOS builds require macOS/Xcode.

Flutter Firebase setup is required before running the app: put your project's
Android `google-services.json` in `apps/mobile/flutter/android/app` and its iOS
`GoogleService-Info.plist` in `apps/mobile/flutter/ios/Runner` (add it to the Runner
target in Xcode). Both files are ignored by Git. Alternatively, supply
`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, and
`FIREBASE_PROJECT_ID` using Flutter `--dart-define` arguments, with the app ID
registered for the platform being built. Optional values are `FIREBASE_AUTH_DOMAIN`,
`FIREBASE_STORAGE_BUCKET`, and `FIREBASE_IOS_BUNDLE_ID`. Web/desktop builds require
explicit values. Do not reuse the web Firebase app ID for Android or iOS, and
never embed server private keys or service-account credentials in the app.

Flutter uses Firebase for Google identity, but chat, friend, and account data
come from the Novyn API and Socket.IO backend, shared with the web app. Make
sure `NOVYN_API_URL` points to the same backend used by web; Flutter defaults to
`https://novyn-live.onrender.com` and can be overridden with
`--dart-define=NOVYN_API_URL=https://your-backend-host`.

The primary Firebase project is `chat-novyn`. For production, set the API's
`FIREBASE_SERVICE_ACCOUNT_JSON` to its Admin service account and update the
web build's `VITE_FIREBASE_*` values to the same project's web app. During the
mobile transition, put the old project's Admin service account in
`FIREBASE_LEGACY_SERVICE_ACCOUNT_JSON`; the API uses it to verify old app tokens,
send notifications to old-project FCM tokens, and remove linked identities.
Keep that variable until old app versions are no longer in use. In Firebase
Authentication, enable Google sign-in and add `novyn-live.onrender.com` to the
authorized domains before deploying the new web configuration.

Google Sign-In troubleshooting: if the app fails with `sign_in_failed` /
`ApiException: 10`, the Firebase Android app configuration is mismatched. Ensure the
Android package name matches the one in `google-services.json`, add the SHA-1 for
the signing key used by the device or build, and download a fresh
`google-services.json` from the Firebase console. The default app package in this
repo is `com.example.novyn`; if you changed the package ID, update the Firebase app
and regenerate the config file to match.

The Firebase-hosted admin monitor source is in `public/admin/`. It signs
administrators in with Google using Firebase Authentication and calls the Render
API for MongoDB-backed usage and feedback data. Configure the API with
`ADMIN_EMAILS=novynchat.app@gmail.com` and
`ADMIN_ALLOWED_ORIGINS=https://chat-novyn.web.app,https://chat-novyn.firebaseapp.com`.
The Render API must use the `chat-novyn` Firebase Admin credentials, and Google
sign-in must be enabled for that Firebase project. Deploy the updated API
service on Render before publishing the dashboard with
`firebase deploy --only hosting --project chat-novyn`; it will be available at
`https://chat-novyn.web.app/admin/`. Administrators can edit usernames, suspend
or restore accounts, and permanently delete accounts with their associated chat
data and uploaded media. Suspension revokes active sessions; deletion also
removes the linked Firebase identity. Admin accounts cannot be changed through
these controls.
The dashboard does not expose chat message contents. The existing main-branch
Hosting workflow intentionally skips admin-only changes, so it cannot publish
this Firebase dashboard to the old project.

Use Node 24 or newer, install with `npm ci`, and start `npm run dev`.
On Windows PowerShell with scripts disabled, use `npm.cmd`.
The backend listens on port 3000; Vite proxies API, uploads, and Socket.IO there.
The server now fails on an occupied port instead of silently moving to a port
that Vite does not proxy. Stop the old backend before starting a new one.

Use `NODE_ENV=development` locally. Loopback browser origins (`localhost`,
`127.0.0.1`, and `::1`) are allowed in development. Production requires exact
origins in `ALLOWED_ORIGIN`. Local accounts and discovery use the configured
local database, not automatically the accounts on a hosted deployment.
Discover lists other online accounts and excludes friends, incoming requests,
blocked accounts, and invisible users. Test two different accounts in separate
browser profiles or a private window; tabs share login cookies, and the current
backend permits only one active socket per account.

## Existing accounts

The old password helper returned fields that signup did not store. Affected
accounts have no usable password hash. Login no longer accepts arbitrary
passwords for those accounts. Use the new **Forgot password?** flow or the
account's Google sign-in. Production password recovery requires SMTP. Local
development prints recovery codes in the backend terminal; production does not.
No existing account records are rewritten by this update.

Access tokens are now linked to revocable sessions. Older access tokens fall
back to a valid refresh cookie; otherwise the user must sign in again.

## Production deployment

Run **one Node backend process and one replica**. The backend still uses local
maps and whole-state MongoDB snapshots. Multiple replicas can overwrite one
another's data; adding a Socket.IO Redis adapter alone does not fix this.
Horizontal scaling requires database-owned operations, shared sessions and rate
limits, shared presence/call state, and coordinated scheduled jobs. These changes
have not been implemented in this patch.

Set `NODE_ENV=production`, `AUTH_SECRET`, `UPLOAD_TOKEN_SECRET`, and
`ALLOWED_ORIGIN=https://your-chat-host`. Terminate HTTPS at your hosting platform.

API HTTP requests emit structured JSON log events to the hosting platform's
standard output. Each response includes a generated `X-Request-Id`; the same
identifier appears in that request's log event for support and incident
correlation. Events include the HTTP method, registered route template, status
code, and duration in milliseconds. Server errors are logged at error level;
slow requests and aborted responses are logged at warning level. The default
slow-request threshold is 1000 ms and can be changed with
`SLOW_REQUEST_LOG_THRESHOLD_MS`.

Request logs intentionally omit raw URLs, query strings, route parameter
values, request bodies, cookies, authorization headers, and client-provided
request IDs. Do not add secrets or personal data to log fields when extending
this middleware.

Unexpected HTTP errors are handled centrally. Server-side failures return a generic
500 response and the request correlation ID, while valid client errors preserve
their 4xx status and message. Detailed internal exception messages and stack
traces are not sent to clients; correlate the request ID with the server logs.
When MongoDB is configured, refresh sessions are stored in its `auth_sessions`
collection and existing `auth-state.json` sessions are migrated automatically.
Without MongoDB, set `DATA_DIR` to a persistent volume so refresh sessions
survive restarts. Keep `UPLOADS_DIR` on persistent storage and back it up:
it contains local uploads and access metadata for new Cloudinary objects.

Configure both stable VAPID keys to enable push. Missing keys now disable push
instead of generating a new subscription identity or logging a private key.
Production startup fails when a configured MongoDB connection/load fails,
preventing an unnoticed switch to a different local account store.

## Media privacy and migration

Local media requires a signed-in owner or access to a conversation containing
the media. A bearer URL alone no longer authorizes downloading. New Cloudinary
objects use authenticated storage, with a 60-second download URL issued after
the same authorization check. Existing local conversation media remains readable
by conversation participants. Unreferenced legacy local files have no known
owner and are denied; re-upload those files if needed.

Previously uploaded **public Cloudinary objects remain public**. This patch
cannot revoke copies of those old URLs. Before claiming that historical media is
private, back up the media, migrate those remote objects to authenticated storage,
record their ownership/conversation mapping, update message URLs, and invalidate
old CDN delivery. This requires a deployment-specific data migration and has not
been run against your account. Media is not cryptographically encrypted by the app
at rest; download access is enforced by the backend.

Cloudinary's temporary-download API bypasses CDN caching and has higher bandwidth
costs. For a high-volume deployment, evaluate authenticated CDN delivery with
token/cookie access controls supported by your plan. See the
[Cloudinary access-control documentation](https://cloudinary.com/documentation/control_access_to_media).

## Verification and dependencies

Run `npm test` and `npm run build` before deployment. CI runs both. Integration
tests launch an isolated backend with test accounts and temporary storage; they
do not connect to the configured production database, mailer, or Cloudinary.
Live SMTP delivery, Google login, Cloudinary delivery, and native Android behavior
still need verification with deployment credentials/devices.

Security updates retain Capacitor 6 and override its archive dependency with
patched `tar` 7 through `vendor/capacitor-tar-compat`. This small wrapper supplies
the default export expected by Capacitor 6's compiled CommonJS code; the patched
upstream package performs all archive operations. `uuid` uses the CommonJS-compatible 11.x line,
and `qs` is overridden to its patched 6.x line. Nodemailer moves to patched 10.x.
Compatibility tests cover Capacitor template extraction and mail construction.
Recheck overrides when upgrading their parent packages.

Message E2EE and its key-management protocol have been removed from the web,
Capacitor, Flutter, and backend messaging paths. Message bodies are readable by
the backend and should only be sent over HTTPS/WSS in production. Password
hashing, session authentication, TOTP secret protection, and transport TLS remain
separate account/network security controls.
