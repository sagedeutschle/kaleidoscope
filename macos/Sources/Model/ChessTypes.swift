import Foundation

// MARK: - Color

enum PieceColor: String, Hashable, CaseIterable, Codable {
    case white, black
    var opposite: PieceColor { self == .white ? .black : .white }
}

// MARK: - Piece

enum PieceType: String, Hashable, CaseIterable, Codable {
    case pawn, knight, bishop, rook, queen, king

    /// Single-letter code (uppercase), e.g. used for SAN / 3D labels.
    var letter: String {
        switch self {
        case .pawn:   return "P"
        case .knight: return "N"
        case .bishop: return "B"
        case .rook:   return "R"
        case .queen:  return "Q"
        case .king:   return "K"
        }
    }

    /// Rough centipawn value, used by the built-in AI.
    var value: Int {
        switch self {
        case .pawn:   return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook:   return 500
        case .queen:  return 900
        case .king:   return 20000
        }
    }
}

struct Piece: Hashable, Codable {
    let color: PieceColor
    let type: PieceType

    /// Unicode chess glyph (filled symbol), colored by view layer.
    var glyph: String {
        switch type {
        case .king:   return "♚"
        case .queen:  return "♛"
        case .rook:   return "♜"
        case .bishop: return "♝"
        case .knight: return "♞"
        case .pawn:   return "♟"
        }
    }
}

// MARK: - Square

/// A board square, 0..63. index = rank * 8 + file.
/// file 0 = a-file, rank 0 = rank 1 (White's home rank).
struct Square: Hashable, Codable {
    let index: Int

    init(index: Int) { self.index = index }
    init(file: Int, rank: Int) { self.index = rank * 8 + file }

    var file: Int { index % 8 }
    var rank: Int { index / 8 }

    var isValid: Bool { index >= 0 && index < 64 }

    var algebraic: String {
        let f = Character(UnicodeScalar(97 + file)!)
        return "\(f)\(rank + 1)"
    }

    static func at(file: Int, rank: Int) -> Square? {
        guard file >= 0, file < 8, rank >= 0, rank < 8 else { return nil }
        return Square(file: file, rank: rank)
    }
}

// MARK: - Move

struct Move: Hashable, Codable {
    let from: Square
    let to: Square
    var promotion: PieceType? = nil
    var isEnPassant: Bool = false
    var isCastleKingside: Bool = false
    var isCastleQueenside: Bool = false
    var isDoublePawnPush: Bool = false

    var isCastle: Bool { isCastleKingside || isCastleQueenside }
}

// MARK: - Castling rights

struct CastlingRights: Hashable, Codable {
    var whiteKingside = true
    var whiteQueenside = true
    var blackKingside = true
    var blackQueenside = true
}

// MARK: - Game status

enum GameStatus: Hashable, Codable {
    case ongoing
    case check(PieceColor)          // the side that is in check (game continues)
    case checkmate(winner: PieceColor)
    case stalemate
    case draw                       // 50-move / insufficient material (v1: reserved)

    var isTerminal: Bool {
        switch self {
        case .checkmate, .stalemate, .draw: return true
        default: return false
        }
    }

    private enum CodingKeys: String, CodingKey { case kind, color, winner }
    private enum Kind: String, Codable { case ongoing, check, checkmate, stalemate, draw }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ongoing:
            try container.encode(Kind.ongoing, forKey: .kind)
        case .check(let color):
            try container.encode(Kind.check, forKey: .kind)
            try container.encode(color, forKey: .color)
        case .checkmate(let winner):
            try container.encode(Kind.checkmate, forKey: .kind)
            try container.encode(winner, forKey: .winner)
        case .stalemate:
            try container.encode(Kind.stalemate, forKey: .kind)
        case .draw:
            try container.encode(Kind.draw, forKey: .kind)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .ongoing:
            self = .ongoing
        case .check:
            self = .check(try container.decode(PieceColor.self, forKey: .color))
        case .checkmate:
            self = .checkmate(winner: try container.decode(PieceColor.self, forKey: .winner))
        case .stalemate:
            self = .stalemate
        case .draw:
            self = .draw
        }
    }
}
