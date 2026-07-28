import XCTest
@testable import PrismetShared

final class MookiesBrandIPadCasinoTests: XCTestCase {
    func testRegularPortraitUsesTwoColumnsWhileLandscapeUsesThree() {
        XCTAssertEqual(
            MookiesIPadCasinoLayoutPolicy.layout(
                width: 834,
                height: 1_194,
                isRegularWidth: true,
                usesAccessibilityText: false
            ),
            .balanced
        )
        XCTAssertEqual(
            MookiesIPadCasinoLayoutPolicy.layout(
                width: 1_194,
                height: 834,
                isRegularWidth: true,
                usesAccessibilityText: false
            ),
            .panoramic
        )
    }

    func testSplitViewAndAccessibilityTextKeepThePlaySurfaceReadable() {
        XCTAssertEqual(
            MookiesIPadCasinoLayoutPolicy.layout(
                width: 720,
                height: 1_024,
                isRegularWidth: false,
                usesAccessibilityText: false
            ),
            .stacked
        )
        XCTAssertEqual(
            MookiesIPadCasinoLayoutPolicy.layout(
                width: 1_366,
                height: 1_024,
                isRegularWidth: true,
                usesAccessibilityText: true
            ),
            .stacked
        )
    }

    func testCasinoPresencePlanKeepsBothCharactersVisibleWithoutOwningPlay() {
        let plan = MookiesCasinoMascotPresencePlan.casino

        XCTAssertEqual(plan.primary.character, .reynard)
        XCTAssertEqual(plan.secondary.character, .mookie)
        XCTAssertEqual(Set(plan.presentations.map(\.assetName)), ["MookieHost", "ReynardCasinoHost"])
        XCTAssertTrue(plan.presentations.allSatisfy(\.isDismissible))
        XCTAssertTrue(plan.presentations.allSatisfy { !$0.overlaysPrimaryPlay })
        XCTAssertTrue(plan.presentations.allSatisfy { !$0.affectsGameOutcome })
    }

    func testReduceMotionDisablesAmbientCharacterMovement() {
        XCTAssertEqual(MookiesCasinoMotionPolicy.mode(reduceMotion: false), .ambient)
        XCTAssertEqual(MookiesCasinoMotionPolicy.mode(reduceMotion: true), .staticOnly)
    }

    func testDismissingOneMascotNeverChangesOrHidesTheOther() {
        var visibility = MookiesCasinoMascotVisibility()

        visibility.dismiss(.reynard)

        XCTAssertEqual(
            visibility.visiblePresentations(in: .casino).map(\.character),
            [.mookie]
        )
        XCTAssertTrue(visibility.isVisible(.mookie))
        XCTAssertFalse(visibility.isVisible(.reynard))
    }

    func testRestoringMascotsReturnsTheCanonicalCasinoOrder() {
        var visibility = MookiesCasinoMascotVisibility()
        visibility.dismiss(.mookie)
        visibility.dismiss(.reynard)

        visibility.restoreAll()

        XCTAssertEqual(
            visibility.visiblePresentations(in: .casino).map(\.character),
            [.reynard, .mookie]
        )
    }
}
