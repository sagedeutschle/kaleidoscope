# Game State Retention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep every playable game's progress alive while the user switches Kaleidoscope facets.

**Architecture:** Move per-game mutable state that currently lives inside disposable SwiftUI views into parent-owned session objects. `ContentView` owns one session per playable facet and injects sessions into the detail views, so the `NavigationSplitView` detail switch can recreate views without resetting progress.

**Tech Stack:** SwiftUI, ObservableObject, Xcode test target, existing game model structs.

## Global Constraints

- Keep existing disk persistence for Chess, Wordle, and Brick Bench unchanged.
- Do not render every game view invisibly; timers and SceneKit must not keep running just to preserve state.
- Preserve existing game UI and controls except for replacing local `@State` with injected session state.
- Verify with focused session-retention tests and the full `xcodebuild ... test` suite.

---

### Task 1: Add Session Owners

**Files:**
- Create: `Sources/Model/GameSessionState.swift`
- Modify: `Sources/App/ContentView.swift`
- Test: `Tests/GameSessionStateTests.swift`

**Interfaces:**
- Produces: `Game2048Session`, `LightsOutSession`, `MinesweeperSession`, `SnakeSession`, `SudokuSession`, `SlidingPuzzleSession`, `NonogramSession`, `ReversiSession`, `RubiksCubeSession`
- Consumes: existing game model types and seeds

- [ ] Write tests that mutate a session and assert the same instance retains progress.
- [ ] Add session classes with the same default state values currently declared in each view.
- [ ] Add `@StateObject` owners in `ContentView`.
- [ ] Pass sessions into each game view in `detailPane`.
- [ ] Run `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:KaleidoscopeTests/GameSessionStateTests test`.

### Task 2: Convert Views To Injected Sessions

**Files:**
- Modify: all affected `Sources/Views/*View.swift` files for arcade/logic facets

**Interfaces:**
- Consumes: session classes from Task 1
- Produces: view initializers that accept a session and default to a fresh session for previews/direct use

- [ ] Replace disposable view-level `@State` game progress with `@ObservedObject private var session`.
- [ ] Leave focus-only state local to the view.
- [ ] Route all controls through `session` fields.
- [ ] Run focused compile and session tests.

### Task 3: Verify Full App

**Files:**
- Modify: `docs/AGENT-COORDINATION.md`

**Interfaces:**
- Consumes: all prior task changes
- Produces: final PRISM handoff log

- [ ] Run full suite: `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test`.
- [ ] Relaunch the built app.
- [ ] Record the final verification result in `docs/AGENT-COORDINATION.md`.
