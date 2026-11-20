# Novyn Phase 2 mobile client

This is the clean Phase 2 Flutter client. It contains no legacy chat screens,
Firebase configuration, Google sign-in, old theme system, or old client services.

Current foundation:
- One authentication screen with Sign in and Create account modes.
- Username/email + password authentication through the shared Novyn API.
- Server-issued session cookies stored with Android encrypted storage.
- A separate Welcome screen after successful authentication.
- Continue opens the fresh Phase 2 home, not the old Chats screen.
- Sign out clears server session and local credentials.

The production API defaults to https://novyn-live.onrender.com.
Override it with --dart-define=NOVYN_API_URL=https://your-api.example.

Generate Android platform scaffolding locally with:
flutter create --platforms=android --project-name novyn --org com.novyn --no-pub .
Then run flutter pub get and flutter run.

No Firebase or Google login configuration is required.
