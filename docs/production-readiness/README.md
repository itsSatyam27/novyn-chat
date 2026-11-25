# Novyn Production Readiness

This branch is a staged production-hardening effort. Do not treat the checklist as evidence that an item is already implemented.

## Release gates

### P0 — security and deployment safety
- [ ] Audit authentication/session lifecycle, token/cookie expiry, CSRF and session revocation.
- [ ] Audit rate limits for all sensitive endpoints (auth, password reset, uploads, search, invitations, game actions).
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
