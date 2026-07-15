import XCTest
import PrismetShared
@testable import Prismet

final class CasinoMacPresentationTests: XCTestCase {
    func testLayoutUsesStackedPresentationBelowTheOrdinaryWidthBreakpoint() {
        XCTAssertEqual(CasinoMacLayoutPolicy.presentation(for: 859), .stacked)
        XCTAssertEqual(CasinoMacLayoutPolicy.presentation(for: 860), .split)
        XCTAssertGreaterThanOrEqual(CasinoMacLayoutPolicy.tableCanvasMinimumHeight, 520)
        XCTAssertGreaterThanOrEqual(CasinoTheme.minimumTarget, 44)
    }

    func testSidebarWidthRemainsUsefulAcrossResizableWindows() {
        XCTAssertEqual(CasinoMacLayoutPolicy.sidebarWidth(for: 860), 230)
        XCTAssertEqual(CasinoMacLayoutPolicy.sidebarWidth(for: 1_040), 260)
        XCTAssertEqual(CasinoMacLayoutPolicy.sidebarWidth(for: 1_400), 280)
    }

    func testActiveHandCommandsExposeHitAndStandOnly() {
        let availability = CasinoMacCommandAvailability(canHit: true, canStand: true, canStartNewHand: false, hasReplay: false)
        XCTAssertTrue(availability.hit)
        XCTAssertTrue(availability.stand)
        XCTAssertFalse(availability.newHand)
        XCTAssertFalse(availability.replay)
        XCTAssertTrue(availability.leave)
    }

    func testCompletedHandCommandsExposeNewHandAndReplayOnly() {
        let availability = CasinoMacCommandAvailability(canHit: false, canStand: false, canStartNewHand: true, hasReplay: true)

        XCTAssertFalse(availability.hit)
        XCTAssertFalse(availability.stand)
        XCTAssertTrue(availability.newHand)
        XCTAssertTrue(availability.replay)
        XCTAssertTrue(availability.leave)
    }

    func testFirstHandDisclosureIsExact() {
        XCTAssertEqual(CasinoFairPlayCopy.firstHandDisclosure, "Practice only. No money, purchases, wagering, prizes, or rewards.")
    }

    func testKeyboardHintsDescribeEveryRequiredMacAction() {
        XCTAssertEqual(CasinoMacKeyboardHints.hit, "Return or H")
        XCTAssertEqual(CasinoMacKeyboardHints.stand, "S")
        XCTAssertEqual(CasinoMacKeyboardHints.newHand, "Command-N")
        XCTAssertEqual(CasinoMacKeyboardHints.replay, "Command-R")
        XCTAssertEqual(CasinoMacKeyboardHints.leave, "Escape")
    }

    func testCardSpeechNeverLeaksTheFaceDownCard() {
        let faceUp = PrismetBlackjackDisplayedCard.faceUp(.init(rank: .queen, suit: .hearts))
        XCTAssertEqual(CasinoPlayingCardView.accessibilityLabel(for: faceUp), "Queen of hearts")
        XCTAssertEqual(CasinoPlayingCardView.accessibilityLabel(for: .faceDown), "Face-down card")
    }

    func testAllTwentyOneCatalogTablesHaveAnExplicitFourKindHubRoute() throws {
        let hub = try casinoSource("CasinoHubView.swift")
        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.count, 21)
        XCTAssertEqual(Set(PrismetPracticeCasinoCatalog.all.map(\.kind)), [.blackjack, .poker, .fairChance, .studyLab])
        XCTAssertTrue(hub.contains("switch descriptor.kind"))
        for kind in [".blackjack", ".poker", ".fairChance", ".studyLab"] {
            XCTAssertTrue(hub.contains("case \(kind):"), "Hub must route \(kind) explicitly")
        }
        XCTAssertTrue(hub.contains("PracticeStudyLabView"))
        XCTAssertFalse(hub.contains("default:\n            PracticeChanceGameView"), "Study Labs must never fall through to Fair Chance")
    }

    func testGateIsHonestAndProductionExperienceIsCreatedOnlyAfterEntry() throws {
        let gate = try casinoSource("CasinoEntryGateView.swift")
        let hub = try casinoSource("CasinoHubView.swift")

        for copy in [
            "Adults 18+ only", "This screen does not verify age",
            "I'm 18 or older — Enter", "Casino Practice for this visit",
            "the access decision is not stored",
            "Practice only. No money, purchases, wagering, prizes, rewards, or transferable value.",
        ] {
            XCTAssertTrue(gate.localizedCaseInsensitiveContains(copy), "Missing honest gate copy: \(copy)")
        }
        XCTAssertTrue(gate.contains(".keyboardShortcut(.defaultAction)"))
        XCTAssertTrue(gate.contains(".onExitCommand(perform: onNotNow)"))
        XCTAssertTrue(hub.contains("private struct CasinoExperienceHost"))
        XCTAssertTrue(hub.contains("case .threshold:"))
        XCTAssertTrue(hub.contains("case .sessionAccess:"))
        XCTAssertTrue(hub.contains("CasinoExperienceHost"))
        XCTAssertTrue(hub.contains("entryStatus = .threshold"))
        XCTAssertTrue(hub.contains("init(\n        session: PracticeBlackjackSession"))
    }

    func testProductionUsesFreshRandomnessWhilePreviewUsesAnAdvancingExplicitSeedAndSharedBlackjackFairness() throws {
        let hub = try casinoSource("CasinoHubView.swift")
        let session = try casinoSource("PracticeBlackjackSession.swift")
        let fairness = try casinoSource("CasinoFairPlayView.swift")

        for required in [
            "PracticeBlackjackSession(previewSeed: previewSeed)",
            "PracticeCasinoSession(previewSeed: previewSeed)",
            "previewSeed: UInt64? = nil", "previewSeed ?? seedSource()",
            "private func casinoSystemSeed() -> UInt64", "SystemRandomNumberGenerator()",
            "PrismetBlackjackAuditedSession.start(seed: seed)",
            "CasinoFairPlayCopy.auditPrivacy", "Rules & Fairness",
            "New Hand is always a separate action after the result remains on screen.",
            "Revealed draw order", "State hashes",
        ] {
            XCTAssertTrue(
                hub.contains(required) || session.contains(required) || fairness.contains(required),
                "Production/preview fairness wiring must retain \(required)"
            )
        }
    }

    func testBlackjackPresentationGuardsTableSwitchingEndsTheHandAndRendersTerminalActions() throws {
        let hub = try casinoSource("CasinoHubView.swift")
        let blackjack = try casinoSource("PracticeBlackjackView.swift")

        for required in [
            ".disabled(isBlackjackSwitchBlocked && descriptor.id != .blackjack)",
            "guard gameID != session.selectedGameID else { return }",
            "if session.selectedGameID == .blackjack {", "blackjackSession.endHand()",
            "private var isBlackjackSwitchBlocked", "blackjackSession.loadState != .ready",
        ] {
            XCTAssertTrue(hub.contains(required), "Blackjack switch guard must retain \(required)")
        }
        for required in [
            "if !session.canStartNewHand {", "Label(\"End Hand\"", "session.endHand()",
            "if session.canStartNewHand {", "Label(\"New Hand\"", "session.newHand()",
            "Label(\"Replay\"", "session.showReplay()",
            "The result stays here until you choose New Hand.",
        ] {
            XCTAssertTrue(blackjack.contains(required), "Blackjack terminal presentation must retain \(required)")
        }
    }

    func testChancePresentationRendersTerminalAuditSelectionAndTwelveSegmentWheel() throws {
        let chance = try casinoSource("PracticeChanceGameView.swift")
        let theme = try casinoSource("CasinoTheme.swift")

        for required in [
            "if descriptor.id == .fairWheel {", "fairWheelDiagram",
            "CasinoProbabilityRosette(style: .wheel, highlightedSegment: revealedWheelSegment, diameter: 228)",
            "session.roundResult?.gameID == .fairWheel",
            "Text(\"Seed \\(result.seed) · randomizer v\\(result.randomizerVersion)\")",
            "Label(result.title, systemImage: differentiateWithoutColor ? \"checkmark.seal\" : \"sparkle\")",
            "choiceSummary", "Your choice", "Your choices", "checkmark.circle.fill",
            "Button(\"New Round\"", "Button(\"Leave Game\"", ".onExitCommand(perform: onLeave)",
        ] {
            XCTAssertTrue(chance.contains(required), "Chance presentation must retain \(required)")
        }
        for required in [
            "static let segmentCount = 12", "ForEach(0..<Self.segmentCount, id: \\.self)",
            "Double(index * 30) - 90", "Text(\"\\(index + 1)\")",
            "Fair Wheel with twelve equal numbered segments",
        ] {
            XCTAssertTrue(theme.contains(required), "Fair Wheel geometry must retain \(required)")
        }
    }

    func testPokerPresentationRendersFiveCardHoldsTerminalStateAndExactLedger() throws {
        let poker = try casinoSource("PracticePokerView.swift")

        for required in [
            "Deal five cards, hold any cards, then draw once.", "ForEach(Array(state.cards.enumerated()), id: \\.offset)",
            "session.togglePokerHold(at: index)", "state.heldIndices.contains(index)",
            "Card \\(index + 1), \\(card.accessibilityLabel(isFaceUp: true))",
            "Complete · \\(state.category?.displayName ?? \"Hand classified\")",
            "Button(\"Deal Hand\"", "Button(\"Draw Once\"", "Button(\"New Round\"",
            "PokerProbabilityLedger()", "Exact opening-hand ledger", "2,598,960",
            "PokerProbabilityRow(\"Royal flush\", 4, \"4\")",
            "Text(\"\\(row.countText) / \\(Self.totalText)\")",
        ] {
            XCTAssertTrue(poker.contains(required), "Poker presentation must retain \(required)")
        }
    }

    func testStudyLabPresentationRendersSnapshotGroupsSharedExactLedgerAndTypedAuditHistory() throws {
        let source = try casinoSource("PracticeStudyLabView.swift")
        for required in [
            "studyLabSnapshot", "snapshot.status", "snapshot.summaryRows", "snapshot.cards",
            ".standard", ".hidden", ".joker", "selectedPaiGowCardIndices", "snapshot.dice",
            "snapshot.wheel", "snapshot.ledger", "Exact counts & probabilities", "row.value.displayText", "auditPanel(snapshot.audit)",
            "audit.seeds", "entry.seedUsage.displayText", ".accessibilityLabel(\"Audit", "rulesVersion", "randomizerVersion", "descriptor.rules", "descriptor.fairness",
        ] {
            XCTAssertTrue(source.contains(required), "Study Lab presentation must render \(required)")
        }
    }

    func testStudyLabPresentationPinsKeyboardFocusAndNativeAccessibility() throws {
        let source = try casinoSource("PracticeStudyLabView.swift")
        for required in [
            "@FocusState", "@AccessibilityFocusState", "accessibilityReduceMotion",
            "accessibilityDifferentiateWithoutColor", "session.errorMessage", "Study Lab error:",
            ".keyboardShortcut(.defaultAction)", ".onExitCommand", ".accessibilityLabel",
            "CasinoTheme.minimumTarget",
        ] {
            XCTAssertTrue(source.contains(required), "Missing Study Lab accessibility hook: \(required)")
        }
    }

    func testStudyLabResetConfirmationAndReturnDefaultAreStateAccurate() throws {
        let source = try casinoSource("PracticeStudyLabView.swift")

        for required in [
            "@State private var showingResetConfirmation = false",
            "Button(\"Reset Session\", systemImage: \"trash\") { showingResetConfirmation = true }",
            ".keyboardShortcut(\"r\", modifiers: .command)",
            ".confirmationDialog(\"Reset Session\", isPresented: $showingResetConfirmation)",
            "Button(\"Reset Session\", role: .destructive) { _ = session.resetSession(confirming: true) }",
            "Button(\"Cancel\", role: .cancel)",
            "Adults 18+ only. This clears Chance, Poker, and Study Lab visit state; no money, purchases, wagering, prizes, rewards, or transferable value are involved. Existing Blackjack audit save is preserved.",
            "if let primary = snapshot.primaryAction, primary.enabled",
            "else if snapshot.secondaryNewRoundTitle != nil",
            "Text(\"Return: \\(primary.title) · Escape: leave\")",
            "Text(\"Return: New Round · Escape: leave\")",
            "Text(\"Escape: leave\")",
        ] {
            XCTAssertTrue(source.contains(required), "Study Lab reset/Return contract is missing \(required)")
        }

        XCTAssertEqual(source.components(separatedBy: ".keyboardShortcut(.defaultAction)").count - 1, 2,
                       "Only an enabled primary or an available New Round may claim Return.")
        XCTAssertFalse(source.contains("Return: primary · Escape: leave"),
                       "Study Lab must not advertise a disabled or absent primary action as Return.")
    }

    func testStudyLabPaiGowSelectionKeepsSelectedCardsAvailableForDeselection() throws {
        let source = try casinoSource("PracticeStudyLabView.swift")

        for required in [
            "let canTogglePaiGowCard", "selected || snapshot.selectedPaiGowCardIndices.count < 2",
            ".disabled(!canTogglePaiGowCard)", "checkmark.circle.fill",
            "Activate to deselect it.", "Two cards already selected.",
        ] {
            XCTAssertTrue(source.contains(required), "Pai Gow accessibility interaction is missing \(required)")
        }
    }

    func testStudyLabRendersOnlySelectablePaiGowCardsAsButtons() throws {
        let source = try casinoSource("PracticeStudyLabView.swift")

        for required in [
            "if selectable {", "Button {", "session.togglePaiGowCard(at: position - 1)",
            ".disabled(!canTogglePaiGowCard)", "} else {", "cardFace(card, selected: selected)",
            ".accessibilityAddTraits(.isStaticText)",
        ] {
            XCTAssertTrue(source.contains(required), "Study Lab card rendering must contain \(required)")
        }
    }

    func testStudyLabRendersValueCorrectDieFaces() throws {
        let source = try casinoSource("PracticeStudyLabView.swift")

        XCTAssertTrue(source.contains("DieFace(value: value)"))
        XCTAssertTrue(source.contains("private struct DieFace: View"))
        XCTAssertTrue(source.contains("pipPositions(for: value)"))
        XCTAssertTrue(source.contains("guard (1...6).contains(value)"))
        XCTAssertTrue(source.contains("return switch value {"), "Die-face pip mapping must explicitly return its Set<Int> value")
        XCTAssertTrue(source.contains("ForEach(0..<9, id: \\.self)"))
        XCTAssertTrue(source.contains("pipPositions(for: value).contains(index)"))
    }

    func testStudyLabRendersAnAccessibleThirtySevenPocketEuropeanRouletteWheel() throws {
        let source = try casinoSource("PracticeStudyLabView.swift")

        XCTAssertTrue(source.contains("EuropeanRouletteWheel(wheel: wheel)"))
        XCTAssertTrue(source.contains("private struct EuropeanRouletteWheel: View"))
        XCTAssertTrue(source.contains("static let pocketOrder: [Int]"))
        XCTAssertTrue(source.contains("precondition(Self.pocketOrder.count == 37)"))
        XCTAssertTrue(source.contains("ForEach(Self.pocketOrder.indices, id: \\.self)"))
        XCTAssertTrue(source.contains("pocket == wheel.pocket"))
        XCTAssertTrue(source.contains("accessibilityLabel(\"European roulette wheel with 37 pockets"))
    }

    func testChanceAndPokerRetainFocusedPrimaryAndAuditDetails() throws {
        let chance = try casinoSource("PracticeChanceGameView.swift")
        let poker = try casinoSource("PracticePokerView.swift")
        XCTAssertTrue(chance.contains("Button(\"New Round\""))
        XCTAssertTrue(poker.contains("Button(\"New Round\""))
        XCTAssertTrue(poker.contains("randomizer v\\(state.randomizerVersion)"))
        XCTAssertTrue(chance.contains("accessibilityFocusState"))
        XCTAssertTrue(poker.contains("accessibilityFocusState"))
    }

    private func casinoSource(_ file: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Casino/\(file)"), encoding: .utf8)
    }
}
