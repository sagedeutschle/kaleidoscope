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
    }

    func testEveryCasinoActionUsesAtLeastA44PointTarget() {
        XCTAssertEqual(CasinoTheme.minimumTarget, 44)
        XCTAssertTrue(casinoSource.contains(".frame(minHeight: CasinoTheme.minimumTarget)"))
    }

    func testCompactAndRegularPresentationContractsArePresent() {
        XCTAssertTrue(casinoSource.contains(".safeAreaInset(edge: .bottom)"))
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

    func testHeaderUsesExplicitContrastOverTheDarkFelt() {
        XCTAssertTrue(casinoSource.contains("CasinoTheme.headerPrimary"))
        XCTAssertTrue(casinoSource.contains("CasinoTheme.headerSecondary"))
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
}
