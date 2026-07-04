import Foundation

struct MinesweeperGame: Codable, Equatable, Hashable {
    enum Status: Codable, Equatable, Hashable {
        case playing
        case won
        case lost
    }

    let width: Int
    let height: Int
    let mineCount: Int
    private let seed: UInt64
    private(set) var mines: Set<Int>
    private(set) var revealed: Set<Int> = []
    private(set) var flagged: Set<Int> = []
    private(set) var status: Status = .playing
    private var hasPlacedMines: Bool

    init(width: Int = 9, height: Int = 9, mineCount: Int = 10, seed: UInt64 = 1) {
        precondition(width > 1 && height > 1)
        precondition(mineCount > 0 && mineCount < width * height)
        self.width = width
        self.height = height
        self.mineCount = mineCount
        self.seed = seed
        self.mines = []
        self.hasPlacedMines = false
    }

    init(width: Int, height: Int, mines: Set<Int>) {
        precondition(width > 1 && height > 1)
        self.width = width
        self.height = height
        self.mineCount = mines.count
        self.seed = 1
        self.mines = mines
        self.hasPlacedMines = true
    }

    func hasMine(row: Int, col: Int) -> Bool {
        guard let index = index(row: row, col: col) else { return false }
        return mines.contains(index)
    }

    func isRevealed(row: Int, col: Int) -> Bool {
        guard let index = index(row: row, col: col) else { return false }
        return revealed.contains(index)
    }

    func isFlagged(row: Int, col: Int) -> Bool {
        guard let index = index(row: row, col: col) else { return false }
        return flagged.contains(index)
    }

    func adjacentMineCount(row: Int, col: Int) -> Int {
        neighbors(row: row, col: col).filter { mines.contains($0) }.count
    }

    mutating func toggleFlag(row: Int, col: Int) {
        guard status == .playing, let index = index(row: row, col: col), !revealed.contains(index) else { return }
        if flagged.contains(index) {
            flagged.remove(index)
        } else {
            flagged.insert(index)
        }
    }

    mutating func reveal(row: Int, col: Int) {
        guard status == .playing, let start = index(row: row, col: col), !flagged.contains(start) else { return }
        if !hasPlacedMines {
            placeMines(avoiding: start)
        }
        guard !revealed.contains(start) else { return }

        if mines.contains(start) {
            revealed.insert(start)
            status = .lost
            return
        }

        floodReveal(from: start)
        updateWinState()
    }

    private mutating func placeMines(avoiding safeIndex: Int) {
        var rng = SeededGenerator(seed: seed)
        var placed: Set<Int> = []
        while placed.count < mineCount {
            let candidate = rng.nextInt(upperBound: width * height)
            if candidate != safeIndex {
                placed.insert(candidate)
            }
        }
        mines = placed
        hasPlacedMines = true
    }

    private mutating func floodReveal(from start: Int) {
        var queue = [start]
        var seen: Set<Int> = []

        while let index = queue.popLast() {
            guard !seen.contains(index), !flagged.contains(index), !mines.contains(index) else { continue }
            seen.insert(index)
            revealed.insert(index)

            let row = index / width
            let col = index % width
            if adjacentMineCount(row: row, col: col) == 0 {
                queue.append(contentsOf: neighbors(row: row, col: col))
            }
        }
    }

    private mutating func updateWinState() {
        let safeCount = width * height - mines.count
        if revealed.count == safeCount {
            status = .won
        }
    }

    private func index(row: Int, col: Int) -> Int? {
        guard (0..<height).contains(row), (0..<width).contains(col) else { return nil }
        return row * width + col
    }

    private func neighbors(row: Int, col: Int) -> [Int] {
        var result: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                if let index = index(row: row + dr, col: col + dc) {
                    result.append(index)
                }
            }
        }
        return result
    }
}
