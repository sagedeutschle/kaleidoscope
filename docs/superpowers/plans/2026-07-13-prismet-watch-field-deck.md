# Prismet Apple Watch Field Deck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an embedded Prismet Apple Watch field deck with dated project pulses, three offline games, phone refresh, and complication surfaces.

**Architecture:** A dependency-free `WatchFieldDeckCore` Swift package owns portable snapshot and game rules. A single-target SwiftUI watchOS app persists the last good snapshot and talks to a silent iPhone `WatchConnectivity` bridge. A watchOS WidgetKit extension supplies complication families from the safe bundled catalog.

**Tech Stack:** Swift 5, Swift Package Manager, SwiftUI, WatchConnectivity, WidgetKit, XcodeGen 2.45.4, Xcode 26 SDKs, XCTest.

## Global Constraints

- Preserve the existing iPhone bundle identifier `com.spocksclub.kaleidoscope`, IAP ids, backend keys, game ids, save keys, and build `1.2 (14)`.
- Use watchOS 11.0 as the minimum; keep the iPhone target at iOS 17.0.
- Do not touch Claude/Fable Catan source, macOS Catan, App Store assets/listing, online catalog, or backend match code.
- Never put credentials, local absolute paths, laptop control, or mail actions in Watch payloads.
- Every snapshot must display an honest generation date; uncommitted project work must be labeled in flight, not shipped.
- Build output stays under `~/Library/Caches`, never inside the repo or NAS.

---

### Task 1: Portable Project Pulse Contract

**Files:**
- Create: `shared/WatchFieldDeckCore/Package.swift`
- Create: `shared/WatchFieldDeckCore/Sources/WatchFieldDeckCore/ProjectPulse.swift`
- Create: `shared/WatchFieldDeckCore/Sources/WatchFieldDeckCore/FieldDeckCatalog.swift`
- Create: `shared/WatchFieldDeckCore/Tests/WatchFieldDeckCoreTests/ProjectPulseTests.swift`

**Interfaces:**
- Produces: `ProjectID`, `PulseState`, `ProjectPulse`, `FieldDeckSnapshot`, `FieldDeckCodec`, and `FieldDeckCatalog.july13`.
- Consumes: Foundation `Date`, `JSONEncoder`, and `JSONDecoder` only.

- [ ] **Step 1: Create the package manifest and failing contract tests**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WatchFieldDeckCore",
    platforms: [.iOS(.v17), .watchOS(.v11), .macOS(.v14)],
    products: [.library(name: "WatchFieldDeckCore", targets: ["WatchFieldDeckCore"])],
    targets: [
        .target(name: "WatchFieldDeckCore"),
        .testTarget(name: "WatchFieldDeckCoreTests", dependencies: ["WatchFieldDeckCore"]),
    ]
)
```

```swift
import XCTest
@testable import WatchFieldDeckCore

final class ProjectPulseTests: XCTestCase {
    func testJuly13CatalogCoversEveryActiveProjectFamily() {
        XCTAssertEqual(Set(FieldDeckCatalog.july13.projects.map(\.id)), Set(ProjectID.allCases))
        XCTAssertEqual(FieldDeckCatalog.july13.schemaVersion, FieldDeckSnapshot.currentSchemaVersion)
    }

    func testContextRoundTripPreservesSnapshot() throws {
        let context = try FieldDeckCodec.context(for: .july13)
        XCTAssertEqual(try FieldDeckCodec.snapshot(from: context), .july13)
    }

    func testOnlyNewerMatchingSchemaSnapshotIsAccepted() {
        let current = FieldDeckCatalog.july13
        let newer = current.replacingGeneratedAt(current.generatedAt.addingTimeInterval(60))
        let older = current.replacingGeneratedAt(current.generatedAt.addingTimeInterval(-60))
        XCTAssertTrue(FieldDeckCodec.shouldAccept(newer, replacing: current))
        XCTAssertFalse(FieldDeckCodec.shouldAccept(older, replacing: current))
        XCTAssertFalse(FieldDeckCodec.shouldAccept(
            newer.replacingSchemaVersion(current.schemaVersion + 1), replacing: current
        ))
    }
}
```

- [ ] **Step 2: Run the contract tests and verify RED**

Run: `cd shared/WatchFieldDeckCore && swift test`

Expected: compilation fails because `FieldDeckCatalog`, `ProjectID`, and the snapshot contract do not exist.

- [ ] **Step 3: Implement the snapshot contract and exact July 13 catalog**

```swift
public enum ProjectID: String, Codable, CaseIterable, Sendable {
    case prismet, longNow, allhands, prismCode, protonOutlook, minecraftMesh, mediaNAS, macWorkflow
}

public enum PulseState: String, Codable, Sendable {
    case shipped, ready, active, queued, guarded
}

public struct ProjectPulse: Codable, Equatable, Identifiable, Sendable {
    public let id: ProjectID
    public let title: String
    public let state: PulseState
    public let headline: String
    public let detail: String
    public let nextAction: String
    public let symbol: String
    public let accentHex: String
}

public struct FieldDeckSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public let schemaVersion: Int
    public let generatedAt: Date
    public let projects: [ProjectPulse]

    public func replacingGeneratedAt(_ date: Date) -> Self { .init(schemaVersion: schemaVersion, generatedAt: date, projects: projects) }
    public func replacingSchemaVersion(_ version: Int) -> Self { .init(schemaVersion: version, generatedAt: generatedAt, projects: projects) }
}

public enum FieldDeckCodec {
    public static let contextKey = "prismet.fieldDeck.snapshot"

    public static func context(for snapshot: FieldDeckSnapshot) throws -> [String: Any] {
        [contextKey: try JSONEncoder().encode(snapshot)]
    }

    public static func snapshot(from context: [String: Any]) throws -> FieldDeckSnapshot {
        guard let data = context[contextKey] as? Data else { throw FieldDeckCodecError.missingSnapshot }
        return try JSONDecoder().decode(FieldDeckSnapshot.self, from: data)
    }

    public static func shouldAccept(_ candidate: FieldDeckSnapshot, replacing current: FieldDeckSnapshot) -> Bool {
        candidate.schemaVersion == FieldDeckSnapshot.currentSchemaVersion && candidate.generatedAt > current.generatedAt
    }
}

public enum FieldDeckCodecError: Error { case missingSnapshot }

public extension FieldDeckSnapshot {
    static var july13: Self { FieldDeckCatalog.july13 }
}
```

Create `FieldDeckCatalog.july13` with exactly eight cards and the wording from the approved spec.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `cd shared/WatchFieldDeckCore && swift test`

Expected: `3 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add shared/WatchFieldDeckCore
git commit -m "feat(watch): add portable field deck snapshot"
```

### Task 2: Test-First Pocket Game Models

**Files:**
- Create: `shared/WatchFieldDeckCore/Sources/WatchFieldDeckCore/SeededRandom.swift`
- Create: `shared/WatchFieldDeckCore/Sources/WatchFieldDeckCore/Pocket2048.swift`
- Create: `shared/WatchFieldDeckCore/Sources/WatchFieldDeckCore/PocketLightsOut.swift`
- Create: `shared/WatchFieldDeckCore/Sources/WatchFieldDeckCore/CatanHarvest.swift`
- Create: `shared/WatchFieldDeckCore/Tests/WatchFieldDeckCoreTests/PocketGameTests.swift`

**Interfaces:**
- Produces: `Pocket2048.move(_:)`, `PocketLightsOut.press(row:col:)`, `CatanHarvest.roll()` and `.bank()`.
- Consumes: deterministic `SeededRandom` owned by this package.

- [ ] **Step 1: Write one failing test per game behavior**

```swift
final class PocketGameTests: XCTestCase {
    func test2048MergesEachPairOnlyOnce() {
        var game = Pocket2048(grid: [2,2,2,2] + Array(repeating: 0, count: 12), score: 0, seed: 9)
        XCTAssertTrue(game.move(.left, spawn: false))
        XCTAssertEqual(Array(game.grid.prefix(4)), [4,4,0,0])
        XCTAssertEqual(game.score, 8)
    }

    func testLightsOutPressTogglesCrossAndPuzzleIsSolvableByReplayingSeedPresses() {
        var game = PocketLightsOut.newPuzzle(seed: 42, pressCount: 8)
        for press in game.solution.reversed() { game.press(row: press.row, col: press.col) }
        XCTAssertTrue(game.isSolved)
    }

    func testCatanHarvestProductiveRollAddsPipsAndRobberHalvesUnbanked() {
        var game = CatanHarvest(seed: 1)
        XCTAssertEqual(game.apply(total: 6), .productive(total: 6, gained: 5))
        XCTAssertEqual(game.unbanked, 5)
        XCTAssertEqual(game.apply(total: 7), .robber(lost: 3))
        XCTAssertEqual(game.unbanked, 2)
    }

    func testCatanHarvestWinsAtTwentyFiveBanked() {
        var game = CatanHarvest(seed: 2)
        for _ in 0..<5 { _ = game.apply(total: 6); _ = game.bank() }
        XCTAssertTrue(game.didWin)
    }
}
```

- [ ] **Step 2: Run and verify RED**

Run: `cd shared/WatchFieldDeckCore && swift test --filter PocketGameTests`

Expected: compilation fails because the three game types do not exist.

- [ ] **Step 3: Implement deterministic minimal rules**

Implement `SeededRandom` as a Codable 64-bit linear congruential generator. Implement standard
4×4 2048 line compaction/one-merge-per-pair and deterministic 2/4 spawning. Implement a 5×5
Lights Out cross-toggle board whose generated puzzle retains the legal press sequence as
`solution`. Implement Catan pip scoring with `pips(2/12)=1`, `pips(3/11)=2`, `pips(4/10)=3`,
`pips(5/9)=4`, `pips(6/8)=5`, `7=robber`, and all other totals barren. Robber loss is
`(unbanked + 1) / 2`; victory is `banked >= 25`.

- [ ] **Step 4: Run focused and full core tests GREEN**

Run: `cd shared/WatchFieldDeckCore && swift test --filter PocketGameTests && swift test`

Expected: all core tests pass with zero failures.

- [ ] **Step 5: Commit**

```bash
git add shared/WatchFieldDeckCore
git commit -m "feat(watch): add three offline pocket games"
```

### Task 3: Generate and Embed Modern Watch Targets

**Files:**
- Modify: `ios/project.yml`
- Create: `ios/WatchFieldDeck/Resources/Assets.xcassets/Contents.json`
- Create: `ios/WatchFieldDeck/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `ios/WatchFieldDeck/App/PrismetFieldDeckApp.swift`
- Create: `ios/WatchFieldDeck/App/FieldDeckRootView.swift`

**Interfaces:**
- Produces: Xcode schemes `Prismet Watch App` and `Prismet Field Deck Widget` and an `Embed Watch Content` phase on `Prismet`.
- Consumes: `WatchFieldDeckCore` as a local package.

- [ ] **Step 1: Add a failing generated-project contract test**

Create `ios/Tests/WatchProjectConfigurationTests.swift` that loads `project.yml` as text and asserts
the exact package path, bundle identifiers, `platform: watchOS`, watchOS 11.0 deployment target,
and iOS-to-Watch dependency names.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
cd ios
xcodebuild test -project Prismet.xcodeproj -scheme Prismet \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0.1' \
  -derivedDataPath ~/Library/Caches/PrismetWatchBuild \
  -only-testing:PrismetTests/WatchProjectConfigurationTests
```

Expected: test fails because the Watch package/targets are absent.

- [ ] **Step 3: Add exact XcodeGen target graph**

Add `watchOS: "11.0"` to deployment targets; add local package `WatchFieldDeckCore` at
`../shared/WatchFieldDeckCore`; add `WatchFieldDeckCore` and target `Prismet Watch App` dependencies
to `Prismet`; add:

```yaml
  Prismet Watch App:
    type: application
    platform: watchOS
    deploymentTarget: "11.0"
    sources:
      - path: WatchFieldDeck
    dependencies:
      - package: WatchFieldDeckCore
        product: WatchFieldDeckCore
      - target: Prismet Field Deck Widget
        embed: true
    info:
      path: WatchFieldDeck/Info.plist
      properties:
        CFBundleDisplayName: Field Deck
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        WKWatchKitApp: true
        WKCompanionAppBundleIdentifier: com.spocksclub.kaleidoscope
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.spocksclub.kaleidoscope.watchkitapp
        PRODUCT_NAME: Prismet Watch App
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        CURRENT_PROJECT_VERSION: "14"
        MARKETING_VERSION: "1.2"

  Prismet Field Deck Widget:
    type: app-extension
    platform: watchOS
    deploymentTarget: "11.0"
    sources:
      - path: WatchFieldDeckWidget
    dependencies:
      - package: WatchFieldDeckCore
        product: WatchFieldDeckCore
    info:
      path: WatchFieldDeckWidget/Info.plist
      properties:
        CFBundleDisplayName: Field Deck Pulse
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.spocksclub.kaleidoscope.watchkitapp.fielddeck-widget
        PRODUCT_NAME: Prismet Field Deck Widget
        APPLICATION_EXTENSION_API_ONLY: "YES"
        SKIP_INSTALL: "YES"
        CURRENT_PROJECT_VERSION: "14"
        MARKETING_VERSION: "1.2"
```

- [ ] **Step 4: Add the minimal `@main` Watch app and root list**

The root list contains `Today`, `Pocket Games`, and `Phone Link` navigation destinations and uses
`FieldDeckCatalog.july13` until Task 4 supplies the live store.

- [ ] **Step 5: Generate and inspect the project**

Run:

```bash
cd ios && xcodegen generate
xcodebuild -project Prismet.xcodeproj -scheme 'Prismet Watch App' -showBuildSettings
rg -n 'Embed Watch Content|Prismet Watch App.app|Prismet Field Deck Widget.appex' Prismet.xcodeproj/project.pbxproj
```

Expected: both Watch targets exist, the widget is embedded in the Watch app, and the Watch app is
embedded in Prismet.

- [ ] **Step 6: Run configuration test GREEN and commit**

```bash
git add ios/project.yml ios/WatchFieldDeck ios/Tests/WatchProjectConfigurationTests.swift
git commit -m "feat(watch): embed Prismet field deck targets"
```

### Task 4: Phone-to-Watch Snapshot Refresh

**Files:**
- Create: `ios/Sources/Watch/PhoneFieldDeckBridge.swift`
- Modify: `ios/Sources/App/PrismetApp.swift`
- Create: `ios/Tests/PhoneFieldDeckBridgeTests.swift`
- Create: `ios/WatchFieldDeck/App/FieldDeckStore.swift`
- Create: `ios/WatchFieldDeck/App/GamePersistence.swift`

**Interfaces:**
- Produces: `PhoneFieldDeckBridge.shared.activate()`, `FieldDeckStore.requestRefresh()`, and
  snapshot/game persistence.
- Consumes: `FieldDeckCodec.context(for:)` and `.snapshot(from:)`.

- [ ] **Step 1: Write failing iPhone bridge payload tests**

```swift
final class PhoneFieldDeckBridgeTests: XCTestCase {
    func testBridgeContextRoundTripsSharedCatalog() throws {
        let context = try PhoneFieldDeckBridge.applicationContext(snapshot: .july13)
        XCTAssertEqual(try FieldDeckCodec.snapshot(from: context), .july13)
    }

    func testRefreshRequestKeyIsStable() {
        XCTAssertEqual(PhoneFieldDeckBridge.refreshRequestKey, "prismet.fieldDeck.refresh")
    }
}
```

- [ ] **Step 2: Run focused test RED**

Expected: `PhoneFieldDeckBridge` is undefined.

- [ ] **Step 3: Implement the bridge and activate it without changing auth flow**

`PhoneFieldDeckBridge` subclasses `NSObject`, conforms to `WCSessionDelegate`, activates only when
`WCSession.isSupported()`, pushes `.july13` after successful activation, and responds to a message
containing `refreshRequestKey: true` with the same context. iOS-only delegate methods
`sessionDidBecomeInactive` and `sessionDidDeactivate` reactivate cleanly. `PrismetApp.init()` calls
`PhoneFieldDeckBridge.shared.activate()` before the existing AdMob gate.

- [ ] **Step 4: Implement Watch store acceptance and persistence**

`FieldDeckStore` loads a saved `Data` snapshot or `.july13`, becomes the Watch session delegate,
accepts application context on the main actor only when `FieldDeckCodec.shouldAccept` passes, and
persists the accepted value. `requestRefresh()` sends the stable refresh key when reachable and
otherwise updates only its non-blocking status string. `GamePersistence` generically encodes and
decodes Codable values by stable keys.

- [ ] **Step 5: Run bridge tests and build Watch app GREEN**

Run focused iPhone tests, then:

```bash
xcodebuild build -project Prismet.xcodeproj -scheme 'Prismet Watch App' \
  -destination 'generic/platform=watchOS' \
  -derivedDataPath ~/Library/Caches/PrismetWatchBuild CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 6: Commit**

```bash
git add ios/Sources/Watch ios/Sources/App/PrismetApp.swift ios/Tests/PhoneFieldDeckBridgeTests.swift ios/WatchFieldDeck/App
git commit -m "feat(watch): sync field deck snapshots from iPhone"
```

### Task 5: Watch Project Pulse and Game UI

**Files:**
- Create: `ios/WatchFieldDeck/Views/TodayView.swift`
- Create: `ios/WatchFieldDeck/Views/ProjectPulseDetailView.swift`
- Create: `ios/WatchFieldDeck/Views/GamesHubView.swift`
- Create: `ios/WatchFieldDeck/Views/Pocket2048View.swift`
- Create: `ios/WatchFieldDeck/Views/PocketLightsOutView.swift`
- Create: `ios/WatchFieldDeck/Views/CatanHarvestView.swift`
- Create: `ios/WatchFieldDeck/Views/PhoneLinkView.swift`
- Create: `ios/WatchFieldDeck/Views/WatchTheme.swift`
- Modify: `ios/WatchFieldDeck/App/FieldDeckRootView.swift`

**Interfaces:**
- Consumes: `FieldDeckStore`, `ProjectPulse`, and all three core game models.
- Produces: watch-optimized accessible SwiftUI screens with local persistence.

- [ ] **Step 1: Add source-contract tests before UI implementation**

Extend `WatchProjectConfigurationTests` to assert that the Watch source tree contains accessibility
labels for every 2048 direction, every Lights Out cell, Harvest roll/bank actions, the snapshot date,
and a manual phone refresh control. Run and confirm RED.

- [ ] **Step 2: Implement Watch theme and Today flow**

Use a dark navy background, Prismet gold project-state accent, rounded material cards, and standard
Dynamic Type. `TodayView` lists all snapshot projects; each row exposes title, state, and headline.
`ProjectPulseDetailView` exposes detail, next action, and `generatedAt.formatted(date: .abbreviated,
time: .shortened)`.

- [ ] **Step 3: Implement Pocket 2048 UI**

Render the 4×4 grid in a square `LazyVGrid`, show score, provide four 44-point directional buttons,
persist every accepted move, and offer restart after win/game-over. Every button has an explicit
direction accessibility label.

- [ ] **Step 4: Implement Lights Out UI**

Render a 5×5 square grid with lit/unlit contrast plus borders (never color alone), move count,
solved banner, and New Puzzle. Each cell's accessibility label names row, column, and state.

- [ ] **Step 5: Implement Catan Harvest UI**

Show two large dice, banked/unbanked totals, the last event, Roll and Bank actions, a 25-point goal,
and restart after victory. Disable Bank at zero. Productive, robber, bank, and victory events fire
native Watch haptics.

- [ ] **Step 6: Implement Phone Link and root navigation**

The root opens on Today and exposes Games and Link as list sections. Link shows reachable/unreachable,
last accepted snapshot time, the current non-blocking status, and `Request Update`.

- [ ] **Step 7: Run source contracts and generic/simulator Watch builds GREEN, then commit**

```bash
git add ios/WatchFieldDeck ios/Tests/WatchProjectConfigurationTests.swift
git commit -m "feat(watch): add field pulse and pocket game UI"
```

### Task 6: WidgetKit Complications

**Files:**
- Create: `ios/WatchFieldDeckWidget/FieldDeckWidget.swift`
- Create: `ios/WatchFieldDeckWidget/FieldDeckWidgetBundle.swift`
- Create: `ios/Tests/FieldDeckWidgetSourceTests.swift`

**Interfaces:**
- Consumes: `FieldDeckCatalog.july13`.
- Produces: `.accessoryRectangular`, `.accessoryCircular`, and `.accessoryInline` widgets.

- [ ] **Step 1: Write failing source contract test**

Assert the widget declares all three families, renders active project count and top project title,
and carries a `widgetURL` into the Field Deck app. Run RED.

- [ ] **Step 2: Implement a static safe timeline provider and family-specific layouts**

Use one entry per day because the bundled catalog is dated, not live. Rectangular shows top project
and `8 lanes`; circular shows a prism glyph plus lane count; inline shows `Field Deck · 8 lanes`.

- [ ] **Step 3: Build widget and Watch app GREEN**

Run generic watchOS and watchOS Simulator builds, inspect the final Watch app `PlugIns` directory,
and run the source contract GREEN.

- [ ] **Step 4: Commit**

```bash
git add ios/WatchFieldDeckWidget ios/Tests/FieldDeckWidgetSourceTests.swift
git commit -m "feat(watch): add field deck complications"
```

### Task 7: Full Verification, Device Install, and PRISM Release Record

**Files:**
- Modify: `docs/AGENT-COORDINATION.md`
- Create: `docs/superpowers/handoffs/2026-07-13-prismet-watch-field-deck.md`

**Interfaces:**
- Consumes: all completed Watch changes.
- Produces: reproducible evidence and exact phone/Watch device status.

- [ ] **Step 1: Run full static and package gates**

```bash
git diff --check
cd shared/WatchFieldDeckCore && swift test
cd ../../ios && xcodegen generate
xcodebuild test -project Prismet.xcodeproj -scheme Prismet \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0.1' \
  -derivedDataPath ~/Library/Caches/PrismetWatchFinal
xcodebuild build -project Prismet.xcodeproj -scheme 'Prismet Watch App' \
  -destination 'generic/platform=watchOS' \
  -derivedDataPath ~/Library/Caches/PrismetWatchFinal CODE_SIGNING_ALLOWED=NO
```

Expected: core tests and full iPhone suite report zero failures; generic Watch build succeeds.

- [ ] **Step 2: Build signed iPhone product and inspect embedding**

Build for each available registered iPhone hardware UDID, then verify:

```bash
find ~/Library/Caches/PrismetWatchDevice/Build/Products/Debug-iphoneos/Prismet.app \
  -maxdepth 4 -type d \( -name '*.app' -o -name '*.appex' \) -print
codesign --verify --deep --strict ~/Library/Caches/PrismetWatchDevice/Build/Products/Debug-iphoneos/Prismet.app
```

Expected: signed iPhone app contains the Watch app, whose `PlugIns` contains the widget.

- [ ] **Step 3: Install and launch on reachable phones**

Use hardware UDID for `xcodebuild` and CoreDevice identifier for `devicectl`. Record install and
launch separately for Benjamin's iPhone and Poopoohead. Do not claim a Watch install solely from
the iPhone result.

- [ ] **Step 4: Verify paired Watch if exposed**

Re-run `xcrun xctrace list devices` and `xcrun devicectl list devices`. If the Watch appears, build,
install, launch, and capture process/app evidence. If it remains absent, inspect the embedded product
and leave only the exact Watch Developer Mode/pairing/install toggle handoff.

- [ ] **Step 5: Write handoff and release the PRISM claim**

Record test counts, build outcomes, phone install/launch table, Watch visibility, branch/commit, and
the one-step device action if any. Change the ledger entry from CLAIM to RELEASE without altering
other entries.

- [ ] **Step 6: Final commit and push isolated branch**

```bash
git add docs/AGENT-COORDINATION.md docs/superpowers/handoffs/2026-07-13-prismet-watch-field-deck.md
git commit -m "docs: record Watch field deck deployment"
git push -u origin codex/watch-field-deck-20260713
```
