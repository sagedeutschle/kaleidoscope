import Foundation
import XCTest
@testable import PrismetShared

final class PrismetBlackjackOddsTests: XCTestCase {
    private let assumption = "Uses only your cards and the dealer’s face-up card; the hole card and draw pile are treated as unseen."

    func testHardSixteenHasThirtyBustingCardsAmongFortyNineUnseen() {
        let odds = PrismetBlackjackHitOdds(
            playerCards: [
                PrismetBlackjackFixtures.card(.ten, .clubs),
                PrismetBlackjackFixtures.card(.six, .hearts)
            ],
            dealerFaceUpCard: PrismetBlackjackFixtures.card(.five, .diamonds)
        )

        XCTAssertEqual(odds.bustingCardCount, 30)
        XCTAssertEqual(odds.unseenCardCount, 49)
        XCTAssertEqual(odds.unseenCardCountsByRank.values.reduce(0, +), 49)
        XCTAssertEqual(odds.probability, 30.0 / 49.0, accuracy: 0.000_000_1)
        XCTAssertEqual(odds.assumption, assumption)
    }

    func testSoftSeventeenHasNoOneCardBusts() {
        let odds = PrismetBlackjackHitOdds(
            playerCards: [
                PrismetBlackjackFixtures.card(.ace, .clubs),
                PrismetBlackjackFixtures.card(.six, .hearts)
            ],
            dealerFaceUpCard: PrismetBlackjackFixtures.card(.five, .diamonds)
        )

        XCTAssertEqual(odds.bustingCardCount, 0)
        XCTAssertEqual(odds.unseenCardCount, 49)
        XCTAssertEqual(odds.probability, 0)
    }

    func testHardTwentyHasFortyFiveBustingCards() {
        let odds = PrismetBlackjackHitOdds(
            playerCards: [
                PrismetBlackjackFixtures.card(.ten, .clubs),
                PrismetBlackjackFixtures.card(.king, .hearts)
            ],
            dealerFaceUpCard: PrismetBlackjackFixtures.card(.five, .diamonds)
        )

        XCTAssertEqual(odds.bustingCardCount, 45)
        XCTAssertEqual(odds.unseenCardCount, 49)
        XCTAssertEqual(odds.probability, 45.0 / 49.0, accuracy: 0.000_000_1)
    }

    func testOddsRoundTripWithoutChangingRankCounts() throws {
        let odds = PrismetBlackjackHitOdds(
            playerCards: PrismetBlackjackFixtures.cards(.ten, .six),
            dealerFaceUpCard: PrismetBlackjackFixtures.card(.five, .spades)
        )

        XCTAssertEqual(
            try JSONDecoder().decode(
                PrismetBlackjackHitOdds.self,
                from: JSONEncoder().encode(odds)
            ),
            odds
        )
    }
}
