# Novyn shared backend architecture

This directory records the target organization for Novyn's platform-independent backend.

## Current implementation

The active Node.js + Express + Socket.IO backend currently lives at `apps/api` (entry point: `apps/api/server.js`). Authentication, chat, calls, realtime handlers, MongoDB integration and current tests must continue to use that implementation until a deliberate migration is designed and verified.

This directory is **not** a second runtime server yet. Do not copy the existing server here or switch deployment scripts merely to make this folder look complete.

## Target responsibilities

- Node.js + Express HTTP API
- Socket.IO realtime gateway
- MongoDB persistence and migrations
- Authentication, sessions and authorization
- Shared request / response contracts for Flutter and React clients
- Server-side email delivery and account recovery

The backend must remain independent of Flutter, Android, iOS and browser UI code. Device-specific functionality belongs in the relevant client.

## Migration rules

1. Inventory the existing module, its callers, tests, environment variables and deployment path.
2. Move one coherent module at a time.
3. Keep API and realtime contracts compatible across mobile and web clients.
4. Run the relevant tests before changing deployment configuration.
5. Update documentation and environment examples alongside each migration.
6. Never place credentials or production secrets in this directory.

Nearby Mode's direct device-to-device offline transport belongs in the mobile clients; the backend should not become a relay dependency for that offline path.
