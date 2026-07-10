import XCTest
@testable import Prismet

final class SudokuGameTests: XCTestCase {
    func testGivenCellsCannotBeEdited() {
        var game = SudokuGame.standardPuzzle()

        XCTAssertTrue(game.isGiven(row: 0, col: 0))
        XCTAssertFalse(game.setValue(9, row: 0, col: 0))
        XCTAssertEqual(game.value(row: 0, col: 0), 5)
    }

    func testEditableCellsAcceptOneThroughNineAndErase() {
        var game = SudokuGame.standardPuzzle()

        XCTAssertFalse(game.isGiven(row: 0, col: 2))
        XCTAssertTrue(game.setValue(4, row: 0, col: 2))
        XCTAssertEqual(game.value(row: 0, col: 2), 4)
        XCTAssertTrue(game.setValue(0, row: 0, col: 2))
        XCTAssertEqual(game.value(row: 0, col: 2), 0)
    }

    func testConflictDetectsRowColumnAndBoxDuplicates() {
        var game = SudokuGame.standardPuzzle()

        _ = game.setValue(5, row: 0, col: 2)
        _ = game.setValue(6, row: 2, col: 0)
        _ = game.setValue(8, row: 1, col: 1)

        XCTAssertTrue(game.hasConflict(row: 0, col: 2))
        XCTAssertTrue(game.hasConflict(row: 2, col: 0))
        XCTAssertTrue(game.hasConflict(row: 1, col: 1))
    }

    func testSolvedBoardIsCompleteOnlyWhenItMatchesSolution() {
        var game = SudokuGame.standardPuzzle()
        game.fillSolution()

        XCTAssertTrue(game.isComplete)

        _ = game.setValue(1, row: 0, col: 2)
        XCTAssertFalse(game.isComplete)
    }

    func testSudokuCodableRoundTripPreservesEntries() throws {
        var game = SudokuGame.standardPuzzle()
        _ = game.setValue(4, row: 0, col: 2)

        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(SudokuGame.self, from: data)

        XCTAssertEqual(restored, game)
    }
}
