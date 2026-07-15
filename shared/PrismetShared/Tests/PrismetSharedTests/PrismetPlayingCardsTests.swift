import XCTest
@testable import PrismetShared

final class PrismetPlayingCardsTests: XCTestCase {
    func testStableSuitAndRankOrder() {
        XCTAssertEqual(PrismetCardSuit.allCases, [.clubs, .diamonds, .hearts, .spades])
        XCTAssertEqual(PrismetCardRank.allCases.map(\.rawValue), Array(2...14))
    }

    func testStandardDeckContainsEveryCardOnceInCanonicalOrder() {
        let standard = PrismetDeckFactory.standard52()

        XCTAssertEqual(standard.count, 52)
        XCTAssertEqual(Set(standard).count, 52)
        XCTAssertEqual(standard.first?.id, "two-of-clubs")
        XCTAssertEqual(standard[12].id, "ace-of-clubs")
        XCTAssertEqual(standard.last?.id, "ace-of-spades")

        for suit in PrismetCardSuit.allCases {
            XCTAssertEqual(standard.filter { $0.suit == suit }.count, 13)
        }
        for rank in PrismetCardRank.allCases {
            XCTAssertEqual(standard.filter { $0.rank == rank }.count, 4)
        }
    }

    func testEuchreDeckContainsOnlyNineThroughAce() {
        let euchre = PrismetDeckFactory.euchre24()

        XCTAssertEqual(euchre.count, 24)
        XCTAssertEqual(Set(euchre).count, 24)
        XCTAssertEqual(Set(euchre.map(\.rank)), Set([.nine, .ten, .jack, .queen, .king, .ace]))
        for suit in PrismetCardSuit.allCases {
            XCTAssertEqual(euchre.filter { $0.suit == suit }.count, 6)
        }
    }

    func testIdentifiersAndAccessibilityLabelsAreStable() {
        let card = PrismetPlayingCard(rank: .queen, suit: .hearts)

        XCTAssertEqual(card.id, "queen-of-hearts")
        XCTAssertEqual(card.accessibilityLabel(isFaceUp: true), "Queen of hearts")
        XCTAssertEqual(card.accessibilityLabel(isFaceUp: false), "Face-down card")
    }

    func testCardCodableRoundTripPreservesIdentity() throws {
        let card = PrismetPlayingCard(rank: .ace, suit: .spades)
        let roundTripped = try JSONDecoder().decode(
            PrismetPlayingCard.self,
            from: JSONEncoder().encode(card)
        )

        XCTAssertEqual(roundTripped, card)
        XCTAssertEqual(roundTripped.id, "ace-of-spades")
    }
}
