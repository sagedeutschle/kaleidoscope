import XCTest
@testable import PrismetShared

final class PrismetThreeCardPokerLabTests: XCTestCase {
    func testRanksStraightAboveFlushAndTreatsAceTwoThreeAsThreeHigh() throws {
        let straight = try PrismetThreeCardPokerHandValue(cards: [card(.seven, .clubs), card(.six, .diamonds), card(.five, .hearts)])
        let flush = try PrismetThreeCardPokerHandValue(cards: [card(.ace, .spades), card(.nine, .spades), card(.four, .spades)])
        let wheel = try PrismetThreeCardPokerHandValue(cards: [card(.ace, .clubs), card(.two, .diamonds), card(.three, .hearts)])

        XCTAssertGreaterThan(straight, flush)
        XCTAssertEqual(wheel.category, .straight)
        XCTAssertEqual(wheel.tieBreakRanks, [3])
    }

    func testExactSingleHandCountsMatchAllTwentyTwoThousandOneHundredCombinations() throws {
        let deck = PrismetDeckFactory.standard52()
        var counts: [PrismetThreeCardPokerCategory: Int] = [:]
        for first in 0..<(deck.count - 2) {
            for second in (first + 1)..<(deck.count - 1) {
                for third in (second + 1)..<deck.count {
                    let value = try PrismetThreeCardPokerHandValue(cards: [deck[first], deck[second], deck[third]])
                    counts[value.category, default: 0] += 1
                }
            }
        }

        XCTAssertEqual(PrismetThreeCardPokerLab.exactTotalSingleHandCount, 22_100)
        XCTAssertEqual(counts, [.straightFlush: 48, .threeOfAKind: 52, .straight: 720, .flush: 1_096, .onePair: 3_744, .highCard: 16_440])
        XCTAssertEqual(PrismetThreeCardPokerLab.exactCategoryCounts, counts)
    }

    func testDealRedactsReferenceUntilExplicitComparisonAndReplayIsDeterministic() throws {
        let dealt = try PrismetThreeCardPokerLab.deal(seed: 0xCAFE)

        XCTAssertEqual(dealt, try PrismetThreeCardPokerLab.deal(seed: 0xCAFE))
        XCTAssertEqual(dealt.phase, .dealt)
        XCTAssertEqual(dealt.learnerCards.count, 3)
        XCTAssertEqual(dealt.referenceCards, [.hidden, .hidden, .hidden])
        XCTAssertNil(dealt.comparison)

        let revealed = try PrismetThreeCardPokerLab.revealComparison(in: dealt)
        XCTAssertEqual(revealed.phase, .revealed)
        XCTAssertEqual(revealed.referenceCards.count, 3)
        XCTAssertTrue(revealed.referenceCards.allSatisfy { $0.card != nil })
        XCTAssertNotNil(revealed.comparison)
        XCTAssertEqual(revealed, try PrismetThreeCardPokerLab.revealComparison(in: try PrismetThreeCardPokerLab.deal(seed: 0xCAFE)))
    }

    func testSecondRevealAndTamperedCursorReturnTypedErrors() throws {
        let dealt = try PrismetThreeCardPokerLab.deal(seed: 41)
        let revealed = try PrismetThreeCardPokerLab.revealComparison(in: dealt)
        XCTAssertThrowsError(try PrismetThreeCardPokerLab.revealComparison(in: revealed)) {
            XCTAssertEqual($0 as? PrismetThreeCardPokerLabError, .invalidPhase(.revealed))
        }

        var object = try jsonObject(dealt)
        object["cursor"] = 5
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetThreeCardPokerLabState.self, from: data)) {
            XCTAssertEqual($0 as? PrismetThreeCardPokerLabStateValidationError, .invalidCursor(expected: 6, actual: 5))
        }

        var deckMismatch = try jsonObject(dealt)
        deckMismatch["seed"] = 42
        let deckData = try JSONSerialization.data(withJSONObject: deckMismatch, options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetThreeCardPokerLabState.self, from: deckData)) {
            XCTAssertEqual($0 as? PrismetThreeCardPokerLabStateValidationError, .shuffledDeckMismatch)
        }
    }

    private func card(_ rank: PrismetCardRank, _ suit: PrismetCardSuit) -> PrismetPlayingCard { PrismetPlayingCard(rank: rank, suit: suit) }
    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]) }
}
