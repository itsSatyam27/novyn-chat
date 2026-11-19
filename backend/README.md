# Mello Shared Backend

This directory is the target home for Mello's platform-independent backend.

## Responsibilities

- Node.js + Express REST API under `/api/v1`
- Socket.IO realtime gateway
- MongoDB persistence
- Authentication and session validation
- Shared contracts for Flutter mobile and the future React web client

## Suggested source layout

```text
src/
├── config/
├── modules/
│   ├── auth/
│   ├── users/
│   ├── conversations/
│   ├── messages/
│   └── realtime/
├── middleware/
├── services/
└── server.js
```

The previous Novyn API currently lives under `apps/api`. It is intentionally not copied or moved blindly: migrate modules here after reviewing dependencies, tests, environment variables and deployment configuration.

No production secrets belong in this directory. Use a local `.env` file and commit only a sanitized `.env.example`.
