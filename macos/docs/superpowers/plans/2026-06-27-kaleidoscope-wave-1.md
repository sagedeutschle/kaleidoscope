# Kaleidoscope Wave 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand ChessHotSwap to Kaleidoscope, replace the segmented workspace picker with a home facet launcher, and add three playable Wave 1 facets: Rubik's Cube, 2048, and Lights Out.

**Architecture:** Keep the shell generic by introducing facet descriptors and moving chess-specific state/chrome into `ChessFacetView`. Add each new game as a pure model plus SwiftUI/SceneKit view so behavior can be tested without UI. Preserve existing persistence by migrating Application Support from `ChessHotSwap` to `Kaleidoscope` on first access.

**Tech Stack:** Swift 5, SwiftUI, SceneKit, XCTest, XcodeGen, macOS 14.

## Global Constraints

- Existing Chess, Brick Bench, Wordle, and Oracle behavior must continue to work behind the new shell.
- Rename product, bundle id, module, app entry, window title, persistence directory, and all test imports from `ChessHotSwap` to `Kaleidoscope`.
- Preserve existing saved state by moving Application Support `ChessHotSwap` to `Kaleidoscope` only when the old directory exists and the new directory does not.
- The Home grid is the app's launcher; ready facets are tappable and coming-soon facets are disabled.
- Wave 1 ready facets are Chess, Brick Bench, Wordle, Oracle, Rubik's Cube, 2048, and Lights Out.
- Coming-soon facets are Sudoku, Minesweeper, Sliding-15, Nonogram, and Reversi.
- Rubik's Cube v1 may use on-screen move buttons if drag-to-turn is too costly; the model must still support U/D/L/R/F/B, prime, and double moves.
- New model logic must be unit-tested with deterministic behavior.
- Verification gate: `xcodegen generate` then `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test` reports `** TEST SUCCEEDED **`.

---

## File Structure

- `project.yml`: rename app and test targets, product name, bundle ids, and display name.
- `Sources/App/ChessHotSwapApp.swift` -> `Sources/App/KaleidoscopeApp.swift`: rename `@main` app and window title.
- `Sources/App/ContentView.swift`: replace root segmented workspace shell with generic Kaleidoscope root view and home/facet navigation.
- `Sources/Views/ChessFacetView.swift`: new chess-specific view owning chess state, board mode, theme, import/export, and chess toolbar/footer.
- `Sources/Views/HomeLensView.swift`: new home grid and facet tile UI.
- `Sources/Model/FacetRegistry.swift`: new facet metadata, categories, statuses, and factory closures.
- `Sources/Model/GamePersistence.swift`: persistence directory migration.
- `Sources/Model/RubiksCube.swift`, `Sources/Views/RubiksCubeView.swift`: cube model and SceneKit/control view.
- `Sources/Model/Game2048.swift`, `Sources/Views/Game2048View.swift`: 2048 model and SwiftUI view.
- `Sources/Model/LightsOut.swift`, `Sources/Views/LightsOutView.swift`: Lights Out model and SwiftUI view.
- `Tests/AppWorkspaceTests.swift` -> `Tests/FacetRegistryTests.swift`: registry expectations.
- `Tests/GamePersistenceTests.swift`: migration coverage.
- `Tests/RubiksCubeTests.swift`, `Tests/Game2048Tests.swift`, `Tests/LightsOutTests.swift`: new game model coverage.
- `docs/HANDOFF.md`: update project name, commands, and current state.

## Task 1: Product Rename And Persistence Migration

**Files:**
- Modify: `project.yml`
- Move: `Sources/App/ChessHotSwapApp.swift` to `Sources/App/KaleidoscopeApp.swift`
- Modify: `Sources/Model/GamePersistence.swift`
- Modify: all files in `Tests/*.swift`
- Test: `Tests/GamePersistenceTests.swift`

**Interfaces:**
- Produces: Swift module `Kaleidoscope`
- Produces: `GamePersistenceStore.defaultRootURL(baseURL:fileManager:) -> URL`
- Consumes: existing `GamePersistenceStore(rootURL:)`

- [ ] Write a failing migration test in `Tests/GamePersistenceTests.swift` that creates temp `ChessHotSwap` and `Kaleidoscope` directories, calls a new default-root helper with the temp Application Support base, and asserts the old directory moves to the new path only when the new path is absent.
- [ ] Run `xcodebuild -project ChessHotSwap.xcodeproj -scheme ChessHotSwap -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test` and confirm the new migration test fails because the helper/migration does not exist.
- [ ] Change `GamePersistenceStore.defaultRootURL()` to delegate to `static func defaultRootURL(baseURL:fileManager:)`, returning `baseURL.appendingPathComponent("Kaleidoscope", isDirectory: true)` after performing the one-time move from `ChessHotSwap`.
- [ ] Rename `project.yml` app/test targets from `ChessHotSwap`/`ChessHotSwapTests` to `Kaleidoscope`/`KaleidoscopeTests`, set `PRODUCT_NAME: Kaleidoscope`, `PRODUCT_BUNDLE_IDENTIFIER: com.gtrktscrb.kaleidoscope`, test bundle id `com.gtrktscrb.kaleidoscope.tests`, and display name `Kaleidoscope`.
- [ ] Move the app entry file to `Sources/App/KaleidoscopeApp.swift`, rename `ChessHotSwapApp` to `KaleidoscopeApp`, and set `WindowGroup("Kaleidoscope")`.
- [ ] Replace every `@testable import ChessHotSwap` with `@testable import Kaleidoscope`.
- [ ] Run `xcodegen generate`.
- [ ] Run `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test` and confirm the suite passes.

## Task 2: Generic Facet Shell

**Files:**
- Create: `Sources/Model/FacetRegistry.swift`
- Create: `Sources/Views/HomeLensView.swift`
- Create: `Sources/Views/ChessFacetView.swift`
- Modify: `Sources/App/ContentView.swift`
- Test: `Tests/FacetRegistryTests.swift`

**Interfaces:**
- Produces: `enum FacetCategory: String, CaseIterable`
- Produces: `enum FacetStatus: Equatable`
- Produces: `struct FacetDescriptor: Identifiable`
- Produces: `enum FacetRegistry { static let all: [FacetDescriptor]; static let ready: [FacetDescriptor]; static func descriptor(for id: String) -> FacetDescriptor? }`
- Consumes: existing `Board2DView`, `Board3DView`, `LegoBuilderView`, `WordPuzzleView`, `DecreeView`

- [ ] Replace `Tests/AppWorkspaceTests.swift` with `Tests/FacetRegistryTests.swift` that asserts ready ids equal `["chess", "brick-bench", "wordle", "oracle", "rubiks-cube", "2048", "lights-out"]` after all Wave 1 tasks, and coming-soon ids include `sudoku`, `minesweeper`, `sliding-15`, `nonogram`, and `reversi`.
- [ ] Run the registry test and confirm it fails because `FacetRegistry` does not exist.
- [ ] Create `FacetRegistry.swift` with category/status/descriptor types and placeholder ready descriptors for the existing four facets plus temporary coming-soon descriptors for the three Wave 1 games until their views are available.
- [ ] Extract chess state and toolbar content from `ContentView` into `ChessFacetView`, preserving existing board style, theme, drag placement, import/export, status bar, and persistence behavior.
- [ ] Replace `ContentView` with a root view that stores `activeFacetID: String?`, renders `HomeLensView` when nil, renders the selected facet with a Home button when non-nil, and supports Escape/Command-period back to Home.
- [ ] Implement `HomeLensView` as grouped facet tiles with disabled styling for `.comingSoon`.
- [ ] Run the registry test and full suite.

## Task 3: 2048 And Lights Out Models And Views

**Files:**
- Create: `Sources/Model/Game2048.swift`
- Create: `Sources/Views/Game2048View.swift`
- Create: `Sources/Model/LightsOut.swift`
- Create: `Sources/Views/LightsOutView.swift`
- Modify: `Sources/Model/FacetRegistry.swift`
- Test: `Tests/Game2048Tests.swift`
- Test: `Tests/LightsOutTests.swift`

**Interfaces:**
- Produces: `struct Game2048: Equatable`
- Produces: `mutating func move(_ direction: Game2048.Direction, spawn: Bool = true, rng: inout SeededGenerator) -> Bool`
- Produces: `struct LightsOut: Equatable`
- Produces: `mutating func press(row: Int, col: Int)`
- Consumes: `FacetRegistry` from Task 2

- [ ] Write failing `Game2048Tests` for left merge `[2,2,0,0] -> [4,0,0,0]`, no chained merge `[2,2,4,0] -> [4,4,0,0]`, unchanged move spawns no tile, full board with no merges is game-over, and a 2048 tile sets `hasWon`.
- [ ] Write failing `LightsOutTests` for same cell twice as identity, corner press flips exactly 3 cells, center press flips exactly 5 cells, and replaying scramble presses solves the scrambled board.
- [ ] Implement deterministic model types and the minimal seeded generator needed by tests.
- [ ] Add SwiftUI views with keyboard/drag support for 2048 and a 5x5 button grid for Lights Out.
- [ ] Change `FacetRegistry` entries for `2048` and `lights-out` to `.ready` and wire their views.
- [ ] Run `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test`.

## Task 4: Rubik's Cube Model And Facet

**Files:**
- Create: `Sources/Model/RubiksCube.swift`
- Create: `Sources/Views/RubiksCubeView.swift`
- Modify: `Sources/Model/FacetRegistry.swift`
- Test: `Tests/RubiksCubeTests.swift`

**Interfaces:**
- Produces: `struct RubiksCube: Equatable`
- Produces: `enum RubiksMove: String, CaseIterable, Identifiable`
- Produces: `mutating func apply(_ move: RubiksMove)`
- Produces: `func applying(_ moves: [RubiksMove]) -> RubiksCube`
- Consumes: `FacetRegistry` from Task 2

- [ ] Write failing tests for solved initial state, move plus inverse returns solved, `(R U R' U')` repeated six times returns solved, seeded scramble is not solved, and applying a recorded scramble inverse returns solved.
- [ ] Implement a sticker or cubie model that passes the move tests for U/D/L/R/F/B, prime, and double moves.
- [ ] Build `RubiksCubeView` with SceneKit cubies or a clear button-driven v1, including Scramble, Reset, timer, move counter, and solved banner.
- [ ] Change the `rubiks-cube` facet to `.ready` and wire `RubiksCubeView`.
- [ ] Run cube tests and the full suite.

## Task 5: Final Integration And Handoff

**Files:**
- Modify: `docs/HANDOFF.md`
- Verify: all touched files

**Interfaces:**
- Consumes: Tasks 1-4
- Produces: updated handoff and verified Wave 1 app

- [ ] Run `xcodegen generate`.
- [ ] Run `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO test`.
- [ ] Launch `Kaleidoscope.app`.
- [ ] Smoke-check Home grid, Chess, Brick Bench, Wordle, Oracle, 2048, Lights Out, and Rubik's Cube.
- [ ] Update `docs/HANDOFF.md` with the new project name, paths, verification command, test count, and any remaining limitations.

## Self-Review

- Spec coverage: the plan covers rebrand, shell, existing facets, three Wave 1 games, persistence migration, coming-soon facets, and final verification.
- Placeholder scan: no `TBD` or `TODO` placeholders are present.
- Type consistency: new facet, game, and persistence names are defined before later tasks consume them.
