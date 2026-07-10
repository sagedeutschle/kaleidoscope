import Foundation

public enum PrismetPlatform: String, CaseIterable, Codable, Hashable, Sendable {
    case iOS
    case macOS
}

public enum PrismetFeatureCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case daily = "Daily"
    case puzzles = "Puzzles"
    case board = "Board"
    case cards = "Cards"
    case oracle = "Oracle"
}

public enum PrismetLeaderboardMetric: String, Codable, Hashable, Sendable {
    case highScore
    case fewestMoves
    case fastestTime

    public var higherIsBetter: Bool {
        self == .highScore
    }
}

public enum PrismetLeaderboardPeriod: String, Codable, Hashable, Sendable {
    case daily
    case lifetime
}

public struct PrismetFeature: Codable, Hashable, Identifiable, Sendable {
    public var id: String { canonicalID.rawValue }

    public let canonicalID: PrismetFeatureID
    public let title: String
    public let category: PrismetFeatureCategory
    public let iOSID: String?
    public let macOSID: String?
    public let leaderboardMetric: PrismetLeaderboardMetric?
    public let leaderboardPeriod: PrismetLeaderboardPeriod
    public let visibleInLaunchReview: Bool

    public init(
        canonicalID: PrismetFeatureID,
        title: String,
        category: PrismetFeatureCategory,
        iOSID: String?,
        macOSID: String?,
        leaderboardMetric: PrismetLeaderboardMetric? = nil,
        leaderboardPeriod: PrismetLeaderboardPeriod = .lifetime,
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

    public func platformID(for platform: PrismetPlatform) -> String? {
        switch platform {
        case .iOS: return iOSID
        case .macOS: return macOSID
        }
    }
}

public enum PrismetFeatureID: String, CaseIterable, Codable, Hashable, Sendable {
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

public enum PrismetFeatureManifest {
    public static let all: [PrismetFeature] = [
        PrismetFeature(canonicalID: .game2048,
                            title: "2048",
                            category: .puzzles,
                            iOSID: "2048",
                            macOSID: "2048",
                            leaderboardMetric: .highScore),
        PrismetFeature(canonicalID: .snake,
                            title: "Snake",
                            category: .puzzles,
                            iOSID: "snake",
                            macOSID: "snake",
                            leaderboardMetric: .highScore),
        PrismetFeature(canonicalID: .minesweeper,
                            title: "Minesweeper",
                            category: .puzzles,
                            iOSID: "minesweeper",
                            macOSID: "minesweeper",
                            leaderboardMetric: .fastestTime),
        PrismetFeature(canonicalID: .sudoku,
                            title: "Sudoku",
                            category: .puzzles,
                            iOSID: "sudoku",
                            macOSID: "sudoku"),
        PrismetFeature(canonicalID: .rubiksCube,
                            title: "Rubik's Cube",
                            category: .puzzles,
                            iOSID: "rubiks",
                            macOSID: "rubiks-cube",
                            leaderboardMetric: .fewestMoves),
        PrismetFeature(canonicalID: .lightsOut,
                            title: "Lights Out",
                            category: .puzzles,
                            iOSID: "lightsout",
                            macOSID: "lights-out",
                            leaderboardMetric: .fewestMoves),
        PrismetFeature(canonicalID: .slidingPuzzle,
                            title: "Sliding Puzzle",
                            category: .puzzles,
                            iOSID: "sliding",
                            macOSID: "sliding-15",
                            leaderboardMetric: .fewestMoves),
        PrismetFeature(canonicalID: .nonogram,
                            title: "Nonogram",
                            category: .puzzles,
                            iOSID: "nonogram",
                            macOSID: "nonogram"),
        PrismetFeature(canonicalID: .wordgame,
                            title: "Wordgame",
                            category: .daily,
                            iOSID: "wordle",
                            macOSID: "wordle",
                            leaderboardMetric: .fewestMoves,
                            leaderboardPeriod: .daily,
                            visibleInLaunchReview: true),
        PrismetFeature(canonicalID: .chess,
                            title: "Chess",
                            category: .board,
                            iOSID: "chess",
                            macOSID: "chess"),
        PrismetFeature(canonicalID: .reversi,
                            title: "Reversi",
                            category: .board,
                            iOSID: "reversi",
                            macOSID: "reversi"),
        PrismetFeature(canonicalID: .checkers,
                            title: "Checkers",
                            category: .board,
                            iOSID: "checkers",
                            macOSID: "checkers",
                            leaderboardMetric: .highScore),
        PrismetFeature(canonicalID: .connectFour,
                            title: "Connect Four",
                            category: .board,
                            iOSID: "connectfour",
                            macOSID: "connect-four",
                            leaderboardMetric: .highScore),
        PrismetFeature(canonicalID: .solitaire,
                            title: "Solitaire",
                            category: .cards,
                            iOSID: "solitaire",
                            macOSID: "solitaire"),
        PrismetFeature(canonicalID: .brickBench,
                            title: "Brick Bench",
                            category: .oracle,
                            iOSID: "brickbench",
                            macOSID: "brick-bench"),
        PrismetFeature(canonicalID: .oracle,
                            title: "Oracle",
                            category: .oracle,
                            iOSID: "oracle",
                            macOSID: "oracle"),
        PrismetFeature(canonicalID: .debtClock,
                            title: "Debt Clock",
                            category: .oracle,
                            iOSID: "debtclock",
                            macOSID: "debt-clock")
    ]

    public static func feature(for canonicalID: PrismetFeatureID) -> PrismetFeature? {
        all.first { $0.canonicalID == canonicalID }
    }

    public static func feature(platformID: String, platform: PrismetPlatform) -> PrismetFeature? {
        all.first { $0.platformID(for: platform) == platformID }
    }

    public static func platformID(for canonicalID: PrismetFeatureID, platform: PrismetPlatform) -> String? {
        feature(for: canonicalID)?.platformID(for: platform)
    }
}
