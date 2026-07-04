import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — simple puzzle persistence/input congruency
enum ReversiPiece: String, Codable, Equatable, Hashable {
    case black = "Black"
    case white = "White"

    var opponent: ReversiPiece {
        self == .black ? .white : .black
    }
}

struct ReversiMove: Codable, Equatable, Hashable {
    var row: Int
    var col: Int
}

struct ReversiGame: Codable, Equatable, Hashable {
    static let size = 8

    private(set) var board: [ReversiPiece?]
    private(set) var currentPlayer: ReversiPiece

    init(board: [ReversiPiece?]? = nil, currentPlayer: ReversiPiece = .black) {
        if let board {
            precondition(board.count == Self.size * Self.size)
            self.board = board
        } else {
            var initial = Array<ReversiPiece?>(repeating: nil, count: Self.size * Self.size)
            initial[3 * Self.size + 3] = .white
            initial[3 * Self.size + 4] = .black
            initial[4 * Self.size + 3] = .black
            initial[4 * Self.size + 4] = .white
            self.board = initial
        }
        self.currentPlayer = currentPlayer
    }

    var isGameOver: Bool {
        legalMoves(for: .black).isEmpty && legalMoves(for: .white).isEmpty
    }

    func piece(row: Int, col: Int) -> ReversiPiece? {
        guard let index = index(row: row, col: col) else { return nil }
        return board[index]
    }

    func legalMoves() -> [ReversiMove] {
        legalMoves(for: currentPlayer)
    }

    func legalMoves(for player: ReversiPiece) -> [ReversiMove] {
        var moves: [ReversiMove] = []

        for row in 0..<Self.size {
            for col in 0..<Self.size where piece(row: row, col: col) == nil {
                if !flippedIndexes(row: row, col: col, player: player).isEmpty {
                    moves.append(ReversiMove(row: row, col: col))
                }
            }
        }

        return moves
    }

    func count(for piece: ReversiPiece) -> Int {
        board.filter { $0 == piece }.count
    }

    @discardableResult
    mutating func applyMove(row: Int, col: Int) -> Bool {
        guard let index = index(row: row, col: col), board[index] == nil else { return false }
        let flips = flippedIndexes(row: row, col: col, player: currentPlayer)
        guard !flips.isEmpty else { return false }

        board[index] = currentPlayer
        for flip in flips {
            board[flip] = currentPlayer
        }

        advanceTurn()
        return true
    }

    mutating func passIfNeeded() {
        if legalMoves(for: currentPlayer).isEmpty, !legalMoves(for: currentPlayer.opponent).isEmpty {
            currentPlayer = currentPlayer.opponent
        }
    }

    private mutating func advanceTurn() {
        let opponent = currentPlayer.opponent
        if !legalMoves(for: opponent).isEmpty {
            currentPlayer = opponent
        } else if legalMoves(for: currentPlayer).isEmpty {
            currentPlayer = opponent
        }
    }

    private func flippedIndexes(row: Int, col: Int, player: ReversiPiece) -> [Int] {
        let directions = [
            (-1, -1), (-1, 0), (-1, 1),
            (0, -1),           (0, 1),
            (1, -1),  (1, 0),  (1, 1)
        ]
        var flips: [Int] = []

        for direction in directions {
            var line: [Int] = []
            var nextRow = row + direction.0
            var nextCol = col + direction.1

            while let nextIndex = index(row: nextRow, col: nextCol),
                  let nextPiece = board[nextIndex] {
                if nextPiece == player.opponent {
                    line.append(nextIndex)
                } else {
                    if !line.isEmpty { flips.append(contentsOf: line) }
                    break
                }

                nextRow += direction.0
                nextCol += direction.1
            }
        }

        return flips
    }

    private func index(row: Int, col: Int) -> Int? {
        guard (0..<Self.size).contains(row), (0..<Self.size).contains(col) else { return nil }
        return row * Self.size + col
    }
}
