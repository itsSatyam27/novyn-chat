# Mello 💬

**Little chats, big connections.**

Mello is a lightweight, privacy-focused chat app. Phase 2 is a fresh product and architecture direction: Flutter-first mobile, a platform-independent backend, and a future React web client.

## Phase 2 architecture

```text
mello/
├── apps/
│   ├── mobile/          # Flutter Android / iOS application
│   └── web/             # Future React web client
├── backend/             # Shared Node.js API + realtime gateway
├── docs/                # Architecture, API, security and feature specs
├── .env.example
└── README.md
```

The backend is independent of the client platform. Both Flutter and the future web app use the same versioned HTTP API and Socket.IO realtime gateway.

## Planned stack

| Layer | Technology |
|---|---|
| Mobile | Flutter (Android / iOS) |
| Web | React (planned) |
| Backend | Node.js + Express |
| Realtime | Socket.IO |
| Database | MongoDB |
| Local conversation storage | SQLite / Drift |
| Nearby discovery | BLE + platform-native nearby connectivity |

## Product decisions

- **Nearby Mode:** both users must have Nearby Mode enabled before a nearby connection can be established.
- **Nearby transport:** direct device-to-device transfer; no cloud relay for the offline P2P path.
- **Conversation storage:** each conversation lets users choose cloud sync or local-only storage.
- **Platform separation:** device-specific APIs stay inside the mobile client. The backend remains platform-independent.
- **API versioning:** HTTP endpoints live under `/api/v1`.
- **Security:** secrets stay in environment variables. End-to-end encryption will use an audited protocol/library; no custom cryptography.

## Phase 2 status

This branch is the Mello redesign foundation. Existing Novyn implementation files are being reviewed and migrated deliberately; legacy code is not automatically considered part of the new architecture. The old app's production services and `main` branch are not changed by this Phase 2 work.

See [Phase 2 structure and migration plan](docs/MELLO_PHASE2_STRUCTURE.md).

## Development

The Flutter app lives in `apps/mobile`. The shared backend target lives in `backend`. Setup instructions will be added to each workspace as implementation begins.

> **Status:** architecture and foundation stage. Authentication, messaging, Nearby Mode and E2EE must be implemented and tested before this branch is considered production-ready.
