import PrismetShared
import XCTest
@testable import Prismet

final class CasinoMobilePresentationTests: XCTestCase {
    func testCatalogExhaustivelyDescribesTwentyOneTablesAcrossFourKinds() {
        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.count, 21)
        XCTAssertEqual(Set(PrismetPracticeCasinoCatalog.all.map(\.id)), Set(PrismetPracticeCasinoGameID.allCases))

        let grouped = Dictionary(grouping: PrismetPracticeCasinoCatalog.all, by: \.kind)
        XCTAssertEqual(grouped[.blackjack]?.count, 1)
        XCTAssertEqual(grouped[.poker]?.count, 1)
        XCTAssertEqual(grouped[.fairChance]?.count, 9)
        XCTAssertEqual(grouped[.studyLab]?.count, 10)
    }

    func testHubRoutesByDescriptorKindWithoutALegacyIDList() {
        let hub = casinoFile("CasinoHubView.swift")

        XCTAssertTrue(hub.contains("switch casinoSession.descriptor.kind"))
        XCTAssertTrue(hub.contains("case .blackjack:"))
        XCTAssertTrue(hub.contains("PracticeBlackjackView(session: session)"))
        XCTAssertTrue(hub.contains("case .poker:"))
        XCTAssertTrue(hub.contains("PracticePokerView(session: casinoSession)"))
        XCTAssertTrue(hub.contains("case .fairChance:"))
        XCTAssertTrue(hub.contains("PracticeChanceGameView(session: casinoSession)"))
        XCTAssertTrue(hub.contains("case .studyLab:"))
        XCTAssertTrue(hub.contains("PracticeStudyLabView(session: casinoSession)"))
        XCTAssertFalse(hub.contains("routeIDs"), "Routing must follow the catalog kind, not a duplicated ID list.")
    }

    func testGateIsHonestAboutSelfAttestationAndDoesNotPersistAccess() {
        let gate = casinoFile("CasinoEntryGateView.swift")

        XCTAssertTrue(gate.contains("Adults 18+ only"))
        XCTAssertTrue(gate.contains("This screen does not verify age"))
        XCTAssertTrue(gate.contains("I'm 18 or older — Enter"))
        XCTAssertTrue(gate.contains("only for this visit"))
        XCTAssertTrue(gate.contains("access decision is not stored"))
        XCTAssertFalse(gate.localizedCaseInsensitiveContains("verified-age access is planned"))
        XCTAssertFalse(gate.localizedCaseInsensitiveContains("you are verified"))
        XCTAssertFalse(gate.contains("@AppStorage"))
        XCTAssertFalse(gate.contains("UserDefaults"))
    }

    func testHubCreatesExperienceHostOnlyAfterThresholdGrantAndReleasesItOnExit() {
        let hub = casinoFile("CasinoHubView.swift")
        let hostRange = try! XCTUnwrap(hub.range(of: "private struct CasinoExperienceHost"))
        let grantRange = try! XCTUnwrap(hub.range(of: "if entryAccessStatus.canEnterCasino"))

        XCTAssertLessThan(grantRange.lowerBound, hostRange.lowerBound)
        XCTAssertTrue(hub.contains("CasinoExperienceHost("))
        XCTAssertTrue(hub.contains("@StateObject private var session: PracticeBlackjackSession"))
        XCTAssertTrue(hub.contains("@StateObject private var casinoSession: PracticeCasinoSession"))
        let preHostSource = hub[..<hostRange.lowerBound]
        XCTAssertFalse(preHostSource.contains("PracticeBlackjackSession"))
        XCTAssertFalse(preHostSource.contains("PracticeCasinoSession"))
        XCTAssertTrue(hub.contains("entryAccessStatus = .threshold"))
        XCTAssertTrue(hub.contains("dismiss()"))
    }

    func testHeaderAndResetCopyNameTheVisitStateAndPreservedBlackjackAudit() {
        let hub = casinoFile("CasinoHubView.swift")

        XCTAssertTrue(hub.contains("18+ practice only · no money or transferable value."))
        XCTAssertTrue(hub.contains("chance-table, Five-Card Draw, and Study Lab visit state"))
        XCTAssertTrue(hub.contains("preserving the Blackjack audit save"))
    }

    func testStudyLabUsesNaturalHeightAdaptiveSnapshotDrivenPresentation() {
        let lab = casinoFile("PracticeStudyLabView.swift")

        XCTAssertFalse(lab.contains("GeometryReader"))
        XCTAssertFalse(lab.contains("ScrollView"))
        XCTAssertTrue(lab.contains("@Environment(\\.horizontalSizeClass)"))
        XCTAssertTrue(lab.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(lab.contains("HStack(alignment: .top, spacing: 16)"))
        XCTAssertTrue(lab.contains("VStack(alignment: .leading, spacing: 16)"))
        XCTAssertTrue(lab.contains("@Environment(\\.accessibilityReduceMotion)"))
        XCTAssertTrue(lab.contains("ForEach(Array(snapshot.summaryRows.enumerated()), id: \\.offset)"))
        XCTAssertTrue(lab.contains("ForEach(Array(snapshot.cards.enumerated()), id: \\.offset)"))
        XCTAssertTrue(lab.contains("PrismetCasinoStudyLabCard"))
        XCTAssertTrue(lab.contains("case .standard"))
        XCTAssertTrue(lab.contains("case .hidden"))
        XCTAssertTrue(lab.contains("case .joker"))
        XCTAssertTrue(lab.contains("accessibilityLabel"))
        XCTAssertTrue(lab.contains("toggleStudyLabPaiGowCard(at:"))
        XCTAssertTrue(lab.contains("selectedPaiGowCardIndices"))
        XCTAssertTrue(lab.contains("index + 1"))
        XCTAssertTrue(lab.contains("snapshot.dice"))
        XCTAssertTrue(lab.contains("snapshot.wheel"))
        XCTAssertTrue(lab.contains("if let primaryAction = snapshot.primaryAction"))
        XCTAssertTrue(lab.contains("Label(primaryAction.title, systemImage: \"play.circle.fill\")"))
        XCTAssertTrue(lab.contains(".disabled(!snapshot.primaryControlEnabled)"))
        XCTAssertTrue(lab.contains("snapshot.secondaryNewRoundTitle"))
        XCTAssertTrue(lab.contains("CasinoTheme.minimumTarget"))
    }

    func testPaiGowSelectionLimitDoesNotAdvertiseUnavailableSelectionAndKeepsSelectedCardsDeselectable() {
        let lab = casinoFile("PracticeStudyLabView.swift")

        XCTAssertTrue(lab.contains("let isSelected = selectedPositions.contains(position)"))
        XCTAssertTrue(lab.contains("let hasReachedSelectionLimit = selectedPositions.count >= 2"))
        XCTAssertTrue(lab.contains(".disabled(hasReachedSelectionLimit && !isSelected)"))
        XCTAssertTrue(lab.contains("isSelected ?"))
        XCTAssertTrue(lab.contains("Double tap to deselect this card from the low hand."))
        XCTAssertTrue(lab.contains("Two-card selection limit reached. Deselect another selected card before selecting this card."))
        XCTAssertFalse(lab.contains("Card position \\(position). Double tap to select or remove it from the two-card low hand."))
    }

    func testStudyLabUsesSharedLedgerDisplayTextAndDistinguishesNewFromReusedSeeds() {
        let lab = casinoFile("PracticeStudyLabView.swift")

        XCTAssertTrue(lab.contains("ForEach(Array(rows.enumerated()), id: \\.offset)"))
        XCTAssertTrue(lab.contains("Text(\"Exact counts & probabilities\")"))
        XCTAssertTrue(lab.contains("row.displayText"))
        XCTAssertFalse(lab.contains("ledgerText("))
        XCTAssertTrue(lab.contains("ForEach(snapshot.audit.seeds"))
        XCTAssertTrue(lab.contains("audit.rulesVersion"))
        XCTAssertTrue(lab.contains("audit.randomizerVersion"))
        XCTAssertTrue(lab.contains("seed.sequence"))
        XCTAssertTrue(lab.contains("seed.action"))
        XCTAssertTrue(lab.contains("seed.seed"))
        XCTAssertTrue(lab.contains("seed.seedUsage"))
        XCTAssertTrue(lab.contains("seed.seedUsage.displayText"))
        XCTAssertFalse(lab.contains("auditSeedUsageText("))
        XCTAssertFalse(lab.contains("auditSeedUsageAccessibilityText("))
    }

    func testCasinoHostPassesPreviewSeedToEveryPracticeSessionWhileLeavingBlackjackWiringIntact() {
        let hub = casinoFile("CasinoHubView.swift")

        XCTAssertTrue(hub.contains("PracticeBlackjackSession(previewSeed: previewSeed)"))
        XCTAssertTrue(hub.contains("PracticeCasinoSession(previewSeed: previewSeed)"))
    }

    func testStudyLabLeavesRulesInspectorToTheHubAndDisplaysGreenZeroWithDarkCasinoThemeContrast() {
        let lab = casinoFile("PracticeStudyLabView.swift")
        let hub = casinoFile("CasinoHubView.swift")

        XCTAssertTrue(hub.contains("private var rulesInspector: some View"))
        XCTAssertTrue(hub.contains("casinoSession.descriptor.rules"))
        XCTAssertTrue(hub.contains("casinoSession.descriptor.fairness"))
        XCTAssertFalse(lab.contains("session.descriptor.rules"))
        XCTAssertFalse(lab.contains("session.descriptor.fairness"))
        XCTAssertTrue(lab.contains("Text(\"Ordered audit\")"))
        XCTAssertTrue(lab.contains("wheel.color.lowercased() == \"green\" ? CasinoTheme.feltTop"))
        XCTAssertFalse(lab.contains("wheel.color.lowercased() == \"green\" ? Color.green"))
    }

    func testCompactAndRegularCasinoPresentationRemainAdaptive() {
        XCTAssertEqual(CasinoMobileLayoutPolicy.layout(isCompactWidth: true, usableWidth: 1_024), .compact)
        XCTAssertEqual(CasinoMobileLayoutPolicy.layout(isCompactWidth: false, usableWidth: 759), .compact)
        XCTAssertEqual(CasinoMobileLayoutPolicy.layout(isCompactWidth: false, usableWidth: 1_200), .regular(sidebarWidth: 340))
        XCTAssertEqual(CasinoTheme.minimumTarget, 44)
    }

    func testLayoutPolicyUsesExactRegularBoundaryAndReadableFloors() {
        XCTAssertEqual(CasinoMobileLayoutPolicy.layout(isCompactWidth: false, usableWidth: 760), .regular(sidebarWidth: 300))
        XCTAssertEqual(CasinoMobileLayoutPolicy.layout(isCompactWidth: false, usableWidth: 1_200), .regular(sidebarWidth: 340))
        XCTAssertGreaterThanOrEqual(CasinoMobileLayoutPolicy.libraryWidth, 180)
        XCTAssertGreaterThanOrEqual(CasinoMobileLayoutPolicy.regularTableMinimumHeight, 480)
        XCTAssertGreaterThanOrEqual(
            CasinoMobileLayoutPolicy.availableTableWidth(usableWidth: 760, sidebarWidth: 300),
            220
        )
    }

    func testBlackjackConcealsDealerCardsAndRespectsAccessibleMotionAndStatusPolicies() {
        let blackjack = casinoFile("PracticeBlackjackView.swift")
        let card = casinoFile("CasinoPlayingCardView.swift")

        XCTAssertTrue(card.contains("guard let card else { return \"Face-down card\" }"))
        XCTAssertTrue(card.contains("card.accessibilityLabel(isFaceUp: true)"))
        XCTAssertTrue(blackjack.contains("hiddenCardCount"))
        XCTAssertTrue(blackjack.contains("dealerSummaryAccessibilityLabel"))
        XCTAssertTrue(blackjack.contains("@Environment(\\.accessibilityReduceMotion)"))
        XCTAssertTrue(blackjack.contains("reduceMotion ? nil : .easeOut(duration: 0.20)"))
        XCTAssertTrue(blackjack.contains("@Environment(\\.accessibilityDifferentiateWithoutColor)"))
        XCTAssertTrue(blackjack.contains("if differentiateWithoutColor"))
        XCTAssertTrue(blackjack.contains("Image(systemName: statusSymbol)"))
    }

    func testBlackjackActionRailSeparatesActiveDecisionsFromTerminalNewHand() {
        let blackjack = casinoFile("PracticeBlackjackView.swift")

        XCTAssertEqual(CasinoMobileActionPolicy.actions(canStartNewHand: false), .decisions)
        XCTAssertEqual(CasinoMobileActionPolicy.actions(canStartNewHand: true), .newHand)
        XCTAssertTrue(blackjack.contains("Button(\"Hit\") { session.hit() }"))
        XCTAssertTrue(blackjack.contains(".disabled(!session.canHit)"))
        XCTAssertTrue(blackjack.contains("Button(\"Stand\") { session.stand() }"))
        XCTAssertTrue(blackjack.contains(".disabled(!session.canStand)"))
        XCTAssertTrue(blackjack.contains("if session.table.canEndHand"))
        XCTAssertTrue(blackjack.contains("Button(\"End Hand\", role: .destructive) { session.endHand() }"))
        XCTAssertTrue(blackjack.contains("Button(\"New Hand\") { session.newHand() }"))
    }

    func testHubHasCompactAndRegularCompositionsWithSafeBlackjackSwitching() {
        let hub = casinoFile("CasinoHubView.swift")

        XCTAssertTrue(hub.contains("case .compact:"))
        XCTAssertTrue(hub.contains("VStack(spacing: 12) { compactGamePicker; compactTableRegion }"))
        XCTAssertTrue(hub.contains("ScrollView(.horizontal, showsIndicators: true)"))
        XCTAssertTrue(hub.contains("if casinoSession.descriptor.kind == .blackjack { tableSurface }"))
        XCTAssertTrue(hub.contains("HStack(alignment: .top, spacing: CasinoMobileLayoutPolicy.hubSpacing)"))
        XCTAssertTrue(hub.contains("ScrollView { casinoLibrary }.frame(width: CasinoMobileLayoutPolicy.libraryWidth)"))
        XCTAssertTrue(hub.contains("ScrollView { rulesInspector }.frame(width: sidebarWidth)"))
        XCTAssertTrue(hub.contains("if casinoSession.selectedGameID == .blackjack { session.endHand() }"))
        XCTAssertTrue(hub.contains("private var isBlackjackSwitchBlocked: Bool { session.loadState != .ready }"))
        XCTAssertTrue(hub.contains(".disabled(isBlackjackSwitchBlocked && game.id != .blackjack)"))
    }

    func testRootKeepsBannerNavigationScopedToHomeOnly() {
        let home = homeSource

        XCTAssertTrue(home.contains("@State private var navigationPath = NavigationPath()"))
        XCTAssertTrue(home.contains("NavigationStack(path: $navigationPath)"))
        XCTAssertTrue(home.contains("if navigationPath.isEmpty && AdConfig.shouldDisplayBanner"))
        XCTAssertTrue(home.contains("BannerAdBar(entitlement: adEntitlement)"))
    }

    func testPokerPresentsFiveCardsHeldStateTerminalAuditAndExactLedger() {
        let poker = casinoFile("PracticePokerView.swift")

        XCTAssertTrue(poker.contains("ForEach(Array(state.cards.enumerated()), id: \\.offset)"))
        XCTAssertTrue(poker.contains("CasinoPlayingCardView(displayedCard: .faceUp(card), maximumWidth: 72)"))
        XCTAssertTrue(poker.contains("Label(\"Held\", systemImage: \"checkmark\")"))
        XCTAssertTrue(poker.contains("if state.phase == .complete"))
        XCTAssertTrue(poker.contains("Seed \\(state.seed) · randomizer v\\(state.randomizerVersion)"))
        XCTAssertTrue(poker.contains("private static let total = 2_598_960"))
        XCTAssertTrue(poker.contains("Exact opening-hand ledger"))
        XCTAssertTrue(poker.contains("1,302,540"))
        XCTAssertTrue(poker.contains("1,098,240"))
        XCTAssertTrue(poker.contains("Royal flush"))
        XCTAssertTrue(poker.contains("Text(row.percentText)"))
    }

    func testFairChanceCoversHigherLowerStagesSelectionCuesAndWheelGeometry() {
        let chance = casinoFile("PracticeChanceGameView.swift")
        let theme = casinoFile("CasinoTheme.swift")

        XCTAssertTrue(chance.contains("PrismetHigherLowerPreview"))
        XCTAssertTrue(chance.contains("Show one card first. Its rank sets the conditional odds before you choose."))
        XCTAssertTrue(chance.contains("Button(\"Show Card\") { session.showHigherLowerCard() }"))
        XCTAssertTrue(chance.contains("Button(\"Reveal Next Card\") { session.revealHigherLower() }"))
        XCTAssertTrue(chance.contains(".disabled(session.selectedChoiceIDs.count != 1)"))
        XCTAssertTrue(chance.contains("Text(choices.count == 1 ? \"Your choice\" : \"Your choices\")"))
        XCTAssertTrue(chance.contains("selected && differentiateWithoutColor ? \"checkmark.circle.fill\""))
        XCTAssertTrue(chance.contains(".accessibilityValue(selected ? \"Selected\" : \"Not selected\")"))
        XCTAssertTrue(chance.contains("CasinoProbabilityRosette(style: .wheel, highlightedSegment: revealedWheelSegment, diameter: 196)"))
        XCTAssertTrue(chance.contains("12 equal segments · 6 ivory · 6 emerald · no zero"))
        XCTAssertTrue(theme.contains("static let segmentCount = 12"))
        XCTAssertTrue(theme.contains("ForEach(0..<Self.segmentCount, id: \\.self)"))
    }

    func testGateProvidesMotionNonColorWheelTargetAndLeaveContracts() {
        let gate = casinoFile("CasinoEntryGateView.swift")

        XCTAssertTrue(gate.contains("@Environment(\\.accessibilityReduceMotion)"))
        XCTAssertTrue(gate.contains(".opacity(reduceMotion ? 0.62 : 0.78)"))
        XCTAssertTrue(gate.contains("@Environment(\\.accessibilityDifferentiateWithoutColor)"))
        XCTAssertTrue(gate.contains("Information: this is a practice-only destination."))
        XCTAssertTrue(gate.contains("CasinoProbabilityRosette(style: .wheel"))
        XCTAssertTrue(gate.contains("minHeight: CasinoTheme.minimumTarget"))
        XCTAssertTrue(gate.contains("Button(action: onLeave)"))
        XCTAssertTrue(gate.contains("Label(\"Not Now\", systemImage: \"xmark.circle\")"))
    }

    func testCasinoHeaderUsesExplicitHighContrastTokens() {
        let hub = casinoFile("CasinoHubView.swift")

        XCTAssertTrue(hub.contains("foregroundStyle(CasinoTheme.headerPrimary)"))
        XCTAssertTrue(hub.contains("foregroundStyle(CasinoTheme.headerSecondary)"))
        XCTAssertTrue(hub.contains("Text(\"18+ practice only · no money or transferable value.\")"))
    }

    private func casinoFile(_ name: String) -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Casino", isDirectory: true)
        return (try? String(contentsOf: root.appendingPathComponent(name))) ?? ""
    }

    private var homeSource: String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Home/HomeView.swift")
        return (try? String(contentsOf: root)) ?? ""
    }
}
