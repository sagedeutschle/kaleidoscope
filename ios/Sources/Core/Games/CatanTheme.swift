import SwiftUI

// PRISM: CLAIM Claude 2026-07-13 — Catan 3D overhaul (research branch). Themes/customization.
//
// The visual-customization catalog for Catan: board THEMES (island skins), PIECE STYLES, and
// the PLAYER COLOR set. Everything here is pure data (RGB numbers), so the very same catalog
// drives the SwiftUI chrome, the 2D Canvas board, and the 3D SceneKit board — no per-renderer
// duplication. Rendering code reads `.color` (SwiftUI) or `.uiColor` (SceneKit/UIKit).

/// A plain sRGB triple. Theme palettes are numbers so both SwiftUI and SceneKit can consume them.
struct CatanRGB: Codable, Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    var color: Color { Color(red: r, green: g, blue: b) }
    var uiColor: UIColor { UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1) }

    /// Shift toward white (f > 0) or black (f < 0). Used to shade hex side-walls vs. tops.
    func adjusted(_ f: Double) -> CatanRGB {
        if f >= 0 { return CatanRGB(r: r + (1 - r) * f, g: g + (1 - g) * f, b: b + (1 - b) * f) }
        let k = 1 + f
        return CatanRGB(r: max(0, r * k), g: max(0, g * k), b: max(0, b * k))
    }
    var lightened: CatanRGB { adjusted(0.18) }
    var darkened: CatanRGB { adjusted(-0.22) }
}

private func srgb(_ r: Double, _ g: Double, _ b: Double) -> CatanRGB { CatanRGB(r: r, g: g, b: b) }

/// A board skin: a full palette for the island, its water, rim, tokens, background, and the
/// mood of the light. The biome fills are keyed by the producing resource (desert == nil).
struct CatanTheme: Identifiable, Equatable {
    var id: String
    var name: String
    var blurb: String

    var hills: CatanRGB       // brick
    var forest: CatanRGB      // lumber
    var pasture: CatanRGB     // wool
    var fields: CatanRGB      // grain
    var mountains: CatanRGB   // ore
    var desert: CatanRGB
    var water: CatanRGB
    var rim: CatanRGB
    var tokenFace: CatanRGB
    var background: CatanRGB   // SCNView backgroundColor + a hint for the 2D backdrop

    var lightTint: CatanRGB    // key-light color (warmth of the sun/lanterns)
    var ambientScale: Double   // multiplies the base ambient intensity
    var keyScale: Double       // multiplies the base key intensity
    var isNight: Bool          // pieces glow softly at night

    func fill(for resource: CatanResource?) -> CatanRGB {
        switch resource {
        case .brick: return hills
        case .lumber: return forest
        case .wool: return pasture
        case .grain: return fields
        case .ore: return mountains
        case .none: return desert
        }
    }

    // MARK: Catalog

    static let meadow = CatanTheme(
        id: "meadow", name: "Meadow", blurb: "A sunny, grassy island — the cozy default.",
        hills: srgb(0.80, 0.49, 0.30), forest: srgb(0.29, 0.53, 0.33), pasture: srgb(0.67, 0.80, 0.47),
        fields: srgb(0.92, 0.78, 0.36), mountains: srgb(0.56, 0.60, 0.66), desert: srgb(0.90, 0.82, 0.60),
        water: srgb(0.36, 0.62, 0.80), rim: srgb(0.85, 0.74, 0.52), tokenFace: srgb(0.97, 0.94, 0.85),
        background: srgb(0.73, 0.83, 0.87), lightTint: srgb(1.0, 0.97, 0.90),
        ambientScale: 1.0, keyScale: 1.0, isNight: false)

    static let autumn = CatanTheme(
        id: "autumn", name: "Autumn", blurb: "Warm harvest reds, ambers and golds.",
        hills: srgb(0.72, 0.40, 0.24), forest: srgb(0.74, 0.42, 0.18), pasture: srgb(0.80, 0.66, 0.32),
        fields: srgb(0.87, 0.62, 0.22), mountains: srgb(0.50, 0.46, 0.44), desert: srgb(0.82, 0.66, 0.44),
        water: srgb(0.36, 0.52, 0.58), rim: srgb(0.60, 0.42, 0.26), tokenFace: srgb(0.97, 0.91, 0.79),
        background: srgb(0.80, 0.66, 0.50), lightTint: srgb(1.0, 0.92, 0.78),
        ambientScale: 0.95, keyScale: 1.0, isNight: false)

    static let winter = CatanTheme(
        id: "winter", name: "Winter", blurb: "A snow-dusted island under a pale sky.",
        hills: srgb(0.80, 0.66, 0.60), forest: srgb(0.52, 0.66, 0.58), pasture: srgb(0.86, 0.90, 0.90),
        fields: srgb(0.88, 0.84, 0.66), mountains: srgb(0.74, 0.78, 0.84), desert: srgb(0.90, 0.90, 0.92),
        water: srgb(0.60, 0.76, 0.86), rim: srgb(0.82, 0.86, 0.90), tokenFace: srgb(0.99, 0.99, 1.0),
        background: srgb(0.86, 0.90, 0.94), lightTint: srgb(0.92, 0.96, 1.0),
        ambientScale: 1.1, keyScale: 0.92, isNight: false)

    static let candy = CatanTheme(
        id: "candy", name: "Candy", blurb: "Soft pastels — sweet and playful.",
        hills: srgb(0.96, 0.62, 0.62), forest: srgb(0.60, 0.84, 0.66), pasture: srgb(0.80, 0.92, 0.68),
        fields: srgb(0.98, 0.86, 0.52), mountains: srgb(0.72, 0.68, 0.90), desert: srgb(0.98, 0.90, 0.76),
        water: srgb(0.62, 0.80, 0.94), rim: srgb(0.94, 0.80, 0.86), tokenFace: srgb(1.0, 0.98, 0.94),
        background: srgb(0.96, 0.90, 0.94), lightTint: srgb(1.0, 0.98, 0.96),
        ambientScale: 1.15, keyScale: 0.95, isNight: false)

    static let night = CatanTheme(
        id: "night", name: "Cozy Night", blurb: "Lantern-lit island under a starry dark sky.",
        hills: srgb(0.44, 0.29, 0.24), forest: srgb(0.18, 0.33, 0.28), pasture: srgb(0.31, 0.42, 0.31),
        fields: srgb(0.54, 0.45, 0.25), mountains: srgb(0.30, 0.32, 0.40), desert: srgb(0.42, 0.37, 0.31),
        water: srgb(0.10, 0.18, 0.32), rim: srgb(0.22, 0.20, 0.27), tokenFace: srgb(0.93, 0.88, 0.73),
        background: srgb(0.05, 0.07, 0.13), lightTint: srgb(1.0, 0.86, 0.62),
        ambientScale: 0.62, keyScale: 0.82, isNight: true)

    static let classic = CatanTheme(
        id: "classic", name: "Classic", blurb: "The familiar tabletop look.",
        hills: srgb(0.80, 0.44, 0.24), forest: srgb(0.20, 0.44, 0.24), pasture: srgb(0.56, 0.74, 0.40),
        fields: srgb(0.90, 0.76, 0.30), mountains: srgb(0.52, 0.54, 0.58), desert: srgb(0.88, 0.80, 0.58),
        water: srgb(0.26, 0.50, 0.72), rim: srgb(0.70, 0.58, 0.40), tokenFace: srgb(0.96, 0.92, 0.82),
        background: srgb(0.28, 0.48, 0.64), lightTint: srgb(1.0, 0.98, 0.94),
        ambientScale: 1.0, keyScale: 1.0, isNight: false)

    static let all: [CatanTheme] = [meadow, autumn, winter, candy, night, classic]

    static func theme(id: String) -> CatanTheme { all.first { $0.id == id } ?? meadow }
}

/// How the little buildings and roads look.
enum CatanPieceStyle: String, Codable, CaseIterable, Identifiable {
    case cottage   // rounded storybook houses (default)
    case blocky    // chunky toy blocks

    var id: String { rawValue }
    var name: String {
        switch self {
        case .cottage: return "Cottage"
        case .blocky: return "Toy Blocks"
        }
    }
    var blurb: String {
        switch self {
        case .cottage: return "Rounded storybook houses with little roofs."
        case .blocky: return "Chunky, bright building blocks."
        }
    }
}

/// A named player color. Index 0 is the human; the picker lets you choose yours and the bots
/// take the remaining colors so everyone stays distinct.
struct CatanPlayerColor: Identifiable, Equatable {
    var id: String
    var name: String
    var rgb: CatanRGB

    static let choices: [CatanPlayerColor] = [
        CatanPlayerColor(id: "lapis",  name: "Lapis",   rgb: srgb(0.22, 0.48, 0.74)),
        CatanPlayerColor(id: "amber",  name: "Amber",   rgb: srgb(0.90, 0.57, 0.20)),
        CatanPlayerColor(id: "jade",   name: "Jade",    rgb: srgb(0.24, 0.62, 0.44)),
        CatanPlayerColor(id: "garnet", name: "Garnet",  rgb: srgb(0.78, 0.28, 0.34)),
        CatanPlayerColor(id: "plum",   name: "Plum",    rgb: srgb(0.52, 0.36, 0.66)),
        CatanPlayerColor(id: "teal",   name: "Teal",    rgb: srgb(0.20, 0.62, 0.66)),
        CatanPlayerColor(id: "rose",   name: "Rose",    rgb: srgb(0.90, 0.52, 0.62)),
        CatanPlayerColor(id: "slate",  name: "Slate",   rgb: srgb(0.44, 0.48, 0.56)),
    ]

    static func color(id: String) -> CatanPlayerColor { choices.first { $0.id == id } ?? choices[0] }

    /// Ordered per-player colors for a game, given the human's chosen color id. The human keeps
    /// their pick at index 0; bots take the remaining choices in order so no two players clash.
    static func palette(humanColorID: String, playerCount: Int) -> [CatanRGB] {
        let human = color(id: humanColorID)
        var ordered = [human]
        for c in choices where c.id != human.id { ordered.append(c) }
        return (0..<max(1, playerCount)).map { ordered[$0 % ordered.count].rgb }
    }
}
