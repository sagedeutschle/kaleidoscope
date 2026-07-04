// PRISM: RELEASE Agent-Design(chess-icons) 2026-07-03
import SwiftUI
import UIKit

/// A color that bridges SwiftUI (`Color`) and SceneKit/UIKit (`UIColor`) so the
/// flat 2D board and the 3D SceneKit board stay in sync on a theme change.
/// Mirrors the macOS app's `ThemeColor` so the two apps share one palette.
struct ChessThemeColor: Hashable {
    let r, g, b, a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// Hex like 0xRRGGBB.
    init(hex: Int, a: Double = 1) {
        self.r = Double((hex >> 16) & 0xFF) / 255
        self.g = Double((hex >> 8) & 0xFF) / 255
        self.b = Double(hex & 0xFF) / 255
        self.a = a
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }
    /// Same hue at full opacity — for 3D geometry (markers, pieces, tiles) where
    /// translucency is controlled by the material, not the color.
    var solidUIColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
}

/// A complete chess board skin, applied identically to the 2D and 3D renderers.
/// Palette values match the macOS Kaleidoscope `Theme` (chess.com-style green is
/// the default) so the two apps look the same.
struct ChessBoardTheme: Identifiable, Hashable {
    let id: String
    let name: String

    let lightSquare: ChessThemeColor
    let darkSquare: ChessThemeColor
    let boardEdge: ChessThemeColor

    let whitePiece: ChessThemeColor
    let blackPiece: ChessThemeColor

    let selection: ChessThemeColor   // selected square
    let lastMove: ChessThemeColor    // from/to of last move
    let legalDot: ChessThemeColor    // legal-destination markers
    let check: ChessThemeColor       // king in check

    static let green = ChessBoardTheme(
        id: "green", name: "Green",
        lightSquare: ChessThemeColor(hex: 0xEBECD0),  // RGB 235,236,208 — chess.com light cream
        darkSquare:  ChessThemeColor(hex: 0x739552),  // RGB 115,149,82 — chess.com dark green
        boardEdge:   ChessThemeColor(hex: 0x3E4E33),
        whitePiece:  ChessThemeColor(hex: 0xFAFAF6),
        blackPiece:  ChessThemeColor(hex: 0x2B2B28),
        selection:   ChessThemeColor(hex: 0xF6F669, a: 0.55),
        lastMove:    ChessThemeColor(hex: 0xF6F669, a: 0.40),
        legalDot:    ChessThemeColor(hex: 0xF6F669),
        check:       ChessThemeColor(hex: 0xE05A4B, a: 0.80)
    )

    static let walnut = ChessBoardTheme(
        id: "walnut", name: "Walnut",
        lightSquare: ChessThemeColor(hex: 0xE6CCA0),
        darkSquare:  ChessThemeColor(hex: 0x9C6B3F),
        boardEdge:   ChessThemeColor(hex: 0x4A2F18),
        whitePiece:  ChessThemeColor(hex: 0xFBF2E2),
        blackPiece:  ChessThemeColor(hex: 0x33231A),
        selection:   ChessThemeColor(hex: 0xFFD86B, a: 0.55),
        lastMove:    ChessThemeColor(hex: 0xFFD86B, a: 0.40),
        legalDot:    ChessThemeColor(hex: 0xFFD86B),
        check:       ChessThemeColor(hex: 0xD24632, a: 0.80)
    )

    static let slate = ChessBoardTheme(
        id: "slate", name: "Slate Blue",
        lightSquare: ChessThemeColor(hex: 0xDEE3E6),
        darkSquare:  ChessThemeColor(hex: 0x6F8CA8),
        boardEdge:   ChessThemeColor(hex: 0x2E3D4D),
        whitePiece:  ChessThemeColor(hex: 0xFFFFFF),
        blackPiece:  ChessThemeColor(hex: 0x222A33),
        selection:   ChessThemeColor(hex: 0x86C5FF, a: 0.55),
        lastMove:    ChessThemeColor(hex: 0x86C5FF, a: 0.42),
        legalDot:    ChessThemeColor(hex: 0x86C5FF),
        check:       ChessThemeColor(hex: 0xE0584B, a: 0.80)
    )

    static let midnight = ChessBoardTheme(
        id: "midnight", name: "Midnight Neon",
        lightSquare: ChessThemeColor(hex: 0x3A3F4B),
        darkSquare:  ChessThemeColor(hex: 0x22252E),
        boardEdge:   ChessThemeColor(hex: 0x0E0F14),
        whitePiece:  ChessThemeColor(hex: 0xEDEFFF),
        blackPiece:  ChessThemeColor(hex: 0x8A7BFF),
        selection:   ChessThemeColor(hex: 0x5BE0C8, a: 0.50),
        lastMove:    ChessThemeColor(hex: 0x5BE0C8, a: 0.34),
        legalDot:    ChessThemeColor(hex: 0x5BE0C8),
        check:       ChessThemeColor(hex: 0xFF5C7A, a: 0.85)
    )

    static let all: [ChessBoardTheme] = [.green, .walnut, .slate, .midnight]

    /// Resolve a persisted id back to a theme, defaulting to chess.com green.
    static func resolve(_ id: String) -> ChessBoardTheme {
        all.first { $0.id == id } ?? .green
    }
}
