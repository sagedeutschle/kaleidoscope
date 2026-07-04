import SwiftUI
import AppKit

/// A color that bridges SwiftUI (`Color`) and SceneKit/AppKit (`NSColor`),
/// so the 2D and 3D boards stay perfectly in sync on a theme change.
struct ThemeColor: Hashable {
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
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
}

/// A complete board skin, applied identically to both renderers.
struct Theme: Identifiable, Hashable {
    let id: String
    let name: String

    let lightSquare: ThemeColor
    let darkSquare: ThemeColor
    let boardEdge: ThemeColor

    let whitePiece: ThemeColor
    let blackPiece: ThemeColor
    let pieceOutline: ThemeColor

    let selection: ThemeColor   // selected square
    let lastMove: ThemeColor    // from/to of last move
    let legalDot: ThemeColor    // legal-destination markers
    let check: ThemeColor       // king in check

    static let green = Theme(
        id: "green", name: "Green",
        lightSquare: ThemeColor(hex: 0xEEEED2),
        darkSquare:  ThemeColor(hex: 0x769656),
        boardEdge:   ThemeColor(hex: 0x3E4E33),
        whitePiece:  ThemeColor(hex: 0xFAFAF6),
        blackPiece:  ThemeColor(hex: 0x2B2B28),
        pieceOutline:ThemeColor(hex: 0x14140F),
        selection:   ThemeColor(hex: 0xF6F669, a: 0.55),
        lastMove:    ThemeColor(hex: 0xF6F669, a: 0.40),
        legalDot:    ThemeColor(hex: 0x000000, a: 0.22),
        check:       ThemeColor(hex: 0xE05A4B, a: 0.80)
    )

    static let walnut = Theme(
        id: "walnut", name: "Walnut",
        lightSquare: ThemeColor(hex: 0xE6CCA0),
        darkSquare:  ThemeColor(hex: 0x9C6B3F),
        boardEdge:   ThemeColor(hex: 0x4A2F18),
        whitePiece:  ThemeColor(hex: 0xFBF2E2),
        blackPiece:  ThemeColor(hex: 0x33231A),
        pieceOutline:ThemeColor(hex: 0x1C120A),
        selection:   ThemeColor(hex: 0xFFD86B, a: 0.55),
        lastMove:    ThemeColor(hex: 0xFFD86B, a: 0.40),
        legalDot:    ThemeColor(hex: 0x000000, a: 0.22),
        check:       ThemeColor(hex: 0xD24632, a: 0.80)
    )

    static let slate = Theme(
        id: "slate", name: "Slate Blue",
        lightSquare: ThemeColor(hex: 0xDEE3E6),
        darkSquare:  ThemeColor(hex: 0x6F8CA8),
        boardEdge:   ThemeColor(hex: 0x2E3D4D),
        whitePiece:  ThemeColor(hex: 0xFFFFFF),
        blackPiece:  ThemeColor(hex: 0x222A33),
        pieceOutline:ThemeColor(hex: 0x10161D),
        selection:   ThemeColor(hex: 0x86C5FF, a: 0.55),
        lastMove:    ThemeColor(hex: 0x86C5FF, a: 0.42),
        legalDot:    ThemeColor(hex: 0x10161D, a: 0.22),
        check:       ThemeColor(hex: 0xE0584B, a: 0.80)
    )

    static let midnight = Theme(
        id: "midnight", name: "Midnight Neon",
        lightSquare: ThemeColor(hex: 0x3A3F4B),
        darkSquare:  ThemeColor(hex: 0x22252E),
        boardEdge:   ThemeColor(hex: 0x0E0F14),
        whitePiece:  ThemeColor(hex: 0xEDEFFF),
        blackPiece:  ThemeColor(hex: 0x8A7BFF),
        pieceOutline:ThemeColor(hex: 0x05060A),
        selection:   ThemeColor(hex: 0x5BE0C8, a: 0.50),
        lastMove:    ThemeColor(hex: 0x5BE0C8, a: 0.34),
        legalDot:    ThemeColor(hex: 0x5BE0C8, a: 0.45),
        check:       ThemeColor(hex: 0xFF5C7A, a: 0.85)
    )

    static let all: [Theme] = [.green, .walnut, .slate, .midnight]
}
