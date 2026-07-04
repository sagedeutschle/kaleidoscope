import XCTest
@testable import Kaleidoscope

final class CrazyEightGameTests: XCTestCase {
    func testNewGameDealsSevenCardsEachAndStartsDiscard() {
        let game = CrazyEightGame.newGame(seed: 3)

        XCTAssertEqual(game.hand(for: .host).count, 7)
        XCTAssertEqual(game.hand(for: .guest).count, 7)
        XCTAssertNotNil(game.discardTop)
        XCTAssertEqual(game.currentPlayer, .host)
    }

    func testCardMatchingRankCanBePlayedAndTurnPasses() throws {
        var game = CrazyEightGame(
            hands: [
                .host: [Card(rank: .five, suit: .clubs)],
                .guest: [Card(rank: .king, suit: .diamonds)]
            ],
            drawPile: [],
            discardPile: [Card(rank: .five, suit: .hearts)],
            currentPlayer: .host,
            declaredSuit: .hearts
        )

        XCTAssertTrue(game.playCard(Card(rank: .five, suit: .clubs)))

        XCTAssertEqual(game.discardTop, Card(rank: .five, suit: .clubs))
        XCTAssertEqual(game.currentSuit, .clubs)
        XCTAssertEqual(game.currentPlayer, .guest)
        XCTAssertEqual(game.winner, .host)
    }

    func testEightCanDeclareSuit() {
        var game = CrazyEightGame(
            hands: [.host: [Card(rank: .eight, suit: .clubs)], .guest: [Card(rank: .king, suit: .diamonds)]],
            drawPile: [],
            discardPile: [Card(rank: .two, suit: .hearts)],
            currentPlayer: .host,
            declaredSuit: .hearts
        )

        XCTAssertTrue(game.playCard(Card(rank: .eight, suit: .clubs), declaredSuit: .spades))
        XCTAssertEqual(game.currentSuit, .spades)
        XCTAssertEqual(game.winner, .host)
    }

    func testDrawAddsOneCardAndPassesTurn() {
        var game = CrazyEightGame(
            hands: [.host: [], .guest: []],
            drawPile: [Card(rank: .ace, suit: .spades)],
            discardPile: [Card(rank: .two, suit: .hearts)],
            currentPlayer: .host,
            declaredSuit: .hearts
        )

        XCTAssertTrue(game.drawCard())
        XCTAssertEqual(game.hand(for: .host), [Card(rank: .ace, suit: .spades)])
        XCTAssertEqual(game.currentPlayer, .guest)
    }
}
