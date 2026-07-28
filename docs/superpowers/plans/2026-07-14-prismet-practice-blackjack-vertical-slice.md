# Prismet Practice Blackjack Three-Platform Vertical Slice Plan

> **Execution:** Begin only after the Fair Play Phase 1 shared suite is green. Use one shared-engine worker, one iPhone/iPad worker, and one macOS worker. Follow test-driven development and the exact PRISM claim before editing.

**Goal:** Deliver the first playable no-money Casino table as one honest, deterministic Practice Blackjack hand on iPhone, iPad, and Mac, then build and launch all three versions together.

**Architecture:** `PrismetShared` owns the complete rules state machine, concealed-information boundary, factual Hit bust odds, replay/audit construction, and versioned persistence payload. Platform modules receive only a player-safe observation and render native SwiftUI layouts. A new isolated XcodeGen launch harness references the production Casino modules so the slice can run now without touching active root navigation, Catan, cabinet-shell, or App Store files. Final Prismet navigation integration waits for those claims to release.

**Tech stack:** Swift 5.9, Foundation, SwiftUI, Swift Package Manager, XCTest, XcodeGen, Xcode 26, `simctl`.

## Locked product rules

- One standard 52-card deck, freshly shuffled before each independently requested hand.
- Player commands are Hit and Stand only. End Hand is a lifecycle escape, not a table command.
- Dealer stands on every 17, including soft 17.
- A two-card natural 21 beats a non-natural 21.
- Equal final values tie.
- No split, double, insurance, surrender, side bets, multi-hand play, money, chips, balances, wagers, stakes, payouts, prizes, rewards, streaks, pressure, automatic next hand, or outcome adjustment.
- New Hand is enabled only after completion or abandonment and always requires a deliberate player action.
- The seed, dealer hole card, draw pile, and audit are hidden while a hand is active.
- “Hit bust probability” uses only the player cards and dealer face-up card. The hole card and draw pile are treated as unseen. The UI never labels this a guaranteed win chance.

## Owned files

### Shared

- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetBlackjackModels.swift`
- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetBlackjackEngine.swift`
- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetBlackjackOdds.swift`
- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetBlackjackAudit.swift`
- Create matching `PrismetBlackjack*Tests.swift` and `PrismetBlackjackFixtures.swift` under `shared/PrismetShared/Tests/PrismetSharedTests/`

### iPhone and iPad

- Create: `ios/Sources/Features/Casino/CasinoHubView.swift`
- Create: `ios/Sources/Features/Casino/PracticeBlackjackView.swift`
- Create: `ios/Sources/Features/Casino/PracticeBlackjackSession.swift`
- Create: `ios/Sources/Features/Casino/PracticeBlackjackStore.swift`
- Create: `ios/Sources/Features/Casino/CasinoPlayingCardView.swift`
- Create: `ios/Sources/Features/Casino/CasinoFairPlayView.swift`
- Create: `ios/Sources/Features/Casino/CasinoTheme.swift`
- Create: `ios/Tests/PracticeBlackjackSessionTests.swift`
- Create: `ios/Tests/CasinoMobilePresentationTests.swift`
- Create: `ios/Tests/CasinoSafetyContractTests.swift`

### macOS

- Create: `macos/Sources/Casino/CasinoHubView.swift`
- Create: `macos/Sources/Casino/PracticeBlackjackView.swift`
- Create: `macos/Sources/Casino/PracticeBlackjackSession.swift`
- Create: `macos/Sources/Casino/PracticeBlackjackStore.swift`
- Create: `macos/Sources/Casino/CasinoPlayingCardView.swift`
- Create: `macos/Sources/Casino/CasinoFairPlayView.swift`
- Create: `macos/Sources/Casino/CasinoTheme.swift`
- Create: `macos/Tests/PracticeBlackjackSessionTests.swift`
- Create: `macos/Tests/CasinoMacPresentationTests.swift`
- Create: `macos/Tests/CasinoSafetyContractTests.swift`

### Isolated three-platform launcher

- Create: `tools/PracticeCasinoHarness/project.yml`
- Create: `tools/PracticeCasinoHarness/Sources/iOS/PracticeCasinoIOSApp.swift`
- Create: `tools/PracticeCasinoHarness/Sources/macOS/PracticeCasinoMacApp.swift`
- Create: `tools/PracticeCasinoHarness/README.md`

The harness contains app entry points only. It compiles the production iOS or macOS Casino source directory plus `PrismetShared`; it must not fork game rules or copy production views.

## Task 1 — hand values and typed outcomes

**Test first:** Create `PrismetBlackjackHandTests.swift` and require:

```swift
public enum PrismetBlackjackRulesV1
public enum PrismetBlackjackParticipant: String, Codable, Hashable, Sendable
public enum PrismetBlackjackPhase: String, Codable, Hashable, Sendable
public enum PrismetBlackjackCommand: String, CaseIterable, Codable, Hashable, Sendable
public struct PrismetBlackjackHandValue: Codable, Hashable, Sendable
public enum PrismetBlackjackOutcome: String, Codable, Hashable, Sendable
public enum PrismetBlackjackResolutionReason: String, Codable, Hashable, Sendable
public struct PrismetBlackjackResolution: Codable, Hashable, Sendable
```

`PrismetBlackjackRulesV1` publishes canonical ID `blackjack`, name `Practice Blackjack`, rules/payload version `1`, one deck, and `dealerStandsOnSoft17 == true`.

Fixtures:

- Ace + 6 is soft 17.
- Ace + 6 + King is hard 17.
- Ace + Ace + 9 is soft 21 but not natural.
- King + Queen + 2 busts at 22.
- Ace + King is natural.
- 7 + 7 + 7 is non-natural 21.
- Player natural beats dealer three-card 21.
- Dealer natural beats player three-card 21.
- Equal 18s tie.

Run:

```zsh
cd shared/PrismetShared
swift test --scratch-path "$HOME/Library/Caches/PrismetFairPlaySwiftPM" --filter PrismetBlackjackHandTests
```

Expected RED: missing Blackjack symbols. Implement only the models/evaluator, rerun, and expect all focused tests green.

## Task 2 — deterministic engine and concealed observation

**Test first:** Create `PrismetBlackjackEngineTests.swift` and `PrismetBlackjackObservationTests.swift` before production changes.

Public surface:

```swift
public enum PrismetBlackjackDisplayedCard: Codable, Hashable, Sendable {
    case faceUp(PrismetPlayingCard)
    case faceDown
}

public struct PrismetBlackjackObservation: Codable, Hashable, Sendable {
    public let playerCards: [PrismetPlayingCard]
    public let dealerCards: [PrismetBlackjackDisplayedCard]
    public let playerValue: PrismetBlackjackHandValue
    public let dealerVisibleValue: PrismetBlackjackHandValue
    public let dealerFinalValue: PrismetBlackjackHandValue?
    public let legalCommands: [PrismetBlackjackCommand]
    public let canEndHand: Bool
    public let hitOdds: PrismetBlackjackHitOdds?
    public let phase: PrismetBlackjackPhase
    public let resolution: PrismetBlackjackResolution?
}

public struct PrismetBlackjackTransition: Hashable, Sendable {
    public let state: PrismetBlackjackState
    public let events: [PrismetBlackjackEvent]
}

public enum PrismetBlackjackEngine {
    public static func start(seed: UInt64) throws -> PrismetBlackjackTransition
    public static func observation(for state: PrismetBlackjackState) -> PrismetBlackjackObservation
    public static func legalCommands(in state: PrismetBlackjackState) -> [PrismetBlackjackCommand]
    public static func applying(_ command: PrismetBlackjackCommand, to state: PrismetBlackjackState) throws -> PrismetBlackjackTransition
    public static func endHand(_ state: PrismetBlackjackState) throws -> PrismetBlackjackTransition
}
```

`PrismetBlackjackState` is Codable for persistence but its seed, full deck, dealer hole card, draw index, and histories are not public properties. Platform sessions store it privately and expose only `PrismetBlackjackObservation`.

Add an internal test seam `start(seed:shuffledDeck:)`. Fixture draw order is player, dealer, player, dealer. Pin naturals, player bust, dealer bust, dealer soft-17 stand, dealer soft-16 hit, higher totals, equal totals, illegal-command non-mutation, and same-seed equivalence. Completed and abandoned states have no legal commands. No transition constructs another hand.

Prove the focused tests RED, implement minimally, then rerun green.

## Task 3 — factual Hit bust odds

**Test first:** Create `PrismetBlackjackOddsTests.swift` and require:

```swift
public struct PrismetBlackjackHitOdds: Codable, Hashable, Sendable {
    public let bustingCardCount: Int
    public let unseenCardCount: Int
    public let unseenCardCountsByRank: [PrismetCardRank: Int]
    public let assumption: String
    public var probability: Double { get }
}
```

Exact assumption: `Uses only your cards and the dealer’s face-up card; the hole card and draw pile are treated as unseen.`

Fixtures:

- hard 16 from 10 + 6 with dealer showing 5: 30 of 49 unseen cards bust;
- soft 17 from Ace + 6 with dealer showing 5: 0 of 49 bust;
- hard 20 from 10 + King with dealer showing 5: 45 of 49 bust;
- terminal hand: no Hit odds.

The active observation encodes neither seed, hole card, nor draw order. Terminal observation reveals the dealer cards and final total.

## Task 4 — audit, replay, and versioned restore

**Test first:** Create `PrismetBlackjackAuditTests.swift`. Keep all dependencies on Phase 1 replay initializer details inside `PrismetBlackjackAudit.swift`.

Require:

```swift
public struct PrismetBlackjackAuditedSession: Codable, Hashable, Sendable {
    public let state: PrismetBlackjackState
    public var observation: PrismetBlackjackObservation { get }
    public static func start(seed: UInt64) throws -> Self
    public func applying(_ command: PrismetBlackjackCommand) throws -> Self
    public func endingHand() throws -> Self
    public func versionedState(modifiedAt: Date) throws -> PrismetVersionedGameState
    public static func restore(from state: PrismetVersionedGameState) throws -> Self
    public func auditDisclosure() throws -> PrismetBlackjackAuditDisclosure
}
```

The terminal disclosure contains seed, rules/randomizer versions, commands, revealed draw order, state hashes, and generic replay. Generic replay outcome is structural `completed` or `abandoned`; typed Blackjack resolution carries player/dealer/tie detail.

Tests prove same-seed/same-command replay equivalence, active audit denial, terminal disclosure, first tampered hash mismatch, unsupported-version failure, mid-hand save/restore fidelity, abandoned neutral outcome, and absence of account/profile/device/purchase/balance/chip/token/wager/stake/payout/prize/streak/automatic-play fields.

Run all shared Blackjack tests and then the complete shared suite. Commit shared models/engine/odds/audit in separate verified commits.

## Task 5 — iPhone/iPad session and persistence

**Test first:** Add `PracticeBlackjackSessionTests.swift` and `CasinoSafetyContractTests.swift`.

```swift
@MainActor
final class PracticeBlackjackSession: ObservableObject {
    @Published private(set) var table: PrismetBlackjackObservation
    @Published private(set) var loadState: LoadState
    @Published var presentedSheet: Sheet?
    var canHit: Bool { get }
    var canStand: Bool { get }
    func restoreOrDeal() async
    func hit()
    func stand()
    func endHand()
    func newHand()
    func persist() async
}
```

Tests prove commands delegate to the shared engine, `newHand()` is player-triggered and unavailable during active play, background persistence restores the exact future deck, corrupt data is preserved until explicit Start Fresh, audit is unavailable while active, and safety-copy/source scans contain no prohibited economy or pressure language.

`PracticeBlackjackStore` writes atomically under Application Support and never uses account or leaderboard state.

## Task 6 — adaptive iPhone/iPad presentation

**Test first:** Add `CasinoMobilePresentationTests.swift` for a pure `CasinoMobileLayoutPolicy`:

- compact width or usable width below 760: vertical scrolling table plus bottom safe-area action rail;
- regular width at least 760: table left and 300–340-point rules/action sidebar right;
- no fixed text height;
- every action has a 44-point minimum target.

`CasinoHubView` shows Practice Blackjack and a non-interactive `Five-Card Poker — Coming next` card. It never exposes a fake Poker route. The first hand shows: `Practice only. No money, purchases, wagering, prizes, or rewards.`

Cards announce rank and suit; the hidden card announces only `Face-down card`. Dealer summary announces its visible total and hidden-card count. Hit odds include the exact assumption. Result language is neutral. Reduce Motion removes card travel/flip motion while preserving state changes.

## Task 7 — native macOS session and presentation

Use the same shared engine and equivalent store/session tests in the macOS target. `CasinoHubView` uses a native sidebar/table split at ordinary widths and collapses to a stacked layout when narrow. `PracticeBlackjackView` supplies:

- visible keyboard focus for all controls;
- Return or H for Hit, S for Stand, Command-N for New Hand only when legal, Command-R for Replay only after completion, and Escape for Leave/close;
- pointer hover only as enhancement, never the sole state cue;
- resizable narrow, standard, and wide policies;
- native sheets or inspector-style panels for Rules & Fairness without hiding the table;
- Reduce Motion and Differentiate Without Color support.

Mac tests pin layout policy, keyboard-command availability, accessibility labels, persistence, terminal-only audit, and no prohibited economy fields/copy.

## Task 8 — isolated launch harness

Create one XcodeGen project under `tools/PracticeCasinoHarness`. It has two app targets:

- `PrismetPracticeCasinoIOS`, deployment iOS 17, device families 1 and 2, bundle ID `com.spocksclub.prismet.practice-casino-preview`, sources from `Sources/iOS` and `../../../ios/Sources/Features/Casino`, package dependency `../../../shared/PrismetShared`;
- `PrismetPracticeCasinoMac`, deployment macOS 14, bundle ID `com.gtrktscrb.prismet.practice-casino-preview`, sources from `Sources/macOS` and `../../../macos/Sources/Casino`, package dependency `../../../shared/PrismetShared`.

Each app entry point launches its production `CasinoHubView` with a deterministic preview seed only in DEBUG. No game logic lives in the harness.

Generate with `xcodegen generate`. Build into separate caches:

```zsh
xcodebuild -project PrismetPracticeCasino.xcodeproj -scheme PrismetPracticeCasinoIOS \
  -destination 'platform=iOS Simulator,id=CFA90B6D-5C64-4E5A-8640-3D361140B9B5' \
  -derivedDataPath "$HOME/Library/Caches/PrismetCasino-iPhone" CODE_SIGNING_ALLOWED=NO build

xcodebuild -project PrismetPracticeCasino.xcodeproj -scheme PrismetPracticeCasinoIOS \
  -destination 'platform=iOS Simulator,id=A4B18E67-3CE3-4531-9B54-3B26F36B48BD' \
  -derivedDataPath "$HOME/Library/Caches/PrismetCasino-iPad" CODE_SIGNING_ALLOWED=NO build

xcodebuild -project PrismetPracticeCasino.xcodeproj -scheme PrismetPracticeCasinoMac \
  -destination 'platform=macOS' \
  -derivedDataPath "$HOME/Library/Caches/PrismetCasino-Mac" CODE_SIGNING_ALLOWED=NO build
```

Install and launch both simulator builds with `xcrun simctl install` and `xcrun simctl launch`. Copy the Mac harness app to `~/Applications/Prismet Practice Casino.app`, terminate its bundle if running, and open the freshly copied app.

The launch gate is green only when:

1. iPhone 17 Pro boots, installs, and opens the Blackjack table;
2. iPad Pro 13-inch boots, installs, and opens the regular-width table/sidebar layout;
3. the Mac app installs and opens, accepts keyboard focus, and shows the same deterministic rules state;
4. all three show the no-money disclosure and no automatic next hand;
5. screenshots or direct inspection confirm that the dealer hole card stays concealed during play.

## Task 9 — final Prismet integration after claim release

Do not perform this task while current root/shell claims are active. After release, create a short exact integration claim and add Casino as a first-class top-level destination: Cabinet/Casino tabs on iPhone and iPad; Casino sidebar destination on Mac. Do not make Blackjack a Home card, leaderboard entry, Game Center mode, or online route. Remove the need for the isolated harness only after all three main Prismet apps launch the same production views.

## Completion verification

```zsh
swift test --package-path shared/PrismetShared --scratch-path "$HOME/Library/Caches/PrismetFairPlaySwiftPM"
```

Then run focused and reliable full iOS/macOS tests, iPhone and iPad main-target compile smokes, the macOS no-sign main build, strict parity check, and `git diff --check`. Stage only claimed files and commit shared engine, iOS/iPad UI, macOS UI, harness, and coordination/docs separately.
