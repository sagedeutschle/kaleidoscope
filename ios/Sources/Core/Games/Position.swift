import Foundation

/// An immutable-ish snapshot of the board. Moves are applied functionally,
/// producing a new Position (see MoveGenerator.makeMove).
struct Position: Hashable, Codable {
    var board: [Piece?]          // 64 entries, index = rank*8 + file
    var sideToMove: PieceColor
    var castling: CastlingRights
    var enPassant: Square?       // square a pawn may move *to* to capture en passant
    var halfmoveClock: Int       // plies since the last pawn move or capture (50-move rule)

    init(board: [Piece?],
         sideToMove: PieceColor,
         castling: CastlingRights = CastlingRights(),
         enPassant: Square? = nil,
         halfmoveClock: Int = 0) {
        precondition(board.count == 64, "board must have 64 squares")
        self.board = board
        self.sideToMove = sideToMove
        self.castling = castling
        self.enPassant = enPassant
        self.halfmoveClock = halfmoveClock
    }

    func piece(at sq: Square) -> Piece? { board[sq.index] }
    func piece(at index: Int) -> Piece? { board[index] }

    /// Identity for threefold-repetition: two positions repeat if they share
    /// piece placement, side to move, castling rights, and en-passant target —
    /// the move clocks are deliberately excluded.
    var repetitionKey: RepetitionKey {
        RepetitionKey(board: board, sideToMove: sideToMove, castling: castling, enPassant: enPassant)
    }

    /// Locate the king of a given color (assumes one exists).
    func kingSquare(of color: PieceColor) -> Square? {
        for i in 0..<64 {
            if let p = board[i], p.type == .king, p.color == color {
                return Square(index: i)
            }
        }
        return nil
    }

    // MARK: - Repetition key

/// A position's identity for repetition purposes (excludes the move clocks).
struct RepetitionKey: Hashable {
    let board: [Piece?]
    let sideToMove: PieceColor
    let castling: CastlingRights
    let enPassant: Square?
}

// MARK: - Standard starting position

    static let initial: Position = {
        var b = [Piece?](repeating: nil, count: 64)

        func place(_ type: PieceType, _ color: PieceColor, _ file: Int, _ rank: Int) {
            b[rank * 8 + file] = Piece(color: color, type: type)
        }

        let backRank: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for file in 0..<8 {
            place(backRank[file], .white, file, 0)
            place(.pawn, .white, file, 1)
            place(.pawn, .black, file, 6)
            place(backRank[file], .black, file, 7)
        }

        return Position(board: b, sideToMove: .white)
    }()
}
