# Kaleidoscope Game Center Slice 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the macOS Game Center submission layer while preserving local leaderboards as the verified offline fallback.

**Architecture:** Keep game views talking to the existing `LeaderboardService` protocol. Add a Game Center mapping/submission adapter under `Sources/Model`, then wrap local storage and optional Game Center submission in a single app-level service. Local scores remain authoritative for in-app display until App Store Connect leaderboards exist and can be queried in a signed build.

**Tech Stack:** Swift 5, SwiftUI, XCTest, XcodeGen, macOS 14, GameKit via the local Xcode SDK.

## Global Constraints

- Do not require a signed-in Game Center account for tests.
- Do not require App Store Connect leaderboard setup for local verification.
- Keep 2048 and Snake wired through `LeaderboardService`; do not duplicate submission logic in the views.
- Keep `LocalLeaderboardService` behavior unchanged for `.local` score display.
- Treat Game Center global/friends boards as unavailable until the Apple-side IDs exist.
- The current macOS app directory is untracked from the top-level git root, so do not run broad `git add` or commit commands.

---

## File Structure

- Create `Sources/Model/GameCenterLeaderboard.swift`: Game Center leaderboard ID mapping, score-submission protocol, GameKit-backed submitter, authentication state/controller, and composite `KaleidoscopeLeaderboardService`.
- Modify `Sources/Views/LeaderboardViews.swift`: generalize `LocalLeaderboardPanel` from `LocalLeaderboardService` to any `LeaderboardService`.
- Modify `Sources/Views/Game2048View.swift`: use `KaleidoscopeLeaderboardService.shared`.
- Modify `Sources/Views/SnakeView.swift`: use `KaleidoscopeLeaderboardService.shared`.
- Create `Tests/GameCenterLeaderboardTests.swift`: red/green tests for ID mapping, local fallback, remote submission, and remote failure isolation.
- Create `Kaleidoscope.entitlements`: Game Center entitlement for real signed builds.
- Modify `project.yml`: point the app target at `Kaleidoscope.entitlements`.
- Modify `docs/AGENT-COORDINATION.md`: release note with verification and external Apple setup status.

---

### Task 1: Game Center Mapping and Composite Service

**Files:**
- Create: `Sources/Model/GameCenterLeaderboard.swift`
- Create: `Tests/GameCenterLeaderboardTests.swift`

**Interfaces:**
- Consumes: `GameResult`, `LeaderboardService`, `LocalLeaderboardService`, `LeaderboardScope`
- Produces:
  - `struct GameCenterScoreSubmission: Equatable, Sendable`
  - `enum GameCenterLeaderboardCatalog`
  - `protocol GameCenterScoreSubmitting: Sendable`
  - `actor KaleidoscopeLeaderboardService: LeaderboardService`

- [ ] **Step 1: Write failing tests**

Add `Tests/GameCenterLeaderboardTests.swift` with tests that assert:

```swift
func testGameCenterCatalogMapsSupportedModes()
func testCompositeServiceSubmitsSupportedResultToLocalAndGameCenter()
func testCompositeServiceKeepsLocalResultWhenGameCenterSubmissionFails()
func testCompositeServiceDoesNotSubmitUnsupportedResultToGameCenter()
```

Use a test actor:

```swift
actor RecordingGameCenterSubmitter: GameCenterScoreSubmitting {
    var submissions: [GameCenterScoreSubmission] = []
    var error: Error?

    func submit(_ submission: GameCenterScoreSubmission) async throws {
        if let error { throw error }
        submissions.append(submission)
    }

    func recordedSubmissions() -> [GameCenterScoreSubmission] {
        submissions
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodegen generate && xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-gamecenter-dd -only-testing:KaleidoscopeTests/GameCenterLeaderboardTests test
```

Expected: compile failure naming missing `GameCenterScoreSubmitting`, `GameCenterScoreSubmission`, `GameCenterLeaderboardCatalog`, and `KaleidoscopeLeaderboardService`.

- [ ] **Step 3: Implement minimal production code**

Add `GameCenterLeaderboard.swift` with:

```swift
struct GameCenterScoreSubmission: Equatable, Sendable {
    var leaderboardID: String
    var score: Int64
    var context: UInt64
}

enum GameCenterLeaderboardCatalog {
    static func leaderboardID(for facetID: String, mode: String) -> String?
    static func submission(for result: GameResult) -> GameCenterScoreSubmission?
}

protocol GameCenterScoreSubmitting: Sendable {
    func submit(_ submission: GameCenterScoreSubmission) async throws
}

actor KaleidoscopeLeaderboardService: LeaderboardService {
    static let shared = KaleidoscopeLeaderboardService(localService: .shared,
                                                       gameCenterSubmitter: GameKitScoreSubmitter())
    init(localService: LocalLeaderboardService, gameCenterSubmitter: any GameCenterScoreSubmitting)
    func submit(_ result: GameResult) async throws
    func entries(facetID: String, mode: String, scope: LeaderboardScope, limit: Int) async throws -> [LeaderboardEntry]
    func personalBest(facetID: String, mode: String) async throws -> LeaderboardEntry?
}
```

`submit(_:)` must save locally first, then attempt Game Center only when `GameCenterLeaderboardCatalog.submission(for:)` returns a mapped score. Game Center submission errors must not remove or hide the local result.

- [ ] **Step 4: Run focused tests**

Run the same focused command from Step 2.

Expected: `GameCenterLeaderboardTests` passes.

---

### Task 2: GameKit Submitter and Authentication State

**Files:**
- Modify: `Sources/Model/GameCenterLeaderboard.swift`

**Interfaces:**
- Consumes: `GameCenterScoreSubmission`, `GameCenterScoreSubmitting`
- Produces:
  - `final class GameKitScoreSubmitter: GameCenterScoreSubmitting`
  - `enum GameCenterAuthenticationState: Equatable`
  - `@MainActor final class GameCenterAuthenticationController: ObservableObject`

- [ ] **Step 1: Add compile-only GameKit implementation**

In `GameCenterLeaderboard.swift`, import GameKit behind `#if canImport(GameKit)`.

Implement:

```swift
final class GameKitScoreSubmitter: GameCenterScoreSubmitting {
    func submit(_ submission: GameCenterScoreSubmission) async throws
}
```

The implementation must call:

```swift
GKLeaderboard.submitScore(Int(submission.score),
                          context: UInt(submission.context),
                          player: GKLocalPlayer.local,
                          leaderboardIDs: [submission.leaderboardID],
                          completionHandler: ...)
```

It must throw `GameCenterSubmissionError.notAuthenticated` when `GKLocalPlayer.local.isAuthenticated` is false.

- [ ] **Step 2: Add authentication state controller**

Add:

```swift
enum GameCenterAuthenticationState: Equatable {
    case notStarted
    case authenticating
    case authenticated(displayName: String)
    case unauthenticated(message: String)
}
```

Add `GameCenterAuthenticationController.startAuthentication()` using `GKLocalPlayer.local.authenticateHandler`. On macOS, the handler receives `NSViewController?` and `Error?`; set state to `.authenticated(displayName:)` when `GKLocalPlayer.local.isAuthenticated` is true, otherwise `.unauthenticated(message:)` unless a view controller is presented.

- [ ] **Step 3: Build focused tests**

Run:

```bash
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-gamecenter-dd -only-testing:KaleidoscopeTests/GameCenterLeaderboardTests test
```

Expected: focused tests still pass and app target compiles with GameKit imported.

---

### Task 3: Wire Views Through the Composite Service

**Files:**
- Modify: `Sources/Views/LeaderboardViews.swift`
- Modify: `Sources/Views/Game2048View.swift`
- Modify: `Sources/Views/SnakeView.swift`

**Interfaces:**
- Consumes: `KaleidoscopeLeaderboardService.shared`
- Produces: 2048 and Snake submit to local + Game Center through the same service.

- [ ] **Step 1: Generalize leaderboard panel**

Change:

```swift
let service: LocalLeaderboardService
```

to:

```swift
let service: any LeaderboardService
```

in `LocalLeaderboardPanel`, keeping the async `entries(...)` call unchanged.

- [ ] **Step 2: Swap game views to composite service**

Change both `Game2048View` and `SnakeView` from:

```swift
private let leaderboardService = LocalLeaderboardService.shared
```

to:

```swift
private let leaderboardService = KaleidoscopeLeaderboardService.shared
```

- [ ] **Step 3: Run focused tests**

Run:

```bash
xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-gamecenter-dd -only-testing:KaleidoscopeTests/GameCenterLeaderboardTests -only-testing:KaleidoscopeTests/GameLeaderboardTests -only-testing:KaleidoscopeTests/GameResultExtractorTests test
```

Expected: all selected tests pass.

---

### Task 4: Project Entitlement and Handoff Docs

**Files:**
- Create: `Kaleidoscope.entitlements`
- Modify: `project.yml`
- Modify: `docs/AGENT-COORDINATION.md`

**Interfaces:**
- Produces: Game Center entitlement is present for signed builds.

- [ ] **Step 1: Add entitlement file**

Create `Kaleidoscope.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.game-center</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Point project at entitlements**

In `project.yml`, under the app target base settings, add:

```yaml
CODE_SIGN_ENTITLEMENTS: Kaleidoscope.entitlements
```

- [ ] **Step 3: Regenerate and full test**

Run:

```bash
xcodegen generate && xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/kaleidoscope-gamecenter-full-dd test
```

Expected: full suite passes.

- [ ] **Step 4: Update PRISM release note**

Append a `PRISM: RELEASE Agent-B 2026-06-28 (Game Center adapter slice)` note to `docs/AGENT-COORDINATION.md` listing:

- Game Center adapter scaffold added.
- 2048 and Snake submit through the composite local + Game Center service.
- Local fallback is still the in-app display source.
- Real global boards still require Apple Developer team, signed entitlements, and App Store Connect leaderboard IDs.
- Verification command and test count.
