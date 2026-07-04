import XCTest
@testable import Kaleidoscope

final class Game2048Tests: XCTestCase {
    func testLeftMergeCombinesPair() {
        var rng = SeededGenerator(seed: 1)
        var game = Game2048(grid: [2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        _ = game.move(.left, spawn: false, rng: &rng)
        XCTAssertEqual(Array(game.grid[0..<4]), [4, 0, 0, 0])
        XCTAssertEqual(game.score, 4)
    }

    func testNoChainedMergeInOneMove() {
        var rng = SeededGenerator(seed: 1)
        var game = Game2048(grid: [2, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        _ = game.move(.left, spawn: false, rng: &rng)
        XCTAssertEqual(Array(game.grid[0..<4]), [4, 4, 0, 0])
    }

    func testNonChangingMoveSpawnsNothing() {
        var rng = SeededGenerator(seed: 1)
        var game = Game2048(grid: [2, 4, 8, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        let changed = game.move(.left, rng: &rng)
        XCTAssertFalse(changed)
        XCTAssertEqual(game.grid.filter { $0 != 0 }.count, 4)
    }

    func testWinFlagAt2048() {
        let game = Game2048(grid: [2048, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertTrue(game.hasWon)
    }

    func testGameOverWhenFullWithNoMerges() {
        let game = Game2048(grid: [2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2])
        XCTAssertTrue(game.isGameOver)
    }

    func testShuffleTilesPreservesValuesAndScore() {
        var rng = SeededGenerator(seed: 99)
        var game = Game2048(grid: [
            2, 0, 4, 0,
            8, 0, 16, 0,
            32, 0, 64, 0,
            128, 0, 256, 0
        ], score: 510)
        let beforeValues = game.grid.sorted()

        XCTAssertTrue(game.shuffleTiles(rng: &rng))
        XCTAssertEqual(game.grid.sorted(), beforeValues)
        XCTAssertEqual(game.score, 510)
        XCTAssertNotEqual(game.grid, [
            2, 0, 4, 0,
            8, 0, 16, 0,
            32, 0, 64, 0,
            128, 0, 256, 0
        ])
    }

    func testShuffleTilesRequiresAtLeastTwoDistinctSlotValues() {
        var rng = SeededGenerator(seed: 1)
        var empty = Game2048()
        var identicalTiles = Game2048(grid: Array(repeating: 2, count: 16))

        XCTAssertFalse(empty.shuffleTiles(rng: &rng))
        XCTAssertFalse(identicalTiles.shuffleTiles(rng: &rng))
    }
}
