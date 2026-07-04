import XCTest
@testable import Kaleidoscope

final class SudokuGameTests: XCTestCase {

    // MARK: - Helpers

    /// True if `grid` is a complete, rule-consistent Sudoku solution.
    private func isValidCompleteSolution(_ grid: [Int]) -> Bool {
        guard grid.count == 81 else { return false }
        guard grid.allSatisfy({ (1...9).contains($0) }) else { return false }

        let full: Set<Int> = [1, 2, 3, 4, 5, 6, 7, 8, 9]

        // Rows
        for r in 0..<9 {
            var seen = Set<Int>()
            for c in 0..<9 { seen.insert(grid[r * 9 + c]) }
            if seen != full { return false }
        }
        // Columns
        for c in 0..<9 {
            var seen = Set<Int>()
            for r in 0..<9 { seen.insert(grid[r * 9 + c]) }
            if seen != full { return false }
        }
        // 3x3 boxes
        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                var seen = Set<Int>()
                for r in boxRow..<(boxRow + 3) {
                    for c in boxCol..<(boxCol + 3) {
                        seen.insert(grid[r * 9 + c])
                    }
                }
                if seen != full { return false }
            }
        }
        return true
    }

    // MARK: - Bundled puzzle integrity

    func testEveryBundledPuzzleHasValidCompleteSolution() {
        let all = SudokuPuzzleBank.all
        XCTAssertFalse(all.isEmpty, "Puzzle bank must not be empty")

        for (i, puzzle) in all.enumerated() {
            XCTAssertEqual(puzzle.givens.count, 81, "puzzle \(i) givens size")
            XCTAssertEqual(puzzle.solution.count, 81, "puzzle \(i) solution size")
            XCTAssertTrue(
                isValidCompleteSolution(puzzle.solution),
                "puzzle \(i) has an invalid or incomplete solution"
            )
        }
    }

    func testEveryBundledPuzzleGivensAreSubsetOfSolution() {
        for (i, puzzle) in SudokuPuzzleBank.all.enumerated() {
            for index in 0..<81 {
                let given = puzzle.givens[index]
                if given != 0 {
                    XCTAssertEqual(
                        given, puzzle.solution[index],
                        "puzzle \(i) given at \(index) contradicts its solution"
                    )
                } else {
                    XCTAssertTrue((0...9).contains(given))
                }
            }
        }
    }

    func testEachDifficultyProvidesMultiplePuzzles() {
        for difficulty in SudokuDifficulty.allCases {
            XCTAssertGreaterThanOrEqual(
                SudokuPuzzleBank.puzzles(for: difficulty).count, 2,
                "\(difficulty.label) needs multiple puzzles so New Game can vary"
            )
        }
    }

    func testRandomAvoidsCurrentPuzzleWhenAlternativesExist() {
        for difficulty in SudokuDifficulty.allCases {
            let pool = SudokuPuzzleBank.puzzles(for: difficulty)
            guard let first = pool.first else { continue }
            var rng = SeededGenerator(seed: 42)
            let next = SudokuPuzzleBank.random(
                for: difficulty,
                excludingGivens: first.givens,
                using: &rng
            )
            XCTAssertNotEqual(
                next.givens, first.givens,
                "random(excluding:) should not return the excluded puzzle when others exist"
            )
        }
    }

    // MARK: - Notes toggling

    func testNoteTogglesOnAndOff() {
        var game = SudokuGame.standardPuzzle()
        // Find an empty, non-given cell.
        var target: (Int, Int)?
        outer: for r in 0..<9 {
            for c in 0..<9 where !game.isGiven(row: r, col: c) && game.value(row: r, col: c) == 0 {
                target = (r, c)
                break outer
            }
        }
        let (r, c) = try! XCTUnwrap(target)

        XCTAssertTrue(game.notes(row: r, col: c).isEmpty)

        XCTAssertTrue(game.toggleNote(5, row: r, col: c))
        XCTAssertTrue(game.notes(row: r, col: c).contains(5))

        // Toggling the same candidate again removes it.
        XCTAssertTrue(game.toggleNote(5, row: r, col: c))
        XCTAssertFalse(game.notes(row: r, col: c).contains(5))

        // Multiple candidates coexist.
        game.toggleNote(1, row: r, col: c)
        game.toggleNote(9, row: r, col: c)
        XCTAssertEqual(game.notes(row: r, col: c), [1, 9])
    }

    func testNotesRejectedOnGivenCells() {
        var game = SudokuGame.standardPuzzle()
        // Find a given cell.
        var given: (Int, Int)?
        outer: for r in 0..<9 {
            for c in 0..<9 where game.isGiven(row: r, col: c) {
                given = (r, c)
                break outer
            }
        }
        let (r, c) = try! XCTUnwrap(given)
        XCTAssertFalse(game.toggleNote(3, row: r, col: c))
        XCTAssertTrue(game.notes(row: r, col: c).isEmpty)
    }

    func testPlacingValueClearsThatCellsNotes() {
        var game = SudokuGame.standardPuzzle()
        var target: (Int, Int)?
        outer: for r in 0..<9 {
            for c in 0..<9 where !game.isGiven(row: r, col: c) && game.value(row: r, col: c) == 0 {
                target = (r, c)
                break outer
            }
        }
        let (r, c) = try! XCTUnwrap(target)

        game.toggleNote(2, row: r, col: c)
        game.toggleNote(7, row: r, col: c)
        XCTAssertFalse(game.notes(row: r, col: c).isEmpty)

        XCTAssertTrue(game.setValue(4, row: r, col: c))
        XCTAssertEqual(game.value(row: r, col: c), 4)
        XCTAssertTrue(
            game.notes(row: r, col: c).isEmpty,
            "placing a real value must clear that cell's notes"
        )
    }

    func testResetClearsNotes() {
        var game = SudokuGame.standardPuzzle()
        var target: (Int, Int)?
        outer: for r in 0..<9 {
            for c in 0..<9 where !game.isGiven(row: r, col: c) && game.value(row: r, col: c) == 0 {
                target = (r, c)
                break outer
            }
        }
        let (r, c) = try! XCTUnwrap(target)

        game.toggleNote(8, row: r, col: c)
        XCTAssertFalse(game.notes(row: r, col: c).isEmpty)

        game.reset()
        XCTAssertTrue(game.notes(row: r, col: c).isEmpty)
    }

    // MARK: - Codable round-trip (notes persist) + backward compatibility

    func testNotesSurviveCodableRoundTrip() throws {
        var game = SudokuGame(SudokuPuzzleBank.easy[0])
        var target: (Int, Int)?
        outer: for r in 0..<9 {
            for c in 0..<9 where !game.isGiven(row: r, col: c) && game.value(row: r, col: c) == 0 {
                target = (r, c)
                break outer
            }
        }
        let (r, c) = try XCTUnwrap(target)
        game.toggleNote(3, row: r, col: c)
        game.toggleNote(6, row: r, col: c)

        let data = try JSONEncoder().encode(game)
        let decoded = try JSONDecoder().decode(SudokuGame.self, from: data)
        XCTAssertEqual(decoded.notes(row: r, col: c), [3, 6])
        XCTAssertEqual(decoded, game)
    }

    func testDecodesLegacyPayloadWithoutNotes() throws {
        // Older saves have no `notes` key; decoding must still succeed with empty notes.
        let puzzle = SudokuPuzzleBank.easy[0]
        let json = """
        {
            "puzzle": \(jsonArray(puzzle.givens)),
            "entries": \(jsonArray(puzzle.givens)),
            "solution": \(jsonArray(puzzle.solution))
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SudokuGame.self, from: data)
        XCTAssertEqual(decoded.puzzle, puzzle.givens)
        XCTAssertEqual(decoded.solution, puzzle.solution)
        for r in 0..<9 {
            for c in 0..<9 {
                XCTAssertTrue(decoded.notes(row: r, col: c).isEmpty)
            }
        }
    }

    private func jsonArray(_ values: [Int]) -> String {
        "[" + values.map(String.init).joined(separator: ",") + "]"
    }
}
