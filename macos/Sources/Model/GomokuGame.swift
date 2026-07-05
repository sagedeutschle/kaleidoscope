import Foundation

enum GomokuPlayer: String, Codable, Equatable, Hashable {
    case black = "Black"
    case white = "White"

    var opponent: GomokuPlayer {
        self == .black ? .white : .black
    }
}

struct GomokuPoint: Codable, Equatable, Hashable {
    var row: Int
    var col: Int
}

struct GomokuGame: Codable, Equatable, Hashable {
    static let size = 15
    static let stonesToWin = 5

    private(set) var board: [GomokuPlayer?]
    private(set) var currentPlayer: GomokuPlayer
    private(set) var winner: GomokuPlayer?
    private(set) var moveCount: Int

    init(board: [GomokuPlayer?]? = nil,
         currentPlayer: GomokuPlayer = .black,
         winner: GomokuPlayer? = nil) {
        let initialBoard = board ?? Array<GomokuPlayer?>(repeating: nil, count: Self.size * Self.size)
        precondition(initialBoard.count == Self.size * Self.size)
        self.board = initialBoard
        self.currentPlayer = currentPlayer
        self.winner = winner ?? Self.winner(in: initialBoard)
        self.moveCount = initialBoard.compactMap { $0 }.count
    }

    var isDraw: Bool {
        winner == nil && moveCount == Self.size * Self.size
    }

    var isGameOver: Bool {
        winner != nil || isDraw
    }

    func stone(row: Int, col: Int) -> GomokuPlayer? {
        guard let index = index(row: row, col: col) else { return nil }
        return board[index]
    }

    @discardableResult
    mutating func placeStone(row: Int, col: Int) -> Bool {
        guard !isGameOver,
              let index = index(row: row, col: col),
              board[index] == nil else {
            return false
        }

        let player = currentPlayer
        board[index] = player
        moveCount += 1

        if hasFiveConnected(row: row, col: col, player: player) {
            winner = player
        } else if !isDraw {
            currentPlayer = player.opponent
        }

        return true
    }

    mutating func reset() {
        self = GomokuGame()
    }

    private func index(row: Int, col: Int) -> Int? {
        guard (0..<Self.size).contains(row), (0..<Self.size).contains(col) else { return nil }
        return row * Self.size + col
    }

    private func hasFiveConnected(row: Int, col: Int, player: GomokuPlayer) -> Bool {
        Self.directions.contains { direction in
            1
                + countStones(row: row, col: col, delta: direction, player: player)
                + countStones(row: row, col: col, delta: (-direction.0, -direction.1), player: player) >= Self.stonesToWin
        }
    }

    private func countStones(row: Int,
                             col: Int,
                             delta: (Int, Int),
                             player: GomokuPlayer) -> Int {
        var count = 0
        var nextRow = row + delta.0
        var nextCol = col + delta.1

        while stone(row: nextRow, col: nextCol) == player {
            count += 1
            nextRow += delta.0
            nextCol += delta.1
        }

        return count
    }

    private static let directions: [(Int, Int)] = [
        (0, 1),
        (1, 0),
        (1, 1),
        (1, -1)
    ]

    private static func winner(in board: [GomokuPlayer?]) -> GomokuPlayer? {
        for row in 0..<Self.size {
            for col in 0..<Self.size {
                guard let player = board[row * Self.size + col] else { continue }
                for direction in directions {
                    let cells = (0..<Self.stonesToWin).map { offset in
                        (row + direction.0 * offset, col + direction.1 * offset)
                    }
                    guard cells.allSatisfy({ (0..<Self.size).contains($0.0) && (0..<Self.size).contains($0.1) }) else {
                        continue
                    }
                    if cells.allSatisfy({ board[$0.0 * Self.size + $0.1] == player }) {
                        return player
                    }
                }
            }
        }
        return nil
    }
}
