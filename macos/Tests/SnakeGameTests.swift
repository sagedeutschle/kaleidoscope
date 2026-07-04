import XCTest
@testable import Kaleidoscope

final class SnakeGameTests: XCTestCase {
    func testStepMovesHeadForwardAndDropsTail() {
        var game = SnakeGame(width: 6,
                             height: 6,
                             body: [SnakePoint(row: 2, col: 2), SnakePoint(row: 2, col: 1)],
                             direction: .right,
                             apple: SnakePoint(row: 0, col: 0))
        var rng = SeededGenerator(seed: 1)

        game.step(rng: &rng)

        XCTAssertEqual(game.body, [SnakePoint(row: 2, col: 3), SnakePoint(row: 2, col: 2)])
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.status, .playing)
    }

    func testEatingAppleGrowsSnakeAndScores() {
        var game = SnakeGame(width: 4,
                             height: 4,
                             body: [SnakePoint(row: 1, col: 1), SnakePoint(row: 1, col: 0)],
                             direction: .right,
                             apple: SnakePoint(row: 1, col: 2))
        var rng = SeededGenerator(seed: 3)

        game.step(rng: &rng)

        XCTAssertEqual(game.body.count, 3)
        XCTAssertEqual(game.score, 1)
        XCTAssertFalse(game.body.contains(game.apple))
    }

    func testWallCollisionEndsGame() {
        var game = SnakeGame(width: 3,
                             height: 3,
                             body: [SnakePoint(row: 0, col: 2)],
                             direction: .right,
                             apple: SnakePoint(row: 2, col: 2))
        var rng = SeededGenerator(seed: 1)

        game.step(rng: &rng)

        XCTAssertEqual(game.status, .lost)
    }

    func testReverseTurnIsIgnored() {
        var game = SnakeGame(width: 6,
                             height: 6,
                             body: [SnakePoint(row: 2, col: 2), SnakePoint(row: 2, col: 1)],
                             direction: .right,
                             apple: SnakePoint(row: 0, col: 0))

        game.turn(.left)

        XCTAssertEqual(game.direction, .right)
    }

    func testSnakeCodableRoundTripPreservesBoardAndStatus() throws {
        var game = SnakeGame(width: 6,
                             height: 6,
                             body: [SnakePoint(row: 0, col: 2)],
                             direction: .right,
                             apple: SnakePoint(row: 2, col: 2))
        var rng = SeededGenerator(seed: 1)
        game.step(rng: &rng)

        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(SnakeGame.self, from: data)

        XCTAssertEqual(restored, game)
    }
}
