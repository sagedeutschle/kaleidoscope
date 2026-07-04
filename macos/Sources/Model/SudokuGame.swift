import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — simple puzzle persistence/input congruency
struct SudokuGame: Codable, Equatable, Hashable {
    static let size = 9

    private(set) var puzzle: [Int]
    private(set) var entries: [Int]
    let solution: [Int]

    init(puzzle: [Int], solution: [Int], entries: [Int]? = nil) {
        precondition(puzzle.count == Self.size * Self.size)
        precondition(solution.count == Self.size * Self.size)
        self.puzzle = puzzle
        self.solution = solution
        self.entries = entries ?? puzzle
    }

    static func standardPuzzle() -> SudokuGame {
        SudokuGame(puzzle: [
            5, 3, 0, 0, 7, 0, 0, 0, 0,
            6, 0, 0, 1, 9, 5, 0, 0, 0,
            0, 9, 8, 0, 0, 0, 0, 6, 0,
            8, 0, 0, 0, 6, 0, 0, 0, 3,
            4, 0, 0, 8, 0, 3, 0, 0, 1,
            7, 0, 0, 0, 2, 0, 0, 0, 6,
            0, 6, 0, 0, 0, 0, 2, 8, 0,
            0, 0, 0, 4, 1, 9, 0, 0, 5,
            0, 0, 0, 0, 8, 0, 0, 7, 9
        ], solution: [
            5, 3, 4, 6, 7, 8, 9, 1, 2,
            6, 7, 2, 1, 9, 5, 3, 4, 8,
            1, 9, 8, 3, 4, 2, 5, 6, 7,
            8, 5, 9, 7, 6, 1, 4, 2, 3,
            4, 2, 6, 8, 5, 3, 7, 9, 1,
            7, 1, 3, 9, 2, 4, 8, 5, 6,
            9, 6, 1, 5, 3, 7, 2, 8, 4,
            2, 8, 7, 4, 1, 9, 6, 3, 5,
            3, 4, 5, 2, 8, 6, 1, 7, 9
        ])
    }

    var isComplete: Bool {
        entries == solution
    }

    func value(row: Int, col: Int) -> Int {
        guard let index = index(row: row, col: col) else { return 0 }
        return entries[index]
    }

    func isGiven(row: Int, col: Int) -> Bool {
        guard let index = index(row: row, col: col) else { return false }
        return puzzle[index] != 0
    }

    func isCorrect(row: Int, col: Int) -> Bool {
        guard let index = index(row: row, col: col), entries[index] != 0 else { return true }
        return entries[index] == solution[index]
    }

    func hasConflict(row: Int, col: Int) -> Bool {
        guard let index = index(row: row, col: col) else { return false }
        let value = entries[index]
        guard value != 0 else { return false }

        for nextCol in 0..<Self.size where nextCol != col && self.value(row: row, col: nextCol) == value {
            return true
        }
        for nextRow in 0..<Self.size where nextRow != row && self.value(row: nextRow, col: col) == value {
            return true
        }

        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for nextRow in boxRow..<(boxRow + 3) {
            for nextCol in boxCol..<(boxCol + 3)
                where (nextRow != row || nextCol != col) && self.value(row: nextRow, col: nextCol) == value {
                return true
            }
        }

        return false
    }

    @discardableResult
    mutating func setValue(_ value: Int, row: Int, col: Int) -> Bool {
        guard (0...9).contains(value),
              let index = index(row: row, col: col),
              puzzle[index] == 0 else { return false }

        entries[index] = value
        return true
    }

    mutating func fillSolution() {
        entries = solution
    }

    mutating func reset() {
        entries = puzzle
    }

    private func index(row: Int, col: Int) -> Int? {
        guard (0..<Self.size).contains(row), (0..<Self.size).contains(col) else { return nil }
        return row * Self.size + col
    }
}
