# Novyn applications

Each runnable Novyn client or service lives under this directory.

```text
apps/
├── api/                 Express, Socket.IO, security modules, and API tests
│   └── runtime/         Ignored local data and upload storage
├── web/                 React + Vite browser client and static assets
└── mobile/
    ├── capacitor/       Capacitor Android shell for the React client
    └── flutter/         Native Flutter client (Android, iOS, desktop, web)
```

Run all project commands from the repository root. For example:

```sh
npm run dev
npm run build
npm test
npm run cap:sync:android
npm run flutter:run:android
```

The root package remains the deployment entry point: `npm run build` creates
`apps/web/dist`, and `npm start` serves it through `apps/api/server.js`.
