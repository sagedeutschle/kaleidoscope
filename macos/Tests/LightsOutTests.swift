import XCTest
@testable import Kaleidoscope

final class LightsOutTests: XCTestCase {
    func testPressingSameCellTwiceReturnsToOriginalGrid() {
        var game = LightsOut()
        let original = game

        game.press(row: 2, col: 2)
        game.press(row: 2, col: 2)

        XCTAssertEqual(game, original)
        XCTAssertTrue(game.isSolved)
    }

    func testCornerPressFlipsExactlyThreeCells() {
        var game = LightsOut()

        game.press(row: 0, col: 0)

        XCTAssertEqual(game.litCount, 3)
        XCTAssertTrue(game.isLit(row: 0, col: 0))
        XCTAssertTrue(game.isLit(row: 0, col: 1))
        XCTAssertTrue(game.isLit(row: 1, col: 0))
    }

    func testCenterPressFlipsExactlyFiveCells() {
        var game = LightsOut()

        game.press(row: 2, col: 2)

        XCTAssertEqual(game.litCount, 5)
        XCTAssertTrue(game.isLit(row: 2, col: 2))
        XCTAssertTrue(game.isLit(row: 1, col: 2))
        XCTAssertTrue(game.isLit(row: 3, col: 2))
        XCTAssertTrue(game.isLit(row: 2, col: 1))
        XCTAssertTrue(game.isLit(row: 2, col: 3))
    }

    func testReplayingScramblePressesSolvesScrambledBoard() {
        var game = LightsOut()
        let presses = game.scramble(seed: 42)

        XCTAssertFalse(game.isSolved)

        for press in presses {
            game.press(row: press.row, col: press.col)
        }

        XCTAssertTrue(game.isSolved)
    }

    func testNewPuzzleStartsScrambled() {
        let game = LightsOut.newPuzzle(seed: 7)

        XCTAssertFalse(game.isSolved)
    }

    func testLightsOutCodableRoundTripPreservesGrid() throws {
        var game = LightsOut.newPuzzle(seed: 7)
        game.press(row: 2, col: 3)

        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(LightsOut.self, from: data)

        XCTAssertEqual(restored, game)
    }
}
