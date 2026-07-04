import Foundation

/// Small deterministic PRNG (shared by games for seeded, testable randomness).
struct SeededGenerator: Codable, Equatable, Hashable {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}

/// Self-contained 4×4 2048 model (pure Swift, portable to any platform).
struct Game2048: Codable, Equatable, Hashable {
    enum Direction: Codable, Equatable, Hashable { case up, down, left, right }

    private(set) var grid: [Int]
    private(set) var score: Int

    init(grid: [Int] = Array(repeating: 0, count: 16), score: Int = 0) {
        precondition(grid.count == 16, "Game2048 requires a 4x4 grid.")
        self.grid = grid
        self.score = score
    }

    static func newGame(seed: UInt64 = 1) -> Game2048 {
        var rng = SeededGenerator(seed: seed)
        return newGame(rng: &rng)
    }

    static func newGame(rng: inout SeededGenerator) -> Game2048 {
        var game = Game2048()
        game.spawnTile(rng: &rng)
        game.spawnTile(rng: &rng)
        return game
    }

    var hasWon: Bool { grid.contains { $0 >= 2048 } }

    var isGameOver: Bool {
        guard !grid.contains(0) else { return false }
        for row in 0..<4 {
            for col in 0..<4 {
                let value = self[row, col]
                if row < 3, self[row + 1, col] == value { return false }
                if col < 3, self[row, col + 1] == value { return false }
            }
        }
        return true
    }

    subscript(row: Int, col: Int) -> Int { grid[row * 4 + col] }

    @discardableResult
    mutating func move(_ direction: Direction, spawn: Bool = true, rng: inout SeededGenerator) -> Bool {
        let before = grid
        var gained = 0
        for indexes in lineIndexes(for: direction) {
            let values = indexes.map { grid[$0] }
            let result = Self.mergedLine(values)
            gained += result.score
            for (offset, index) in indexes.enumerated() { grid[index] = result.values[offset] }
        }
        guard grid != before else { return false }
        score += gained
        if spawn { spawnTile(rng: &rng) }
        return true
    }

    @discardableResult
    mutating func shuffleTiles(rng: inout SeededGenerator) -> Bool {
        let before = grid
        var shuffled = grid

        for index in stride(from: shuffled.count - 1, through: 1, by: -1) {
            let swapIndex = rng.nextInt(upperBound: index + 1)
            shuffled.swapAt(index, swapIndex)
        }

        if shuffled == before,
           let first = shuffled.indices.first(where: { index in
               shuffled.indices.contains { shuffled[$0] != shuffled[index] }
           }),
           let second = shuffled.indices.first(where: { shuffled[$0] != shuffled[first] }) {
            shuffled.swapAt(first, second)
        }

        guard shuffled != before else { return false }
        grid = shuffled
        return true
    }

    private static func mergedLine(_ values: [Int]) -> (values: [Int], score: Int) {
        let compacted = values.filter { $0 != 0 }
        var merged: [Int] = []
        var score = 0
        var index = 0
        while index < compacted.count {
            if index + 1 < compacted.count, compacted[index] == compacted[index + 1] {
                let value = compacted[index] * 2
                merged.append(value); score += value; index += 2
            } else {
                merged.append(compacted[index]); index += 1
            }
        }
        merged.append(contentsOf: Array(repeating: 0, count: values.count - merged.count))
        return (merged, score)
    }

    private func lineIndexes(for direction: Direction) -> [[Int]] {
        switch direction {
        case .left:  return (0..<4).map { row in (0..<4).map { row * 4 + $0 } }
        case .right: return (0..<4).map { row in (0..<4).reversed().map { row * 4 + $0 } }
        case .up:    return (0..<4).map { col in (0..<4).map { $0 * 4 + col } }
        case .down:  return (0..<4).map { col in (0..<4).reversed().map { $0 * 4 + col } }
        }
    }

    private mutating func spawnTile(rng: inout SeededGenerator) {
        let empty = grid.indices.filter { grid[$0] == 0 }
        guard !empty.isEmpty else { return }
        let index = empty[rng.nextInt(upperBound: empty.count)]
        grid[index] = rng.nextInt(upperBound: 10) == 0 ? 4 : 2
    }
}
