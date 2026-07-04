# Gomoku Multiplayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add clean-room Gomoku as the first new GamePigeon-style multiplayer game in Kaleidoscope.

**Architecture:** Add a small pure Swift `GomokuGame` model, a `GomokuSnapshot`, and catalog wiring through `CanonicalGameID`, `GameModeCatalog`, `HomeView`, and `OnlineGameLobbyView`. The view follows the existing Connect Four/Reversi pattern: local games persist through `PersistedGameSession`, online games receive and send full encoded snapshots.

**Tech Stack:** Swift, SwiftUI, XCTest, XcodeGen, existing Supabase-backed online match session.

## Global Constraints

- Do not use GamePigeon branding, names, icons, screenshots, or assets.
- Preserve existing online/local routing behavior for Chess, Checkers, Reversi, and Connect Four.
- New game must be fully represented in `CanonicalGameID.allCases`, snapshot coverage, home catalog, and launch-mode tests.
- No leaderboard ranking for Gomoku in this slice.

---

### Task 1: Pure Gomoku Model

**Files:**
- Create: `Sources/Core/Games/GomokuGame.swift`
- Create: `Tests/GomokuGameTests.swift`

**Interfaces:**
- Produces: `GomokuPlayer`, `GomokuPoint`, `GomokuGame`, `GomokuGame.placeStone(row:col:) -> Bool`, `GomokuGame.winner`, `GomokuGame.isDraw`

- [ ] Write failing XCTest coverage for first move, occupied-cell rejection, horizontal/vertical/diagonal wins, and draw state.
- [ ] Run `xcodebuild test -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KaleidoscopeTests/GomokuGameTests`.
- [ ] Implement the minimal model code.
- [ ] Re-run the focused test until green.

### Task 2: Catalog, Persistence, and Online Snapshot Wiring

**Files:**
- Modify: `Sources/Core/Games/GameSync.swift`
- Modify: `Sources/Core/Games/GamePlayMode.swift`
- Modify: `Sources/Core/Games/GameSnapshots.swift`
- Modify: `Sources/Features/Games/OnlineLobbyView.swift`
- Modify: `Tests/GamePlayModeTests.swift`
- Modify: `Tests/AllGamePersistenceTests.swift`

**Interfaces:**
- Consumes: `GomokuGame`
- Produces: `CanonicalGameID.gomoku`, `GomokuSnapshot`, online initial-state support for `.gomoku`

- [ ] Add failing tests that Gomoku is a multiplayer-designed game, has snapshot round-trip coverage, and online initial JSON decodes to a fresh `GomokuGame`.
- [ ] Run the focused tests and confirm the expected failures.
- [ ] Add catalog and snapshot wiring.
- [ ] Re-run focused tests until green.

### Task 3: SwiftUI Play Surface

**Files:**
- Create: `Sources/Features/Games/GomokuView.swift`
- Modify: `Sources/Features/Home/HomeView.swift`
- Modify: `Tests/HomeCatalogTests.swift`

**Interfaces:**
- Consumes: `GomokuGame`, `GomokuSnapshot`, `OnlineMatchSession`
- Produces: playable local/online Gomoku route from the home grid

- [ ] Add failing home catalog tests for the Gomoku card.
- [ ] Run the focused home catalog test and confirm failure.
- [ ] Add the Board card and route to `GomokuView`.
- [ ] Implement the view with a stable 15x15 board, turn badges, new-game/reset for local mode, and resign control for online mode.
- [ ] Re-run focused tests.

### Task 4: Project Regeneration and Verification

**Files:**
- Generated: `Kaleidoscope.xcodeproj`

- [ ] Run `xcodegen generate --quiet`.
- [ ] Run focused test selectors for `GomokuGameTests`, `GamePlayModeTests`, `AllGamePersistenceTests`, and `HomeCatalogTests`.
- [ ] Run a simulator Debug build.
- [ ] If the phone is available and unlocked, install the Debug build on Poopoohead.

## Self-Review

- Spec coverage: Tasks cover model, routing, persistence, online state, home catalog, and verification.
- Placeholder scan: No TBD/TODO placeholders.
- Type consistency: `GomokuGame`, `GomokuSnapshot`, and `.gomoku` are used consistently across tasks.
