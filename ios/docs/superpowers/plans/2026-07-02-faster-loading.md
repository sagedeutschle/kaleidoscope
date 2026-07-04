# Faster Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Kaleidoscope looking and behaving the same while reducing visible loading waits on first launch, Wordgame, and Debt Clock.

**Architecture:** Prefer instant local/cached state and background refresh. First launch should render Home from a stable guest identity while cloud identity restores; Wordgame should reuse a cached broker daily when available; Debt Clock should render the last saved snapshot before public APIs return.

**Tech Stack:** SwiftUI, Swift concurrency, XCTest, Codable JSON persistence, XcodeGen iOS project.

## Global Constraints

- Do not remove Game Center, Supabase cloud sync, leaderboards, Wordgame broker daily, or Debt Clock live refresh.
- Preserve the same visible screens and styling; replace blocking waits with cached/local state plus background updates.
- Avoid new source files so `xcodegen generate` is not required for this pass.
- Work in place because this checkout has no `.git` metadata at the project root.

---

### Task 1: First Launch Starts From Guest State

**Files:**
- Modify: `Sources/Backend/AuthManager.swift`
- Test: `Tests/GameCenterOnlySurfaceTests.swift`

**Interfaces:**
- Produces: `AuthManager.state` starts as `.signedIn(<stable guest UUID>)` and `isCloudBacked == false`.
- Preserves: `AuthManager.restore()` still upgrades to Game Center/Supabase when available.

- [ ] **Step 1: Write the failing test**

Add an `@MainActor` XCTest that constructs `AuthManager` and asserts it does not start in `.loading`.

- [ ] **Step 2: Run the focused test and confirm it fails**

Run `xcodebuild ... -only-testing:KaleidoscopeTests/GameCenterOnlySurfaceTests/testAuthManagerStartsWithLocalGuestIdentity`.

- [ ] **Step 3: Initialize `AuthManager` with the existing stable guest id**

Set the published default state to `.signedIn(Self.localGuestID())`.

- [ ] **Step 4: Re-run the focused test**

Expected: the new test passes.

### Task 2: Wordgame Reuses Cached Broker Daily

**Files:**
- Modify: `Sources/Core/Games/DailyWordProvider.swift`
- Modify: `Sources/Core/Games/WordleSession.swift`
- Test: `Tests/WordleSessionTests.swift`

**Interfaces:**
- Produces: `DailyWordCache` with `load`, `save`, and date-scoped remote daily entries.
- Produces: `DailyWordProvider.cachedRemoteWord(from:date:)`.
- Preserves: failed remote fetch still falls back to local daily.

- [ ] **Step 1: Write failing cache round-trip and session behavior tests**

Test that a cached remote payload loads for the same URL/date and that `WordleSession.loadDaily()` starts from cached daily before fetching fresh data.

- [ ] **Step 2: Run the focused tests and confirm failure**

Run `xcodebuild ... -only-testing:KaleidoscopeTests/WordleSessionTests`.

- [ ] **Step 3: Implement `DailyWordCache` and wire it into `DailyWordProvider` / `WordleSession`**

Use a small JSON file under Application Support for production and temp files in tests.

- [ ] **Step 4: Re-run Wordle tests**

Expected: all `WordleSessionTests` pass.

### Task 3: Debt Clock Shows Cached Snapshot Immediately

**Files:**
- Modify: `Sources/Core/Stats/DebtClockStats.swift`
- Modify: `Sources/Features/Stats/DebtClockStatsView.swift`
- Test: `Tests/DebtClockStatsTests.swift`

**Interfaces:**
- Produces: `DebtClockSnapshotCache` with JSON `load` and `save`.
- Produces: `DebtClockStatsStore.init(client:cache:)` that seeds `snapshot` from cache.
- Preserves: `DebtClockStatsStore.load()` still refreshes live public sources.

- [ ] **Step 1: Write failing cache tests**

Test snapshot cache round-trip and store initialization from a temp cached snapshot.

- [ ] **Step 2: Run focused Debt Clock tests and confirm failure**

Run `xcodebuild ... -only-testing:KaleidoscopeTests/DebtClockStatsTests`.

- [ ] **Step 3: Implement snapshot cache and store seeding**

Save refreshed non-empty snapshots; if a refresh returns no metrics, preserve the cached snapshot and expose the error.

- [ ] **Step 4: Re-run Debt Clock tests**

Expected: all `DebtClockStatsTests` pass.

### Task 4: Verification

**Files:**
- Existing tests only.

- [ ] Run `xcodebuild` focused tests for auth, Wordgame, and Debt Clock.
- [ ] Run a Debug simulator build using `~/Library/Caches/Kaleidoscope-sim-dd`.
- [ ] Report any unavailable device deploy separately.
