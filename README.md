# ⚡ Novyn Chat — Real-Time Messaging Platform

<div align="center">

![Novyn Chat Banner](public/logo192.png)

**A real-time messaging platform with direct and group chats, WebRTC voice/video calling, in-chat mini-games, and React + Capacitor web/Android clients.**

[![React](https://img.shields.io/badge/React-19-blue.svg)](https://reactjs.org/)
[![Vite](https://img.shields.io/badge/Vite-8.x-purple.svg)](https://vitejs.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-24+-green.svg)](https://nodejs.org/)
[![Socket.IO](https://img.shields.io/badge/Socket.IO-4.x-black.svg)](https://socket.io/)
[![MongoDB](https://img.shields.io/badge/MongoDB-Atlas%20Ready-brightgreen.svg)](https://www.mongodb.com/)
[![Capacitor](https://img.shields.io/badge/Capacitor-6.x%20(Android)-1192e8.svg)](https://capacitorjs.com/)

</div>

---

## 📑 Table of Contents
1. [Architecture & Unified Platform Design](#-architecture--unified-platform-design)
3. [Feature Showcase](#-feature-showcase)
4. [MongoDB Data Schema](#-mongodb-data-schema)
5. [Directory & File Structure](#-directory--file-structure)
6. [Quick Start & Local Development](#-quick-start--local-development)
7. [Building for Android (Capacitor)](#-building-for-android-capacitor)
8. [Production Deployment & Environment Variables](#-production-deployment--environment-variables)

> The repository is organized by application: `apps/web` (React/Vite),
> `apps/api` (Express/Socket.IO), `apps/mobile/capacitor` (native web shell),
> and `apps/mobile/flutter` (Flutter client). Root `package.json` commands are
> intentionally retained as the single local-development and deployment entry point.

---

## 🏛️ Architecture & Unified Platform Design

Novyn's primary client is a **Vite + React + TypeScript** application packaged for Android with **Capacitor**. The Node.js + Express + Socket.IO backend is shared by the web, Capacitor, and Flutter clients.

```mermaid
graph TD
    subgraph Client ["📱 Unified Cross-Platform Client"]
        A[🌐 Web Browser] & B[🤖 Native Android Shell (Capacitor)]
        C[⚛️ React 18 + Vite SPA UI]
        E[⚡ Socket.IO Client + WebRTC Manager]
        F[💾 Local IndexedDB + Session Cache]
        A --> C
        B --> C
        C --> E
        C --> F
    end

    subgraph Backend ["☁️ Node.js + Express + Socket.IO Server"]
        G[🛡️ Authenticated Messaging & Session Controller]
        H[📡 WebSocket Event Dispatcher]
        I[📦 Cloudinary / Local Disk Media Engine]
        J[📬 WebPush & SMTP Reset Service]
    end

    subgraph Database ["🗄️ Database & Storage Layer"]
        K[(🍃 MongoDB Atlas / Split Collections)]
        L[📁 uploads/ Storage]
    end

    E <-->|Message Text & WebRTC Signaling over HTTPS/WSS| Backend
    Backend <--> Database
```

### Key Architectural Strengths:
- **Same Data & Identity**: Log in from any browser or your Android phone; your conversations, media, and friendships sync instantly in real-time.
- **Fast local UX**: In-memory and IndexedDB caching can render cached conversations before the server roundtrip completes; server history is paginated.
- **Hardware Native Integrations**: Smooth haptics, splash screen control, camera access, and status bar coloring via Capacitor native plugins on mobile.

---

## 🔐 Messaging and transport security

Novyn direct and group messages are sent to the authenticated backend as ordinary
message text. The backend can read and persist message bodies, and authorized
conversation participants receive that text through the realtime messaging
transport. Novyn does **not** provide end-to-end encryption for messages.

Production deployments should serve the app and API over HTTPS/WSS. TLS protects
traffic while it travels between the client and server; it does not make stored
message bodies end-to-end encrypted or unreadable to the backend.

Account security is separate from message encryption: passwords continue to be
stored as password hashes, and sign-in sessions and two-factor authentication
remain protected by the existing authentication controls.

Older messages created by the former E2EE prototype may appear as
**“Previous encrypted message unavailable”**. Removing the encryption code does
not recover the old plaintext or make legacy ciphertext readable.

---

## 🌟 Feature Showcase

| Category | Features |
|---|---|
| **💬 Messaging** | • Real-time 1-on-1 & Group Chats<br>• Message Delivery Arrows (`sent`, `delivered`, `seen`)<br>• Draft Auto-Save per conversation (persists across page reloads & tabs)<br>• Swipe-to-Reply & Message Pinning<br>• Unsend & Edit Message Support<br>• In-Chat Search with highlight jumps |
| **🎮 In-Chat Mini Games** | • **Tic-Tac-Toe**: Turn-based board duel inside chat bubbles<br>• **Rock-Paper-Scissors**: Interactive move challenges<br>• **Connect 4**: Grid-based strategy game<br>• Dark slate card design with real-time socket move synchronization |
| **📞 Audio & Video Calling** | • Peer-to-Peer **WebRTC Calling** (Direct DTLS-SRTP encryption)<br>• Crystal-clear voice and HD video streams<br>• Ringtones, call logs, camera flip, and screen sharing |
| **🎙️ Voice Notes** | • Audio recording with live interactive waveform visualizers<br>• Variable playback speed (`1x`, `1.5x`, `2x`) |
| **😀 Reactions & Expressions** | • Quick emoji reaction bar with reaction animations<br>• Sender reactions anchored on left; receiver reactions anchored on right<br>• GIF picker & custom emoji picker |
| **🎨 Customization & Theming** | • Per-chat custom wallpaper selector with instant background synchronization<br>• Modern Glassmorphism aesthetic with theme accent presets<br>• Font sizing and typography selections |
| **📱 Mobile-First UX** | • Fixed mobile bottom navigation bar (`Chats`, `Calls`, `Discover`, `Contacts`, `Settings`)<br>• Responsive sub-settings drill-down with back button headers<br>• Capacitor hardware haptics on taps, reactions, and sends |

---

## 🗄️ MongoDB Data Schema

When connected to MongoDB Atlas, Novyn Chat organizes data into high-performance split collections. Message text is stored as ordinary readable text, not end-to-end encrypted ciphertext:

### 1. `messages` Collection
```json
{
  "_id": "alex::satyam::msg_1786870000_a8f9",
  "conversationKey": "alex::satyam",
  "messageId": "msg_1786870000_a8f9",
  "from": "satyam",
  "to": "alex",
  "fromKey": "satyam",
  "toKey": "alex",
  "toType": "friend",
  "timestamp": "2026-08-16T09:44:00.000Z",
  "deliveredAt": "2026-08-16T09:44:01.000Z",
  "seenAt": "2026-08-16T09:44:05.000Z",
  
  "text": "Hello from Novyn!"
}
```

### 2. `users` Collection
```json
{
  "_id": "satyam",
  "username": "Satyam",
  "email": "satyam@example.com",
  "displayName": "Satyam",
  "avatarId": "avatar_robot_01",
  "bio": "Building with Novyn Chat",
  "publicKey": "{\"crv\":\"P-256\",\"ext\":true,\"key_ops\":[],\"kty\":\"EC\",\"x\":\"...\",\"y\":\"...\"}",
  "friends": ["alex"],
  "groups": [],
  "presenceMode": "online",
  "isRegistered": true
}
```

### 3. `conversations` Collection
```json
{
  "_id": "alex::satyam",
  "userA": "alex",
  "userB": "satyam",
  "messageCount": 142,
  "lastTimestamp": "2026-08-16T09:44:00.000Z",
  "updatedAt": "2026-08-16T09:44:00.000Z"
}
```

---

## 📂 Directory & File Structure

```text
novyn-chat/
├── apps/
│   ├── web/                  # React/Vite source, public assets, dist
│   ├── api/                  # Express, Socket.IO, tests, runtime storage
│   └── mobile/
│       ├── capacitor/        # Capacitor configuration and Android shell
│       └── flutter/          # Flutter Android, iOS, web and desktop client
├── scripts/                  # Maintenance commands
├── .github/                  # CI
├── capacitor.config.ts       # Root CLI entry point
└── package.json              # Root development and deployment commands
```

---

## 🚀 Quick Start & Local Development

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/itsSatyam27/novyn-chat.git
cd novyn-chat
npm install
```

### 2. Configure Environment (`.env`)
Create a `.env` file in the root directory:
```env
PORT=3000
NODE_ENV=development

# MongoDB Atlas (Optional - defaults to data/chat-state.json)
MONGODB_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/
MONGODB_DB=novyn

# Email Reset Codes (Optional - via SMTP or Resend)
SMTP_HOST=smtp.resend.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=resend
SMTP_PASS=your_resend_api_key
SMTP_FROM=Novyn <onboarding@resend.dev>

# Cloudinary Media Storage (Optional - defaults to uploads/)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

### 3. Start Development Server
```bash
npm run dev
```
Open `http://localhost:3000` (or `http://localhost:5173`) in two browser tabs or private windows to test live instant messaging, games, and encrypted calls.

---

## 🤖 Building for Android (Capacitor)

The project includes an **Android Capacitor shell** ready to be compiled into an `.apk` or `.aab`:

```bash
# 1. Build the production web bundle
npm run build

# 2. Sync web bundle and plugins to native Android folder
npm run android:sync

# 3. Open Android Studio to build APK or run on emulator
npm run android:open
```

*Tip: You can also run directly from the terminal if you have Android SDK tools installed:*
```bash
npm run android:run
```

---

## 🌐 Production Deployment & Environment Variables

Deploy to **Render**, **Railway**, **Fly.io**, or any VPS:

1. Connect your GitHub repository to your cloud host.
2. Configure build & start commands:
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `npm start`
3. Add the following environment variables in your cloud provider's dashboard:
   - `AUTH_SECRET` *(one long random value; keep the same value across deploys)*
   - `MONGODB_URI` *(MongoDB connection string)*
   - `MONGODB_DB` *(Default: `novyn`)*
   - `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` *(For persistent media uploads)*
   - `UPLOAD_TOKEN_SECRET` *(Stable secret string for signed media URLs)*
   - `CHAT_RETENTION_DAYS` *(Default: 30 days)*

### Keeping users signed in on Render

Novyn validates browser cookies against a server-side session record. Use a stable
`AUTH_SECRET` and configure `MONGODB_URI`; Novyn stores auth sessions in MongoDB as
well as users and chats. If you intentionally run without MongoDB, attach a Render
persistent disk and set `DATA_DIR` to its mount path (for example,
`/var/data/novyn`). Render's normal service filesystem is replaced during a deploy,
so file-based sessions on that filesystem cause every account to be signed out.

---

<div align="center">

Built with ❤️ by **Satyam** • Powered by **Novyn Technologies**

</div>
