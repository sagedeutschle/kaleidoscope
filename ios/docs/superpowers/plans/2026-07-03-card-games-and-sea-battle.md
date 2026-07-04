# Card Games and Sea Battle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Spider, Crazy 8, and Sea Battle as playable iOS Kaleidoscope games.

**Architecture:** Pure Swift rule engines feed SwiftUI views through existing persistence and online snapshot paths. Spider is solo; Crazy 8 and Sea Battle are local/online friend games.

**Tech Stack:** Swift, SwiftUI, XCTest, XcodeGen, existing `PersistedGameSession`, `OnlineMatchSession`, and `GameSaveCodec`.

## Global Constraints

- Keep game logic clean-room and deterministic.
- Add new source files under `Sources/` and regenerate with `xcodegen generate --quiet`.
- Preserve ads, entitlements, and `project.yml`.
- Run focused XCTest, strict parity, and simulator build before completion.

---

### Task 1: Model Tests and Rule Engines

**Files:**
- Create: `Tests/SpiderGameTests.swift`
- Create: `Tests/CrazyEightGameTests.swift`
- Create: `Tests/SeaBattleGameTests.swift`
- Create: `Sources/Core/Games/SpiderGame.swift`
- Create: `Sources/Core/Games/CrazyEightGame.swift`
- Create: `Sources/Core/Games/SeaBattleGame.swift`

**Interfaces:**
- Produces: `SpiderGame`, `CrazyEightGame`, `SeaBattleGame`, and their player/point/card helper value types.

- [x] Write failing model tests.
- [x] Regenerate the Xcode project.
- [x] Verify the red run fails on missing game symbols.
- [x] Implement minimal deterministic rule engines.
- [x] Verify focused model tests pass.

### Task 2: Catalog, Snapshots, and Online Handoff

**Files:**
- Modify: `Sources/Core/Games/GameSync.swift`
- Modify: `Sources/Core/Games/GamePlayMode.swift`
- Modify: `Sources/Core/Games/GameSnapshots.swift`
- Modify: `Sources/Features/Games/OnlineLobbyView.swift`
- Modify: `Tests/GamePlayModeTests.swift`
- Modify: `Tests/AllGamePersistenceTests.swift`

**Interfaces:**
- Produces: `.spider`, `.crazyEight`, `.seaBattle`, `SpiderSnapshot`, `CrazyEightSnapshot`, `SeaBattleSnapshot`.

- [x] Add routing tests for solo/local/online mode expectations.
- [x] Add snapshot registry coverage.
- [x] Add online initial-state encoding for Crazy 8 and Sea Battle.
- [x] Verify focused catalog/persistence tests pass.

### Task 3: SwiftUI Screens and Home Routing

**Files:**
- Create: `Sources/Features/Games/SpiderView.swift`
- Create: `Sources/Features/Games/CrazyEightView.swift`
- Create: `Sources/Features/Games/SeaBattleView.swift`
- Modify: `Sources/Features/Home/HomeView.swift`
- Modify: `Tests/HomeCatalogTests.swift`

**Interfaces:**
- Produces: playable Home cards and navigation destinations for all three games.

- [x] Build compact touch-first game views.
- [x] Wire local persistence.
- [x] Wire online snapshot send/apply for Crazy 8 and Sea Battle.
- [x] Add Home cards in Board/Cards categories.
- [x] Verify focused Home catalog tests pass.

### Task 4: Verification and Coordination

**Files:**
- Modify: `docs/AGENT-COORDINATION.md`
- Modify: `docs/MAC-IOS-GAME-PARITY.md`

- [x] Run focused XCTest selectors.
- [x] Run `./scripts/check-mac-ios-parity.sh --strict`.
- [x] Run simulator build for iPhone 17.
- [x] Record PRISM and parity notes.
