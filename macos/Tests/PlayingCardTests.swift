import XCTest
@testable import Kaleidoscope

final class PlayingCardTests: XCTestCase {

    func testStandardDeckHas52UniqueCards() {
        let deck = Card.standardDeck
        XCTAssertEqual(deck.count, 52)
        XCTAssertEqual(Set(deck).count, 52)
    }

    func testStandardDeckHas13PerSuitAnd4PerRank() {
        let deck = Card.standardDeck
        for suit in Suit.allCases {
            XCTAssertEqual(deck.filter { $0.suit == suit }.count, 13)
        }
        for rank in Rank.allCases {
            XCTAssertEqual(deck.filter { $0.rank == rank }.count, 4)
        }
    }

    func testSeededShuffleIsDeterministic() {
        XCTAssertEqual(Deck(shuffledWithSeed: 42).cards, Deck(shuffledWithSeed: 42).cards)
    }

    func testDifferentSeedsProduceDifferentOrder() {
        XCTAssertNotEqual(Deck(shuffledWithSeed: 1).cards, Deck(shuffledWithSeed: 2).cards)
    }

    func testShuffledDeckIsAPermutationOfStandard() {
        let shuffled = Deck(shuffledWithSeed: 7)
        XCTAssertEqual(shuffled.count, 52)
        XCTAssertEqual(Set(shuffled.cards), Set(Card.standardDeck))
    }

    func testDrawTakesFromTop() {
        var deck = Deck()
        let top = deck.cards.last
        XCTAssertEqual(deck.draw(), top)
        XCTAssertEqual(deck.count, 51)
    }

    func testDrawNStopsWhenEmpty() {
        var deck = Deck(cards: Array(Card.standardDeck.prefix(3)))
        let drawn = deck.draw(10)
        XCTAssertEqual(drawn.count, 3)
        XCTAssertTrue(deck.isEmpty)
    }

    func testRankIsComparable() {
        XCTAssertLessThan(Rank.ace, Rank.king)
        XCTAssertLessThan(Rank.two, Rank.ten)
    }

    func testLabels() {
        XCTAssertEqual(Card(rank: .ace, suit: .spades).label, "A♠")
        XCTAssertEqual(Card(rank: .ten, suit: .hearts).label, "10♥")
        XCTAssertTrue(Card(rank: .king, suit: .diamonds).isRed)
        XCTAssertFalse(Card(rank: .king, suit: .clubs).isRed)
    }
}
