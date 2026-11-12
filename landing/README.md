# Novyn — Official landing page

This folder contains the standalone Novyn product website. It does not replace or modify the existing web app in `apps/web`.

## Firebase Hosting

From the repository root:

1. Create/select a Firebase project in the Firebase Console and enable **Hosting**.
2. Install the Firebase CLI: `npm install -g firebase-tools`.
3. Sign in: `firebase login`.
4. Link your Firebase project: `firebase use --add` (select your project and choose a local alias).
5. Deploy only this landing site: `firebase deploy --only hosting`.

The root `firebase.json` publishes only the `landing/` directory. The existing web app remains at `https://novyn-chat.onrender.com`.

## Website links

- Try web app: `https://novyn-chat.onrender.com`
- Android releases: `https://github.com/itsSatyam27/novyn-chat/releases/latest`

Upload the signed APK as an asset to a GitHub Release; the Android button opens the latest release so visitors can download its APK asset.

## Brand

Website title: **Novyn — Make every conversation count**.
