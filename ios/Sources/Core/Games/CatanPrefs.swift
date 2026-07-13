import SwiftUI

// PRISM: CLAIM Claude 2026-07-13 — Catan 3D overhaul (research branch). Customization store.
//
// Player-chosen customization, persisted in UserDefaults (app-level prefs, NOT per-game state —
// per-game state lives in CatanSnapshot). Mirrors the PrismetDesign.paper accessor idiom: thin
// computed get/set over UserDefaults with sensible defaults, so any view can read the current
// choice without plumbing.

/// 3D is the star; 2D is the always-playable fallback renderer (honors Sage's "3d option").
enum CatanBoardStyle: String, Codable, CaseIterable, Identifiable {
    case threeD, twoD
    var id: String { rawValue }
    var name: String { self == .threeD ? "3D" : "2D" }
}

enum CatanPrefs {
    private static let d = UserDefaults.standard

    private static func string(_ key: String, _ fallback: String) -> String {
        d.string(forKey: key) ?? fallback
    }
    private static func setString(_ key: String, _ value: String) { d.set(value, forKey: key) }
    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        d.object(forKey: key) == nil ? fallback : d.bool(forKey: key)
    }
    private static func int(_ key: String, _ fallback: Int) -> Int {
        d.object(forKey: key) == nil ? fallback : d.integer(forKey: key)
    }

    // MARK: Keys
    private static let kTheme = "catan.themeID"
    private static let kPiece = "catan.pieceStyle"
    private static let kPlayerColor = "catan.playerColorID"
    private static let kBoardStyle = "catan.boardStyle"
    private static let kAutoRotate = "catan.autoRotate"
    private static let kReduceMotion = "catan.reduceMotion"
    private static let kDifficulty = "catan.difficulty"
    private static let kPlayerCount = "catan.playerCount"

    // MARK: Theme
    static var themeID: String {
        get { string(kTheme, CatanTheme.meadow.id) }
        set { setString(kTheme, newValue) }
    }
    static var theme: CatanTheme { CatanTheme.theme(id: themeID) }

    // MARK: Pieces
    static var pieceStyle: CatanPieceStyle {
        get { CatanPieceStyle(rawValue: string(kPiece, CatanPieceStyle.cottage.rawValue)) ?? .cottage }
        set { setString(kPiece, newValue.rawValue) }
    }

    // MARK: Player color (human's pick)
    static var playerColorID: String {
        get { string(kPlayerColor, CatanPlayerColor.choices[0].id) }
        set { setString(kPlayerColor, newValue) }
    }

    // MARK: Board style
    static var boardStyle: CatanBoardStyle {
        get { CatanBoardStyle(rawValue: string(kBoardStyle, CatanBoardStyle.threeD.rawValue)) ?? .threeD }
        set { setString(kBoardStyle, newValue.rawValue) }
    }

    // MARK: Camera / motion
    static var autoRotate: Bool {
        get { bool(kAutoRotate, false) }
        set { d.set(newValue, forKey: kAutoRotate) }
    }
    /// User can force reduce-motion for the board even if the system setting is off.
    static var reduceMotionOverride: Bool {
        get { bool(kReduceMotion, false) }
        set { d.set(newValue, forKey: kReduceMotion) }
    }
    /// Effective reduce-motion: system accessibility OR the per-game override.
    static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled || reduceMotionOverride }

    // MARK: New-game defaults
    static var difficulty: CatanBotDifficulty {
        get { CatanBotDifficulty(rawValue: string(kDifficulty, CatanBotDifficulty.cozy.rawValue)) ?? .cozy }
        set { setString(kDifficulty, newValue.rawValue) }
    }
    static var playerCount: Int {
        get { min(4, max(2, int(kPlayerCount, 3))) }
        set { d.set(min(4, max(2, newValue)), forKey: kPlayerCount) }
    }

    /// The ordered per-player colors for a game, from the current pick + count.
    static func playerPalette(count: Int) -> [CatanRGB] {
        CatanPlayerColor.palette(humanColorID: playerColorID, playerCount: count)
    }
}
