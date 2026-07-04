import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — active arcade persistence snapshots.
struct SeededGenerator: Codable, Equatable, Hashable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}

struct Game2048TileSlide: Codable, Equatable, Hashable, Identifiable {
    var value: Int
    var fromIndex: Int
    var toIndex: Int

    var id: String { "\(fromIndex)-\(toIndex)-\(value)" }
}

struct Game2048MovePlan: Equatable {
    var grid: [Int]
    var scoreGained: Int
    var slides: [Game2048TileSlide]
}

struct Game2048: Codable, Equatable, Hashable {
    static let defaultSize = 4
    static let minSize = 3
    static let maxSize = 6

    enum Direction: Codable, Equatable, Hashable {
        case up
        case down
        case left
        case right
    }

    private(set) var grid: [Int]
    private(set) var score: Int
    let size: Int

    init(grid: [Int] = Array(repeating: 0, count: Self.defaultSize * Self.defaultSize),
         size: Int = Self.defaultSize,
         score: Int = 0) {
        precondition((Self.minSize...Self.maxSize).contains(size), "Game2048 size must be 3...6.")
        precondition(grid.count == size * size, "Game2048 grid count must match size squared.")
        self.grid = grid
        self.score = score
        self.size = size
    }

    static func newGame(size: Int = Self.defaultSize, seed: UInt64 = 1) -> Game2048 {
        let clampedSize = min(max(size, Self.minSize), Self.maxSize)
        var game = Game2048(grid: Array(repeating: 0, count: clampedSize * clampedSize), size: clampedSize)
        var rng = SeededGenerator(seed: seed)
        game.spawnTile(rng: &rng)
        game.spawnTile(rng: &rng)
        return game
    }

    var hasWon: Bool {
        grid.contains { $0 >= 2048 }
    }

    var isGameOver: Bool {
        guard !grid.contains(0) else { return false }

        for row in 0..<size {
            for col in 0..<size {
                let value = self[row, col]
                if row < size - 1, self[row + 1, col] == value { return false }
                if col < size - 1, self[row, col + 1] == value { return false }
            }
        }

        return true
    }

    subscript(row: Int, col: Int) -> Int {
        grid[row * size + col]
    }

    @discardableResult
    mutating func move(_ direction: Direction, spawn: Bool = true, rng: inout SeededGenerator) -> Bool {
        let plan = plannedMove(direction)
        return apply(plan, spawn: spawn, rng: &rng)
    }

    func plannedMove(_ direction: Direction) -> Game2048MovePlan {
        var plannedGrid = Array(repeating: 0, count: grid.count)
        var scoreGained = 0
        var slides: [Game2048TileSlide] = []

        for indexes in lineIndexes(for: direction) {
            let occupied = indexes.compactMap { index -> (index: Int, value: Int)? in
                let value = grid[index]
                return value == 0 ? nil : (index, value)
            }
            var sourceOffset = 0
            var targetOffset = 0

            while sourceOffset < occupied.count {
                let first = occupied[sourceOffset]
                let targetIndex = indexes[targetOffset]

                if sourceOffset + 1 < occupied.count,
                   occupied[sourceOffset + 1].value == first.value {
                    let second = occupied[sourceOffset + 1]
                    plannedGrid[targetIndex] = first.value * 2
                    scoreGained += first.value * 2
                    slides.append(Game2048TileSlide(value: first.value, fromIndex: first.index, toIndex: targetIndex))
                    slides.append(Game2048TileSlide(value: second.value, fromIndex: second.index, toIndex: targetIndex))
                    sourceOffset += 2
                } else {
                    plannedGrid[targetIndex] = first.value
                    slides.append(Game2048TileSlide(value: first.value, fromIndex: first.index, toIndex: targetIndex))
                    sourceOffset += 1
                }

                targetOffset += 1
            }
        }

        return Game2048MovePlan(grid: plannedGrid, scoreGained: scoreGained, slides: slides)
    }

    @discardableResult
    mutating func apply(_ plan: Game2048MovePlan, spawn: Bool = true, rng: inout SeededGenerator) -> Bool {
        guard grid != plan.grid else { return false }

        grid = plan.grid
        score += plan.scoreGained
        if spawn {
            spawnTile(rng: &rng)
        }
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
                merged.append(value)
                score += value
                index += 2
            } else {
                merged.append(compacted[index])
                index += 1
            }
        }

        merged.append(contentsOf: Array(repeating: 0, count: values.count - merged.count))
        return (merged, score)
    }

    private func lineIndexes(for direction: Direction) -> [[Int]] {
        switch direction {
        case .left:
            return (0..<size).map { row in (0..<size).map { row * size + $0 } }
        case .right:
            return (0..<size).map { row in (0..<size).reversed().map { row * size + $0 } }
        case .up:
            return (0..<size).map { col in (0..<size).map { $0 * size + col } }
        case .down:
            return (0..<size).map { col in (0..<size).reversed().map { $0 * size + col } }
        }
    }

    private mutating func spawnTile(rng: inout SeededGenerator) {
        let emptyIndexes = grid.indices.filter { grid[$0] == 0 }
        guard !emptyIndexes.isEmpty else { return }

        let index = emptyIndexes[rng.nextInt(upperBound: emptyIndexes.count)]
        grid[index] = rng.nextInt(upperBound: 10) == 0 ? 4 : 2
    }
}
