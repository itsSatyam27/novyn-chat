# Novyn

**Your conversations. Your space. Your control.**

Novyn is a lightweight, privacy-first social messenger. Phase 2 is the active redesign and cleanup branch for the existing Novyn product—not a separate Mello app.

## Repository layout

```text
novyn-chat/
├── apps/
│   ├── api/                 # Current Node.js + Express + Socket.IO backend
│   ├── mobile/
│   │   ├── flutter/         # Native Flutter client (Android / iOS)
│   │   └── capacitor/       # Capacitor shell for the web client
│   └── web/                 # React + Vite web client
├── backend/                 # Target shared-backend architecture notes
├── docs/                    # Product scope, audits and technical decisions
├── scripts/
├── .env.example
└── README.md
```

The current running backend remains in `apps/api`. The `backend/` directory documents the intended organization for a future reviewed migration; it is not a second deployed server. Keep the backend platform-independent so the Flutter and React clients can share the same authentication, API, database and realtime services.

## Technology

| Layer | Technology |
|---|---|
| Mobile | Flutter |
| Web | React + Vite |
| Optional web wrapper | Capacitor |
| API | Node.js + Express |
| Realtime | Socket.IO |
| Database | MongoDB |
| Mobile local storage | SQLite / Drift |
| Email delivery | SMTP / Nodemailer |

## Product direction

Novyn combines three pillars:

- **Lightweight messaging:** dependable one-to-one and group conversations.
- **Social experiences:** chat games, Close Friends and shared interactions.
- **Privacy and control:** account security, privacy settings, user-controlled conversation storage and Nearby Mode.

Nearby Mode requires both people to enable it. Its offline path is intended to use direct device-to-device transport. Each conversation can offer a choice between cloud sync and local-only storage. Do not claim end-to-end encryption or guaranteed background delivery until those capabilities are implemented and verified.

## Phase 2 scope

The current product definition and source audit are documented in [NOVYN_PHASE2_PRODUCT_SCOPE.md](docs/NOVYN_PHASE2_PRODUCT_SCOPE.md). The audit distinguishes source-code evidence from functionality that still needs integration or device testing.

All Phase 2 work stays isolated on the `phase-2` branch. Do not merge it into `main` unless explicitly requested.

## Development

Install dependencies from the repository root:

```bash
npm ci
```

Run the API and web client:

```bash
npm run dev
```

Run backend tests and build the web client:

```bash
npm test
npm run build
```

Run the Flutter app:

```bash
cd apps/mobile/flutter
flutter pub get
flutter run
```

Android ARM64 build artifacts are produced through the existing GitHub Actions workflows. Check the relevant workflow run before treating a build as successful.

## Configuration

Copy `.env.example` to `.env` for local development and configure only the services you intend to use. Never commit API keys, SMTP credentials, Firebase service-account files, keystores or other secrets.

