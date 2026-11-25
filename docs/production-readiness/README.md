# Novyn Production Readiness

This branch is a staged production-hardening effort. Do not treat the checklist as evidence that an item is already implemented.

## Implemented changes

- [x] Render HTTP and unauthenticated Socket.IO rate limits use a syntactically valid `CF-Connecting-IP` value for client identity. If that trusted edge header is missing or malformed, the limiter falls back to the socket peer rather than trusting potentially client-supplied `X-Forwarded-For` values. Regression tests cover HTTP throttling, HTTP client isolation, and Socket.IO identity.
- [x] HTTP rate limiting fails closed with `503` when the configured counter store is unavailable or malformed instead of silently bypassing the protection. Regression tests cover both cases.
- [x] Auth token creation reserves `sub`, `kind`, `iat`, and `exp` against metadata overrides; verification explicitly requires the signed `HS256` / `JWT` header. Regression tests cover reserved-claim overrides and unsupported signed headers.
- [x] SIGTERM/SIGINT shutdown waits for startup to settle, drains Socket.IO and HTTP, stops background timers, flushes application/auth state, then closes MongoDB. A bounded timeout forces a non-zero exit; persistence/storage failures also produce a non-zero exit. Unit and real Socket.IO/HTTP integration tests cover ordering and failure handling.
- [x] Web SPA and legacy browser auth now coalesce concurrent refresh calls into one in-flight request, preventing duplicate submissions of a rotating refresh cookie. Tests exercise concurrent calls and retry after completion/failure.
- [x] Encrypted identity-backup writes acknowledge success only after the state snapshot is durably flushed; failed writes restore the previous in-memory values and return an error. Integration coverage reads the persisted file immediately after the success acknowledgement.
- [x] CI validation now runs on pushes to `production-readiness` and for pull requests targeting it.
- [x] Socket.IO now rejects unauthenticated or stale-session sockets at handshake time; integration coverage asserts revoked refresh sessions receive `connect_error` before any event handler can run.
- [x] Device-pairing start/status/complete responses use `no-store` and `no-referrer`; status polling and primary-phone approval are rate-limited. Integration tests cover approval, status transition, encrypted identity return, session-cookie issuance and single-use completion.
- [x] Sensitive account socket actions (password/username changes, account deletion, 2FA toggles and device-pair approval) have per-account throttles. Integration coverage verifies repeated password-change attempts are stopped.
- [x] Signup reserves email and username while password hashing is pending. Google account creation reserves email, username and Google UID; linking an existing account also reserves its Google UID, preventing concurrent registrations/link operations from claiming the same identity in this single-process runtime. Tests cover reservation release and concurrent password signups.
- [x] SSRF protection blocks deprecated IPv4-compatible IPv6 destinations in addition to private IPv4/IPv6 ranges; tests include `::127.0.0.1`.
- [x] Sign-in now returns the same generic credential-failure response for unknown email/username, incorrect password, passwordless legacy accounts and suspended accounts. Missing-account attempts also execute a dummy PBKDF2 verification to reduce timing-based account enumeration. Integration tests cover equivalent responses.
- [x] Voice and file uploads now reject unsupported MIME headers in Multer before staging files and cap multipart files, fields, field size and total parts. Tests cover unsupported types and multipart abuse limits. File-signature verification and malware scanning are not yet implemented.
- [x] HTTP rate limits cover GIPHY, game-history reads/writes, game leaderboard, call-log reads/writes, public stats, RTC ICE configuration, push public-key retrieval, account-settings reads/writes and the 2FA setup/enable/disable endpoints. Integration coverage checks the 2FA setup and public-stats limits.
- [x] Socket action rate-limit bucket cleanup now sweeps the global map at most once per minute while checking and enforcing each active bucket on every protected action.
- [x] Local voice/file uploads and wallpaper imports remove the final on-disk file when metadata persistence fails, preventing inaccessible orphaned media.

## Deployment constraint

The authoritative user, conversation, group, presence, session and rate-limit state currently lives in in-process maps (see `apps/api/server/core/state.js`). Deploy **one backend process/replica only**. Do not enable multiple Render instances or horizontal autoscaling until authoritative state, rate limits and registration reservations are moved to shared storage with atomic operations. The current signup reservation closes same-process races; it is not a distributed lock.

## Release gates

### P0 — security and deployment safety
- [ ] Audit authentication/session lifecycle, token/cookie expiry, CSRF and session revocation.
- [ ] Complete rate-limit audit for all sensitive endpoints (auth, password reset, uploads, search, invitations, game actions); verify distributed storage before adding multiple backend replicas.
- [ ] Audit authorization boundaries for chat, group, media, games, calls, profile and settings.
- [ ] Verify upload limits, file-type validation, malware-risk handling, storage cleanup and access authorization.
- [ ] Review CORS/socket origin policy, TLS/proxy trust, security headers and production error responses.
- [ ] Ensure secrets are not committed, logged or exposed to clients; rotate any exposed secrets.
- [ ] Validate Firebase Admin identity and configuration fail-safe behavior.
- [ ] Verify MongoDB connection settings, indexes, validation, backups and restore procedures.
- [ ] Check abuse prevention, account enumeration and privacy leakage.

### P1 — reliability
- [ ] Health/readiness/liveness endpoints and dependency health.
- [ ] graceful shutdown and socket draining.
- [ ] MongoDB retry/backoff and timeout behavior; avoid silent failures.
- [ ] Offline/reconnect behavior, idempotent sends and retry queue.
- [ ] Push delivery reliability and notification deduplication.
- [ ] Presence cleanup and multi-device/session correctness.
- [ ] Error logging, correlation IDs, metrics and alerting.

### P2 — quality and operations
- [ ] API and integration tests for critical flows.
- [ ] Flutter tests/analyze and release APK validation.
- [ ] Web build, smoke tests and deployment verification.
- [ ] Accessibility, loading/error/empty states and performance.
- [ ] Privacy policy, terms, account deletion and data export/delete process.
- [ ] Release notes, rollback plan and versioning.

## Rules
- Work on this branch only; main remains untouched until review/merge.
- Keep each hardening change small, tested, and reviewable.
- Do not relax security checks to make CI pass.
- Firebase deploy/hosting changes are not part of this initial backend/mobile hardening scope unless explicitly requested.
- Secrets/configuration changes require owner-side setup and must never be committed.
