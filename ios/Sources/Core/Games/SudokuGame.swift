import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — simple puzzle persistence/input congruency
// PRISM: pencil notes (per-cell candidates) + curated multi-puzzle support.
struct SudokuGame: Codable, Equatable, Hashable {
    static let size = 9
    static let cellCount = size * size

    private(set) var puzzle: [Int]
    private(set) var entries: [Int]
    let solution: [Int]
    /// Pencil-mark candidates per cell (index == row * size + col). Empty when no notes.
    private(set) var notes: [Set<Int>]

    init(puzzle: [Int], solution: [Int], entries: [Int]? = nil, notes: [Set<Int>]? = nil) {
        precondition(puzzle.count == Self.cellCount)
        precondition(solution.count == Self.cellCount)
        self.puzzle = puzzle
        self.solution = solution
        self.entries = entries ?? puzzle
        if let notes, notes.count == Self.cellCount {
            self.notes = notes
        } else {
            self.notes = Array(repeating: Set<Int>(), count: Self.cellCount)
        }
    }

    /// Build a fresh game from a curated puzzle (givens + verified solution).
    init(_ curated: SudokuPuzzle) {
        self.init(puzzle: curated.givens, solution: curated.solution)
    }

    // MARK: - Codable (backward compatible)

    private enum CodingKeys: String, CodingKey {
        case puzzle, entries, solution, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let puzzle = try container.decode([Int].self, forKey: .puzzle)
        let solution = try container.decode([Int].self, forKey: .solution)
        let entries = try container.decodeIfPresent([Int].self, forKey: .entries) ?? puzzle
        // `notes` is a newer field; older saves won't have it. Decode as arrays of Ints
        // (Set isn't order-stable to encode) and fall back to empty notes.
        let decodedNotes = try container.decodeIfPresent([[Int]].self, forKey: .notes)
        let notes: [Set<Int>]?
        if let decodedNotes, decodedNotes.count == Self.cellCount {
            notes = decodedNotes.map { Set($0) }
        } else {
            notes = nil
        }
        self.init(puzzle: puzzle, solution: solution, entries: entries, notes: notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(puzzle, forKey: .puzzle)
        try container.encode(entries, forKey: .entries)
        try container.encode(solution, forKey: .solution)
        // Encode notes as sorted Int arrays for deterministic output.
        try container.encode(notes.map { $0.sorted() }, forKey: .notes)
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

    // MARK: - Notes (pencil marks)

    /// Candidate marks currently penciled into the cell (empty if none).
    func notes(row: Int, col: Int) -> Set<Int> {
        guard let index = index(row: row, col: col) else { return [] }
        return notes[index]
    }

    /// Toggle a candidate note (1...9) on an empty, non-given cell.
    /// Notes are ignored on given cells or cells that already hold a value.
    @discardableResult
    mutating func toggleNote(_ candidate: Int, row: Int, col: Int) -> Bool {
        guard (1...9).contains(candidate),
              let index = index(row: row, col: col),
              puzzle[index] == 0,
              entries[index] == 0 else { return false }

        if notes[index].contains(candidate) {
            notes[index].remove(candidate)
        } else {
            notes[index].insert(candidate)
        }
        return true
    }

    /// Clear all notes in a single cell.
    mutating func clearNotes(row: Int, col: Int) {
        guard let index = index(row: row, col: col) else { return }
        notes[index].removeAll()
    }

    @discardableResult
    mutating func setValue(_ value: Int, row: Int, col: Int) -> Bool {
        guard (0...9).contains(value),
              let index = index(row: row, col: col),
              puzzle[index] == 0 else { return false }

        entries[index] = value
        // Entering a real value clears that cell's pencil notes.
        if value != 0 {
            notes[index].removeAll()
        }
        return true
    }

    mutating func fillSolution() {
        entries = solution
        clearAllNotes()
    }

    mutating func reset() {
        entries = puzzle
        clearAllNotes()
    }

    private mutating func clearAllNotes() {
        notes = Array(repeating: Set<Int>(), count: Self.cellCount)
    }

    private func index(row: Int, col: Int) -> Int? {
        guard (0..<Self.size).contains(row), (0..<Self.size).contains(col) else { return nil }
        return row * Self.size + col
    }
}
