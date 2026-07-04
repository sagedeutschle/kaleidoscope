# Sea Battle Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GamePigeon-style ship deployment phase before Sea Battle starts in solo AI and online friend modes.

**Architecture:** Keep firing rules in `SeaBattleGame`, add pure placement helpers to the core model, and store deployment readiness in `SeaBattleSnapshot`. `SeaBattleView` switches between a placement board and the existing firing UI based on the snapshot setup state.

**Tech Stack:** Swift 5, SwiftUI, XCTest, XcodeGen.

## Global Constraints

- Preserve Fable's released Sea Battle visual styling.
- Do not touch ads, entitlements, Rubik, or unrelated game files.
- Use standard 10x10 Battleship rules: ships are length 5, 4, 3, 3, 2; horizontal or vertical; no overlap; no off-board cells.
- Run `xcodegen generate` after adding or moving Swift files.
- This checkout is not a git repository, so verification replaces commit steps.

---

### Task 1: Core Placement Model

**Files:**
- Modify: `Sources/Core/Games/SeaBattleGame.swift`
- Test: `Tests/SeaBattleGameTests.swift`

**Interfaces:**
- Produces: `SeaBattleOrientation`, `SeaBattlePlacement`, `SeaBattleFleetDeployment`, `SeaBattleGame.gameFromDeployments(host:guest:)`.

- [ ] Write failing tests for valid deployment, off-board rejection, overlap rejection, and creating a game from two deployments.
- [ ] Run `xcodebuild ... -only-testing:KaleidoscopeTests/SeaBattleGameTests test` and confirm compile/test failure.
- [ ] Add the placement types and validation helpers.
- [ ] Re-run focused Sea Battle tests and confirm pass.

### Task 2: Snapshot Setup State

**Files:**
- Modify: `Sources/Core/Games/GameSnapshots.swift`
- Test: `Tests/AllGamePersistenceTests.swift`

**Interfaces:**
- Produces: `SeaBattleSetupState` with host/guest deployments and ready flags.

- [ ] Write failing tests for old save decode defaults and ready state.
- [ ] Run `AllGamePersistenceTests` and confirm failure.
- [ ] Add setup state to `SeaBattleSnapshot` with old-save defaults.
- [ ] Re-run persistence tests and confirm pass.

### Task 3: Placement UI and Flow

**Files:**
- Modify: `Sources/Features/Games/SeaBattleView.swift`

**Interfaces:**
- Consumes: `SeaBattleSnapshot.setup`, `SeaBattleFleetDeployment`, `SeaBattleGame.gameFromDeployments`.

- [ ] Add state for the selected ship and orientation.
- [ ] Render the placement board before firing starts.
- [ ] In solo, place the AI fleet automatically and start after player ready.
- [ ] In online, send the local deployment and wait until both sides are ready before firing.
- [ ] Preserve the existing firing board and shot animation code.

### Task 4: Verification

**Files:**
- `Kaleidoscope.xcodeproj`

- [ ] Run `xcodegen generate`.
- [ ] Run focused Sea Battle, GamePlayMode, and persistence tests.
- [ ] Report test counts and any simulator-only warnings.
