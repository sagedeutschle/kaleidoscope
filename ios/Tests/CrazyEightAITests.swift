import XCTest
@testable import Prismet

final class CrazyEightAITests: XCTestCase {
    func testDifficultyDepthScalesAcrossELO() {
        XCTAssertEqual(CrazyEightAI.searchDepth(forELO: 600), 1)
        XCTAssertLessThan(CrazyEightAI.searchDepth(forELO: 900), CrazyEightAI.searchDepth(forELO: 1700))
        XCTAssertEqual(CrazyEightAI.searchDepth(forELO: 2400), 5)
        XCTAssertEqual(CrazyEightAI.searchDepth(forELO: 100), 1)
        XCTAssertEqual(CrazyEightAI.searchDepth(forELO: 3000), 5)
    }

    func testAIPlaysImmediateWinningCard() throws {
        let winningCard = Card(rank: .five, suit: .clubs)
        let game = CrazyEightGame(
            hands: [
                .host: [Card(rank: .king, suit: .diamonds)],
                .guest: [winningCard]
            ],
            drawPile: [],
            discardPile: [Card(rank: .five, suit: .hearts)],
            currentPlayer: .guest,
            declaredSuit: .hearts
        )

        let move = try XCTUnwrap(CrazyEightAI(player: .guest, targetELO: 1800).move(in: game))

        XCTAssertEqual(move, .play(winningCard, declaredSuit: nil))
    }

    func testEightDeclaresSuitFromRemainingHand() throws {
        let eight = Card(rank: .eight, suit: .clubs)
        let game = CrazyEightGame(
            hands: [
                .host: [Card(rank: .king, suit: .diamonds)],
                .guest: [
                    eight,
                    Card(rank: .two, suit: .spades),
                    Card(rank: .jack, suit: .spades),
                    Card(rank: .queen, suit: .hearts)
                ]
            ],
            drawPile: [],
            discardPile: [Card(rank: .five, suit: .diamonds)],
            currentPlayer: .guest,
            declaredSuit: .diamonds
        )

        let move = try XCTUnwrap(CrazyEightAI(player: .guest, targetELO: 1800).move(in: game))

        XCTAssertEqual(move, .play(eight, declaredSuit: .spades))
    }

    func testAIDrawsWhenNoCardIsPlayable() throws {
        let game = CrazyEightGame(
            hands: [
                .host: [Card(rank: .king, suit: .diamonds)],
                .guest: [Card(rank: .two, suit: .spades)]
            ],
            drawPile: [Card(rank: .ace, suit: .clubs)],
            discardPile: [Card(rank: .five, suit: .hearts)],
            currentPlayer: .guest,
            declaredSuit: .hearts
        )

        let move = try XCTUnwrap(CrazyEightAI(player: .guest, targetELO: 1800).move(in: game))

        XCTAssertEqual(move, .draw)
    }
}
