# Mello Phase 2 — Repository Structure & Migration

## Goal

Give Mello a clean, platform-independent architecture while keeping the redesign isolated on the `phase-2` branch. The default `main` branch is not part of this work.

## Target monorepo

```text
mello/
├── apps/
│   ├── mobile/
│   │   └── lib/
│   │       ├── app/
│   │       ├── core/
│   │       ├── shared/
│   │       └── features/
│   │           ├── auth/
│   │           ├── chats/
│   │           ├── contacts/
│   │           ├── calls/
│   │           ├── profile/
│   │           └── nearby/
│   └── web/                 # Future React client
├── backend/
│   └── src/
│       ├── config/
│       ├── modules/
│       │   ├── auth/
│       │   ├── users/
│       │   ├── conversations/
│       │   ├── messages/
│       │   └── realtime/
│       ├── middleware/
│       ├── services/
│       └── server.js
├── docs/
│   ├── architecture.md
│   ├── API.md
│   ├── authentication.md
│   └── NEARBY_MODE.md
└── README.md
```

## Ownership boundaries

- `apps/mobile`: Flutter UI, navigation, device permissions, local database and platform integrations.
- `apps/web`: future React UI; it must consume the same backend contract as mobile.
- `backend`: Node.js + Express REST API, Socket.IO gateway, authentication/session validation and MongoDB access. No Flutter, Android or iOS dependencies.
- `docs`: decisions and contracts shared by all clients.

## Backend contract

- REST routes are versioned under `/api/v1`.
- Socket.IO authenticates using the same backend-issued identity/session.
- MongoDB is the shared cloud data store.
- Redis can be introduced later for horizontal realtime scaling; it is not required for the first milestone.
- Secrets and deployment-specific values are supplied through environment variables.

## Nearby Mode decisions

1. Both users must have Nearby Mode ON.
2. Nearby discovery and offline transfer are isolated in `apps/mobile/lib/features/nearby/`.
3. Use BLE for discovery and native platform transport (Android Nearby Connections / iOS Multipeer Connectivity) for direct device-to-device transfer.
4. Nearby offline P2P must not depend on the cloud backend being reachable.
5. Each conversation lets the user choose **sync** (cloud-backed) or **local-only** storage. The selected mode must be visible and respected by message persistence logic.

## Migration approach

The existing Novyn code is legacy input, not the target architecture. Review and port features deliberately; do not bulk-copy the old UI or assume old services satisfy Mello's security requirements.

The current Phase 2 branch still contains legacy paths such as `apps/api`, `apps/web` and a previous mobile client. They remain temporarily so the existing project is not destroyed during the foundation setup. Move backend modules into `backend/` only after checking imports, scripts, environment variables and deployment configuration. Retire old client paths only after their replacement is runnable.

## Milestones

1. **Foundation:** Mello naming, workspace boundaries, docs and environment templates.
2. **Mobile shell:** Flutter app bootstrap, routing, theme and feature module boundaries.
3. **Backend foundation:** Express app, MongoDB connection, health route, API versioning and Socket.IO bootstrap.
4. **Identity:** registration, sign-in, session lifecycle and account recovery.
5. **Messaging:** one-to-one and group conversations, persistence and realtime delivery.
6. **Nearby Mode:** permissions, discovery, pairing, direct transport and local-only/sync selection.
7. **Web client:** React app using the same API and realtime contract.
8. **Hardening:** tests, security review, observability and deployment checks.

No milestone is considered complete solely because its folders or placeholder files exist.
