import XCTest
@testable import Kaleidoscope

final class SlidingPuzzleTests: XCTestCase {
    func testSolvedBoardReportsSolved() {
        XCTAssertTrue(SlidingPuzzle.solved.isSolved)
    }

    func testLegalMoveSwapsTileIntoBlank() {
        var puzzle = SlidingPuzzle(tiles: [1, 2, 3, 4,
                                           5, 6, 7, 8,
                                           9, 10, 11, 12,
                                           13, 14, 0, 15])

        XCTAssertTrue(puzzle.moveTile(at: 15))
        XCTAssertEqual(puzzle.tiles, SlidingPuzzle.solved.tiles)
    }

    func testIllegalMoveDoesNothing() {
        var puzzle = SlidingPuzzle.solved

        XCTAssertFalse(puzzle.moveTile(at: 0))
        XCTAssertEqual(puzzle.tiles, SlidingPuzzle.solved.tiles)
    }

    func testSeededShuffleIsSolvableAndNotSolved() {
        let puzzle = SlidingPuzzle.shuffled(seed: 9, moves: 30)

        XCTAssertTrue(puzzle.isSolvable)
        XCTAssertFalse(puzzle.isSolved)
    }

    func testSlidingPuzzleCodableRoundTripPreservesTiles() throws {
        let puzzle = SlidingPuzzle.shuffled(seed: 14, moves: 20)

        let data = try JSONEncoder().encode(puzzle)
        let restored = try JSONDecoder().decode(SlidingPuzzle.self, from: data)

        XCTAssertEqual(restored, puzzle)
    }
}
