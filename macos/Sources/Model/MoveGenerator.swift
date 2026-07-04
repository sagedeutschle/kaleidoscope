import Foundation

/// Stateless rules engine: legal move generation, attack queries,
/// move application, and game-status evaluation.
enum MoveGenerator {

    // Offsets expressed as (fileDelta, rankDelta).
    private static let knightDeltas = [(1,2),(2,1),(2,-1),(1,-2),(-1,-2),(-2,-1),(-2,1),(-1,2)]
    private static let kingDeltas   = [(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1)]
    private static let bishopDirs   = [(1,1),(1,-1),(-1,1),(-1,-1)]
    private static let rookDirs     = [(1,0),(-1,0),(0,1),(0,-1)]

    // MARK: - Public API

    /// All fully-legal moves for the side to move.
    static func legalMoves(in pos: Position) -> [Move] {
        pseudoLegalMoves(in: pos).filter { isLegal($0, in: pos) }
    }

    /// Fully-legal moves originating from a particular square.
    static func legalMoves(from sq: Square, in pos: Position) -> [Move] {
        legalMoves(in: pos).filter { $0.from == sq }
    }

    static func isInCheck(_ color: PieceColor, in pos: Position) -> Bool {
        guard let k = pos.kingSquare(of: color) else { return false }
        return isAttacked(k, by: color.opposite, in: pos)
    }

    static func status(of pos: Position) -> GameStatus {
        let hasMoves = !legalMoves(in: pos).isEmpty
        let inCheck = isInCheck(pos.sideToMove, in: pos)
        // Mate / stalemate take precedence over any draw claim.
        if !hasMoves {
            return inCheck ? .checkmate(winner: pos.sideToMove.opposite) : .stalemate
        }
        if isInsufficientMaterial(in: pos) { return .draw }
        if pos.halfmoveClock >= 100 { return .draw }   // fifty-move rule (100 plies)
        return inCheck ? .check(pos.sideToMove) : .ongoing
    }

    /// True when the most recent position in `history` has appeared three or
    /// more times (threefold repetition). History should be every position that
    /// has occurred in the game, including the current one.
    static func isThreefoldRepetition(history: [Position]) -> Bool {
        guard let key = history.last?.repetitionKey else { return false }
        return history.reduce(0) { $0 + ($1.repetitionKey == key ? 1 : 0) } >= 3
    }

    /// FIDE "dead position" by insufficient mating material: K vs K,
    /// K + single minor (bishop or knight) vs K, or K+B vs K+B where both
    /// bishops stand on the same color square.
    static func isInsufficientMaterial(in pos: Position) -> Bool {
        var minorCount = 0
        var bishopColorParities: [Int] = []
        for i in 0..<64 {
            guard let p = pos.board[i] else { continue }
            switch p.type {
            case .king:
                continue
            case .pawn, .rook, .queen:
                return false                       // a heavy piece or pawn can mate
            case .knight:
                minorCount += 1
            case .bishop:
                minorCount += 1
                let sq = Square(index: i)
                bishopColorParities.append((sq.file + sq.rank) % 2)
            }
        }
        switch minorCount {
        case 0, 1:
            return true
        case 2:
            return bishopColorParities.count == 2 && bishopColorParities[0] == bishopColorParities[1]
        default:
            return false
        }
    }

    // MARK: - Attack detection

    /// Is `target` attacked by any piece of `color` in this position?
    static func isAttacked(_ target: Square, by color: PieceColor, in pos: Position) -> Bool {
        let tf = target.file, tr = target.rank

        // Pawns: a pawn of `color` attacks diagonally "forward".
        let pawnDir = (color == .white) ? 1 : -1
        for df in [-1, 1] {
            if let s = Square.at(file: tf + df, rank: tr - pawnDir),
               let p = pos.piece(at: s), p.color == color, p.type == .pawn {
                return true
            }
        }

        // Knights
        for (df, dr) in knightDeltas {
            if let s = Square.at(file: tf + df, rank: tr + dr),
               let p = pos.piece(at: s), p.color == color, p.type == .knight {
                return true
            }
        }

        // King (adjacency)
        for (df, dr) in kingDeltas {
            if let s = Square.at(file: tf + df, rank: tr + dr),
               let p = pos.piece(at: s), p.color == color, p.type == .king {
                return true
            }
        }

        // Sliding: bishop/queen on diagonals
        if rayHit(from: target, dirs: bishopDirs, color: color, types: [.bishop, .queen], in: pos) {
            return true
        }
        // Sliding: rook/queen on ranks & files
        if rayHit(from: target, dirs: rookDirs, color: color, types: [.rook, .queen], in: pos) {
            return true
        }

        return false
    }

    private static func rayHit(from target: Square,
                               dirs: [(Int, Int)],
                               color: PieceColor,
                               types: Set<PieceType>,
                               in pos: Position) -> Bool {
        for (df, dr) in dirs {
            var f = target.file + df
            var r = target.rank + dr
            while let s = Square.at(file: f, rank: r) {
                if let p = pos.piece(at: s) {
                    if p.color == color, types.contains(p.type) { return true }
                    break // blocked
                }
                f += df; r += dr
            }
        }
        return false
    }

    // MARK: - Legality (does this move leave our own king safe?)

    static func isLegal(_ move: Move, in pos: Position) -> Bool {
        let mover = pos.sideToMove
        // Castling squares the king passes through must not be attacked.
        if move.isCastleKingside || move.isCastleQueenside {
            if isInCheck(mover, in: pos) { return false }
            let rank = move.from.rank
            let throughFiles = move.isCastleKingside ? [5, 6] : [3, 2]
            for f in throughFiles {
                let s = Square(file: f, rank: rank)
                if isAttacked(s, by: mover.opposite, in: pos) { return false }
            }
        }
        let next = applyToBoard(move, in: pos)
        return !isInCheck(mover, in: next)
    }

    // MARK: - Move application

    /// Apply a move, returning the resulting position (side to move flipped,
    /// castling rights / en passant updated). Assumes `move` is legal.
    static func makeMove(_ move: Move, in pos: Position) -> Position {
        applyToBoard(move, in: pos)
    }

    /// Core board mutation shared by makeMove and the legality probe.
    private static func applyToBoard(_ move: Move, in pos: Position) -> Position {
        var board = pos.board
        let mover = pos.sideToMove
        guard let moving = board[move.from.index] else { return pos }

        // A move resets the 50-move clock if it's a pawn move or a capture
        // (incl. en passant); otherwise the clock advances by one ply.
        let isCapture = pos.board[move.to.index] != nil || move.isEnPassant
        let nextHalfmoveClock = (moving.type == .pawn || isCapture) ? 0 : pos.halfmoveClock + 1

        // Lift the piece.
        board[move.from.index] = nil

        // En passant capture removes the pawn behind the destination.
        if move.isEnPassant {
            let capturedRank = move.to.rank + (mover == .white ? -1 : 1)
            let capSq = Square(file: move.to.file, rank: capturedRank)
            board[capSq.index] = nil
        }

        // Place piece (with promotion if any).
        if let promo = move.promotion {
            board[move.to.index] = Piece(color: mover, type: promo)
        } else {
            board[move.to.index] = moving
        }

        // Castling: relocate the rook.
        if move.isCastleKingside {
            let r = move.from.rank
            board[Square(file: 5, rank: r).index] = board[Square(file: 7, rank: r).index]
            board[Square(file: 7, rank: r).index] = nil
        } else if move.isCastleQueenside {
            let r = move.from.rank
            board[Square(file: 3, rank: r).index] = board[Square(file: 0, rank: r).index]
            board[Square(file: 0, rank: r).index] = nil
        }

        // Update castling rights.
        var castling = pos.castling
        if moving.type == .king {
            if mover == .white { castling.whiteKingside = false; castling.whiteQueenside = false }
            else { castling.blackKingside = false; castling.blackQueenside = false }
        }
        // Rook moved or was captured: clear the matching right.
        func touchRookSquare(_ sq: Square) {
            switch (sq.file, sq.rank) {
            case (0, 0): castling.whiteQueenside = false
            case (7, 0): castling.whiteKingside  = false
            case (0, 7): castling.blackQueenside = false
            case (7, 7): castling.blackKingside  = false
            default: break
            }
        }
        touchRookSquare(move.from)
        touchRookSquare(move.to)

        // En passant target: only set on a double pawn push.
        var ep: Square? = nil
        if move.isDoublePawnPush {
            let midRank = (move.from.rank + move.to.rank) / 2
            ep = Square(file: move.from.file, rank: midRank)
        }

        return Position(board: board,
                        sideToMove: mover.opposite,
                        castling: castling,
                        enPassant: ep,
                        halfmoveClock: nextHalfmoveClock)
    }

    // MARK: - Pseudo-legal generation

    static func pseudoLegalMoves(in pos: Position) -> [Move] {
        var moves: [Move] = []
        let mover = pos.sideToMove
        for i in 0..<64 {
            guard let p = pos.board[i], p.color == mover else { continue }
            let sq = Square(index: i)
            switch p.type {
            case .pawn:   pawnMoves(from: sq, color: mover, pos: pos, into: &moves)
            case .knight: stepMoves(from: sq, deltas: knightDeltas, color: mover, pos: pos, into: &moves)
            case .king:   kingMoves(from: sq, color: mover, pos: pos, into: &moves)
            case .bishop: slideMoves(from: sq, dirs: bishopDirs, color: mover, pos: pos, into: &moves)
            case .rook:   slideMoves(from: sq, dirs: rookDirs, color: mover, pos: pos, into: &moves)
            case .queen:  slideMoves(from: sq, dirs: bishopDirs + rookDirs, color: mover, pos: pos, into: &moves)
            }
        }
        return moves
    }

    private static func stepMoves(from sq: Square, deltas: [(Int, Int)],
                                  color: PieceColor, pos: Position, into moves: inout [Move]) {
        for (df, dr) in deltas {
            guard let s = Square.at(file: sq.file + df, rank: sq.rank + dr) else { continue }
            if let p = pos.piece(at: s), p.color == color { continue }
            moves.append(Move(from: sq, to: s))
        }
    }

    private static func slideMoves(from sq: Square, dirs: [(Int, Int)],
                                   color: PieceColor, pos: Position, into moves: inout [Move]) {
        for (df, dr) in dirs {
            var f = sq.file + df
            var r = sq.rank + dr
            while let s = Square.at(file: f, rank: r) {
                if let p = pos.piece(at: s) {
                    if p.color != color { moves.append(Move(from: sq, to: s)) }
                    break
                }
                moves.append(Move(from: sq, to: s))
                f += df; r += dr
            }
        }
    }

    private static func kingMoves(from sq: Square, color: PieceColor,
                                  pos: Position, into moves: inout [Move]) {
        stepMoves(from: sq, deltas: kingDeltas, color: color, pos: pos, into: &moves)

        // Castling (rights + empty squares; through-check handled in isLegal).
        let rank = (color == .white) ? 0 : 7
        guard sq == Square(file: 4, rank: rank) else { return }
        let rights = pos.castling
        let canK = (color == .white) ? rights.whiteKingside  : rights.blackKingside
        let canQ = (color == .white) ? rights.whiteQueenside : rights.blackQueenside

        func empty(_ files: [Int]) -> Bool {
            files.allSatisfy { pos.piece(at: Square(file: $0, rank: rank)) == nil }
        }

        if canK, empty([5, 6]) {
            moves.append(Move(from: sq, to: Square(file: 6, rank: rank), isCastleKingside: true))
        }
        if canQ, empty([1, 2, 3]) {
            moves.append(Move(from: sq, to: Square(file: 2, rank: rank), isCastleQueenside: true))
        }
    }

    private static func pawnMoves(from sq: Square, color: PieceColor,
                                  pos: Position, into moves: inout [Move]) {
        let dir = (color == .white) ? 1 : -1
        let startRank = (color == .white) ? 1 : 6
        let promoRank = (color == .white) ? 7 : 0

        // Single push
        if let one = Square.at(file: sq.file, rank: sq.rank + dir), pos.piece(at: one) == nil {
            addPawnMove(from: sq, to: one, promoRank: promoRank, into: &moves)
            // Double push
            if sq.rank == startRank,
               let two = Square.at(file: sq.file, rank: sq.rank + 2 * dir),
               pos.piece(at: two) == nil {
                moves.append(Move(from: sq, to: two, isDoublePawnPush: true))
            }
        }

        // Captures (incl. en passant)
        for df in [-1, 1] {
            guard let s = Square.at(file: sq.file + df, rank: sq.rank + dir) else { continue }
            if let p = pos.piece(at: s), p.color == color.opposite {
                addPawnMove(from: sq, to: s, promoRank: promoRank, into: &moves)
            } else if let ep = pos.enPassant, ep == s {
                moves.append(Move(from: sq, to: s, isEnPassant: true))
            }
        }
    }

    private static func addPawnMove(from: Square, to: Square, promoRank: Int, into moves: inout [Move]) {
        if to.rank == promoRank {
            for promo in [PieceType.queen, .rook, .bishop, .knight] {
                moves.append(Move(from: from, to: to, promotion: promo))
            }
        } else {
            moves.append(Move(from: from, to: to))
        }
    }
}
