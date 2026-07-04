# Gomoku Multiplayer Design

**Goal:** Add the first new GamePigeon-style multiplayer game to Kaleidoscope as a clean-room classic Gomoku implementation.

**Chosen first game:** Gomoku. It is the lowest-risk next multiplayer addition because it is deterministic, turn-based, perfect-information, and fits the existing local/online match snapshot pipeline already used by Chess, Checkers, Reversi, and Connect Four.

**Alternatives considered:** Dots and Boxes is also simple but needs edge ownership, box completion, and extra-turn scoring. Mancala is compact but has rule variants and capture edge cases. Physics-style games such as Cup Pong, Darts, 8-Ball, Mini Golf, Archery, and Basketball are intentionally deferred because they require input physics and fairness tuning before online play feels good.

**Scope for this slice:**
- Add `gomoku` as a canonical saved game in the Board category.
- Support Local 2-player and Online friend. Solo bot is planned, not playable.
- Persist and online-sync a `GomokuSnapshot` using the shared `GameSaveCodec`.
- Implement standard 15x15 freestyle Gomoku: black moves first, five or more contiguous stones wins, full board with no winner is a draw.
- Use original UI and generic classic-game wording, not GamePigeon branding.

**Out of scope:** AI opponent, ranked leaderboard scoring, custom icon art, tournament variants such as overline bans or Renju restrictions.

**Verification:** Add red-first model/catalog/online snapshot tests, then run focused `GomokuGameTests`, `GamePlayModeTests`, `AllGamePersistenceTests`, and `HomeCatalogTests`, followed by `xcodegen generate` and a focused simulator build if time allows.
