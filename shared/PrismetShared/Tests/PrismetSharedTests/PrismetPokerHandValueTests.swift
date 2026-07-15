import XCTest
@testable import PrismetShared

final class PrismetPokerHandValueTests: XCTestCase {
    func testLexicographicTieBreakRanksAndAceLowStraightOrdering() throws {
        let kings = try PrismetPokerHandValue(cards: [
            card(.king, .clubs), card(.king, .diamonds), card(.ace, .hearts), card(.nine, .spades), card(.three, .clubs),
        ])
        let queens = try PrismetPokerHandValue(cards: [
            card(.queen, .clubs), card(.queen, .diamonds), card(.ace, .hearts), card(.nine, .spades), card(.three, .clubs),
        ])
        let wheel = try PrismetPokerHandValue(cards: [
            card(.ace, .clubs), card(.two, .diamonds), card(.three, .hearts), card(.four, .spades), card(.five, .clubs),
        ])
        let sixHigh = try PrismetPokerHandValue(cards: [
            card(.two, .clubs), card(.three, .diamonds), card(.four, .hearts), card(.five, .spades), card(.six, .clubs),
        ])

        XCTAssertEqual(kings.category, .onePair)
        XCTAssertEqual(kings.tieBreakRanks, [13, 14, 9, 3])
        XCTAssertGreaterThan(kings, queens)
        XCTAssertEqual(wheel.category, .straight)
        XCTAssertEqual(wheel.tieBreakRanks, [5])
        XCTAssertLessThan(wheel, sixHigh)
    }

    func testBestFiveEnumeratesSevenCardSubsets() throws {
        let cards = [
            card(.ten, .hearts), card(.nine, .clubs), card(.ace, .hearts), card(.king, .hearts),
            card(.queen, .hearts), card(.jack, .hearts), card(.two, .clubs),
        ]

        let best = try PrismetPokerHandValue.bestFive(of: cards)

        XCTAssertEqual(best.category, .royalFlush)
        XCTAssertEqual(best.tieBreakRanks, [14])
    }

    func testValueRejectsInvalidAndDuplicateInputs() {
        XCTAssertThrowsError(try PrismetPokerHandValue(cards: [card(.ace), card(.king)])) {
            XCTAssertEqual($0 as? PrismetPokerHandValueError, .invalidCardCount(expectedAtLeast: 5, actual: 2))
        }
        let ace = card(.ace)
        XCTAssertThrowsError(try PrismetPokerHandValue.bestFive(of: [ace, ace, card(.king), card(.queen), card(.jack)])) {
            XCTAssertEqual($0 as? PrismetPokerHandValueError, .duplicateCards)
        }
    }

    private func card(_ rank: PrismetCardRank, _ suit: PrismetCardSuit = .spades) -> PrismetPlayingCard {
        PrismetPlayingCard(rank: rank, suit: suit)
    }
}
