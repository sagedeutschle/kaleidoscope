# Classic Facets Wave 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add playable Minesweeper, Snake, and Sliding-15 facets to Kaleidoscope.

**Architecture:** Each game gets a pure deterministic model, focused XCTest coverage, and a SwiftUI view. The existing Home lens routes ready facets by stable ids, so integration is limited to `FacetRegistry` and `ContentView`.

**Tech Stack:** Swift 5, SwiftUI, XCTest, XcodeGen, macOS 14.

## Global Constraints

- Keep existing ready facets reachable: Chess, Brick Bench, Wordle, Oracle, Rubik's Cube, 2048, and Lights Out.
- Do not rewrite or revert existing Rubik's Cube, 2048, Lights Out, chess, Brick Bench, Wordle, or Oracle files beyond routing updates.
- New game model behavior must be deterministic under tests.
- New views must be playable from the Home grid and compile without extra package dependencies.
- Verification gate: `xcodegen generate` then `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test` reports `** TEST SUCCEEDED **`.

---

## File Structure

- `Sources/Model/MinesweeperGame.swift`: mine placement, reveal/flood fill, flags, win/loss state.
- `Sources/Views/MinesweeperView.swift`: playable grid, flag mode, reset/status controls.
- `Tests/MinesweeperGameTests.swift`: first-click safety, counts, flag behavior, loss, win.
- `Sources/Model/SnakeGame.swift`: snake body, direction, apple spawning, score, collision state.
- `Sources/Views/SnakeView.swift`: playable grid with keyboard/button controls and step timer.
- `Tests/SnakeGameTests.swift`: movement, eating/growth, wall collision, reverse prevention.
- `Sources/Model/SlidingPuzzle.swift`: 15-puzzle board, blank movement, solvable shuffling, solved state.
- `Sources/Views/SlidingPuzzleView.swift`: playable numbered tile grid and shuffle/reset controls.
- `Tests/SlidingPuzzleTests.swift`: legal/illegal moves, solved detection, deterministic shuffle sanity.
- `Sources/Model/FacetRegistry.swift`: mark new facets ready and add Snake descriptor.
- `Sources/App/ContentView.swift`: route the three new facet ids to their views.
- `docs/HANDOFF.md`: update ready/coming-soon lists and verification count.

## Task 1: Model Tests

**Files:**
- Create: `Tests/MinesweeperGameTests.swift`
- Create: `Tests/SnakeGameTests.swift`
- Create: `Tests/SlidingPuzzleTests.swift`

**Interfaces:**
- Produces failing expectations for `MinesweeperGame`, `SnakeGame`, and `SlidingPuzzle`.

- [ ] Write tests for Minesweeper first-click safety, adjacent counts, flag preventing reveal, mine reveal losing, and revealing all safe cells winning.
- [ ] Write tests for Snake movement, apple eating/growth/score, wall collision, and ignored reverse turns.
- [ ] Write tests for Sliding-15 legal move, illegal move, solved state, and seeded shuffle producing a non-solved solvable board.
- [ ] Run focused tests and confirm failures are missing model types.

## Task 2: Models

**Files:**
- Create: `Sources/Model/MinesweeperGame.swift`
- Create: `Sources/Model/SnakeGame.swift`
- Create: `Sources/Model/SlidingPuzzle.swift`

**Interfaces:**
- Produces: `struct MinesweeperGame`
- Produces: `struct SnakeGame`
- Produces: `struct SlidingPuzzle`

- [ ] Implement the minimal deterministic models to satisfy Task 1 tests.
- [ ] Run focused model tests and confirm they pass.

## Task 3: Views And Routing

**Files:**
- Create: `Sources/Views/MinesweeperView.swift`
- Create: `Sources/Views/SnakeView.swift`
- Create: `Sources/Views/SlidingPuzzleView.swift`
- Modify: `Sources/Model/FacetRegistry.swift`
- Modify: `Sources/App/ContentView.swift`
- Modify: `Tests/FacetRegistryTests.swift`

**Interfaces:**
- Consumes: Task 2 model APIs.
- Produces: ready facets with ids `minesweeper`, `snake`, and `sliding-15`.

- [ ] Build simple playable SwiftUI views.
- [ ] Add Snake to the registry and mark Minesweeper and Sliding-15 ready.
- [ ] Route the three ids in `ContentView`.
- [ ] Update registry tests to include the new ready ids.

## Task 4: Verification And Handoff

**Files:**
- Modify: `docs/HANDOFF.md`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: updated handoff and verified app state.

- [ ] Run `xcodegen generate`.
- [ ] Run full `xcodebuild`.
- [ ] Launch `Kaleidoscope.app`.
- [ ] Update `docs/HANDOFF.md` with ready facets and test count.

## Self-Review

- Spec coverage: covers Minesweeper, Snake, Sliding-15, routing, tests, docs, and verification.
- Placeholder scan: no placeholders remain.
- Type consistency: task interfaces match the model/view names used by routing.
