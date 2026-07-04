// PRISM: RELEASE Agent-B 2026-06-28 — clean-room Checkers model.
import Foundation

enum CheckersPlayer: String, Codable, Equatable, Hashable {
    case dark = "Dark"
    case light = "Light"

    var opponent: CheckersPlayer {
        self == .dark ? .light : .dark
    }

    var forwardRowDelta: Int {
        self == .dark ? -1 : 1
    }

    var promotionRow: Int {
        self == .dark ? 0 : CheckersGame.size - 1
    }
}

enum CheckersPieceKind: String, Codable, Equatable, Hashable {
    case man
    case king
}

struct CheckersPiece: Codable, Equatable, Hashable {
    var player: CheckersPlayer
    var kind: CheckersPieceKind
}

struct CheckersPoint: Codable, Equatable, Hashable {
    var row: Int
    var col: Int
}

struct CheckersMove: Codable, Equatable, Hashable {
    var from: CheckersPoint
    var to: CheckersPoint
    var captured: CheckersPoint?

    init(from: CheckersPoint, to: CheckersPoint, captured: CheckersPoint? = nil) {
        self.from = from
        self.to = to
        self.captured = captured
    }

    var isCapture: Bool {
        captured != nil
    }
}

struct CheckersGame: Codable, Equatable, Hashable {
    static let size = 8

    private(set) var board: [CheckersPiece?]
    private(set) var currentPlayer: CheckersPlayer
    private(set) var activeJumpOrigin: CheckersPoint?

    init(board: [CheckersPiece?]? = nil,
         currentPlayer: CheckersPlayer = .dark,
         activeJumpOrigin: CheckersPoint? = nil) {
        if let board {
            precondition(board.count == Self.size * Self.size)
            self.board = board
        } else {
            self.board = Self.initialBoard()
        }
        self.currentPlayer = currentPlayer
        self.activeJumpOrigin = activeJumpOrigin
    }

    static func board(pieces: [(Int, Int, CheckersPiece)]) -> [CheckersPiece?] {
        var board = Array<CheckersPiece?>(repeating: nil, count: size * size)
        for piece in pieces {
            guard let index = index(row: piece.0, col: piece.1),
                  isPlayable(row: piece.0, col: piece.1) else { continue }
            board[index] = piece.2
        }
        return board
    }

    static func isPlayable(row: Int, col: Int) -> Bool {
        guard (0..<size).contains(row), (0..<size).contains(col) else { return false }
        return (row + col) % 2 == 1
    }

    var isGameOver: Bool {
        winner != nil
    }

    var winner: CheckersPlayer? {
        let darkCount = count(for: .dark)
        let lightCount = count(for: .light)

        if darkCount == 0, lightCount == 0 { return nil }
        if darkCount == 0 { return .light }
        if lightCount == 0 { return .dark }
        if availableMoves(for: currentPlayer, restrictedTo: activeJumpOrigin).isEmpty {
            return currentPlayer.opponent
        }
        return nil
    }

    func piece(row: Int, col: Int) -> CheckersPiece? {
        guard let index = Self.index(row: row, col: col) else { return nil }
        return board[index]
    }

    func piece(at point: CheckersPoint) -> CheckersPiece? {
        piece(row: point.row, col: point.col)
    }

    func count(for player: CheckersPlayer) -> Int {
        board.filter { $0?.player == player }.count
    }

    func resultScore(for player: CheckersPlayer) -> Int? {
        guard winner == player else { return nil }
        let winnerPieces = count(for: player)
        let loserPieces = count(for: player.opponent)
        let winnerKings = board.compactMap { $0 }.filter { $0.player == player && $0.kind == .king }.count
        return (winnerPieces - loserPieces) * 100 + winnerKings * 25
    }

    func legalMoves() -> [CheckersMove] {
        availableMoves(for: currentPlayer, restrictedTo: activeJumpOrigin)
    }

    @discardableResult
    mutating func applyMove(_ move: CheckersMove) -> Bool {
        guard let legalMove = legalMoves().first(where: { $0 == move }),
              let fromIndex = Self.index(legalMove.from),
              let toIndex = Self.index(legalMove.to),
              var movingPiece = board[fromIndex],
              movingPiece.player == currentPlayer,
              board[toIndex] == nil else { return false }

        board[fromIndex] = nil
        if let captured = legalMove.captured, let capturedIndex = Self.index(captured) {
            board[capturedIndex] = nil
        }

        let promoted = movingPiece.kind == .man && legalMove.to.row == movingPiece.player.promotionRow
        if promoted {
            movingPiece.kind = .king
        }
        board[toIndex] = movingPiece

        if legalMove.isCapture, !promoted {
            let continuation = captureMoves(from: legalMove.to, piece: movingPiece)
            if !continuation.isEmpty {
                activeJumpOrigin = legalMove.to
                return true
            }
        }

        activeJumpOrigin = nil
        currentPlayer = currentPlayer.opponent
        return true
    }

    private static func initialBoard() -> [CheckersPiece?] {
        var board = Array<CheckersPiece?>(repeating: nil, count: size * size)
        for row in 0..<size {
            for col in 0..<size where isPlayable(row: row, col: col) {
                guard let index = index(row: row, col: col) else { continue }
                if row <= 2 {
                    board[index] = CheckersPiece(player: .light, kind: .man)
                } else if row >= 5 {
                    board[index] = CheckersPiece(player: .dark, kind: .man)
                }
            }
        }
        return board
    }

    private func availableMoves(for player: CheckersPlayer, restrictedTo point: CheckersPoint?) -> [CheckersMove] {
        let points = pointsForMovablePieces(player: player, restrictedTo: point)
        let captures = points.flatMap { source -> [CheckersMove] in
            guard let piece = piece(at: source) else { return [] }
            return captureMoves(from: source, piece: piece)
        }
        if !captures.isEmpty { return captures }
        guard point == nil else { return [] }
        return points.flatMap { source -> [CheckersMove] in
            guard let piece = piece(at: source) else { return [] }
            return quietMoves(from: source, piece: piece)
        }
    }

    private func pointsForMovablePieces(player: CheckersPlayer, restrictedTo point: CheckersPoint?) -> [CheckersPoint] {
        if let point, piece(at: point)?.player == player {
            return [point]
        }

        var points: [CheckersPoint] = []
        for row in 0..<Self.size {
            for col in 0..<Self.size {
                if piece(row: row, col: col)?.player == player {
                    points.append(CheckersPoint(row: row, col: col))
                }
            }
        }
        return points
    }

    private func quietMoves(from source: CheckersPoint, piece: CheckersPiece) -> [CheckersMove] {
        var moves: [CheckersMove] = []
        for rowDelta in rowDirections(for: piece) {
            for colDelta in [-1, 1] {
                let target = CheckersPoint(row: source.row + rowDelta, col: source.col + colDelta)
                if Self.isPlayable(row: target.row, col: target.col), self.piece(at: target) == nil {
                    moves.append(CheckersMove(from: source, to: target))
                }
            }
        }
        return moves
    }

    private func captureMoves(from source: CheckersPoint, piece: CheckersPiece) -> [CheckersMove] {
        var moves: [CheckersMove] = []
        for rowDelta in rowDirections(for: piece) {
            for colDelta in [-1, 1] {
                let jumped = CheckersPoint(row: source.row + rowDelta, col: source.col + colDelta)
                let target = CheckersPoint(row: source.row + rowDelta * 2, col: source.col + colDelta * 2)
                if Self.isPlayable(row: target.row, col: target.col),
                   self.piece(at: target) == nil,
                   self.piece(at: jumped)?.player == piece.player.opponent {
                    moves.append(CheckersMove(from: source, to: target, captured: jumped))
                }
            }
        }
        return moves
    }

    private func rowDirections(for piece: CheckersPiece) -> [Int] {
        piece.kind == .king ? [-1, 1] : [piece.player.forwardRowDelta]
    }

    private static func index(_ point: CheckersPoint) -> Int? {
        index(row: point.row, col: point.col)
    }

    private static func index(row: Int, col: Int) -> Int? {
        guard (0..<size).contains(row), (0..<size).contains(col) else { return nil }
        return row * size + col
    }
}
