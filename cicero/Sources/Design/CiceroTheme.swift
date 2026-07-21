import SwiftUI

/// Central dark "editor" palette + type ramp. Deliberately a single committed
/// look (Cicero forces dark mode), so values here don't need light variants.
enum CiceroTheme {
    // Surfaces
    static let bg = Color(hex: "0E1117")        // app background (deepest)
    static let surface = Color(hex: "161B22")    // cards, editor gutter
    static let surfaceHi = Color(hex: "1F2630")  // raised rows, input fields
    static let border = Color(hex: "2A313C")

    // Text
    static let ink = Color(hex: "E6EDF3")        // primary text
    static let ink2 = Color(hex: "9AA7B4")       // secondary text
    static let faint = Color(hex: "6B7681")      // captions, line numbers

    // Brand / accent
    static let accent = Color(hex: "7AA2F7")     // primary accent (calm blue)
    static let accent2 = Color(hex: "BB9AF7")    // secondary accent (violet)
    static let good = Color(hex: "9ECE6A")
    static let warn = Color(hex: "E0AF68")
    static let bad = Color(hex: "F7768E")

    // Syntax palette (used by SyntaxHighlighter)
    enum Syntax {
        static let plain = ink
        static let keyword = Color(hex: "BB9AF7")
        static let string = Color(hex: "9ECE6A")
        static let number = Color(hex: "FF9E64")
        static let comment = Color(hex: "6B7681")
        static let type = Color(hex: "2AC3DE")
        static let punctuation = Color(hex: "9AA7B4")
    }

    // Type
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Color {
    /// Hex initializer supporting "RGB", "RRGGBB", and "AARRGGBB" (with or
    /// without a leading '#').
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let a, r, g, b: UInt64
        switch raw.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (value >> 8 & 0xF) * 17, (value >> 4 & 0xF) * 17, (value & 0xF) * 17)
        case 6: // RRGGBB
            (a, r, g, b) = (255, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        case 8: // AARRGGBB
            (a, r, g, b) = (value >> 24 & 0xFF, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
