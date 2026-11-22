# Games UI visual QA

**Findings**

- Visual comparison is blocked because this workspace has no Android device/emulator (`adb` is unavailable), so an implementation screenshot could not be captured. The Flutter test/analyzer process also remained running without output and had to be stopped.

**Source visuals**

- `C:/Users/itsme/Downloads/novyn app ui/Tic-Tac-Toe.html` and `Rock Paper Scissors.html` are the supplied UI/gameplay references.

- `C:/Users/itsme/Downloads/novyn app ui/Games@2x.png` — 780 x 1688 px (@2x); intended logical screen approximately 390 x 844 dp.
- `C:/Users/itsme/Downloads/novyn app ui/Tic-Tac-Toe@2x (1).png` — 780 x 1688 px (@2x); intended logical screen approximately 390 x 844 dp.

**Implementation evidence**

- Screens and match UI: `apps/mobile/flutter/lib/screens/games/games_screen.dart`, `apps/mobile/flutter/lib/screens/games/game_lobby_screen.dart`, `apps/mobile/flutter/lib/widgets/game_message_card.dart`, and `apps/mobile/flutter/lib/screens/games/game_history_screen.dart`.
- Implementation screenshot: not captured. No emulator/device was available.
- State intended for comparison: signed-in user, light theme, Games tab at rest; then Tic-Tac-Toe lobby with friend search visible.
- Viewport intended: 390 x 844 dp. Source screenshots are @2x; a rendered capture would need normalization to this logical size.
- Full-view and focused-region comparison: not performed because the implementation capture is unavailable.

**Verification**

- `git diff --check` passed for changed files.
- Flutter analyzer and widget test could not be confirmed: the local Dart/Flutter process hung without output.
- Typography, spacing, colors, asset fidelity, copy, responsive behavior, and interactions remain visually unverified.

**Implementation checklist**

- [x] Keep online play and live socket sync; no bot/offline mode was added.
- [x] Remove other games from Flutter, matchmaking, and server game rules.
- [x] Restyle online Tic-Tac-Toe and Rock Paper Scissors around the supplied HTML references.
- [x] Add the game profile stats card and match-history navigation.
- [x] Save finished match results locally and render the history list.
- [x] Align the lobby's card structure and friend online count with the reference.
- [ ] Capture the app on an emulator/device, compare both references at the same logical viewport, and resolve any visual differences.
- [ ] Run Flutter analyzer and focused widget tests successfully.

final result: blocked
