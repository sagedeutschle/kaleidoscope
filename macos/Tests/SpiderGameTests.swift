import XCTest
@testable import Kaleidoscope

final class SpiderGameTests: XCTestCase {
    func testNewGameDealsTenTableauColumnsAndFiveStockRows() {
        let game = SpiderGame.newGame(seed: 7)

        XCTAssertEqual(game.tableau.count, 10)
        XCTAssertEqual(game.tableau[0].count, 6)
        XCTAssertEqual(game.tableau[3].count, 6)
        XCTAssertEqual(game.tableau[4].count, 5)
        XCTAssertEqual(game.tableau[9].count, 5)
        XCTAssertEqual(game.stockRows.count, 5)
        XCTAssertTrue(game.tableau.allSatisfy { $0.last?.isFaceUp == true })
    }

    func testCanMoveDescendingFaceUpRunOntoNextHigherCard() {
        var game = SpiderGame(
            tableau: [
                [SpiderCard(card: Card(rank: .queen, suit: .spades), isFaceUp: true),
                 SpiderCard(card: Card(rank: .jack, suit: .spades), isFaceUp: true)],
                [SpiderCard(card: Card(rank: .king, suit: .spades), isFaceUp: true)]
            ] + Array(repeating: [], count: 8),
            stockRows: []
        )

        XCTAssertTrue(game.moveRun(from: 0, cardIndex: 0, to: 1))
        XCTAssertEqual(game.tableau[1].map(\.card.rank), [.king, .queen, .jack])
        XCTAssertTrue(game.tableau[0].isEmpty)
        XCTAssertEqual(game.moves, 1)
    }

    func testDealRowRequiresNoEmptyTableauColumns() {
        var game = SpiderGame(
            tableau: Array(repeating: [SpiderCard(card: Card(rank: .king, suit: .spades), isFaceUp: true)], count: 9) + [[]],
            stockRows: [Array(repeating: Card(rank: .ace, suit: .spades), count: 10)]
        )

        XCTAssertFalse(game.dealRow())
        game.tableau[9] = [SpiderCard(card: Card(rank: .two, suit: .spades), isFaceUp: true)]
        XCTAssertTrue(game.dealRow())
        XCTAssertEqual(game.stockRows.count, 0)
        XCTAssertEqual(game.tableau.map(\.count), Array(repeating: 2, count: 10))
    }

    func testCompletedKingToAceRunIsRemoved() {
        var run = Rank.allCases.reversed().map { rank in
            SpiderCard(card: Card(rank: rank, suit: .spades), isFaceUp: true)
        }
        run.insert(SpiderCard(card: Card(rank: .three, suit: .spades), isFaceUp: false), at: 0)
        var game = SpiderGame(tableau: [run] + Array(repeating: [], count: 9), stockRows: [])

        game.collectCompletedRuns()

        XCTAssertEqual(game.completedSets, 1)
        XCTAssertEqual(game.tableau[0].count, 1)
        XCTAssertTrue(game.tableau[0][0].isFaceUp)
    }
}
