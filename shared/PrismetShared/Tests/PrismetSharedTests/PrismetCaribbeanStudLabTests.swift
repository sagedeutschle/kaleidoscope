import XCTest
@testable import PrismetShared

final class PrismetCaribbeanStudLabTests: XCTestCase {
    func testQualificationIsInformationalAndAceKingHighQualifies() throws {
        let aceKingHigh = try PrismetCaribbeanStudQualification.evaluate([card(.ace, .clubs), card(.king, .diamonds), card(.queen, .clubs), card(.jack, .diamonds), card(.nine, .spades)])
        let aceQueenHigh = try PrismetCaribbeanStudQualification.evaluate([card(.ace, .clubs), card(.queen, .diamonds), card(.jack, .clubs), card(.ten, .diamonds), card(.nine, .spades)])
        let pair = try PrismetCaribbeanStudQualification.evaluate([card(.king, .clubs), card(.king, .diamonds), card(.ace, .spades), card(.queen, .hearts), card(.jack, .clubs)])

        XCTAssertEqual(aceKingHigh, .aceKingHigh)
        XCTAssertEqual(aceQueenHigh, .doesNotQualify)
        XCTAssertEqual(pair, .pairOrBetter)
        XCTAssertEqual(PrismetCaribbeanStudLab.exactLabeledDealCount, 3_986_646_103_440)
    }

    func testDealShowsOneReferenceCardThenExplicitRevealComparesFullFiveCardValues() throws {
        let dealt = try PrismetCaribbeanStudLab.deal(seed: 9_001)

        XCTAssertEqual(dealt.phase, .dealt)
        XCTAssertEqual(dealt.learnerCards.count, 5)
        XCTAssertEqual(dealt.referenceCards.filter { $0.card != nil }.count, 1)
        XCTAssertEqual(dealt.referenceCards.filter { $0.card == nil }.count, 4)
        XCTAssertNil(dealt.comparison)
        XCTAssertNil(dealt.referenceQualification)

        let revealed = try PrismetCaribbeanStudLab.revealComparison(in: dealt)
        XCTAssertEqual(revealed.phase, .revealed)
        XCTAssertTrue(revealed.referenceCards.allSatisfy { $0.card != nil })
        XCTAssertNotNil(revealed.comparison)
        XCTAssertNotNil(revealed.referenceQualification)
        XCTAssertEqual(revealed, try PrismetCaribbeanStudLab.revealComparison(in: try PrismetCaribbeanStudLab.deal(seed: 9_001)))
    }

    func testFullFiveCardComparisonUsesKickersAndRejectsInvalidPhaseAndRedaction() throws {
        let better = try PrismetPokerHandValue(cards: [card(.king, .clubs), card(.king, .diamonds), card(.ace, .spades), card(.queen, .hearts), card(.jack, .clubs)])
        let weaker = try PrismetPokerHandValue(cards: [card(.king, .hearts), card(.king, .spades), card(.ace, .diamonds), card(.queen, .clubs), card(.ten, .hearts)])
        XCTAssertGreaterThan(better, weaker)

        let dealt = try PrismetCaribbeanStudLab.deal(seed: 88)
        let revealed = try PrismetCaribbeanStudLab.revealComparison(in: dealt)
        XCTAssertThrowsError(try PrismetCaribbeanStudLab.revealComparison(in: revealed)) {
            XCTAssertEqual($0 as? PrismetCaribbeanStudLabError, .invalidPhase(.revealed))
        }

        var object = try jsonObject(dealt)
        object["referenceFaceUpCount"] = 2
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetCaribbeanStudLabState.self, from: data)) {
            XCTAssertEqual($0 as? PrismetCaribbeanStudLabStateValidationError, .invalidReferenceFaceUpCount(expected: 1, actual: 2))
        }

        var cursorMismatch = try jsonObject(dealt)
        cursorMismatch["cursor"] = 9
        let cursorData = try JSONSerialization.data(withJSONObject: cursorMismatch, options: [.sortedKeys])
        XCTAssertThrowsError(try JSONDecoder().decode(PrismetCaribbeanStudLabState.self, from: cursorData)) {
            XCTAssertEqual($0 as? PrismetCaribbeanStudLabStateValidationError, .invalidCursor(expected: 10, actual: 9))
        }
    }

    private func card(_ rank: PrismetCardRank, _ suit: PrismetCardSuit) -> PrismetPlayingCard { PrismetPlayingCard(rank: rank, suit: suit) }
    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]) }
}
