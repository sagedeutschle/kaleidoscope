import Foundation

/// Forsyth–Edwards Notation parsing for `Position`.
///
/// Supports the 4 required FEN fields (placement, side, castling, en passant);
/// the optional halfmove/fullmove clock fields are tolerated but ignored for now.
extension Position {
    init?(fen: String) {
        let fields = fen.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard fields.count >= 4 else { return nil }

        // 1. Piece placement — FEN lists rank 8 first, a-file first within a rank.
        let ranks = fields[0].split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard ranks.count == 8 else { return nil }

        var board = [Piece?](repeating: nil, count: 64)
        for (rowOffset, rankStr) in ranks.enumerated() {
            let rank = 7 - rowOffset
            var file = 0
            for ch in rankStr {
                if ch.isNumber, let empty = ch.wholeNumberValue {
                    file += empty
                } else if let piece = Position.fenPiece(ch) {
                    guard file < 8 else { return nil }
                    board[rank * 8 + file] = piece
                    file += 1
                } else {
                    return nil
                }
            }
            guard file == 8 else { return nil }
        }

        // 2. Side to move
        let side: PieceColor
        switch fields[1] {
        case "w": side = .white
        case "b": side = .black
        default: return nil
        }

        // 3. Castling rights
        var rights = CastlingRights(whiteKingside: false, whiteQueenside: false,
                                    blackKingside: false, blackQueenside: false)
        if fields[2] != "-" {
            for ch in fields[2] {
                switch ch {
                case "K": rights.whiteKingside = true
                case "Q": rights.whiteQueenside = true
                case "k": rights.blackKingside = true
                case "q": rights.blackQueenside = true
                default: return nil
                }
            }
        }

        // 4. En passant target square
        var ep: Square? = nil
        if fields[3] != "-" {
            guard let sq = Position.fenSquare(fields[3]) else { return nil }
            ep = sq
        }

        // 5. Halfmove clock (optional). Reject a present-but-malformed value.
        var halfmove = 0
        if fields.count >= 5 {
            guard let n = Int(fields[4]), n >= 0 else { return nil }
            halfmove = n
        }

        self.init(board: board, sideToMove: side, castling: rights,
                  enPassant: ep, halfmoveClock: halfmove)
    }

    private static func fenPiece(_ ch: Character) -> Piece? {
        let color: PieceColor = ch.isUppercase ? .white : .black
        let type: PieceType
        switch ch.lowercased() {
        case "p": type = .pawn
        case "n": type = .knight
        case "b": type = .bishop
        case "r": type = .rook
        case "q": type = .queen
        case "k": type = .king
        default: return nil
        }
        return Piece(color: color, type: type)
    }

    private static func fenSquare(_ s: String) -> Square? {
        let chars = Array(s)
        guard chars.count == 2,
              let fileAscii = chars[0].lowercased().unicodeScalars.first?.value,
              fileAscii >= 97, fileAscii <= 104,                 // a–h
              let rankNum = chars[1].wholeNumberValue, rankNum >= 1, rankNum <= 8
        else { return nil }
        return Square(file: Int(fileAscii - 97), rank: rankNum - 1)
    }
}
