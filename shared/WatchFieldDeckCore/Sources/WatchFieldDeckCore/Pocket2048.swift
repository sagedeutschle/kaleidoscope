public struct Pocket2048: Codable, Equatable, Sendable {
    public enum Direction: String, Codable, CaseIterable, Sendable {
        case up
        case down
        case left
        case right
    }

    public private(set) var grid: [Int]
    public private(set) var score: Int
    private var random: SeededRandom

    public init(seed: UInt64) {
        grid = Array(repeating: 0, count: 16)
        score = 0
        random = SeededRandom(seed: seed)
        spawnTile()
        spawnTile()
    }

    public init(grid: [Int], score: Int, seed: UInt64) {
        precondition(grid.count == 16, "Pocket2048 requires a 4x4 grid.")
        self.grid = grid
        self.score = score
        random = SeededRandom(seed: seed)
    }

    public static func newGame(seed: UInt64) -> Self {
        Self(seed: seed)
    }

    public var hasWon: Bool {
        grid.contains { $0 >= 2048 }
    }

    public var isGameOver: Bool {
        guard !grid.contains(0) else { return false }

        for row in 0..<4 {
            for column in 0..<4 {
                let value = self[row, column]
                if row < 3, self[row + 1, column] == value { return false }
                if column < 3, self[row, column + 1] == value { return false }
            }
        }
        return true
    }

    public subscript(row: Int, column: Int) -> Int {
        grid[row * 4 + column]
    }

    @discardableResult
    public mutating func move(_ direction: Direction, spawn: Bool = true) -> Bool {
        let before = grid
        var gained = 0

        for indexes in lineIndexes(for: direction) {
            let merged = Self.merge(indexes.map { grid[$0] })
            gained += merged.score
            for (offset, index) in indexes.enumerated() {
                grid[index] = merged.values[offset]
            }
        }

        guard grid != before else { return false }
        score += gained
        if spawn { spawnTile() }
        return true
    }

    private static func merge(_ values: [Int]) -> (values: [Int], score: Int) {
        let compacted = values.filter { $0 != 0 }
        var output: [Int] = []
        var gained = 0
        var index = 0

        while index < compacted.count {
            if index + 1 < compacted.count, compacted[index] == compacted[index + 1] {
                let merged = compacted[index] * 2
                output.append(merged)
                gained += merged
                index += 2
            } else {
                output.append(compacted[index])
                index += 1
            }
        }

        output.append(contentsOf: Array(repeating: 0, count: 4 - output.count))
        return (output, gained)
    }

    private func lineIndexes(for direction: Direction) -> [[Int]] {
        switch direction {
        case .left:
            return (0..<4).map { row in (0..<4).map { row * 4 + $0 } }
        case .right:
            return (0..<4).map { row in (0..<4).reversed().map { row * 4 + $0 } }
        case .up:
            return (0..<4).map { column in (0..<4).map { $0 * 4 + column } }
        case .down:
            return (0..<4).map { column in (0..<4).reversed().map { $0 * 4 + column } }
        }
    }

    private mutating func spawnTile() {
        let empty = grid.indices.filter { grid[$0] == 0 }
        guard !empty.isEmpty else { return }

        let index = empty[random.nextInt(upperBound: empty.count)]
        grid[index] = random.nextInt(upperBound: 10) == 0 ? 4 : 2
    }
}
