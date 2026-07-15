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
}
