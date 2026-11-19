# Novyn Phase 2 — Product Scope & Existing Feature Audit

**Status:** Product definition draft for review  
**Repository:** `itsSatyam27/novyn-chat`  
**Branch:** `phase-2`  
**Scope rule:** This document supersedes the earlier Mello product direction on this branch. It does not authorize merging into `main`.

## 1. Product identity

**Novyn** is a modern, lightweight, privacy-first social messenger.

**Product promise:** Your conversations. Your space. Your control.

Novyn combines:
- Fast, reliable one-to-one and group communication.
- Social experiences such as chat games and Close Friends.
- Privacy controls, user-controlled conversation storage, and Nearby Mode.

The product should feel simple during everyday use while keeping advanced capabilities discoverable rather than cluttering the chat experience.

## 2. Existing repository audit — evidence and limitations

This is a source/repository audit, not a claim that every feature has been manually tested on physical devices. A feature's presence in source code, tests, or settings UI does not prove end-to-end production readiness.

### Repository evidence observed on `phase-2`

- Flutter legacy client exists at `apps/mobile/flutter`; its dependencies include Firebase Auth, Firestore, FCM, Socket.IO, WebRTC, local storage, media, biometric/PIN, and cryptography packages.
- Node backend exists at `apps/api/server.js` with modular chat, realtime, call, security, and notification code under `apps/api/server/`.
- API test files include chat integration, call handlers, group games, history pagination, security and notification tests.
- The Flutter source is organized into screens, services, models, widgets and theme.
- The separate `apps/mobile/mello` Flutter placeholder and `mello-android-apk.yml` workflow were created during the previous naming exploration. They are not the approved Phase 2 product direction and should be treated as temporary/obsolete until the Novyn implementation plan replaces them.
- The repository also contains a `backend/README.md` describing a future shared backend boundary; the actual established server remains under `apps/api`. Do not assume a backend migration has already happened.

### Feature-by-feature audit

| Feature | Evidence found | Phase 2 decision | Audit status |
|---|---|---|---|
| One-to-one chat | Chat backend modules, history pagination, message mutation handlers, integration tests | Retain; redesign UI and verify send/delivery/read states, offline recovery, pagination, retries and block enforcement | Existing implementation evidence; runtime validation pending |
| Group chat | Group-related realtime/server code and group-game tests | Retain; verify roles, membership changes, invite flow, permissions, group info and media access | Partial evidence; full flow audit pending |
| Voice/video calls | WebRTC dependency, call handlers and call-handler tests | Retain; verify signaling, permissions, reconnect, call lifecycle, background/termination behavior and call notifications | Existing implementation evidence; device/network matrix pending |
| Media sharing | Image/file picker, compression, gallery, Cloudinary/media access code and dependencies | Retain; repair preview, upload/download, compression quality, gallery integration, retry, size limits and access control | Existing implementation evidence; user-reported preview/download issues need regression tests |
| Chat games | Realtime game rules, game UI tests and group-game tests; previously identified Tic-Tac-Toe, Rock-Paper-Scissors and Four Dots | Retain; verify two-player synchronization, reconnect, turn validation and group support before adding more games | Existing implementation evidence; gameplay regression audit pending |
| Close Friends | Previously defined mutual/reciprocal special profile/avatar concept | Retain; define consent, pending/accepted states, mutual visibility, removal and privacy semantics | Product concept known; implementation status not yet verified |
| App lock & privacy | Local auth and secure-storage dependencies, lock wrapper and security settings | Retain; fix PIN storage, timeout/grace behavior, startup enforcement and screenshot protection | Known source-review gaps |
| Blocked users | Backend `set_block` handler and client blocked-user settings | Retain; make server list authoritative and verify messaging, calls, presence, search and existing conversations are consistently restricted | Backend evidence; Android local/server sync gap documented |
| Nearby Mode | Product decision previously made: both users ON; direct device-to-device transport; per-conversation cloud sync or local-only | Retain as a major differentiator; implement after core messaging and threat/OS capability review | Product decision only; production implementation not verified |
| Profile customization | Profile screens and backend profile update handling | Retain; fix client/server route mismatch and verify avatar, bio, username and privacy visibility | Known source-review mismatch |
| Message search | User-selected retention priority; exact full-text implementation not established in this pass | Retain; define search across local/cloud messages, filters, pagination and encrypted-message implications | Implementation not verified |

### Known high-priority defects from the existing mobile settings source audit

The existing settings audit documented these issues; they must be retested against the current branch before implementation:
- Two-factor setup is a local/delayed flow, not verified OTP enrollment or sign-in enforcement.
- Delete Account contains placeholder logic and must not show success until deletion is actually completed.
- Last-seen/profile-photo privacy client route does not match a backend route; visibility must be enforced server-side.
- App-lock PIN is stored in plain SharedPreferences; timeout behavior has a five-second grace period even for Immediately.
- Notification master/preview/group-alert preferences are saved but not all are consumed by runtime notification handling.
- Profile update client route and backend event naming are mismatched.
- Blocked-user settings use local IDs and are not consistently synchronized with the server list.
- Screenshot protection preference is not reapplied at app startup.
- Storage usage figures and clear-cache success behavior are not reliable; media quality/download settings need runtime integration.
- Some accessibility settings are preview-only or marked coming soon.

See `docs/mobile-settings-audit.md` for the detailed source-review findings. That document explicitly notes that it was not a full physical-device test.

## 3. Final proposed product scope

### Core communication
- One-to-one messaging.
- Group messaging and group administration.
- Message replies, reactions, edit/delete, delivery/read state where privacy settings permit.
- Message search.
- Push notifications with granular, actually enforced preferences.
- Reliable media: image, video, document and voice-message flows.
- Voice and video calling.

### Social layer
- Chat games: retain Tic-Tac-Toe, Rock-Paper-Scissors and Four Dots; evaluate additional games after reliability work.
- Close Friends with explicit mutual consent and clear pending/accepted/removed states.
- Profile customization.
- Polls in one-to-one and group conversations, with creator permissions, single/multiple choice rules, closing time and result visibility.

### Privacy and control
- App lock with secure PIN storage and biometric unlock.
- Server-authoritative block list and consistent enforcement.
- Per-conversation disappearing messages with clear duration, expiry semantics and honest caveat that recipients can still capture content.
- Per-conversation storage mode: Cloud Sync or Local Only.
- E2EE must be implemented with an audited protocol/library and a documented key lifecycle. Until verified, do not advertise E2EE. The existing settings audit reports that message-level E2EE/key-transfer paths were removed and that current backend message bodies are readable by the server; this must be addressed before any E2EE claim.
- Session/device management and account deletion must be real server-backed flows, not local UI placeholders.

### Personalization and convenience
- Chat themes: per-conversation theme/wallpaper, with clear local-vs-synced behavior.
- Message scheduling: schedule from a client while online; server-side scheduled delivery is required for delivery when sender's device is offline. Include cancel/edit and timezone handling.
- Search filters for sender, date, media and links, where supported by storage/index design.

### Nearby Mode
- Both participants must explicitly enable Nearby Mode.
- Discover and pair devices with explicit user confirmation.
- Direct device-to-device transport for the offline nearby path; cloud is not a relay for that path.
- Each conversation independently chooses Cloud Sync or Local Only.
- Use platform-native transport capabilities and document Android/iOS foreground/background limitations. Do not promise uninterrupted background delivery until proven on both platforms.

## 4. Non-goals for the first Phase 2 release

- Public social feed or algorithmic discovery.
- Large public communities/channels until core messaging is stable.
- Custom cryptographic algorithms.
- Claims of guaranteed screenshot prevention or recall after a recipient has seen a message.
- Unverified background delivery promises for Nearby Mode.
- Full web client before the mobile/backend contracts are stable.

## 5. Delivery priorities

1. **P0 — Audit and foundation:** establish buildable Novyn Flutter client, baseline tests, app architecture, API contract, design system and environment configuration. Preserve legacy client and services while migration is in progress.
2. **P1 — Core reliability:** authentication/session lifecycle, one-to-one chat, groups, realtime delivery, message history/search, media and notifications.
3. **P2 — Social:** calls, games, Close Friends, polls, profile customization and chat themes.
4. **P3 — Privacy controls:** secure app lock, server-authoritative blocks, disappearing messages, retention/storage controls and E2EE protocol/key lifecycle.
5. **P4 — Nearby Mode:** discovery, pairing, direct transfer, offline queue and local-only/cloud-sync behavior.
6. **P5 — Release readiness:** accessibility, performance, abuse controls, observability, backups, security review and signed Android release.

Dependencies may move individual items earlier when required for safety or architecture, but P0/P1 reliability takes precedence over cosmetic feature additions.

## 6. Acceptance principles

A feature is not complete because a screen or setting exists. Each feature needs:
- A documented user flow and API/data contract.
- Client and backend implementation where applicable.
- Unit/integration tests and failure-state handling.
- Android device testing; iOS testing before claiming iOS support.
- Regression coverage for existing features.
- Honest UI copy: no false success, fake encryption, or unimplemented controls.

## 7. Decisions still requiring product confirmation

- Whether message search includes only downloaded/local content or also queries cloud-synced history.
- Whether polls are editable after votes and whether voters are visible.
- Default disappearing-message duration and whether it can be configured per conversation.
- Whether scheduled messages are supported in groups at launch.
- Which chat-theme settings sync to other devices.
- Exact Close Friends mutual acceptance and removal behavior.
- E2EE rollout scope: one-to-one first, then groups, or another staged approach.
