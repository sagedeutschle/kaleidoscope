# Kaleidoscope Social Leaderboards Slice 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first real macOS social slice: restore the green test baseline, add local result/leaderboard infrastructure, and wire 2048 plus Snake into visible result and leaderboard UI.

**Architecture:** Keep this slice backend-neutral. Add value types and a local file-backed leaderboard service under `Sources/Model`, then attach it to 2048 and Snake views through reusable SwiftUI result/leaderboard components. Game Center and Supabase adapters are follow-up slices after the local loop is proven.

**Tech Stack:** SwiftUI, XCTest, XcodeGen, Codable JSON persistence, existing `Game2048Session` and `SnakeSession`.

## Global Constraints

- macOS app path is `/Users/gtrktscrb/Desktop/GtrktscrB/apps/chess-hotswap`.
- Respect PRISM coordination in `docs/AGENT-COORDINATION.md`: grep for active claims before editing, claim files before edits when another agent may be active, reread files before writing, and keep builds green.
- Do not add Supabase sign-in to macOS in this slice.
- Do not add phone contact discovery.
- Do not require an account to play local games.
- Do not implement Game Center in this slice; expose a service boundary that a later Game Center adapter can satisfy.
- Run `xcodegen generate` after adding Swift files.
- Verify with focused tests first, then the full macOS test command when practical.

---

## File Structure

- `Tests/BrickControlsTests.swift`: verify the existing Tab/Page Down binding baseline.
- `Sources/Model/GameLeaderboard.swift`: new backend-neutral result types, catalog, protocol, and local file-backed service.
- `Tests/GameLeaderboardTests.swift`: tests for result ordering, idempotence, file persistence, and catalog defaults.
- `Sources/Model/GameResultExtraction.swift`: new result extraction helpers for 2048 and Snake.
- `Tests/GameResultExtractionTests.swift`: tests for 2048 and Snake result extraction.
- `Sources/Views/LeaderboardViews.swift`: reusable result sheet and local leaderboard panel.
- `Sources/Views/Game2048View.swift`: submit/display local result on win or game over.
- `Sources/Views/SnakeView.swift`: submit/display local result when Snake is lost.

### Task 0: Baseline Verification

**Files:**
- Test: `Tests/BrickControlsTests.swift`

**Interfaces:**
- Consumes: existing `BrickControls.defaults`
- Produces: verified baseline for current key binding behavior

- [ ] **Step 1: Run focused baseline test**

Run:

```bash
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-brick-controls-dd -only-testing:KaleidoscopeTests/BrickControlsTests test
```

Expected: `BrickControlsTests` passes. If it fails because Tab expects redo, update the assertion to:

```swift
XCTAssertEqual(c.action(for: 48), .lower)       // Tab lowers a level
XCTAssertEqual(c.action(for: 121), .redo)       // Page Down redoes
```

- [ ] **Step 2: Re-run focused baseline test**

Run the same command. Expected: `** TEST SUCCEEDED **`.

### Task 1: Local Leaderboard Service

**Files:**
- Create: `Sources/Model/GameLeaderboard.swift`
- Create: `Tests/GameLeaderboardTests.swift`

**Interfaces:**
- Produces:
  - `GameOutcome`
  - `LeaderboardScope`
  - `LeaderboardSortOrder`
  - `GameResult`
  - `LeaderboardEntry`
  - `LeaderboardService`
  - `LocalLeaderboardService`
  - `LeaderboardCatalog.mode(for:mode:)`

- [ ] **Step 1: Write failing tests**

Create `Tests/GameLeaderboardTests.swift` with tests for:

```swift
func testLocalLeaderboardKeepsBestHighScorePerFacetAndMode() async throws
func testLocalLeaderboardLowerScoreWinsForTimedModes() async throws
func testLocalLeaderboardIgnoresDuplicateResultIDs() async throws
func testLocalLeaderboardPersistsResultsToDisk() async throws
func testCatalogDefinesFirstSliceModes()
```

The tests should use a temp JSON file and should initially fail because the
types do not exist.

- [ ] **Step 2: Verify red**

Run:

```bash
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-leaderboard-dd -only-testing:KaleidoscopeTests/GameLeaderboardTests test
```

Expected: compile failure naming missing leaderboard types.

- [ ] **Step 3: Implement local service**

Create `Sources/Model/GameLeaderboard.swift`.

Required behavior:

- `GameResult` is `Codable`, `Hashable`, `Identifiable`.
- `LeaderboardEntry` is `Codable`, `Hashable`, `Identifiable`.
- `LeaderboardCatalog.mode(for: "2048", mode: "standard")` returns high-score ordering and title `2048`.
- `LeaderboardCatalog.mode(for: "snake", mode: "standard")` returns high-score ordering and title `Snake`.
- `LeaderboardCatalog.mode(for: "minesweeper", mode: "beginner")` returns low-score ordering and title `Minesweeper`.
- `LocalLeaderboardService.submit(_:)` appends a result unless that result id already exists.
- `entries(facetID:mode:scope:limit:)` returns local entries only, sorted by catalog order.
- `personalBest(facetID:mode:)` returns the first local entry.
- Local entries use display name `You`.
- JSON persistence is atomic and reloads across service instances.

- [ ] **Step 4: Verify green**

Run the Task 1 focused test command again. Expected: `** TEST SUCCEEDED **`.

### Task 2: Result Extraction

**Files:**
- Create: `Sources/Model/GameResultExtraction.swift`
- Create: `Tests/GameResultExtractionTests.swift`

**Interfaces:**
- Consumes: `GameResult`, `GameOutcome`, `Game2048Session`, `SnakeSession`
- Produces:
  - `GameResultExtractor.result(for session: Game2048Session, completedAt: Date) -> GameResult?`
  - `GameResultExtractor.result(for session: SnakeSession, completedAt: Date) -> GameResult?`

- [ ] **Step 1: Write failing tests**

Create `Tests/GameResultExtractionTests.swift` with:

```swift
func testExtracts2048GameOverScore() throws
func testDoesNotExtractActive2048Game() throws
func testExtractsSnakeLossScore() throws
func testDoesNotExtractActiveSnakeGame() throws
```

Construct deterministic terminal model states directly. The tests should
initially fail because `GameResultExtractor` does not exist.

- [ ] **Step 2: Verify red**

Run:

```bash
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-result-extract-dd -only-testing:KaleidoscopeTests/GameResultExtractionTests test
```

Expected: compile failure naming missing `GameResultExtractor`.

- [ ] **Step 3: Implement extraction**

Create `Sources/Model/GameResultExtraction.swift`.

Required behavior:

- 2048 returns nil unless `session.game.hasWon || session.game.isGameOver`.
- 2048 result has `facetID = "2048"`, `mode = "standard"`, `outcome = .won` when `hasWon` else `.lost`, and `score = Int64(session.game.score)`.
- Snake returns nil unless `session.game.status == .lost`.
- Snake result has `facetID = "snake"`, `mode = "standard"`, `outcome = .lost`, and `score = Int64(session.game.score)`.
- Result metadata should include compact useful facts: 2048 board size and Snake board dimensions.

- [ ] **Step 4: Verify green**

Run the Task 2 focused test command again. Expected: `** TEST SUCCEEDED **`.

### Task 3: Reusable Result and Leaderboard UI

**Files:**
- Create: `Sources/Views/LeaderboardViews.swift`
- Modify: `Sources/Views/Game2048View.swift`
- Modify: `Sources/Views/SnakeView.swift`

**Interfaces:**
- Consumes: `GameResult`, `LeaderboardEntry`, `LocalLeaderboardService`, `LeaderboardCatalog`
- Produces:
  - `ResultSlipView`
  - `LocalLeaderboardPanel`

- [ ] **Step 1: Add UI component file**

Create `Sources/Views/LeaderboardViews.swift`.

Required UI:

- `ResultSlipView` renders outcome, score, optional personal best, and buttons for Play again, Leaderboard, and Close.
- `LocalLeaderboardPanel` renders local entries for a facet/mode, with an empty state.
- Use `Kaleido`, `StatBadge`, `GlassButtonStyle`, and `AccentButtonStyle`.
- Do not add backend references.

- [ ] **Step 2: Wire 2048**

Modify `Game2048View`:

- Add `@StateObject private var leaderboardService = LocalLeaderboardService.shared`.
- Track `@State private var currentResult: GameResult?`.
- Track `@State private var showLeaderboard = false`.
- After a move commit or shuffle/reset result transition, call an async helper that extracts and submits the result once per `GameResult.id`.
- Present `ResultSlipView` as a sheet when a new result is available.
- Add a trophy menu/button in controls to open `LocalLeaderboardPanel`.

- [ ] **Step 3: Wire Snake**

Modify `SnakeView` similarly:

- Submit once when `session.game.status == .lost`.
- Show result sheet.
- Add a trophy action beside State/New Game.

- [ ] **Step 4: Compile**

Run:

```bash
xcodegen generate
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-social-ui-dd build
```

Expected: `** BUILD SUCCEEDED **`.

### Task 4: Verification

**Files:**
- Modify: `docs/AGENT-COORDINATION.md`

**Interfaces:**
- Consumes: all prior tasks
- Produces: PRISM log entry with final verification evidence

- [ ] **Step 1: Run focused social tests**

Run:

```bash
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-social-focused-dd -only-testing:KaleidoscopeTests/GameLeaderboardTests -only-testing:KaleidoscopeTests/GameResultExtractionTests -only-testing:KaleidoscopeTests/BrickControlsTests test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Run full suite**

Run:

```bash
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-social-full-dd test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Record PRISM log**

Append a short `PRISM:` log entry to `docs/AGENT-COORDINATION.md` with:

- local leaderboard/result slice completed
- 2048 and Snake wired
- focused/full verification result
- no active claims remain

