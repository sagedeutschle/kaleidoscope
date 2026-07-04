import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — simple puzzle persistence/input congruency
struct LightsOut: Codable, Equatable, Hashable {
    typealias Press = (row: Int, col: Int)

    private(set) var grid: [Bool]

    init(grid: [Bool] = Array(repeating: false, count: 25)) {
        precondition(grid.count == 25, "LightsOut requires a 5x5 grid.")
        self.grid = grid
    }

    static func newPuzzle(seed: UInt64) -> LightsOut {
        var game = LightsOut()
        game.scramble(seed: seed)
        return game
    }

    var isSolved: Bool {
        grid.allSatisfy { !$0 }
    }

    var litCount: Int {
        grid.filter { $0 }.count
    }

    func isLit(row: Int, col: Int) -> Bool {
        guard Self.isValid(row: row, col: col) else { return false }
        return grid[row * 5 + col]
    }

    mutating func press(row: Int, col: Int) {
        guard Self.isValid(row: row, col: col) else { return }

        for (nextRow, nextCol) in [(row, col), (row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)]
            where Self.isValid(row: nextRow, col: nextCol) {
            let index = nextRow * 5 + nextCol
            grid[index].toggle()
        }
    }

    @discardableResult
    mutating func scramble(seed: UInt64, pressCount: Int = 10) -> [Press] {
        var rng = SeededGenerator(seed: seed)
        var presses: [Press] = []

        for _ in 0..<max(1, pressCount) {
            let press = (row: rng.nextInt(upperBound: 5), col: rng.nextInt(upperBound: 5))
            presses.append(press)
            self.press(row: press.row, col: press.col)
        }

        if isSolved {
            let press = (row: 0, col: 0)
            presses.append(press)
            self.press(row: press.row, col: press.col)
        }

        return presses
    }

    private static func isValid(row: Int, col: Int) -> Bool {
        (0..<5).contains(row) && (0..<5).contains(col)
    }
}
