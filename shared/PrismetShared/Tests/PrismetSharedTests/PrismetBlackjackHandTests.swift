import XCTest
@testable import PrismetShared

final class PrismetBlackjackHandTests: XCTestCase {
    func testRulesPublishStablePracticeBlackjackIdentity() {
        XCTAssertEqual(PrismetBlackjackRulesV1.canonicalGameID, "blackjack")
        XCTAssertEqual(PrismetBlackjackRulesV1.name, "Practice Blackjack")
        XCTAssertEqual(PrismetBlackjackRulesV1.rulesVersion, 1)
        XCTAssertEqual(PrismetBlackjackRulesV1.payloadVersion, 1)
        XCTAssertEqual(PrismetBlackjackRulesV1.deckCount, 1)
        XCTAssertTrue(PrismetBlackjackRulesV1.dealerStandsOnSoft17)
        XCTAssertEqual(PrismetBlackjackCommand.allCases, [.hit, .stand])
    }

    func testAceSixIsSoftSeventeen() {
        let value = PrismetBlackjackHandValue(
            cards: PrismetBlackjackFixtures.cards(.ace, .six)
        )

        XCTAssertEqual(value.total, 17)
        XCTAssertTrue(value.isSoft)
        XCTAssertFalse(value.isBust)
        XCTAssertFalse(value.isNatural)
    }

    func testAceSixKingIsHardSeventeen() {
        let value = PrismetBlackjackHandValue(
            cards: PrismetBlackjackFixtures.cards(.ace, .six, .king)
        )

        XCTAssertEqual(value.total, 17)
        XCTAssertFalse(value.isSoft)
        XCTAssertFalse(value.isBust)
    }

    func testTwoAcesAndNineIsSoftNonNaturalTwentyOne() {
        let value = PrismetBlackjackHandValue(
            cards: PrismetBlackjackFixtures.cards(.ace, .ace, .nine)
        )

        XCTAssertEqual(value.total, 21)
        XCTAssertTrue(value.isSoft)
        XCTAssertFalse(value.isNatural)
    }

    func testThreeCardTwentyTwoBusts() {
        let value = PrismetBlackjackHandValue(
            cards: PrismetBlackjackFixtures.cards(.king, .queen, .two)
        )

        XCTAssertEqual(value.total, 22)
        XCTAssertTrue(value.isBust)
        XCTAssertFalse(value.isSoft)
    }

    func testOnlyTwoCardTwentyOneIsNatural() {
        XCTAssertTrue(
            PrismetBlackjackHandValue(
                cards: PrismetBlackjackFixtures.cards(.ace, .king)
            ).isNatural
        )
        XCTAssertFalse(
            PrismetBlackjackHandValue(
                cards: PrismetBlackjackFixtures.cards(.seven, .seven, .seven)
            ).isNatural
        )
    }

    func testPlayerNaturalBeatsDealerThreeCardTwentyOne() {
        let resolution = PrismetBlackjackResolution.resolve(
            playerCards: PrismetBlackjackFixtures.cards(.ace, .king),
            dealerCards: PrismetBlackjackFixtures.cards(.seven, .seven, .seven)
        )

        XCTAssertEqual(resolution.outcome, .playerWins)
        XCTAssertEqual(resolution.reason, .playerNatural)
    }

    func testDealerNaturalBeatsPlayerThreeCardTwentyOne() {
        let resolution = PrismetBlackjackResolution.resolve(
            playerCards: PrismetBlackjackFixtures.cards(.seven, .seven, .seven),
            dealerCards: PrismetBlackjackFixtures.cards(.ace, .queen)
        )

        XCTAssertEqual(resolution.outcome, .dealerWins)
        XCTAssertEqual(resolution.reason, .dealerNatural)
    }

    func testEqualEighteensTie() {
        let resolution = PrismetBlackjackResolution.resolve(
            playerCards: PrismetBlackjackFixtures.cards(.king, .eight),
            dealerCards: PrismetBlackjackFixtures.cards(.queen, .eight)
        )

        XCTAssertEqual(resolution.outcome, .tie)
        XCTAssertEqual(resolution.reason, .equalTotals)
        XCTAssertEqual(resolution.playerValue.total, 18)
        XCTAssertEqual(resolution.dealerValue.total, 18)
    }
}
