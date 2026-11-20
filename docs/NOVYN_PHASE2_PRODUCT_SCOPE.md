# Novyn Phase 2 — Clean Rebuild Scope

**Branch:** phase-2  
**Client:** apps/mobile/flutter  
**Backend:** existing shared API under apps/api

## Phase 2 foundation

Phase 2 uses a clean Flutter client. The previous Flutter implementation and its
screens, theme, local services, Firebase wiring, and Google sign-in are not part
of this client.

The initial mobile app contains only the foundation needed to start the rebuild:

- Minimal Flutter entry point and app theme.
- One authentication screen with Sign in and Create account modes.
- Username/email + password authentication against the existing Novyn API.
- Secure storage for server-issued session cookies.
- A separate Welcome screen after successful authentication.
- A fresh Phase 2 home destination after Continue.
- Sign out and basic widget tests.
- CI analysis, tests, and ARM64 APK build.

## Navigation contract

Bootstrap → Authentication → Welcome → Phase 2 Home

A restored account opens the Phase 2 Home. No route in the new client imports or
opens the legacy Chats, Calls, People, Discover, or Profile screens.

## Not included yet

Messaging, groups, calls, games, Nearby Mode, Close Friends, media sharing,
Firebase, Google sign-in, and legacy app settings are intentionally excluded
from this foundation. They will be built back deliberately in later phases,
not carried over by importing old screen trees.

## Backend contract

- Sign in: POST /api/auth/signin with identifier, password, remember.
- Sign up: POST /api/auth/signup with name, username, email, password.
- Session restore: GET /api/auth/session.
- Refresh: POST /api/auth/refresh.
- Sign out: POST /api/auth/logout.

The API CSRF token and server-issued session cookies are handled in the minimal
AuthApi service. The mobile app does not use Google/Firebase authentication.

## Build

The CI workflow generates fresh Android Gradle scaffolding from the pinned
Flutter SDK before building. Generated Android platform files are not committed
as part of the app source.
