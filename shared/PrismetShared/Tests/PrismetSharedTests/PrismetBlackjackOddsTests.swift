import Foundation
import XCTest
@testable import PrismetShared

final class PrismetBlackjackOddsTests: XCTestCase {
    private let assumption = "Uses only your cards and the dealer’s face-up card; the hole card and draw pile are treated as unseen."

    func testHardSixteenHasThirtyBustingCardsAmongFortyNineUnseen() throws {
        let odds = try PrismetBlackjackHitOdds(
            validatingPlayerCards: [
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

    func testSoftSeventeenHasNoOneCardBusts() throws {
        let odds = try PrismetBlackjackHitOdds(
            validatingPlayerCards: [
                PrismetBlackjackFixtures.card(.ace, .clubs),
                PrismetBlackjackFixtures.card(.six, .hearts)
            ],
            dealerFaceUpCard: PrismetBlackjackFixtures.card(.five, .diamonds)
        )

        XCTAssertEqual(odds.bustingCardCount, 0)
        XCTAssertEqual(odds.unseenCardCount, 49)
        XCTAssertEqual(odds.probability, 0)
    }

    func testHardTwentyHasFortyFiveBustingCards() throws {
        let odds = try PrismetBlackjackHitOdds(
            validatingPlayerCards: [
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
        let odds = try PrismetBlackjackHitOdds(
            validatingPlayerCards: PrismetBlackjackFixtures.cards(.ten, .six),
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

    func testDuplicatePhysicalVisibleCardIsRejectedWithTypedError() {
        let duplicate = PrismetBlackjackFixtures.card(.ten, .clubs)

        XCTAssertThrowsError(
            try PrismetBlackjackHitOdds(
                validatingPlayerCards: [
                    duplicate,
                    PrismetBlackjackFixtures.card(.six, .hearts)
                ],
                dealerFaceUpCard: duplicate
            )
        ) { error in
            XCTAssertEqual(
                error as? PrismetBlackjackHitOddsError,
                .duplicateVisibleCard(duplicate)
            )
        }
    }

    func testOddsDoNotDependOnDealerHoleCardOrDrawPile() {
        let playerCards = PrismetBlackjackFixtures.cards(.ten, .six)
        let dealerFaceUpCard = PrismetBlackjackFixtures.card(.five, .diamonds)
        let baseDeck = PrismetDeckFactory.standard52()
        let firstState = PrismetBlackjackState(
            seed: 1,
            shuffledDeck: baseDeck,
            drawIndex: 4,
            playerCards: playerCards,
            dealerCards: [
                dealerFaceUpCard,
                PrismetBlackjackFixtures.card(.ace, .spades)
            ],
            phase: .playerTurn,
            resolution: nil
        )
        let secondState = PrismetBlackjackState(
            seed: 2,
            shuffledDeck: baseDeck.reversed(),
            drawIndex: 17,
            playerCards: playerCards,
            dealerCards: [
                dealerFaceUpCard,
                PrismetBlackjackFixtures.card(.king, .hearts)
            ],
            phase: .playerTurn,
            resolution: nil
        )

        XCTAssertEqual(
            PrismetBlackjackEngine.observation(for: firstState).hitOdds,
            PrismetBlackjackEngine.observation(for: secondState).hitOdds
        )
    }
}
