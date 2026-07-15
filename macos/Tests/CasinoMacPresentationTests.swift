import XCTest
import PrismetShared
@testable import Prismet

final class CasinoMacPresentationTests: XCTestCase {
    func testLayoutUsesStackedPresentationBelowTheOrdinaryWidthBreakpoint() {
        XCTAssertEqual(CasinoMacLayoutPolicy.presentation(for: 859), .stacked)
        XCTAssertEqual(CasinoMacLayoutPolicy.presentation(for: 860), .split)
    }

    func testSidebarWidthRemainsUsefulAcrossResizableWindows() {
        XCTAssertEqual(CasinoMacLayoutPolicy.sidebarWidth(for: 860), 230)
        XCTAssertEqual(CasinoMacLayoutPolicy.sidebarWidth(for: 1_040), 260)
        XCTAssertEqual(CasinoMacLayoutPolicy.sidebarWidth(for: 1_400), 280)
    }

    func testActiveHandCommandsExposeHitAndStandOnly() {
        let availability = CasinoMacCommandAvailability(
            canHit: true,
            canStand: true,
            canStartNewHand: false,
            hasReplay: false
        )

        XCTAssertTrue(availability.hit)
        XCTAssertTrue(availability.stand)
        XCTAssertFalse(availability.newHand)
        XCTAssertFalse(availability.replay)
        XCTAssertTrue(availability.leave)
    }

    func testTerminalCommandsRequireAnExplicitNewHandOrReplayAction() {
        let availability = CasinoMacCommandAvailability(
            canHit: false,
            canStand: false,
            canStartNewHand: true,
            hasReplay: true
        )

        XCTAssertFalse(availability.hit)
        XCTAssertFalse(availability.stand)
        XCTAssertTrue(availability.newHand)
        XCTAssertTrue(availability.replay)
        XCTAssertTrue(availability.leave)
    }

    func testCardSpeechNeverLeaksTheFaceDownCard() {
        let faceUp = PrismetBlackjackDisplayedCard.faceUp(
            PrismetPlayingCard(rank: .queen, suit: .hearts)
        )

        XCTAssertEqual(CasinoPlayingCardView.accessibilityLabel(for: faceUp), "Queen of hearts")
        XCTAssertEqual(CasinoPlayingCardView.accessibilityLabel(for: .faceDown), "Face-down card")
    }

    func testFirstHandDisclosureIsExact() {
        XCTAssertEqual(
            CasinoFairPlayCopy.firstHandDisclosure,
            "Practice only. No money, purchases, wagering, prizes, or rewards."
        )
    }

    func testKeyboardHintsDescribeEveryRequiredMacAction() {
        XCTAssertEqual(CasinoMacKeyboardHints.hit, "Return or H")
        XCTAssertEqual(CasinoMacKeyboardHints.stand, "S")
        XCTAssertEqual(CasinoMacKeyboardHints.newHand, "Command-N")
        XCTAssertEqual(CasinoMacKeyboardHints.replay, "Command-R")
        XCTAssertEqual(CasinoMacKeyboardHints.leave, "Escape")
    }

    func testFairPlayLibraryKeepsTheWideSplitBreakpointAndProvidesACompactStrip() {
        XCTAssertEqual(CasinoMacLayoutPolicy.presentation(for: 859), .stacked)
        XCTAssertEqual(CasinoMacLayoutPolicy.presentation(for: 860), .split)
        XCTAssertGreaterThanOrEqual(CasinoTheme.minimumTarget, 44)
    }

    func testFairPlayKeyboardHintsUseOnlyUnambiguousActions() {
        XCTAssertEqual(CasinoMacKeyboardHints.primaryAction, "Return")
        XCTAssertEqual(CasinoMacKeyboardHints.resetSession, "Command-R")
        XCTAssertEqual(CasinoMacKeyboardHints.leaveGame, "Escape")
    }

    func testMacFairPlayUsesAllRoutesThroughTheSharedCatalog() throws {
        let source = try String(contentsOf: casinoSourceRoot.appendingPathComponent("CasinoHubView.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("PrismetPracticeCasinoCatalog.all"))
        XCTAssertTrue(source.contains("PrismetPracticeCasinoCatalog[session.selectedGameID]"))
        XCTAssertTrue(source.contains("blackjackSession.endHand()"))
        XCTAssertTrue(source.contains(".onExitCommand(perform: leave)"))
        XCTAssertTrue(source.contains("isBlackjackSwitchBlocked"))
        XCTAssertTrue(source.contains(".disabled(isBlackjackSwitchBlocked"))
        XCTAssertTrue(source.contains("blackjackSession.loadState == .ready"))
        XCTAssertEqual(Set(PrismetPracticeCasinoCatalog.all.map(\.id)), Set(PrismetPracticeCasinoGameID.allCases))
    }

    func testProductionCasinoUsesFreshRandomSeedsAndBlackjackShowsSharedFairnessCopy() throws {
        let hub = try String(contentsOf: casinoSourceRoot.appendingPathComponent("CasinoHubView.swift"), encoding: .utf8)
        let fairPlay = try String(contentsOf: casinoSourceRoot.appendingPathComponent("CasinoFairPlayView.swift"), encoding: .utf8)

        XCTAssertTrue(hub.contains("if let previewSeed"))
        XCTAssertTrue(hub.contains("PracticeCasinoSession()"))
        XCTAssertFalse(hub.contains("previewSeed ?? 0"))
        XCTAssertTrue(fairPlay.contains("PrismetPracticeCasinoCatalog[.blackjack].fairness"))
    }

    func testMacFairPlayHasNoEmptyChoicePanelAndExposesInspector() throws {
        let source = try String(contentsOf: casinoSourceRoot.appendingPathComponent("PracticeChanceGameView.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("descriptor.choices.isEmpty"))
        XCTAssertTrue(source.contains("Rules & Fairness"))
        XCTAssertTrue(source.contains("Higher or Lower"))
        XCTAssertTrue(source.contains("accessibilityFocusState"))
    }

    func testCompletedChanceAndPokerRoundsKeepALivePrimaryActionAndAuditDetails() throws {
        let chance = try String(contentsOf: casinoSourceRoot.appendingPathComponent("PracticeChanceGameView.swift"), encoding: .utf8)
        let poker = try String(contentsOf: casinoSourceRoot.appendingPathComponent("PracticePokerView.swift"), encoding: .utf8)

        XCTAssertTrue(chance.contains("if session.roundResult != nil"))
        XCTAssertTrue(chance.contains("Button(\"New Round\""))
        XCTAssertTrue(poker.contains("if state.phase == .complete"))
        XCTAssertTrue(poker.contains("Seed \\(state.seed) · randomizer v\\(state.randomizerVersion)"))
        XCTAssertTrue(chance.contains("token.secondary"))
        XCTAssertTrue(chance.contains("token.isSelected"))
        XCTAssertTrue(chance.contains("Your choice"))
        XCTAssertTrue(chance.contains("selectedChoiceIDs"))
    }

    func testPokerPublishesAHighContrastExactProbabilityLedger() throws {
        let poker = try String(contentsOf: casinoSourceRoot.appendingPathComponent("PracticePokerView.swift"), encoding: .utf8)

        XCTAssertTrue(poker.contains("PokerProbabilityLedger"))
        XCTAssertTrue(poker.contains("2_598_960"))
        XCTAssertTrue(poker.contains("percentText"))
        XCTAssertTrue(poker.contains("monospacedDigit"))
        XCTAssertTrue(poker.contains("CasinoTheme.warmIvory"))
    }

    func testTwelvePartRosetteAppearsAsWatermarkAndFairWheelGeometry() throws {
        let theme = try String(contentsOf: casinoSourceRoot.appendingPathComponent("CasinoTheme.swift"), encoding: .utf8)
        let chance = try String(contentsOf: casinoSourceRoot.appendingPathComponent("PracticeChanceGameView.swift"), encoding: .utf8)
        let hub = try String(contentsOf: casinoSourceRoot.appendingPathComponent("CasinoHubView.swift"), encoding: .utf8)

        XCTAssertTrue(theme.contains("struct CasinoProbabilityRosette"))
        XCTAssertTrue(theme.contains("static let segmentCount = 12"))
        XCTAssertTrue(theme.contains("ForEach(0..<Self.segmentCount"))
        XCTAssertTrue(chance.contains("descriptor.id == .fairWheel"))
        XCTAssertTrue(chance.contains("CasinoProbabilityRosette(style: .wheel"))
        XCTAssertTrue(hub.contains("CasinoProbabilityRosette(style: .watermark"))
    }

    func testWideTableCanvasHasPurposefulMinimumHeight() {
        XCTAssertGreaterThanOrEqual(CasinoMacLayoutPolicy.tableCanvasMinimumHeight, 520)
    }

    func testCasinoEntryPolicyOnlyGrantsAnInMemoryVisitDecision() {
        let policy = PlannedCasinoEntryAccessPolicy()

        XCTAssertEqual(policy.initialStatus, .threshold)
        XCTAssertEqual(policy.enterPracticeCasino(), .sessionAccess)
        XCTAssertEqual(policy.initialStatus, .threshold)
    }

    func testMacEntranceUsesTruthfulPlannedVerificationCopyAndNativeExitPaths() throws {
        let gate = try String(
            contentsOf: casinoSourceRoot.appendingPathComponent("CasinoEntryGateView.swift"),
            encoding: .utf8
        )
        let hub = try String(
            contentsOf: casinoSourceRoot.appendingPathComponent("CasinoHubView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(gate.contains("Verified-age access is planned before public release."))
        XCTAssertTrue(gate.contains("18+ practice destination"))
        XCTAssertTrue(gate.contains("Practice only. No money, purchases, wagering, prizes, rewards, or transferable value."))
        XCTAssertTrue(gate.contains("Enter Practice Casino"))
        XCTAssertTrue(gate.contains("Not Now"))
        XCTAssertTrue(gate.contains("CasinoProbabilityRosette"))
        XCTAssertTrue(gate.contains(".keyboardShortcut(.defaultAction)"))
        XCTAssertTrue(gate.contains(".onExitCommand(perform: onNotNow)"))
        XCTAssertTrue(gate.contains("CasinoTheme.minimumTarget"))
        XCTAssertFalse(gate.localizedCaseInsensitiveContains("verified access"))
        XCTAssertFalse(gate.localizedCaseInsensitiveContains("age verified"))
        XCTAssertTrue(hub.contains("@State private var entryStatus"))
        XCTAssertTrue(hub.contains("entryAccessPolicy.enterPracticeCasino()"))
        XCTAssertTrue(hub.contains("case .threshold"))
        XCTAssertTrue(hub.contains("case .sessionAccess"))
    }

    private var casinoSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Casino", isDirectory: true)
    }

    func testPreviewHarnessOwnsCommandNInASingleWindowScene() throws {
        let source = try String(contentsOf: previewHarnessURL)

        XCTAssertTrue(source.contains("Window(\"Prismet Practice Casino\", id:"))
        XCTAssertFalse(source.contains("WindowGroup"))
        XCTAssertTrue(source.contains("CommandGroup(replacing: .newItem)"))
        XCTAssertTrue(source.contains(".disabled(!session.canStartNewHand)"))
    }

    private var previewHarnessURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("tools/PracticeCasinoHarness/Sources/macOS/PracticeCasinoMacApp.swift")
    }
}
