# Prismet Fair Play Phase 1 Implementation Plan

> **Execution:** Use the repo-local Legion build formation with one shared-package cohort, one iOS/iPadOS cohort, and one macOS cohort. Workers edit only their owned files and do not stage or commit. The root operator reviews and commits each lane separately.

**Goal:** Land the deterministic, auditable foundation required by Practice Blackjack, Five-Card Poker, Euchre, and Lantern Exchange while fixing three independent accessibility/recovery rough edges.

**Architecture:** `PrismetShared` gains platform-neutral playing cards, a SplitMix64-v1 deterministic generator with rejection-sampled bounded draws, Fisher-Yates shuffle, replay records, deterministic state hashes, and versioned game-state payloads. The app work remains narrowly scoped to native controls and state presentation. Existing app-local card/deck/RNG types are not migrated in this slice, so the new public types use `Prismet` prefixes and cannot collide.

**Tech stack:** Swift 5.9, Foundation, SwiftUI, UIKit accessibility notifications, Swift Package Manager, XCTest, XcodeGen, Xcode command-line builds.

## Boundaries

- Follow `docs/superpowers/specs/2026-07-14-prismet-fair-play-expansion-design.md`.
- No currency, chips, balances, wagers, stakes, payouts, prizes, streaks, urgency, automatic next hand, or outcome adjustment.
- Do not edit Catan, Home/catalog/root navigation, shared design-system or Illuminated Cabinet files, App Store/release files, either `project.yml`, generated projects, `PrismetFeatureManifest.swift`, or existing save/identity/launch contracts.
- The root operator has the only coordination-ledger write. Legion workers must not edit `docs/AGENT-COORDINATION.md`.
- Tests must be observed failing for the intended reason before each production change.
- iOS source serves both iPhone and iPadOS; final verification must build and launch a separate iPhone and iPad simulator.

## Owned files

### Shared cohort

- Create `shared/PrismetShared/Sources/PrismetShared/PrismetPlayingCards.swift`
- Create `shared/PrismetShared/Sources/PrismetShared/PrismetDeterministicRandom.swift`
- Create `shared/PrismetShared/Sources/PrismetShared/PrismetReplayContracts.swift`
- Create `shared/PrismetShared/Sources/PrismetShared/PrismetVersionedGameState.swift`
- Create matching files in `shared/PrismetShared/Tests/PrismetSharedTests/`

### iOS/iPadOS cohort

- Modify `ios/Sources/Features/Profile/ProfileSetupView.swift`
- Modify `ios/Sources/Features/Games/WordleView.swift`
- Modify `ios/Tests/WordleSessionTests.swift`
- Create `ios/Tests/ProfileSetupAccessibilityTests.swift`

### macOS cohort

- Modify `macos/Sources/Views/LeaderboardViews.swift`
- Modify `macos/Tests/GameLeaderboardTests.swift`

---

## Task 1: Stable playing-card identities and deck factories

**Tests first:** `PrismetPlayingCardsTests.swift`

1. Add tests that reference the still-missing public types and prove:
   - `PrismetCardSuit.allCases` is clubs, diamonds, hearts, spades in stable order;
   - ranks are two through ace in stable numeric order;
   - every `PrismetPlayingCard.id` is unique and stable across Codable round trips;
   - `PrismetDeckFactory.standard52()` has 52 unique cards, 13 per suit;
   - `PrismetDeckFactory.euchre24()` has 24 unique cards and only ranks nine through ace.
2. Run `swift test --filter PrismetPlayingCardsTests` and record the expected compile failure for missing types.
3. Implement:

```swift
public enum PrismetCardSuit: String, CaseIterable, Codable, Hashable, Sendable
public enum PrismetCardRank: Int, CaseIterable, Codable, Hashable, Sendable
public struct PrismetPlayingCard: Identifiable, Codable, Hashable, Sendable
public enum PrismetDeckFactory {
    public static func standard52() -> [PrismetPlayingCard]
    public static func euchre24() -> [PrismetPlayingCard]
}
```

`id` is derived only from the stable rank/suit raw values. No UI color is part of card identity.

4. Rerun the focused test and expect all card tests to pass.

## Task 2: Unbiased deterministic randomization

**Tests first:** `PrismetDeterministicRandomTests.swift`

1. Add tests for:
   - algorithm version `1`;
   - SplitMix64 seed `0x123456789ABCDEF0` producing the first five values `1592342178222199016`, `12499191764280245088`, `3819614628928595213`, `4718850641434784223`, `11074192720443766454`;
   - identical seeds producing identical sequences and different seeds diverging;
   - `nextInt(upperBound:)` rejecting non-positive bounds;
   - the rejection path consuming another raw draw when the first value falls below the unbiased threshold, using an internal scripted generator helper;
   - Fisher-Yates preserving membership and producing a fixed same-seed deck order;
   - zero- and one-element shuffles doing no invalid bounded draw.
2. Run `swift test --filter PrismetDeterministicRandomTests`; expect missing-symbol compile failures.
3. Implement:

```swift
public struct PrismetDeterministicRandom: RandomNumberGenerator, Codable, Hashable, Sendable {
    public static let algorithmVersion = 1
    public let seed: UInt64
    public private(set) var state: UInt64
    public init(seed: UInt64)
    public mutating func next() -> UInt64
    public mutating func nextInt(upperBound: Int) throws -> Int
    public mutating func shuffle<Element>(_ values: inout [Element]) throws
}

public enum PrismetDeterministicRandomError: Error, Equatable {
    case invalidUpperBound(Int)
}
```

Bounded values use the wrapping-threshold rejection formula `(0 &- bound) % bound`; shuffling is in-place Fisher-Yates from the final index down to one. Do not use modulo-only bounded draws.

4. Rerun the focused test and then the card and RNG tests together; expect green.

## Task 3: Replay audit and versioned game state

**Tests first:** `PrismetReplayContractsTests.swift` and `PrismetVersionedGameStateTests.swift`

1. Add failing tests that prove:
   - FNV-1a-64-v1 state hashing has a fixed UTF-8 fixture and renders 16 lowercase hexadecimal characters;
   - command and event sequence numbers must be non-negative and strictly increasing within a replay;
   - rules/randomizer versions and canonical game IDs must be positive/non-empty;
   - replay JSON round trips the seed, commands, events, final outcome, and final hash;
   - replay JSON contains no account, profile, device, purchase, or storage-scope fields;
   - a mismatched final state hash fails verification with a typed error;
   - a versioned state preserves opaque payload bytes exactly;
   - decode succeeds only when rules, payload, randomizer, and hash-algorithm versions are explicitly supported;
   - unsupported future versions return typed update-required errors without rewriting bytes.
2. Run both focused test filters and record missing-symbol failures.
3. Implement these public contracts:

```swift
public enum PrismetStateHashAlgorithm: String, Codable, Hashable, Sendable { case fnv1a64V1 }
public struct PrismetStateHash: Codable, Hashable, Sendable {
    public let algorithm: PrismetStateHashAlgorithm
    public let value: String
    public static func fnv1a64(_ data: Data) -> PrismetStateHash
}
public struct PrismetGameCommandRecord: Codable, Hashable, Sendable
public struct PrismetGameEventRecord: Codable, Hashable, Sendable
public enum PrismetGameReplayOutcome: String, Codable, Hashable, Sendable
public struct PrismetGameReplay: Codable, Hashable, Sendable {
    public func verify() throws
}
public struct PrismetVersionedGameState: Codable, Hashable, Sendable
public struct PrismetVersionSupport: Hashable, Sendable
public enum PrismetVersionedGameStateCodec {
    public static func encode(_ state: PrismetVersionedGameState) throws -> Data
    public static func decodeSupported(_ data: Data, support: PrismetVersionSupport) throws -> PrismetVersionedGameState
}
```

Command/event payloads are opaque `Data`; canonical game identity is a trimmed non-empty string so this slice does not edit the contended feature manifest. The codec uses sorted JSON keys and seconds-since-1970 dates.

4. Rerun replay/state tests, then `swift test`; expect the complete package suite to pass.
5. Root commits the shared cohort alone as `feat: add Prismet fair play audit foundation`.

## Task 4: Native profile avatar and color controls

**Tests first:** `ProfileSetupAccessibilityTests.swift`

1. Add a source-contract test that loads `ProfileSetupView.swift` and initially fails because the option selectors still use `.onTapGesture`.
2. Assert the final source:
   - contains no `.onTapGesture`;
   - uses native `Button` controls for emoji and color choices;
   - contains a 44-by-44 minimum hit region;
   - applies accessibility labels and selected traits;
   - provides spoken names for all six palette colors rather than reading hex values.
3. Generate the ignored Xcode project locally, then run:

```bash
cd ios
xcodegen generate
xcodebuild test -project Prismet.xcodeproj -scheme Prismet \
  -destination 'platform=iOS Simulator,id=CFA90B6D-5C64-4E5A-8640-3D361140B9B5' \
  -derivedDataPath "$HOME/Library/Caches/Prismet-FairPlay-iOS" \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrismetTests/ProfileSetupAccessibilityTests
```

Expected red: assertions report gesture selectors and missing accessibility contracts.

4. Replace each gesture selector with a plain native button. Emoji labels use descriptive avatar names; colors use Gold, Crimson, Green, Blue, Violet, and Orange. Selected options expose `.isSelected`; all options have at least a 44-by-44 frame.
5. Rerun the focused test; expect green.

## Task 5: Wordgame semantic tiles and Reduce Motion

**Tests first:** additions to `WordleSessionTests.swift`

1. Add source-contract tests for `@Environment(\.accessibilityReduceMotion)`, per-tile row/column labels and state values, a live/posted error announcement, and a reduce-motion branch in `triggerShake()`.
2. Run the focused class with the same iPhone destination and `-only-testing:PrismetTests/WordleSessionTests`; expect the new source-contract tests to fail before production edits.
3. Add:
   - the Reduce Motion environment value;
   - tile semantics: row, column, letter/empty state, and correct/present/absent/in-progress value;
   - an assertive status announcement or `UIAccessibility.post` for invalid/incomplete guesses;
   - a no-travel Reduce Motion path that resets the offset without shake animations.
4. Rerun `WordleSessionTests`, then both focused iOS test classes; expect green.
5. Root commits the iOS cohort alone as `fix: polish Prismet profile and Wordgame accessibility`.

## Task 6: Descriptive macOS leaderboard states

**Tests first:** additions to `GameLeaderboardTests.swift`

1. Add tests for an internal `LocalLeaderboardPresentation` contract with exact copy:
   - loading: `Loading local scores…`;
   - failure: `Scores could not be loaded.`;
   - retry action: `Retry`;
   - empty title: `No scores yet`;
   - empty guidance: `Finish a ranked game to create your first local score.`
2. Generate the ignored project and run:

```bash
cd macos
xcodegen generate
xcodebuild test -project Prismet.xcodeproj -scheme Prismet \
  -destination 'platform=macOS' \
  -derivedDataPath "$HOME/Library/Caches/Prismet-FairPlay-macOS" \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:PrismetTests/GameLeaderboardTests
```

Expected red: `LocalLeaderboardPresentation` is missing.

3. Implement the copy contract and render:
   - labeled progress during loading;
   - failure copy and an adjacent Retry button that calls `loadEntries()`;
   - the empty title plus useful guidance;
   - Refresh only in non-error states;
   - explicit accessibility labels for progress and retry.
4. Rerun the focused test; expect green.
5. Root commits the macOS cohort alone as `fix: clarify Prismet leaderboard recovery states`.

## Task 7: Integrated verification and three-platform launch gate

1. Run `swift test` in `shared/PrismetShared`; expected: all tests pass.
2. Regenerate both ignored Xcode projects.
3. Run the two focused iOS classes and focused macOS class again.
4. Build iPhone and iPad separately with signing disabled:

```bash
xcodebuild build -project ios/Prismet.xcodeproj -scheme Prismet -configuration Debug \
  -destination 'platform=iOS Simulator,id=CFA90B6D-5C64-4E5A-8640-3D361140B9B5' \
  -derivedDataPath "$HOME/Library/Caches/Prismet-FairPlay-iPhone" CODE_SIGNING_ALLOWED=NO
xcodebuild build -project ios/Prismet.xcodeproj -scheme Prismet -configuration Debug \
  -destination 'platform=iOS Simulator,id=A4B18E67-3CE3-4531-9B54-3B26F36B48BD' \
  -derivedDataPath "$HOME/Library/Caches/Prismet-FairPlay-iPad" CODE_SIGNING_ALLOWED=NO
```

5. Build macOS with signing disabled using `macos/scripts/build-macos.sh` if present, otherwise the repository's established no-sign `xcodebuild` command.
6. Install and launch the iPhone simulator app, the iPad simulator app, and `~/Applications/Prismet.app`. Capture exact launch failures; do not equate build success with launch success.
7. Run `git diff --check`, review only owned diffs, and confirm no prohibited economy vocabulary was introduced in the new Fair Play source.

## Next plan

As soon as Tasks 1–3 are green, execute a separate Practice Casino vertical-slice plan: shared Blackjack engine first, then parallel iPhone/iPadOS and macOS views, followed by a three-platform build-and-launch gate. Five-Card Poker follows the same shape. Euchre and Lantern Exchange remain queued behind those Casino slices per Sage's latest priority.
