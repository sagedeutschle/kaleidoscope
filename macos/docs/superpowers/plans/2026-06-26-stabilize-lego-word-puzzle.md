# Stabilize LEGO Word Puzzle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize ChessHotSwap and add clean-room LEGO builder and word-puzzle MVP workspaces.

**Architecture:** Keep chess logic intact and add a workspace switcher at the app shell. Add focused value-model files for LEGO and word puzzle behavior so tests can cover non-UI logic. Implement SwiftUI views that consume those models without embedding proprietary BrickLink Studio or NYT Wordle assets.

**Tech Stack:** SwiftUI, SceneKit, XCTest, XcodeGen, macOS 14 app target.

## Global Constraints

- Do not embed BrickLink Studio or NYT Wordle.
- Keep BrickLink work to clean-room builder features and optional compatible export data.
- Keep Wordle work legally distinct in name, visuals, and bundled word list.
- Preserve the existing chess `GameState` shared-model invariant.
- Verification command is `xcodebuild -project ChessHotSwap.xcodeproj -scheme ChessHotSwap -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build test`.

---

### Task 1: Test Target And Stabilization

**Files:**
- Modify: `project.yml`
- Create: `Tests/MoveGeneratorTests.swift`
- Create: `Tests/LegoBuilderModelTests.swift`
- Create: `Tests/WordPuzzleModelTests.swift`

**Interfaces:**
- Consumes: Existing chess model types.
- Produces: XCTest target `ChessHotSwapTests`.

- [ ] Add a `ChessHotSwapTests` unit-test target depending on the app target.
- [ ] Add chess tests for initial legal move count and a basic move application.
- [ ] Add LEGO and word puzzle tests after those models exist.
- [ ] Run `xcodegen generate` if available; otherwise edit the Xcode project through XcodeGen-compatible project file state.
- [ ] Run build and tests.

### Task 2: Workspace Shell

**Files:**
- Modify: `Sources/App/ContentView.swift`

**Interfaces:**
- Consumes: Existing `Board2DView`, `Board3DView`, and `GameState`.
- Produces: App workspace switching between chess, LEGO, and word puzzle views.

- [ ] Add `AppWorkspace` enum with `Chess`, `LEGO`, and `Word` cases.
- [ ] Wrap existing chess UI in a chess workspace section.
- [ ] Add conditional toolbar content so chess controls do not pollute other workspaces.
- [ ] Add placeholder references to `LegoBuilderView` and `WordPuzzleView`.
- [ ] Build.

### Task 3: LEGO Builder MVP

**Files:**
- Create: `Sources/Model/LegoBuilderModel.swift`
- Create: `Sources/Views/LegoBuilderView.swift`
- Modify: `Tests/LegoBuilderModelTests.swift`

**Interfaces:**
- Produces: `LegoBrick`, `LegoBuildDocument`, `LegoBrickSize`, `LegoBrickColor`, `BrickLinkWantedListExporter`.
- UI supports adding bricks, clearing, selecting color/size, and exporting BrickLink wanted-list XML.

- [ ] Add pure LEGO model types.
- [ ] Add wanted-list XML exporter.
- [ ] Add SwiftUI builder view with a grid preview and parts list.
- [ ] Add tests for adding bricks and XML export.
- [ ] Build and test.

### Task 4: Word Puzzle MVP

**Files:**
- Create: `Sources/Model/WordPuzzleModel.swift`
- Create: `Sources/Views/WordPuzzleView.swift`
- Modify: `Tests/WordPuzzleModelTests.swift`

**Interfaces:**
- Produces: `WordPuzzleGame`, `WordPuzzleGuessResult`, `WordPuzzleLetterScore`.
- UI supports entering guesses, score rows, reset, and legal distinct copy.

- [ ] Add pure word puzzle scoring model.
- [ ] Add SwiftUI word puzzle view with local word bank.
- [ ] Add tests for repeated-letter scoring.
- [ ] Build and test.

### Task 5: Final Verification

**Files:**
- Modify only files created or touched by earlier tasks if verification fails.

**Interfaces:**
- Consumes: All app workspaces.
- Produces: Verified build and test result.

- [ ] Run `xcodebuild -project ChessHotSwap.xcodeproj -scheme ChessHotSwap -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build test`.
- [ ] Launch the app and verify workspace switching manually if practical.
- [ ] Report changed files and residual risks.
