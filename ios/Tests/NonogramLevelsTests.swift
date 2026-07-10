import XCTest
@testable import Prismet

final class NonogramLevelsTests: XCTestCase {

    func testBankIsNonEmptyAndHasVariedSizes() {
        let levels = NonogramLevelBank.levels
        XCTAssertGreaterThanOrEqual(levels.count, 8, "Tester asked for a real bank (~8-12 puzzles).")
        let sizes = Set(levels.map { $0.size })
        XCTAssertTrue(sizes.contains(5), "Expected at least one small (5×5) puzzle.")
        XCTAssertTrue(sizes.contains(10), "Expected at least one large (10×10) puzzle.")
    }

    func testNoMalformedArtInBank() {
        XCTAssertEqual(NonogramLevelBank.validationErrors, [],
                       "Every level's art must be exactly size×size.")
    }

    func testLevelIdsAreUnique() {
        let ids = NonogramLevelBank.levels.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "Level ids must be unique.")
    }

    func testEveryLevelIsWellFormed() {
        for level in NonogramLevelBank.levels {
            XCTAssertTrue(level.isWellFormed, "\(level.id): art is not \(level.size)×\(level.size)")
            XCTAssertEqual(level.solution.count, level.size * level.size, "\(level.id): wrong cell count")
        }
    }

    func testEveryLevelHasFilledCells() {
        for level in NonogramLevelBank.levels {
            XCTAssertTrue(level.solution.contains(true), "\(level.id): puzzle is entirely blank")
        }
    }

    func testDerivedCluesAreInternallyConsistent() {
        for level in NonogramLevelBank.levels {
            let game = level.makeGame()
            let filled = level.solution.filter { $0 }.count
            XCTAssertEqual(game.rowClueFillTotal, filled,
                           "\(level.id): row clues don't sum to the filled-cell count")
            XCTAssertEqual(game.columnClueFillTotal, filled,
                           "\(level.id): column clues don't sum to the filled-cell count")
            XCTAssertEqual(game.rowClues.count, level.size, "\(level.id): wrong row-clue count")
            XCTAssertEqual(game.columnClues.count, level.size, "\(level.id): wrong column-clue count")
        }
    }

    func testEverySolutionSatisfiesItsOwnClues() {
        for level in NonogramLevelBank.levels {
            let solved = level.makeGame().solvedInstance()
            XCTAssertTrue(solved.isSolved,
                          "\(level.id): filling the solution does not register as solved")
        }
    }

    func testLevelAtClampsOutOfRangeIndex() {
        let first = NonogramLevelBank.level(at: 0)
        XCTAssertEqual(NonogramLevelBank.level(at: -5), first)
        XCTAssertEqual(NonogramLevelBank.level(at: 9_999), first)
    }

    func testMakeGameProducesUnsolvedFreshBoard() {
        for level in NonogramLevelBank.levels {
            XCTAssertFalse(level.makeGame().isSolved,
                           "\(level.id): a fresh board should not start solved")
        }
    }
}
