import XCTest
@testable import Prismet

final class CasinoMobilePresentationTests: XCTestCase {
    func testCompactWidthAlwaysUsesVerticalTableAndActionRail() {
        XCTAssertEqual(
            CasinoMobileLayoutPolicy.layout(isCompactWidth: true, usableWidth: 1_024),
            .compact
        )
    }

    func testUsableWidthBelow760UsesCompactLayoutEvenInRegularSizeClass() {
        XCTAssertEqual(
            CasinoMobileLayoutPolicy.layout(isCompactWidth: false, usableWidth: 759),
            .compact
        )
    }

    func testRegularWidthUsesClampedRulesSidebar() {
        XCTAssertEqual(
            CasinoMobileLayoutPolicy.layout(isCompactWidth: false, usableWidth: 760),
            .regular(sidebarWidth: 300)
        )
        XCTAssertEqual(
            CasinoMobileLayoutPolicy.layout(isCompactWidth: false, usableWidth: 1_200),
            .regular(sidebarWidth: 340)
        )
        XCTAssertGreaterThanOrEqual(
            CasinoMobileLayoutPolicy.availableTableWidth(usableWidth: 760, sidebarWidth: 300),
            220
        )
    }

    func testEveryCasinoActionUsesAtLeastA44PointTarget() {
        XCTAssertEqual(CasinoTheme.minimumTarget, 44)
        XCTAssertTrue(casinoSource.contains(".frame(minHeight: CasinoTheme.minimumTarget)"))
    }

    func testCompactAndRegularPresentationContractsArePresent() {
        XCTAssertTrue(casinoSource.contains("case .compact"))
        XCTAssertTrue(casinoSource.contains("case .regular(let sidebarWidth)"))
        XCTAssertFalse(casinoSource.contains("usableWidth: 0"))
        XCTAssertFalse(casinoSource.contains(".frame(height:"), "Casino text and cards must reflow without fixed heights")
    }

    func testCardsAndDealerSummaryHaveConcealedInformationSemantics() {
        XCTAssertTrue(casinoSource.contains(#"card.accessibilityLabel(isFaceUp: true)"#))
        XCTAssertTrue(casinoSource.contains(#""Face-down card""#))
        XCTAssertTrue(casinoSource.contains("hiddenCardCount"))
        XCTAssertTrue(casinoSource.contains("dealerSummaryAccessibilityLabel"))
    }

    func testReduceMotionRemovesTableTravelWithoutRemovingStateChanges() {
        XCTAssertTrue(casinoSource.contains("@Environment(\\.accessibilityReduceMotion)"))
        XCTAssertTrue(casinoSource.contains("reduceMotion ? nil"))
        XCTAssertFalse(casinoSource.contains("rotation3DEffect"))
    }

    func testDifferentiateWithoutColorAddsANonColorStatusCue() {
        XCTAssertTrue(casinoSource.contains("@Environment(\\.accessibilityDifferentiateWithoutColor)"))
        XCTAssertTrue(casinoSource.contains("if differentiateWithoutColor"))
        XCTAssertTrue(casinoSource.contains("statusSymbol"))
    }

    func testCompletedHandUsesAFocusedActionSet() {
        XCTAssertEqual(CasinoMobileActionPolicy.actions(canStartNewHand: false), .decisions)
        XCTAssertEqual(CasinoMobileActionPolicy.actions(canStartNewHand: true), .newHand)
    }

    func testCasinoRoutesEverySharedTableAndKeepsBannerOnHomeOnly() {
        for id in [
            "blackjack", "five-card-draw", "red-black", "higher-lower", "high-card",
            "coin-call", "dice-duel", "over-under-seven", "odd-even", "fair-wheel", "number-draw",
        ] {
            XCTAssertTrue(casinoSource.contains(id), "Missing mobile route for \(id)")
        }
        let home = homeSource
        XCTAssertTrue(home.contains("@State private var navigationPath = NavigationPath()"))
        XCTAssertTrue(home.contains("NavigationStack(path: $navigationPath)"))
        XCTAssertTrue(home.contains("navigationPath.isEmpty"))
        let hub = casinoFile(named: "CasinoHubView.swift")
        XCTAssertTrue(hub.contains("session.endHand()"))
        XCTAssertTrue(hub.contains("isBlackjackSwitchBlocked"))
        XCTAssertTrue(hub.contains(".disabled(isBlackjackSwitchBlocked"))
        XCTAssertTrue(hub.contains("session.loadState == .ready"))
    }

    func testRegularLayoutContainsLibraryTableAndRulesInspector() {
        XCTAssertTrue(casinoSource.contains("casinoLibrary"))
        XCTAssertTrue(casinoSource.contains("tableSurface"))
        XCTAssertTrue(casinoSource.contains("rulesInspector"))
        XCTAssertTrue(casinoSource.contains("GeometryReader"))
    }

    func testCompactHubKeepsBlackjackOutOfAParentScrollAndUsesAHorizontalPicker() {
        let hub = casinoFile(named: "CasinoHubView.swift")

        XCTAssertTrue(hub.contains("compactGamePicker"))
        XCTAssertTrue(hub.contains("ScrollView(.horizontal"))
        XCTAssertTrue(hub.contains("compactTableRegion"))
        XCTAssertTrue(hub.contains("PracticeBlackjackView(session: session)"))
        XCTAssertFalse(hub.contains("case .compact:\n                            casinoLibrary"))
    }

    func testSafetyExitMeetsTargetSizeAndPanelCopyUsesDynamicContrast() {
        let hub = casinoFile(named: "CasinoHubView.swift")

        XCTAssertTrue(hub.contains(".frame(minHeight: CasinoTheme.minimumTarget)"))
        XCTAssertTrue(hub.contains("Text(\"Rules & Fairness\").font(.headline).foregroundStyle(.primary)"))
        XCTAssertTrue(hub.contains("foregroundStyle(.secondary)"))
    }

    func testHigherLowerPresentationNamesTypedPreviewAndExplicitStages() {
        XCTAssertTrue(casinoSource.contains("PrismetHigherLowerPreview"))
        XCTAssertTrue(casinoSource.contains("Show Card"))
        XCTAssertTrue(casinoSource.contains("Reveal Next Card"))
        XCTAssertTrue(casinoSource.contains("conditional odds"))
    }

    func testPokerPresentationPublishesEveryMutuallyExclusiveCount() {
        XCTAssertTrue(casinoSource.contains("1,302,540"))
        XCTAssertTrue(casinoSource.contains("1,098,240"))
        XCTAssertTrue(casinoSource.contains("123,552"))
        XCTAssertTrue(casinoSource.contains("54,912"))
        XCTAssertTrue(casinoSource.contains("10,200"))
        XCTAssertTrue(casinoSource.contains("5,108"))
        XCTAssertTrue(casinoSource.contains("3,744"))
        XCTAssertTrue(casinoSource.contains("624"))
        XCTAssertTrue(casinoSource.contains("36"))
        XCTAssertTrue(casinoSource.contains("Royal flush"))
        XCTAssertTrue(casinoFile(named: "PracticePokerView.swift").contains("if state.phase == .complete"))
    }

    func testCasinoUsesExplicitAccessibilityAndNoColorOnlySelection() {
        XCTAssertTrue(casinoSource.contains("accessibilityReduceMotion"))
        XCTAssertTrue(casinoSource.contains("accessibilityDifferentiateWithoutColor"))
        XCTAssertTrue(casinoSource.contains("Selected"))
        XCTAssertTrue(casinoSource.contains("checkmark"))
        XCTAssertTrue(casinoSource.contains("monospacedDigit"))
        XCTAssertTrue(casinoFile(named: "PracticeChanceGameView.swift").contains("selected && differentiateWithoutColor"))
        XCTAssertFalse(casinoFile(named: "PracticeChanceGameView.swift").contains("selected || differentiateWithoutColor"))
        XCTAssertTrue(casinoFile(named: "PracticeChanceGameView.swift").contains("Your choice"))
        XCTAssertTrue(casinoFile(named: "PracticeChanceGameView.swift").contains("selectedChoiceIDs"))
    }

    func testHeaderUsesExplicitContrastOverTheDarkFelt() {
        XCTAssertTrue(casinoSource.contains("CasinoTheme.headerPrimary"))
        XCTAssertTrue(casinoSource.contains("CasinoTheme.headerSecondary"))
    }

    func testPokerUsesFiveNativeCardsHeldCuesAndAScannableProbabilityLedger() {
        let poker = casinoFile(named: "PracticePokerView.swift")

        XCTAssertTrue(poker.contains("CasinoPlayingCardView"))
        XCTAssertTrue(poker.contains("Label(\"Held\""))
        XCTAssertTrue(poker.contains("CasinoTheme.accent"))
        XCTAssertFalse(poker.contains("ScrollView(.horizontal)"), "All five cards should compose as one phone-width hand")
        XCTAssertTrue(poker.contains("2_598_960"))
        XCTAssertTrue(poker.contains("percentText"))
        XCTAssertTrue(poker.contains("monospacedDigit"))
    }

    func testTwelvePartRosetteIsAReusableWatermarkAndFairWheelDiagram() {
        let theme = casinoFile(named: "CasinoTheme.swift")
        let chance = casinoFile(named: "PracticeChanceGameView.swift")
        let hub = casinoFile(named: "CasinoHubView.swift")

        XCTAssertTrue(theme.contains("struct CasinoProbabilityRosette"))
        XCTAssertTrue(theme.contains("static let segmentCount = 12"))
        XCTAssertTrue(theme.contains("ForEach(0..<Self.segmentCount"))
        XCTAssertTrue(chance.contains("session.descriptor.id == .fairWheel"))
        XCTAssertTrue(chance.contains("CasinoProbabilityRosette(style: .wheel"))
        XCTAssertTrue(hub.contains("CasinoProbabilityRosette(style: .watermark"))
    }

    func testRegularCanvasUsesReadableLibraryWidthAndIntentionalMinimumHeight() {
        XCTAssertGreaterThanOrEqual(CasinoMobileLayoutPolicy.libraryWidth, 180)
        XCTAssertGreaterThanOrEqual(CasinoMobileLayoutPolicy.regularTableMinimumHeight, 480)
        XCTAssertTrue(casinoFile(named: "CasinoHubView.swift").contains("regularTableMinimumHeight"))
    }

    func testCasinoEntryThresholdIsAnHonestSessionOnlyAccessiblePortal() {
        let gate = casinoFile(named: "CasinoEntryGateView.swift")

        XCTAssertTrue(gate.contains("Practice only. No money, purchases, wagering, prizes, rewards, or transferable value."))
        XCTAssertTrue(gate.contains("18+"))
        XCTAssertTrue(gate.contains("Verified-age access is planned before public release."))
        XCTAssertFalse(gate.localizedCaseInsensitiveContains("you are verified"))
        XCTAssertTrue(gate.contains("Enter Practice Casino"))
        XCTAssertTrue(gate.contains("Not Now"))
        XCTAssertTrue(gate.contains("CasinoEntryAccessPolicy"))
        XCTAssertTrue(gate.contains("CasinoEntryAccessStatus"))
        XCTAssertTrue(gate.contains("CasinoProbabilityRosette("))
        XCTAssertTrue(gate.contains("style: .wheel"))
        XCTAssertTrue(gate.contains("accessibilityReduceMotion"))
        XCTAssertTrue(gate.contains("accessibilityDifferentiateWithoutColor"))
        XCTAssertTrue(gate.contains("CasinoTheme.minimumTarget"))

        let hub = casinoFile(named: "CasinoHubView.swift")
        XCTAssertTrue(hub.contains("if entryAccessStatus.canEnterCasino"))
        XCTAssertTrue(hub.contains("CasinoEntryGateView("))
        XCTAssertTrue(hub.contains("entryAccessPolicy.enterPracticeSession()"))
        XCTAssertTrue(hub.contains("guard entryAccessStatus.canEnterCasino else { return }"))
    }

    private var casinoSource: String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Casino", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? String(contentsOf: $0) }
            .joined(separator: "\n")
    }

    private var homeSource: String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Home/HomeView.swift")
        return (try? String(contentsOf: root)) ?? ""
    }

    private func casinoFile(named name: String) -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Casino", isDirectory: true)
        return (try? String(contentsOf: root.appendingPathComponent(name))) ?? ""
    }
}
