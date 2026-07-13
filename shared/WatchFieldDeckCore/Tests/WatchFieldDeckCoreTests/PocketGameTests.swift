import XCTest
@testable import WatchFieldDeckCore

final class PocketGameTests: XCTestCase {
    func test2048MergesEachPairOnlyOnce() {
        var game = Pocket2048(
            grid: [2, 2, 2, 2] + Array(repeating: 0, count: 12),
            score: 0,
            seed: 9
        )

        XCTAssertTrue(game.move(.left, spawn: false))
        XCTAssertEqual(Array(game.grid.prefix(4)), [4, 4, 0, 0])
        XCTAssertEqual(game.score, 8)
    }

    func test2048RejectsMoveThatDoesNotChangeBoard() {
        var game = Pocket2048(
            grid: [2, 4, 8, 16] + Array(repeating: 0, count: 12),
            score: 0,
            seed: 3
        )

        XCTAssertFalse(game.move(.left, spawn: false))
        XCTAssertEqual(Array(game.grid.prefix(4)), [2, 4, 8, 16])
    }

    func testLightsOutPressTogglesCross() {
        var game = PocketLightsOut()
        game.press(row: 2, col: 2)

        XCTAssertEqual(game.litCount, 5)
        XCTAssertTrue(game.isLit(row: 2, col: 2))
        XCTAssertTrue(game.isLit(row: 1, col: 2))
        XCTAssertTrue(game.isLit(row: 3, col: 2))
        XCTAssertTrue(game.isLit(row: 2, col: 1))
        XCTAssertTrue(game.isLit(row: 2, col: 3))
    }

    func testLightsOutPuzzleIsSolvableByReplayingSeedPresses() {
        var game = PocketLightsOut.newPuzzle(seed: 42, pressCount: 8)

        for press in game.solution.reversed() {
            game.press(row: press.row, col: press.col)
        }

        XCTAssertTrue(game.isSolved)
    }

    func testCatanHarvestProductiveRollAddsPipsAndRobberHalvesUnbanked() {
        var game = CatanHarvest(seed: 1)

        XCTAssertEqual(game.apply(total: 6), .productive(total: 6, gained: 5))
        XCTAssertEqual(game.unbanked, 5)
        XCTAssertEqual(game.apply(total: 7), .robber(lost: 3))
        XCTAssertEqual(game.unbanked, 2)
    }

    func testCatanHarvestWinsAtTwentyFiveBanked() {
        var game = CatanHarvest(seed: 2)

        for _ in 0..<5 {
            _ = game.apply(total: 6)
            _ = game.bank()
        }

        XCTAssertTrue(game.didWin)
        XCTAssertEqual(game.banked, CatanHarvest.winningHarvest)
    }
}
