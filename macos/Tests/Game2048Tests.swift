import XCTest
@testable import Kaleidoscope

final class Game2048Tests: XCTestCase {
    func testMovePlanTracksRightwardSlideDestination() {
        let game = Game2048(grid: [
            2, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ])

        let plan = game.plannedMove(.right)

        XCTAssertEqual(plan.grid.prefix(4), [0, 0, 0, 2])
        XCTAssertEqual(plan.slides, [
            Game2048TileSlide(value: 2, fromIndex: 0, toIndex: 3)
        ])
    }

    func testMovePlanTracksMergeSlidesTowardTarget() {
        let game = Game2048(grid: [
            2, 2, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ])

        let plan = game.plannedMove(.left)

        XCTAssertEqual(plan.grid.prefix(4), [4, 0, 0, 0])
        XCTAssertEqual(plan.scoreGained, 4)
        XCTAssertEqual(plan.slides, [
            Game2048TileSlide(value: 2, fromIndex: 0, toIndex: 0),
            Game2048TileSlide(value: 2, fromIndex: 1, toIndex: 0)
        ])
    }

    func testNewGameUsesRequestedBoardSizeAsTileCount() {
        let game = Game2048.newGame(size: 5, seed: 1)

        XCTAssertEqual(game.size, 5)
        XCTAssertEqual(game.grid.count, 25)
        XCTAssertEqual(game.grid.filter { $0 != 0 }.count, 2)
    }

    func testMoveUsesRequestedBoardWidth() {
        var game = Game2048(grid: [
            2, 2, 0, 0, 0,
            4, 4, 0, 0, 0,
            8, 0, 0, 0, 0,
            16, 0, 0, 0, 0,
            32, 0, 0, 0, 0
        ], size: 5)
        var rng = SeededGenerator(seed: 1)

        let changed = game.move(.left, spawn: false, rng: &rng)

        XCTAssertTrue(changed)
        XCTAssertEqual(Array(game.grid[0..<5]), [4, 0, 0, 0, 0])
        XCTAssertEqual(Array(game.grid[5..<10]), [8, 0, 0, 0, 0])
        XCTAssertEqual(game.score, 12)
    }

    func testGameOverUsesRequestedBoardWidth() {
        let game = Game2048(grid: [
            2, 4, 2, 4, 2,
            4, 2, 4, 2, 4,
            2, 4, 2, 4, 2,
            4, 2, 4, 2, 4,
            2, 4, 2, 4, 2
        ], size: 5)

        XCTAssertTrue(game.isGameOver)
    }

    func testLeftMoveMergesPairIntoSingleTile() {
        var game = Game2048(grid: [
            2, 2, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ])
        var rng = SeededGenerator(seed: 1)

        let changed = game.move(.left, spawn: false, rng: &rng)

        XCTAssertTrue(changed)
        XCTAssertEqual(Array(game.grid.prefix(4)), [4, 0, 0, 0])
        XCTAssertEqual(game.score, 4)
    }

    func testLeftMoveDoesNotChainMergeNewTile() {
        var game = Game2048(grid: [
            2, 2, 4, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ])
        var rng = SeededGenerator(seed: 1)

        let changed = game.move(.left, spawn: false, rng: &rng)

        XCTAssertTrue(changed)
        XCTAssertEqual(Array(game.grid.prefix(4)), [4, 4, 0, 0])
        XCTAssertEqual(game.score, 4)
    }

    func testUnchangedMoveDoesNotSpawnTile() {
        var game = Game2048(grid: [
            2, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ])
        var rng = SeededGenerator(seed: 1)

        let changed = game.move(.left, spawn: true, rng: &rng)

        XCTAssertFalse(changed)
        XCTAssertEqual(game.grid.filter { $0 != 0 }, [2])
    }

    func testFullBoardWithNoMergesIsGameOver() {
        let game = Game2048(grid: [
            2, 4, 2, 4,
            4, 2, 4, 2,
            2, 4, 2, 4,
            4, 2, 4, 2
        ])

        XCTAssertTrue(game.isGameOver)
    }

    func test2048TileSetsHasWon() {
        let game = Game2048(grid: [
            2048, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ])

        XCTAssertTrue(game.hasWon)
    }

    func testShuffleTilesRearrangesBoardAndPreservesScoreAndTileValues() {
        var game = Game2048(grid: [
            2, 4, 8, 16,
            0, 0, 0, 0,
            32, 0, 64, 0,
            0, 0, 0, 0
        ], score: 124)
        let originalGrid = game.grid
        var rng = SeededGenerator(seed: 12)

        let changed = game.shuffleTiles(rng: &rng)

        XCTAssertTrue(changed)
        XCTAssertNotEqual(game.grid, originalGrid)
        XCTAssertEqual(game.grid.sorted(), originalGrid.sorted())
        XCTAssertEqual(game.score, 124)
    }

    func testShuffleTilesIsDeterministicForSeed() {
        var first = Game2048(grid: [
            2, 4, 8, 16,
            0, 0, 0, 0,
            32, 0, 64, 0,
            0, 0, 0, 0
        ])
        var second = first
        var firstRng = SeededGenerator(seed: 12)
        var secondRng = SeededGenerator(seed: 12)

        XCTAssertTrue(first.shuffleTiles(rng: &firstRng))
        XCTAssertTrue(second.shuffleTiles(rng: &secondRng))
        XCTAssertEqual(first.grid, second.grid)
    }

    func testGame2048CodableRoundTripPreservesGridSizeAndScore() throws {
        let game = Game2048(grid: [
            2, 4, 8,
            16, 32, 64,
            128, 256, 512
        ], size: 3, score: 1024)

        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(Game2048.self, from: data)

        XCTAssertEqual(restored, game)
    }
}
