import Foundation

public enum KaleidoscopePlatform: String, CaseIterable, Codable, Hashable, Sendable {
    case iOS
    case macOS
}

public enum KaleidoscopeFeatureCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case daily = "Daily"
    case puzzles = "Puzzles"
    case board = "Board"
    case cards = "Cards"
    case oracle = "Oracle"
}

public enum KaleidoscopeLeaderboardMetric: String, Codable, Hashable, Sendable {
    case highScore
    case fewestMoves
    case fastestTime

    public var higherIsBetter: Bool {
        self == .highScore
    }
}

public enum KaleidoscopeLeaderboardPeriod: String, Codable, Hashable, Sendable {
    case daily
    case lifetime
}

public struct KaleidoscopeFeature: Codable, Hashable, Identifiable, Sendable {
    public var id: String { canonicalID.rawValue }

    public let canonicalID: KaleidoscopeFeatureID
    public let title: String
    public let category: KaleidoscopeFeatureCategory
    public let iOSID: String?
    public let macOSID: String?
    public let leaderboardMetric: KaleidoscopeLeaderboardMetric?
    public let leaderboardPeriod: KaleidoscopeLeaderboardPeriod
    public let visibleInLaunchReview: Bool

    public init(
        canonicalID: KaleidoscopeFeatureID,
        title: String,
        category: KaleidoscopeFeatureCategory,
        iOSID: String?,
        macOSID: String?,
        leaderboardMetric: KaleidoscopeLeaderboardMetric? = nil,
        leaderboardPeriod: KaleidoscopeLeaderboardPeriod = .lifetime,
        visibleInLaunchReview: Bool = true
    ) {
        self.canonicalID = canonicalID
        self.title = title
        self.category = category
        self.iOSID = iOSID
        self.macOSID = macOSID
        self.leaderboardMetric = leaderboardMetric
        self.leaderboardPeriod = leaderboardPeriod
        self.visibleInLaunchReview = visibleInLaunchReview
    }

    public func platformID(for platform: KaleidoscopePlatform) -> String? {
        switch platform {
        case .iOS: return iOSID
        case .macOS: return macOSID
        }
    }
}

public enum KaleidoscopeFeatureID: String, CaseIterable, Codable, Hashable, Sendable {
    case game2048 = "2048"
    case snake
    case minesweeper
    case sudoku
    case rubiksCube = "rubiks-cube"
    case lightsOut = "lights-out"
    case slidingPuzzle = "sliding-puzzle"
    case nonogram
    case wordgame
    case chess
    case reversi
    case checkers
    case connectFour = "connect-four"
    case solitaire
    case brickBench = "brick-bench"
    case oracle
    case debtClock = "debt-clock"
}

public enum KaleidoscopeFeatureManifest {
    public static let all: [KaleidoscopeFeature] = [
        KaleidoscopeFeature(canonicalID: .game2048,
                            title: "2048",
                            category: .puzzles,
                            iOSID: "2048",
                            macOSID: "2048",
                            leaderboardMetric: .highScore),
        KaleidoscopeFeature(canonicalID: .snake,
                            title: "Snake",
                            category: .puzzles,
                            iOSID: "snake",
                            macOSID: "snake",
                            leaderboardMetric: .highScore),
        KaleidoscopeFeature(canonicalID: .minesweeper,
                            title: "Minesweeper",
                            category: .puzzles,
                            iOSID: "minesweeper",
                            macOSID: "minesweeper",
                            leaderboardMetric: .fastestTime),
        KaleidoscopeFeature(canonicalID: .sudoku,
                            title: "Sudoku",
                            category: .puzzles,
                            iOSID: "sudoku",
                            macOSID: "sudoku"),
        KaleidoscopeFeature(canonicalID: .rubiksCube,
                            title: "Rubik's Cube",
                            category: .puzzles,
                            iOSID: "rubiks",
                            macOSID: "rubiks-cube",
                            leaderboardMetric: .fewestMoves),
        KaleidoscopeFeature(canonicalID: .lightsOut,
                            title: "Lights Out",
                            category: .puzzles,
                            iOSID: "lightsout",
                            macOSID: "lights-out",
                            leaderboardMetric: .fewestMoves),
        KaleidoscopeFeature(canonicalID: .slidingPuzzle,
                            title: "Sliding Puzzle",
                            category: .puzzles,
                            iOSID: "sliding",
                            macOSID: "sliding-15",
                            leaderboardMetric: .fewestMoves),
        KaleidoscopeFeature(canonicalID: .nonogram,
                            title: "Nonogram",
                            category: .puzzles,
                            iOSID: "nonogram",
                            macOSID: "nonogram"),
        KaleidoscopeFeature(canonicalID: .wordgame,
                            title: "Wordgame",
                            category: .daily,
                            iOSID: "wordle",
                            macOSID: "wordle",
                            leaderboardMetric: .fewestMoves,
                            leaderboardPeriod: .daily,
                            visibleInLaunchReview: true),
        KaleidoscopeFeature(canonicalID: .chess,
                            title: "Chess",
                            category: .board,
                            iOSID: "chess",
                            macOSID: "chess"),
        KaleidoscopeFeature(canonicalID: .reversi,
                            title: "Reversi",
                            category: .board,
                            iOSID: "reversi",
                            macOSID: "reversi"),
        KaleidoscopeFeature(canonicalID: .checkers,
                            title: "Checkers",
                            category: .board,
                            iOSID: "checkers",
                            macOSID: "checkers",
                            leaderboardMetric: .highScore),
        KaleidoscopeFeature(canonicalID: .connectFour,
                            title: "Connect Four",
                            category: .board,
                            iOSID: "connectfour",
                            macOSID: "connect-four",
                            leaderboardMetric: .highScore),
        KaleidoscopeFeature(canonicalID: .solitaire,
                            title: "Solitaire",
                            category: .cards,
                            iOSID: "solitaire",
                            macOSID: "solitaire"),
        KaleidoscopeFeature(canonicalID: .brickBench,
                            title: "Brick Bench",
                            category: .oracle,
                            iOSID: "brickbench",
                            macOSID: "brick-bench"),
        KaleidoscopeFeature(canonicalID: .oracle,
                            title: "Oracle",
                            category: .oracle,
                            iOSID: "oracle",
                            macOSID: "oracle"),
        KaleidoscopeFeature(canonicalID: .debtClock,
                            title: "Debt Clock",
                            category: .oracle,
                            iOSID: "debtclock",
                            macOSID: "debt-clock")
    ]

    public static func feature(for canonicalID: KaleidoscopeFeatureID) -> KaleidoscopeFeature? {
        all.first { $0.canonicalID == canonicalID }
    }

    public static func feature(platformID: String, platform: KaleidoscopePlatform) -> KaleidoscopeFeature? {
        all.first { $0.platformID(for: platform) == platformID }
    }

    public static func platformID(for canonicalID: KaleidoscopeFeatureID, platform: KaleidoscopePlatform) -> String? {
        feature(for: canonicalID)?.platformID(for: platform)
    }
}
