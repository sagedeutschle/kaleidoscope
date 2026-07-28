# Prismet Fair Play Casino 11-Table Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver 11 playable, deterministic, permanently no-money practice tables with exact probability disclosures and polished native presentation on iPhone, iPad, and macOS.

**Architecture:** `PrismetShared` owns one catalog, nine compact fair-chance games, and a typed Five-Card Draw engine while the existing audited Blackjack engine remains unchanged. iOS/iPadOS and macOS each own a thin in-memory controller plus adaptive SwiftUI views; every table uses the same shared IDs, observations, rules, and fractions.

**Tech Stack:** Swift 5.9, Foundation, SwiftUI, XCTest, Swift Package Manager, XcodeGen, iOS/iPadOS 17, macOS 14.

## Global Constraints

- Exactly 11 catalog entries: `blackjack`, `five-card-draw`, `red-black`, `higher-lower`, `high-card`, `coin-call`, `dice-duel`, `over-under-seven`, `odd-even`, `fair-wheel`, and `number-draw`.
- No money, purchase, wallet, cash-out, transferable or purchasable value, prize, reward, persistent balance or aggregate result history, account, cloud, Game Center, leaderboard, ad dependency, timer, automatic next round, outcome tuning, or pressure language in Casino production code.
- Blackjack stays on its existing shared engine and is never described as 50/50.
- Compact games and Poker are session-only. Existing Blackjack may retain only its isolated local auditable active-hand state, never a balance or aggregate statistics. A result appears only after an explicit player action; New Round clears the result and waits.
- Random outcomes use `PrismetDeterministicRandom`; exact probabilities use integer numerator/denominator values.
- Every iOS/iPad action target is at least 44 points. macOS supports focus rings, pointer hover, and Escape to leave.
- All new cross-platform model behavior is test-first: verify the intended red failure before production edits.
- Preserve the pre-existing untracked `docs/superpowers/plans/2026-07-14-prismet-practice-blackjack.md` unchanged.
- Do not change version/build numbers, archive, upload, or submit in this pass.

---

## File Structure

### Shared package

- Create `shared/PrismetShared/Sources/PrismetShared/PrismetPracticeCasinoCatalog.swift` for stable IDs, descriptors, choices, and exact rules copy.
- Create `shared/PrismetShared/Sources/PrismetShared/PrismetFairChanceEngine.swift` for fractions, typed requests/results, and all nine compact games.
- Create `shared/PrismetShared/Sources/PrismetShared/PrismetFiveCardPoker.swift` for deal/hold/draw state and hand evaluation.
- Create matching tests `PrismetPracticeCasinoCatalogTests.swift`, `PrismetFairChanceEngineTests.swift`, and `PrismetFiveCardPokerTests.swift`.

### iPhone and iPad

- Modify `ios/Sources/Features/Casino/CasinoHubView.swift` to own adaptive game-library navigation and leave/reset actions.
- Modify `ios/Sources/Features/Casino/CasinoTheme.swift` to add semantic study-room tokens and shared layout policy.
- Create `ios/Sources/Features/Casino/PracticeCasinoSession.swift` as the in-memory controller and injectable seed source.
- Create `ios/Sources/Features/Casino/PracticeChanceGameView.swift` for the nine compact games.
- Create `ios/Sources/Features/Casino/PracticePokerView.swift` for deal/hold/draw.
- Modify `ios/Sources/Features/Home/HomeView.swift` only to suppress the global banner whenever its navigation path is nonempty, keeping ads out of all game play.
- Modify `ios/Tests/CasinoSafetyContractTests.swift`, `CasinoMobilePresentationTests.swift`; create `PracticeCasinoSessionTests.swift`.

### macOS

- Modify `macos/Sources/Casino/CasinoHubView.swift` to own the 11-table sidebar/strip and routing.
- Modify `macos/Sources/Casino/CasinoTheme.swift` to add matching tokens, layout policy, and keyboard hints.
- Create `macos/Sources/Casino/PracticeCasinoSession.swift`, `PracticeChanceGameView.swift`, and `PracticePokerView.swift`.
- Modify `macos/Tests/CasinoSafetyContractTests.swift`, `CasinoMacPresentationTests.swift`; create `PracticeCasinoSessionTests.swift`.

---

### Task 1: Shared Catalog and Probability Fraction

**Files:**
- Create: `shared/PrismetShared/Tests/PrismetSharedTests/PrismetPracticeCasinoCatalogTests.swift`
- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetPracticeCasinoCatalog.swift`

**Interfaces:**
- Consumes: existing `PrismetBlackjackRulesV1.canonicalGameID` and `PrismetDeterministicRandom.algorithmVersion`.
- Produces: `PrismetPracticeCasinoGameID`, `PrismetPracticeGameKind`, `PrismetPracticeSelectionRule`, `PrismetPracticeChoice`, `PrismetPracticeCasinoGameDescriptor`, and `PrismetPracticeCasinoCatalog.all`.

- [ ] **Step 1: Write the catalog tests first**

```swift
import XCTest
@testable import PrismetShared

final class PrismetPracticeCasinoCatalogTests: XCTestCase {
    func testCatalogHasExactlyElevenStableUniqueIDs() {
        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.map(\.id), [
            .blackjack, .fiveCardDraw, .redBlack, .higherLower, .highCard,
            .coinCall, .diceDuel, .overUnderSeven, .oddEven, .fairWheel, .numberDraw,
        ])
        XCTAssertEqual(Set(PrismetPracticeCasinoCatalog.all.map(\.id)).count, 11)
    }

    func testEveryEntryHasRulesFairnessAndAnExplicitAction() {
        for game in PrismetPracticeCasinoCatalog.all {
            XCTAssertFalse(game.rules.isEmpty)
            XCTAssertFalse(game.fairness.isEmpty)
            XCTAssertFalse(game.actionTitle.isEmpty)
            XCTAssertGreaterThan(game.rulesVersion, 0)
        }
    }

    func testSelectionRulesMatchTheElevenTableContract() {
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.redBlack].selectionRule, .exactly(1))
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.diceDuel].selectionRule, .none)
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.numberDraw].selectionRule, .exactly(3))
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.fiveCardDraw].kind, .poker)
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.blackjack].kind, .blackjack)
    }
}
```

- [ ] **Step 2: Run the focused test and verify the intended red failure**

Run:

```bash
cd shared/PrismetShared
swift test --scratch-path /Users/gtrktscrb/Library/Caches/PrismetCasinoCatalog --filter PrismetPracticeCasinoCatalogTests
```

Expected: compilation fails because the catalog types do not exist.

- [ ] **Step 3: Implement the exact public catalog contract**

```swift
public enum PrismetPracticeCasinoGameID: String, CaseIterable, Codable, Hashable, Sendable {
    case blackjack = "blackjack"
    case fiveCardDraw = "five-card-draw"
    case redBlack = "red-black"
    case higherLower = "higher-lower"
    case highCard = "high-card"
    case coinCall = "coin-call"
    case diceDuel = "dice-duel"
    case overUnderSeven = "over-under-seven"
    case oddEven = "odd-even"
    case fairWheel = "fair-wheel"
    case numberDraw = "number-draw"
}

public enum PrismetPracticeGameKind: String, Codable, Hashable, Sendable {
    case blackjack, poker, fairChance
}

public enum PrismetPracticeSelectionRule: Codable, Hashable, Sendable {
    case none
    case exactly(Int)
}

public struct PrismetPracticeChoice: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
}

public struct PrismetPracticeCasinoGameDescriptor: Identifiable, Codable, Hashable, Sendable {
    public let id: PrismetPracticeCasinoGameID
    public let title: String
    public let subtitle: String
    public let symbol: String
    public let kind: PrismetPracticeGameKind
    public let selectionRule: PrismetPracticeSelectionRule
    public let choices: [PrismetPracticeChoice]
    public let rulesVersion: Int
    public let rules: String
    public let fairness: String
    public let actionTitle: String
}
```

Populate `PrismetPracticeCasinoCatalog.all` in the exact order and with the rules/fractions in the design spec. Implement a nonoptional subscript that preconditions only for an internal catalog construction error, since every public ID is required to exist.

- [ ] **Step 4: Run focused and full package tests**

Run the focused command again, then:

```bash
swift test --scratch-path /Users/gtrktscrb/Library/Caches/PrismetCasinoCatalog
```

Expected: all tests pass.

- [ ] **Step 5: Commit the catalog slice**

```bash
git add shared/PrismetShared/Sources/PrismetShared/PrismetPracticeCasinoCatalog.swift shared/PrismetShared/Tests/PrismetSharedTests/PrismetPracticeCasinoCatalogTests.swift
git commit -m "feat: add fair play casino catalog"
```

### Task 2: Nine Compact Fair-Chance Games

**Files:**
- Create: `shared/PrismetShared/Tests/PrismetSharedTests/PrismetFairChanceEngineTests.swift`
- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetFairChanceEngine.swift`

**Interfaces:**
- Consumes: `PrismetPracticeCasinoGameID`, `PrismetPracticeCasinoCatalog`, `PrismetPlayingCard`, `PrismetDeckFactory.standard52()`, and `PrismetDeterministicRandom`.
- Produces: `PrismetProbabilityFraction`, `PrismetPracticeRoundRequest`, `PrismetPracticeRevealToken`, `PrismetPracticeProbabilityLine`, `PrismetPracticeRoundResult`, `PrismetFairChanceEngineError`, and `PrismetFairChanceEngine.play(_:seed:)`.

- [ ] **Step 1: Write red tests for exact math, deterministic replay, and validation**

Tests must assert these exact invariants:

```swift
XCTAssertEqual(try PrismetProbabilityFraction(26, 52), try PrismetProbabilityFraction(1, 2))
XCTAssertEqual(try PrismetProbabilityFraction(15, 36), try PrismetProbabilityFraction(5, 12))
XCTAssertEqual(try PrismetProbabilityFraction(84, 220), try PrismetProbabilityFraction(21, 55))

let request = PrismetPracticeRoundRequest(gameID: .coinCall, choiceIDs: ["heads"])
XCTAssertEqual(
    try PrismetFairChanceEngine.play(request, seed: 42),
    try PrismetFairChanceEngine.play(request, seed: 42)
)

XCTAssertThrowsError(
    try PrismetFairChanceEngine.play(
        PrismetPracticeRoundRequest(gameID: .numberDraw, choiceIDs: ["1", "1", "2"]),
        seed: 7
    )
)
```

Add one fixture for each compact game. Assert Red/Black 1/2; Higher/Lower equal rank 1/17 and exact conditional above/below counts; High Card 8/17, 8/17, 1/17; Coin 1/2; Dice Duel 5/12, 5/12, 1/6; Over/Under 5/12, 5/12, 1/6; Odd/Even 1/2; Fair Wheel color 1/2 and segment 1/12; Number Draw 21/55, 27/55, 27/220, 1/220. Enumerate every possible die/wheel outcome and prove the counts, not only sampled seeds.

- [ ] **Step 2: Run the focused test and verify red**

```bash
cd shared/PrismetShared
swift test --scratch-path /Users/gtrktscrb/Library/Caches/PrismetCasinoChance --filter PrismetFairChanceEngineTests
```

Expected: compilation fails because the fair-chance engine types do not exist.

- [ ] **Step 3: Implement the exact request/result contract**

```swift
public struct PrismetProbabilityFraction: Codable, Hashable, Sendable {
    public let numerator: Int
    public let denominator: Int
    public init(_ numerator: Int, _ denominator: Int) throws
    public var percentText: String { get }
}

public struct PrismetPracticeRoundRequest: Codable, Hashable, Sendable {
    public let gameID: PrismetPracticeCasinoGameID
    public let choiceIDs: [String]
}

public struct PrismetHigherLowerPreview: Codable, Hashable, Sendable {
    public let seed: UInt64
    public let randomizerVersion: Int
    public let shownCard: PrismetPracticeRevealToken
    public let probabilities: [PrismetPracticeProbabilityLine]
}

public struct PrismetPracticeRevealToken: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let primary: String
    public let secondary: String?
    public let symbol: String
    public let isSelected: Bool
}

public struct PrismetPracticeProbabilityLine: Codable, Hashable, Sendable {
    public let label: String
    public let fraction: PrismetProbabilityFraction
}

public struct PrismetPracticeRoundResult: Codable, Hashable, Sendable {
    public let gameID: PrismetPracticeCasinoGameID
    public let seed: UInt64
    public let randomizerVersion: Int
    public let title: String
    public let detail: String
    public let tokens: [PrismetPracticeRevealToken]
    public let probabilities: [PrismetPracticeProbabilityLine]
}

public enum PrismetFairChanceEngine {
    public static func previewHigherLower(
        seed: UInt64
    ) throws -> PrismetHigherLowerPreview

    public static func play(
        _ request: PrismetPracticeRoundRequest,
        seed: UInt64
    ) throws -> PrismetPracticeRoundResult
}
```

Use rejection-sampled bounded draws for coin/dice/wheel; Fisher-Yates for card and number draws. Validate choices before creating the RNG. Higher or Lower preview and terminal play must reuse the same seed so the first card is stable and the second is drawn without replacement. Use one private function per game so each function has one outcome space and one exact-fraction table.

- [ ] **Step 4: Run focused and full shared suites**

Expected: the focused tests and all package tests pass with no duplicate-card or invalid-selection failures.

- [ ] **Step 5: Commit the compact engine slice**

```bash
git add shared/PrismetShared/Sources/PrismetShared/PrismetFairChanceEngine.swift shared/PrismetShared/Tests/PrismetSharedTests/PrismetFairChanceEngineTests.swift
git commit -m "feat: add nine fair chance practice games"
```

### Task 3: Five-Card Draw Engine

**Files:**
- Create: `shared/PrismetShared/Tests/PrismetSharedTests/PrismetFiveCardPokerTests.swift`
- Create: `shared/PrismetShared/Sources/PrismetShared/PrismetFiveCardPoker.swift`

**Interfaces:**
- Consumes: `PrismetPlayingCard`, `PrismetDeckFactory.standard52()`, and `PrismetDeterministicRandom`.
- Produces: `PrismetPokerCategory`, `PrismetFiveCardPokerPhase`, `PrismetFiveCardPokerState`, and `PrismetFiveCardPokerEngine`.

- [ ] **Step 1: Write category and state-transition tests first**

Use fixed five-card arrays to assert royal flush, ace-low straight, straight flush, four of a kind, full house, flush, straight, three of a kind, two pair, pair, and high card. Add deterministic state tests:

```swift
let initial = try PrismetFiveCardPokerEngine.deal(seed: 91)
XCTAssertEqual(initial, try PrismetFiveCardPokerEngine.deal(seed: 91))
XCTAssertEqual(initial.cards.count, 5)
XCTAssertEqual(Set(initial.cards).count, 5)

let held = try PrismetFiveCardPokerEngine.togglingHold(at: 0, in: initial)
let final = try PrismetFiveCardPokerEngine.drawing(held)
XCTAssertEqual(final.cards[0], initial.cards[0])
XCTAssertEqual(Set(final.cards).count, 5)
XCTAssertEqual(final.phase, .complete)
XCTAssertThrowsError(try PrismetFiveCardPokerEngine.drawing(final))
```

- [ ] **Step 2: Run the focused test and verify red**

```bash
cd shared/PrismetShared
swift test --scratch-path /Users/gtrktscrb/Library/Caches/PrismetCasinoPoker --filter PrismetFiveCardPokerTests
```

Expected: compilation fails because Poker symbols do not exist.

- [ ] **Step 3: Implement the typed Poker state**

```swift
public enum PrismetPokerCategory: Int, CaseIterable, Codable, Comparable, Hashable, Sendable {
    case highCard, onePair, twoPair, threeOfAKind, straight, flush, fullHouse, fourOfAKind, straightFlush, royalFlush
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum PrismetFiveCardPokerPhase: String, Codable, Hashable, Sendable {
    case choosingHolds, complete
}

public struct PrismetFiveCardPokerState: Codable, Hashable, Sendable {
    public let seed: UInt64
    public let randomizerVersion: Int
    public let cards: [PrismetPlayingCard]
    public let heldIndices: Set<Int>
    public let phase: PrismetFiveCardPokerPhase
    public let category: PrismetPokerCategory?
}

public enum PrismetFiveCardPokerEngine {
    public static func deal(seed: UInt64) throws -> PrismetFiveCardPokerState
    public static func togglingHold(at index: Int, in state: PrismetFiveCardPokerState) throws -> PrismetFiveCardPokerState
    public static func drawing(_ state: PrismetFiveCardPokerState) throws -> PrismetFiveCardPokerState
    public static func evaluate(_ cards: [PrismetPlayingCard]) throws -> PrismetPokerCategory
}
```

Keep the shuffled deck and draw cursor as private codable state so Draw uses the exact unused cards. Evaluate straights with unique ranks and the ace-low set `[2, 3, 4, 5, 14]`. Do not add an opponent, score, payout table, or persistent statistics.

Publish the standard straight-flush family total as 40 while exposing mutually exclusive display counts of 36 non-royal straight flushes and 4 royal-flush subtypes. Their sum must remain 40; never publish 40 plus 4.

- [ ] **Step 4: Run focused and full package tests**

Expected: every category fixture, hold transition, invalid action, deterministic deal, and full package test passes.

- [ ] **Step 5: Commit the Poker engine slice**

```bash
git add shared/PrismetShared/Sources/PrismetShared/PrismetFiveCardPoker.swift shared/PrismetShared/Tests/PrismetSharedTests/PrismetFiveCardPokerTests.swift
git commit -m "feat: add five card draw practice engine"
```

### Task 4: iPhone and iPad Casino Library

The mobile hub must begin behind a session-only `CasinoEntryGateView` that visually separates Casino from the main catalog, states the 18+ destination and permanent no-money terms, and exposes a replaceable future verified-age access seam without persisting or collecting age data in this pass.

**Files:**
- Create: `ios/Tests/PracticeCasinoSessionTests.swift`
- Modify: `ios/Tests/CasinoSafetyContractTests.swift`
- Modify: `ios/Tests/CasinoMobilePresentationTests.swift`
- Create: `ios/Sources/Features/Casino/PracticeCasinoSession.swift`
- Create: `ios/Sources/Features/Casino/PracticeChanceGameView.swift`
- Create: `ios/Sources/Features/Casino/PracticePokerView.swift`
- Modify: `ios/Sources/Features/Casino/CasinoHubView.swift`
- Modify: `ios/Sources/Features/Casino/CasinoTheme.swift`
- Modify: `ios/Sources/Features/Home/HomeView.swift`

**Interfaces:**
- Consumes: the Task 1–3 shared APIs and existing `PracticeBlackjackSession` / `PracticeBlackjackView`.
- Produces: an 11-route `PracticeCasinoSession`, adaptive mobile hub, compact-game view, Poker view, and no-banner navigation policy.

- [ ] **Step 1: Extend tests before production edits**

Add deterministic controller tests for selecting all 11 games, explicit play, explicit new round, Poker deal/hold/draw, reset, and switching tables. Add source/policy tests that require `Leave Game`, `Reset Session`, all shared IDs, `.frame(minHeight: CasinoTheme.minimumTarget)`, compact/regular branches, Reduce Motion, Differentiate Without Color, and `navigationPath.isEmpty` around `BannerAdBar`.

```swift
@MainActor
func testEveryCatalogGameCanBeSelectedWithoutStartingARound() {
    let session = PracticeCasinoSession(seedSource: { 7 })
    for game in PrismetPracticeCasinoCatalog.all {
        session.select(game.id)
        XCTAssertEqual(session.selectedGameID, game.id)
        XCTAssertNil(session.roundResult)
        XCTAssertNil(session.pokerState)
    }
}

@MainActor
func testCompactRoundRequiresExplicitPlayAndNewRoundDoesNotAutoplay() {
    let session = PracticeCasinoSession(seedSource: { 42 })
    session.select(.coinCall)
    session.toggleChoice("heads")
    XCTAssertNil(session.roundResult)
    session.playRound()
    XCTAssertEqual(session.roundResult?.seed, 42)
    XCTAssertEqual(session.completedRoundCount, 1)
    session.newRound()
    XCTAssertNil(session.roundResult)
    XCTAssertEqual(session.completedRoundCount, 1)
}

@MainActor
func testPokerHoldDrawAndResetStaySessionOnly() {
    let session = PracticeCasinoSession(seedSource: { 91 })
    session.select(.fiveCardDraw)
    session.dealPoker()
    let opening = try XCTUnwrap(session.pokerState)
    session.togglePokerHold(at: 0)
    session.drawPoker()
    XCTAssertEqual(session.pokerState?.cards[0], opening.cards[0])
    XCTAssertEqual(session.completedRoundCount, 1)
    session.resetSession()
    XCTAssertNil(session.pokerState)
    XCTAssertEqual(session.completedRoundCount, 0)
}
```

Run:

```bash
cd ios
xcodegen generate
xcodebuild test -project Prismet.xcodeproj -scheme Prismet -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /Users/gtrktscrb/Library/Caches/PrismetCasinoIOSRed -only-testing:PrismetTests/PracticeCasinoSessionTests -only-testing:PrismetTests/CasinoSafetyContractTests -only-testing:PrismetTests/CasinoMobilePresentationTests
```

Expected: tests fail because the session/routes/views and banner path guard are absent.

- [ ] **Step 2: Implement the in-memory mobile controller**

```swift
@MainActor
final class PracticeCasinoSession: ObservableObject {
    @Published var selectedGameID: PrismetPracticeCasinoGameID = .blackjack
    @Published var selectedChoiceIDs: Set<String> = []
    @Published private(set) var roundResult: PrismetPracticeRoundResult?
    @Published private(set) var pokerState: PrismetFiveCardPokerState?
    @Published private(set) var completedRoundCount = 0
    @Published private(set) var errorMessage: String?

    init(seedSource: @escaping () -> UInt64 = PracticeCasinoSession.secureSeed)
    func select(_ gameID: PrismetPracticeCasinoGameID)
    func toggleChoice(_ choiceID: String)
    func playRound()
    func newRound()
    func dealPoker()
    func togglePokerHold(at index: Int)
    func drawPoker()
    func resetSession()
}
```

Inject a `() -> UInt64` seed closure in the initializer. Validate selection count from the catalog before calling the engine. Increment the completed count once per terminal compact round or Poker draw. Never persist it.

- [ ] **Step 3: Implement the mobile views and visual tokens**

`CasinoHubView` owns both `PracticeBlackjackSession` and `PracticeCasinoSession`, a Dismiss action, a compact horizontal library, and regular three-column layout. Route Blackjack to the existing view, Poker to `PracticePokerView`, and all other IDs to `PracticeChanceGameView`. Add the exact emerald/ivory/brass colors from the design. Selected choices/cards use outline plus checkmark/text. Probability values use monospaced digits. Every randomizing action is explicit.

Change `HomeView` to `@State private var navigationPath = NavigationPath()`, bind it with `NavigationStack(path:)`, and render `BannerAdBar` only when `navigationPath.isEmpty` and the existing entitlement/readiness condition is true.

- [ ] **Step 4: Run focused tests, iPhone build, and iPad build**

Run the focused tests again, then build for iPhone 17 Pro and an available iPad simulator using separate derived-data directories under `/Users/gtrktscrb/Library/Caches`. Expected: tests and both builds succeed.

- [ ] **Step 5: Commit the mobile slice**

Stage only the files listed in Task 4 and commit:

```bash
git commit -m "feat: add fair play casino library on iPhone and iPad"
```

### Task 5: macOS Casino Library

The macOS hub mirrors the session-only `CasinoEntryGateView`, exact access copy, and replaceable future verified-age seam. Return/Escape work as Enter/Not Now, and no durable acceptance or identity data is stored.

**Files:**
- Create: `macos/Tests/PracticeCasinoSessionTests.swift`
- Modify: `macos/Tests/CasinoSafetyContractTests.swift`
- Modify: `macos/Tests/CasinoMacPresentationTests.swift`
- Create: `macos/Sources/Casino/PracticeCasinoSession.swift`
- Create: `macos/Sources/Casino/PracticeChanceGameView.swift`
- Create: `macos/Sources/Casino/PracticePokerView.swift`
- Modify: `macos/Sources/Casino/CasinoHubView.swift`
- Modify: `macos/Sources/Casino/CasinoTheme.swift`

**Interfaces:**
- Consumes: the same shared APIs and existing Mac Blackjack types.
- Produces: the same 11 routes in a native stacked/split Mac surface with keyboard focus.

- [ ] **Step 1: Extend Mac tests before production edits**

Repeat the deterministic controller invariants on the Mac target. Require all 11 routes, 860-point stacked/split policy, scrollable game library, visible Leave/Reset, Escape leave behavior, focus ring, Reduce Motion, Differentiate Without Color, and no timer/automatic continuation.

```swift
@MainActor
func testMacSessionRoutesEverySharedCatalogEntry() {
    let session = PracticeCasinoSession(seedSource: { 12 })
    for descriptor in PrismetPracticeCasinoCatalog.all {
        session.select(descriptor.id)
        XCTAssertEqual(session.selectedGameID, descriptor.id)
        XCTAssertNil(session.roundResult)
    }
}

@MainActor
func testMacNewRoundAndResetNeverCreateAnOutcome() {
    let session = PracticeCasinoSession(seedSource: { 12 })
    session.select(.oddEven)
    session.toggleChoice("odd")
    session.playRound()
    XCTAssertNotNil(session.roundResult)
    session.newRound()
    XCTAssertNil(session.roundResult)
    session.resetSession()
    XCTAssertNil(session.roundResult)
    XCTAssertEqual(session.completedRoundCount, 0)
}
```

Run the focused tests and verify they fail for absent routes/types.

- [ ] **Step 2: Implement the Mac controller and native views**

Use the same `PracticeCasinoSession` public behavior as iOS. The hub's wide layout is sidebar plus table; the narrow layout is a horizontal library above the table. Add keyboard shortcuts only where unambiguous: Return for the focused primary action, Command-R for Reset Session after confirmation, and Escape for Leave Game. Hover changes border/fill only.

- [ ] **Step 3: Run focused tests and a no-sign Mac build**

```bash
cd macos
xcodegen generate
xcodebuild test -project Prismet.xcodeproj -scheme Prismet -destination 'platform=macOS' -derivedDataPath /Users/gtrktscrb/Library/Caches/PrismetCasinoMacTests -only-testing:PrismetTests/PracticeCasinoSessionTests -only-testing:PrismetTests/CasinoSafetyContractTests -only-testing:PrismetTests/CasinoMacPresentationTests
xcodebuild build -project Prismet.xcodeproj -scheme Prismet -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /Users/gtrktscrb/Library/Caches/PrismetCasinoMacBuild
```

If the hosted test target fails before source tests because of the known test-bundle signing/profile issue, record that exact packaging failure and run the shared package tests plus the no-sign app build; do not describe the hosted suite as passing.

- [ ] **Step 4: Commit the Mac slice**

Stage only the files listed in Task 5 and commit:

```bash
git commit -m "feat: add fair play casino library on macOS"
```

### Task 6: Cross-Platform Integration, Visual QA, and Launch

**Files:**
- Modify: `docs/AGENT-COORDINATION.md`
- Modify: `ios/docs/MAC-IOS-GAME-PARITY.md` only if the strict parity script requires a new tracked row.

**Interfaces:**
- Consumes: all completed Task 1–5 slices.
- Produces: verified iPhone, iPad, and macOS builds/launches plus an exact PRISM release record.

- [ ] **Step 1: Run repository and safety checks**

```bash
git diff --check
./scripts/check-mac-ios-parity.sh --strict
rg -n -i 'StoreKit|GameCenter|Leaderboard|BannerAd|Timer\.publish|scheduledTimer|autoplay|near[- ]miss|loss recovery|cash.?out|wallet|bankroll|jackpot|refill|streak' ios/Sources/Features/Casino macos/Sources/Casino shared/PrismetShared/Sources/PrismetShared/PrismetPracticeCasinoCatalog.swift shared/PrismetShared/Sources/PrismetShared/PrismetFairChanceEngine.swift shared/PrismetShared/Sources/PrismetShared/PrismetFiveCardPoker.swift
```

Expected: no prohibited dependency or pressure-loop match in production Casino code. User-facing safety disclosure terms are reviewed separately rather than hidden by the scan.

- [ ] **Step 2: Run the full shared package suite and focused platform suites**

Use fresh cache directories. Read test counts and failures from the final output before recording any green claim.

- [ ] **Step 3: Build, install, and launch iPhone and iPad**

Regenerate the iOS project, build the freshest app for one available iPhone and one available iPad simulator, install it, and launch `com.spocksclub.kaleidoscope`. Navigate to Casino and inspect Blackjack, Five-Card Draw, and at least one compact game. Confirm the banner is absent while the table is visible.

- [ ] **Step 4: Build, install, and launch macOS**

Run `CONFIG=Debug ./scripts/deploy-mac.sh`. Confirm the resulting process path is `/Users/gtrktscrb/Applications/Prismet.app/Contents/MacOS/Prismet`. Inspect wide and narrow Casino layouts, Poker hold selection, one compact result, Reset, and Leave.

- [ ] **Step 5: Record evidence and commit integration**

Update the active PRISM entry to RELEASED LOCALLY with exact commands, test counts, build outcomes, simulator/device identifiers, installed app path, visual observations, Legion run IDs, and any unresolved blocker. Commit only owned documentation and any required parity-ledger row.

- [ ] **Step 6: Push the branch**

```bash
git push origin HEAD:codex/prismet-shared-parity-foundation
```

Verify the remote ref resolves to the local final commit. Do not archive, upload, or submit a build.
