import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — simple puzzle persistence/input congruency
struct SlidingPuzzle: Codable, Equatable, Hashable {
    enum Direction: CaseIterable, Codable, Hashable {
        case up
        case down
        case left
        case right
    }

    private(set) var tiles: [Int]

    init(tiles: [Int]) {
        precondition(tiles.count == 16)
        self.tiles = tiles
    }

    static let solved = SlidingPuzzle(tiles: [1, 2, 3, 4,
                                              5, 6, 7, 8,
                                              9, 10, 11, 12,
                                              13, 14, 15, 0])

    static func shuffled(seed: UInt64, moves: Int = 80) -> SlidingPuzzle {
        var puzzle = SlidingPuzzle.solved
        var rng = SeededGenerator(seed: seed)
        for _ in 0..<max(1, moves) {
            let legal = Direction.allCases.filter { puzzle.canMoveBlank($0) }
            puzzle.moveBlank(legal[rng.nextInt(upperBound: legal.count)])
        }
        if puzzle.isSolved {
            _ = puzzle.moveTile(at: 14)
        }
        return puzzle
    }

    var isSolved: Bool {
        tiles == Self.solved.tiles
    }

    var isSolvable: Bool {
        let values = tiles.filter { $0 != 0 }
        var inversions = 0
        for i in values.indices {
            for j in values.indices where j > i && values[i] > values[j] {
                inversions += 1
            }
        }
        let blankRowFromBottom = 4 - (blankIndex / 4)
        return blankRowFromBottom.isMultiple(of: 2) ? !inversions.isMultiple(of: 2) : inversions.isMultiple(of: 2)
    }

    var blankIndex: Int {
        tiles.firstIndex(of: 0) ?? 15
    }

    @discardableResult
    mutating func moveTile(at index: Int) -> Bool {
        guard tiles.indices.contains(index), adjacentIndexes(to: blankIndex).contains(index) else { return false }
        tiles.swapAt(index, blankIndex)
        return true
    }

    @discardableResult
    mutating func moveBlank(_ direction: Direction) -> Bool {
        let blank = blankIndex
        let row = blank / 4
        let col = blank % 4
        let target: Int?
        switch direction {
        case .up: target = row > 0 ? blank - 4 : nil
        case .down: target = row < 3 ? blank + 4 : nil
        case .left: target = col > 0 ? blank - 1 : nil
        case .right: target = col < 3 ? blank + 1 : nil
        }
        guard let target else { return false }
        tiles.swapAt(blank, target)
        return true
    }

    private func canMoveBlank(_ direction: Direction) -> Bool {
        var copy = self
        return copy.moveBlank(direction)
    }

    private func adjacentIndexes(to index: Int) -> Set<Int> {
        let row = index / 4
        let col = index % 4
        var indexes: Set<Int> = []
        if row > 0 { indexes.insert(index - 4) }
        if row < 3 { indexes.insert(index + 4) }
        if col > 0 { indexes.insert(index - 1) }
        if col < 3 { indexes.insert(index + 1) }
        return indexes
    }
}
