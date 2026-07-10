import XCTest
@testable import Prismet

final class NonogramGameTests: XCTestCase {
    func testCluesDescribeFilledRuns() {
        let game = NonogramGame.crossPuzzle()

        XCTAssertEqual(game.rowClues[0], [1])
        XCTAssertEqual(game.rowClues[1], [3])
        XCTAssertEqual(game.rowClues[2], [5])
        XCTAssertEqual(game.columnClues[2], [5])
    }

    func testMarkCyclesEmptyFilledCross() {
        var game = NonogramGame.crossPuzzle()

        XCTAssertEqual(game.mark(row: 0, col: 0), .empty)
        game.cycle(row: 0, col: 0)
        XCTAssertEqual(game.mark(row: 0, col: 0), .filled)
        game.cycle(row: 0, col: 0)
        XCTAssertEqual(game.mark(row: 0, col: 0), .crossed)
        game.cycle(row: 0, col: 0)
        XCTAssertEqual(game.mark(row: 0, col: 0), .empty)
    }

    func testSolvedWhenFilledCellsMatchSolution() {
        var game = NonogramGame.crossPuzzle()

        for row in 0..<game.size {
            for col in 0..<game.size where game.solutionValue(row: row, col: col) {
                game.setMark(.filled, row: row, col: col)
            }
        }

        XCTAssertTrue(game.isSolved)

        game.setMark(.filled, row: 0, col: 0)
        XCTAssertFalse(game.isSolved)
    }

    func testNonogramCodableRoundTripPreservesMarks() throws {
        var game = NonogramGame.crossPuzzle()
        game.cycle(row: 2, col: 2)
        game.cycle(row: 0, col: 0)
        game.cycle(row: 0, col: 0)

        let data = try JSONEncoder().encode(game)
        let restored = try JSONDecoder().decode(NonogramGame.self, from: data)

        XCTAssertEqual(restored, game)
    }
}
