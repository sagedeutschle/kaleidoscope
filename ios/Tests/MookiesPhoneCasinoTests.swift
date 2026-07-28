import XCTest
@testable import Prismet

final class MookiesPhoneCasinoTests: XCTestCase {
    func testCompactLayoutProtectsThePlaySurfaceAtTheNarrowPhoneFloor() {
        let layout = MookiesPhoneCasinoPresentation.layout(usableWidth: 320)

        XCTAssertEqual(layout, MookiesPhoneCasinoLayout(
            horizontalPadding: 12,
            hostDiameter: 104,
            stageCornerRadius: 24,
            minimumPlayHeight: 300,
            usesCondensedHostCopy: true
        ))
        XCTAssertLessThanOrEqual(
            (layout.horizontalPadding * 2) + MookiesPhoneCasinoPresentation.minimumPlayWidth,
            320
        )
    }

    func testStandardLayoutMakesReynardProminentWithoutShrinkingTheTable() {
        let layout = MookiesPhoneCasinoPresentation.layout(usableWidth: 430)

        XCTAssertEqual(layout, MookiesPhoneCasinoLayout(
            horizontalPadding: 16,
            hostDiameter: 132,
            stageCornerRadius: 30,
            minimumPlayHeight: 360,
            usesCondensedHostCopy: false
        ))
        XCTAssertGreaterThan(layout.minimumPlayHeight, layout.hostDiameter)
    }

    func testLayoutBoundaryMovesFromCondensedToStandardAt390Points() {
        XCTAssertTrue(MookiesPhoneCasinoPresentation.layout(usableWidth: 389).usesCondensedHostCopy)
        XCTAssertFalse(MookiesPhoneCasinoPresentation.layout(usableWidth: 390).usesCondensedHostCopy)
    }

    func testReynardHostContractUsesTheSelectedDealerArtAndPracticeOnlyVoice() {
        XCTAssertEqual(MookiesPhoneCasinoPresentation.destinationName, "Reynard’s Casino")
        XCTAssertEqual(MookiesPhoneCasinoPresentation.hostAssetName, "ReynardCasinoHost")
        XCTAssertEqual(
            MookiesPhoneCasinoHostMood.welcome.message,
            "Welcome, friend. Pick a table and I’ll deal the theatre — never the odds."
        )
        XCTAssertEqual(
            MookiesPhoneCasinoHostMood.tableReady.accessibilityLabel,
            "Reynard, fox host of Reynard’s Casino. Your practice table is ready. The next move is yours."
        )
    }

    func testReynardMoodCopyNeverClaimsARewardOrChangesAResult() {
        let copy = MookiesPhoneCasinoHostMood.allCases
            .map(\.message)
            .joined(separator: " ")
            .lowercased()

        for prohibitedTerm in ["payout", "jackpot", "reward", "winnings", "guaranteed", "better odds"] {
            XCTAssertFalse(copy.contains(prohibitedTerm), "Host copy contains prohibited promise: \(prohibitedTerm)")
        }
    }
}
