import SwiftUI

enum FacetCategory: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case puzzles = "Puzzles"
    case board = "Board"
    case cards = "Cards"
    case oracle = "Oracle"

    var id: String { rawValue }
}

enum FacetStatus: Equatable {
    case ready
    case comingSoon
}

struct FacetDescriptor: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let accent: Color
    let category: FacetCategory
    let status: FacetStatus
    /// Optional one-line footer shown by the shell. Facets that render their own
    /// live status bar (e.g. Chess) leave this nil.
    var caption: String? = nil
}

enum FacetRegistry {
    static let all: [FacetDescriptor] = [
        FacetDescriptor(id: "chess",
                        title: "Chess",
                        systemImage: "checkerboard.rectangle",
                        accent: Color(red: 0.19, green: 0.50, blue: 0.36),
                        category: .board,
                        status: .ready),
        FacetDescriptor(id: "brick-bench",
                        title: "Brick Bench",
                        systemImage: "shippingbox",
                        accent: Color(red: 0.86, green: 0.35, blue: 0.22),
                        category: .oracle,
                        status: .ready),
        FacetDescriptor(id: "wordle",
                        title: "Wordgame",
                        systemImage: "square.grid.3x3.square",
                        accent: Color(red: 0.33, green: 0.55, blue: 0.30),
                        category: .daily,
                        status: .ready),
        FacetDescriptor(id: "oracle",
                        title: "Oracle",
                        systemImage: "crown",
                        accent: Color(red: 0.62, green: 0.36, blue: 0.72),
                        category: .oracle,
                        status: .ready),
        FacetDescriptor(id: "debt-clock",
                        title: "Debt Clock",
                        systemImage: "chart.line.uptrend.xyaxis",
                        accent: Color(red: 1.00, green: 0.42, blue: 0.33),
                        category: .oracle,
                        status: .ready),
        FacetDescriptor(id: "steam-rewind",
                        title: "Steam Rewind",
                        systemImage: "gamecontroller",
                        accent: Color(red: 0.36, green: 0.60, blue: 0.92),
                        category: .oracle,
                        status: .ready),
        FacetDescriptor(id: "rubiks-cube",
                        title: "Rubik's Cube",
                        systemImage: "cube.transparent",
                        accent: Color(red: 0.08, green: 0.42, blue: 0.82),
                        category: .puzzles,
                        status: .ready),
        FacetDescriptor(id: "2048",
                        title: "2048",
                        systemImage: "square.grid.2x2",
                        accent: Color(red: 0.89, green: 0.59, blue: 0.20),
                        category: .puzzles,
                        status: .ready),
        FacetDescriptor(id: "lights-out",
                        title: "Lights Out",
                        systemImage: "lightbulb",
                        accent: Color(red: 0.95, green: 0.77, blue: 0.22),
                        category: .puzzles,
                        status: .ready),
        FacetDescriptor(id: "minesweeper",
                        title: "Minesweeper",
                        systemImage: "flag",
                        accent: Color(red: 0.74, green: 0.22, blue: 0.27),
                        category: .puzzles,
                        status: .ready),
        FacetDescriptor(id: "snake",
                        title: "Snake",
                        systemImage: "scribble.variable",
                        accent: Color(red: 0.28, green: 0.67, blue: 0.29),
                        category: .puzzles,
                        status: .ready),
        FacetDescriptor(id: "sudoku",
                        title: "Sudoku",
                        systemImage: "number.square",
                        accent: Color(red: 0.20, green: 0.45, blue: 0.78),
                        category: .puzzles,
                        status: .ready),
        FacetDescriptor(id: "sliding-15",
                        title: "Sliding-15",
                        systemImage: "square.grid.4x3.fill",
                        accent: Color(red: 0.24, green: 0.55, blue: 0.66),
                        category: .puzzles,
                        status: .ready),
        FacetDescriptor(id: "nonogram",
                        title: "Nonogram",
                        systemImage: "squareshape.split.3x3",
                        accent: Color(red: 0.48, green: 0.48, blue: 0.52),
                        category: .puzzles,
                        status: .ready),
        FacetDescriptor(id: "reversi",
                        title: "Reversi",
                        systemImage: "circle.grid.cross",
                        accent: Color(red: 0.13, green: 0.39, blue: 0.32),
                        category: .board,
                        status: .ready),
        FacetDescriptor(id: "connect-four",
                        title: "Connect Four",
                        systemImage: "circle.grid.3x3.fill",
                        accent: Color(red: 0.15, green: 0.32, blue: 0.57),
                        category: .board,
                        status: .ready),
        FacetDescriptor(id: "checkers",
                        title: "Checkers",
                        systemImage: "circle.grid.2x2.fill",
                        accent: Color(red: 0.48, green: 0.22, blue: 0.16),
                        category: .board,
                        status: .ready),
        FacetDescriptor(id: "solitaire",
                        title: "Solitaire",
                        systemImage: "suit.spade.fill",
                        accent: Color(red: 0.16, green: 0.45, blue: 0.30),
                        category: .cards,
                        status: .ready),
        FacetDescriptor(id: "gomoku",
                        title: "Gomoku",
                        systemImage: "circle.grid.3x3",
                        accent: Color(red: 0.72, green: 0.55, blue: 0.30),
                        category: .board,
                        status: .ready),
        FacetDescriptor(id: "sea-battle",
                        title: "Sea Battle",
                        systemImage: "lifepreserver",
                        accent: Color(red: 0.22, green: 0.47, blue: 0.66),
                        category: .board,
                        status: .ready),
        FacetDescriptor(id: "crazy-8",
                        title: "Crazy 8",
                        systemImage: "suit.club",
                        accent: Color(red: 0.60, green: 0.28, blue: 0.55),
                        category: .cards,
                        status: .ready),
        FacetDescriptor(id: "spider",
                        title: "Spider",
                        systemImage: "suit.spade",
                        accent: Color(red: 0.25, green: 0.42, blue: 0.30),
                        category: .cards,
                        status: .ready)
    ]

    static var ready: [FacetDescriptor] {
        all.filter { $0.status == .ready }
    }

    static func descriptor(for id: String) -> FacetDescriptor? {
        all.first { $0.id == id }
    }
}
