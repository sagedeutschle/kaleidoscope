// PRISM: RELEASE Agent-B 2026-06-28 — Connect Four clean-room model.

import Foundation

enum ConnectFourPlayer: String, Codable, CaseIterable, Equatable, Hashable {
    case red = "Red"
    case yellow = "Yellow"

    var opponent: ConnectFourPlayer {
        self == .red ? .yellow : .red
    }
}

struct ConnectFourGame: Codable, Equatable, Hashable {
    static let rowCount = 6
    static let columnCount = 7

    private(set) var board: [ConnectFourPlayer?]
    private(set) var currentPlayer: ConnectFourPlayer
    private(set) var winner: ConnectFourPlayer?
    private(set) var moveCount: Int

    init(board: [ConnectFourPlayer?]? = nil, currentPlayer: ConnectFourPlayer = .red) {
        let initialBoard = board ?? Array<ConnectFourPlayer?>(repeating: nil, count: Self.rowCount * Self.columnCount)
        precondition(initialBoard.count == Self.rowCount * Self.columnCount)
        self.board = initialBoard
        self.currentPlayer = currentPlayer
        self.winner = Self.winner(in: initialBoard)
        self.moveCount = initialBoard.compactMap { $0 }.count
    }

    var rows: Int { Self.rowCount }
    var columns: Int { Self.columnCount }

    var isDraw: Bool {
        winner == nil && moveCount == rows * columns
    }

    var isGameOver: Bool {
        winner != nil || isDraw
    }

    var legalColumns: [Int] {
        guard !isGameOver else { return [] }
        return (0..<columns).filter { token(row: 0, column: $0) == nil }
    }

    func token(row: Int, column: Int) -> ConnectFourPlayer? {
        guard let index = index(row: row, column: column) else { return nil }
        return board[index]
    }

    func tokenCount(for player: ConnectFourPlayer) -> Int {
        board.filter { $0 == player }.count
    }

    @discardableResult
    mutating func dropToken(in column: Int) -> Bool {
        guard legalColumns.contains(column),
              let row = stride(from: rows - 1, through: 0, by: -1).first(where: { token(row: $0, column: column) == nil }),
              let index = index(row: row, column: column) else {
            return false
        }

        let player = currentPlayer
        board[index] = player
        moveCount += 1

        if hasFourConnected(row: row, column: column, player: player) {
            winner = player
        } else if !isDraw {
            currentPlayer = player.opponent
        }

        return true
    }

    mutating func reset() {
        self = ConnectFourGame()
    }

    private func index(row: Int, column: Int) -> Int? {
        guard (0..<rows).contains(row), (0..<columns).contains(column) else { return nil }
        return row * columns + column
    }

    private func hasFourConnected(row: Int, column: Int, player: ConnectFourPlayer) -> Bool {
        Self.directions.contains { direction in
            1
                + countTokens(row: row, column: column, delta: direction, player: player)
                + countTokens(row: row, column: column, delta: (-direction.0, -direction.1), player: player) >= 4
        }
    }

    private func countTokens(row: Int,
                             column: Int,
                             delta: (Int, Int),
                             player: ConnectFourPlayer) -> Int {
        var count = 0
        var nextRow = row + delta.0
        var nextColumn = column + delta.1

        while token(row: nextRow, column: nextColumn) == player {
            count += 1
            nextRow += delta.0
            nextColumn += delta.1
        }

        return count
    }

    private static let directions: [(Int, Int)] = [
        (0, 1),
        (1, 0),
        (1, 1),
        (1, -1)
    ]

    private static func winner(in board: [ConnectFourPlayer?]) -> ConnectFourPlayer? {
        for row in 0..<rowCount {
            for column in 0..<columnCount {
                guard let player = board[row * columnCount + column] else { continue }
                for direction in directions {
                    let cells = (0..<4).map { offset in
                        (row + direction.0 * offset, column + direction.1 * offset)
                    }
                    guard cells.allSatisfy({ cell in
                        (0..<rowCount).contains(cell.0) && (0..<columnCount).contains(cell.1)
                    }) else { continue }
                    if cells.allSatisfy({ cell in
                        board[cell.0 * columnCount + cell.1] == player
                    }) {
                        return player
                    }
                }
            }
        }
        return nil
    }
}
