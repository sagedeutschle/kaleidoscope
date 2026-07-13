public struct GridPress: Codable, Equatable, Hashable, Sendable {
    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

public struct PocketLightsOut: Codable, Equatable, Sendable {
    public private(set) var grid: [Bool]
    public private(set) var moveCount: Int
    public private(set) var solution: [GridPress]

    public init(
        grid: [Bool] = Array(repeating: false, count: 25),
        moveCount: Int = 0,
        solution: [GridPress] = []
    ) {
        precondition(grid.count == 25, "PocketLightsOut requires a 5x5 grid.")
        self.grid = grid
        self.moveCount = moveCount
        self.solution = solution
    }

    public static func newPuzzle(seed: UInt64, pressCount: Int = 10) -> Self {
        var random = SeededRandom(seed: seed)
        var game = Self()
        var presses: [GridPress] = []

        for _ in 0..<max(1, pressCount) {
            let press = GridPress(
                row: random.nextInt(upperBound: 5),
                col: random.nextInt(upperBound: 5)
            )
            presses.append(press)
            game.toggleCross(row: press.row, col: press.col)
        }

        if game.isSolved {
            let press = GridPress(row: 0, col: 0)
            presses.append(press)
            game.toggleCross(row: press.row, col: press.col)
        }

        game.solution = presses
        game.moveCount = 0
        return game
    }

    public var isSolved: Bool {
        grid.allSatisfy { !$0 }
    }

    public var litCount: Int {
        grid.filter { $0 }.count
    }

    public func isLit(row: Int, col: Int) -> Bool {
        guard Self.isValid(row: row, col: col) else { return false }
        return grid[row * 5 + col]
    }

    public mutating func press(row: Int, col: Int) {
        guard Self.isValid(row: row, col: col) else { return }
        toggleCross(row: row, col: col)
        moveCount += 1
    }

    private mutating func toggleCross(row: Int, col: Int) {
        let cells = [
            GridPress(row: row, col: col),
            GridPress(row: row - 1, col: col),
            GridPress(row: row + 1, col: col),
            GridPress(row: row, col: col - 1),
            GridPress(row: row, col: col + 1),
        ]

        for cell in cells where Self.isValid(row: cell.row, col: cell.col) {
            grid[cell.row * 5 + cell.col].toggle()
        }
    }

    private static func isValid(row: Int, col: Int) -> Bool {
        (0..<5).contains(row) && (0..<5).contains(col)
    }
}
