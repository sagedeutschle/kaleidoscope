import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — simple puzzle persistence/input congruency
enum NonogramMark: Codable, Equatable, Hashable {
    case empty
    case filled
    case crossed
}

struct NonogramGame: Codable, Equatable, Hashable {
    let size: Int
    let solution: [Bool]
    private(set) var marks: [NonogramMark]

    init(size: Int = 5, solution: [Bool], marks: [NonogramMark]? = nil) {
        precondition(size > 0)
        precondition(solution.count == size * size)
        self.size = size
        self.solution = solution
        self.marks = marks ?? Array(repeating: .empty, count: solution.count)
    }

    static func crossPuzzle() -> NonogramGame {
        NonogramGame(solution: [
            false, false, true, false, false,
            false, true, true, true, false,
            true, true, true, true, true,
            false, true, true, true, false,
            false, false, true, false, false
        ])
    }

    var rowClues: [[Int]] {
        (0..<size).map { row in clues(for: (0..<size).map { solutionValue(row: row, col: $0) }) }
    }

    var columnClues: [[Int]] {
        (0..<size).map { col in clues(for: (0..<size).map { solutionValue(row: $0, col: col) }) }
    }

    var isSolved: Bool {
        solution.indices.allSatisfy { index in
            (marks[index] == .filled) == solution[index]
        }
    }

    func mark(row: Int, col: Int) -> NonogramMark {
        guard let index = index(row: row, col: col) else { return .empty }
        return marks[index]
    }

    func solutionValue(row: Int, col: Int) -> Bool {
        guard let index = index(row: row, col: col) else { return false }
        return solution[index]
    }

    mutating func cycle(row: Int, col: Int) {
        guard let index = index(row: row, col: col) else { return }
        switch marks[index] {
        case .empty: marks[index] = .filled
        case .filled: marks[index] = .crossed
        case .crossed: marks[index] = .empty
        }
    }

    mutating func setMark(_ mark: NonogramMark, row: Int, col: Int) {
        guard let index = index(row: row, col: col) else { return }
        marks[index] = mark
    }

    mutating func reset() {
        marks = Array(repeating: .empty, count: solution.count)
    }

    private func clues(for line: [Bool]) -> [Int] {
        var clues: [Int] = []
        var run = 0

        for filled in line {
            if filled {
                run += 1
            } else if run > 0 {
                clues.append(run)
                run = 0
            }
        }

        if run > 0 { clues.append(run) }
        return clues.isEmpty ? [0] : clues
    }

    private func index(row: Int, col: Int) -> Int? {
        guard (0..<size).contains(row), (0..<size).contains(col) else { return nil }
        return row * size + col
    }
}
