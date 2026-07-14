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
    case workshop = "Workshop"
    case lenses = "Lenses"
}

public enum PrismetPlatformDisposition: String, Codable, Hashable, Sendable {
    case mirrored
    case adapted
    case notApplicable
    case trackedDebt
}

public enum PrismetFeatureCapability: String, CaseIterable, Codable, Hashable, Sendable {
    case soloPlay
    case localTwoPlayer
    case onlineFriend
    case localSave
    case cloudSave
    case leaderboard
    case lens
    case parlorTable
    case ambientSpectator
}

public struct PrismetCapabilityStatus: Codable, Hashable, Sendable {
    public let capability: PrismetFeatureCapability
    public let disposition: PrismetPlatformDisposition
    public let rationale: String?

    public var isAvailable: Bool {
        disposition == .mirrored || disposition == .adapted
    }

    public init(
        capability: PrismetFeatureCapability,
        disposition: PrismetPlatformDisposition,
        rationale: String? = nil
    ) {
        precondition(
            disposition == .mirrored ||
            rationale?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        )
        self.capability = capability
        self.disposition = disposition
        self.rationale = rationale
    }
}

public struct PrismetPlatformSupport: Codable, Hashable, Sendable {
    public let platform: PrismetPlatform
    public let legacyID: String?
    public let presentationDisposition: PrismetPlatformDisposition
    public let presentationRationale: String?
    public let capabilityStatuses: [PrismetCapabilityStatus]

    public init(
        platform: PrismetPlatform,
        legacyID: String?,
        presentationDisposition: PrismetPlatformDisposition,
        presentationRationale: String? = nil,
        capabilityStatuses: [PrismetCapabilityStatus]
    ) {
        precondition(Set(capabilityStatuses.map(\.capability)).count == capabilityStatuses.count)
        precondition(
            presentationDisposition == .mirrored ||
            presentationRationale?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        )
        let presentationIsAvailable = presentationDisposition == .mirrored || presentationDisposition == .adapted
        precondition(!presentationIsAvailable || legacyID?.isEmpty == false)
        self.platform = platform
        self.legacyID = legacyID
        self.presentationDisposition = presentationDisposition
        self.presentationRationale = presentationRationale
        self.capabilityStatuses = capabilityStatuses
    }

    public var capabilities: Set<PrismetFeatureCapability> {
        Set(capabilityStatuses.filter(\.isAvailable).map(\.capability))
    }

    public func status(for capability: PrismetFeatureCapability) -> PrismetCapabilityStatus? {
        capabilityStatuses.first { $0.capability == capability }
    }
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
    case gomoku
    case seaBattle = "sea-battle"
    case catan
    case solitaire
    case spider
    case crazyEight = "crazy-eight"
    case brickBench = "brick-bench"
    case oracle
    case debtClock = "debt-clock"
    case steamRewind = "steam-rewind"
}

public struct PrismetFeature: Codable, Hashable, Identifiable, Sendable {
    public var id: String { canonicalID.rawValue }

    public let canonicalID: PrismetFeatureID
    public let title: String
    public let category: PrismetFeatureCategory
    public let support: [PrismetPlatformSupport]
    public let leaderboardMetric: PrismetLeaderboardMetric?
    public let leaderboardPeriod: PrismetLeaderboardPeriod
    public let visibleInLaunchReview: Bool

    public init(
        canonicalID: PrismetFeatureID,
        title: String,
        category: PrismetFeatureCategory,
        support: [PrismetPlatformSupport],
        leaderboardMetric: PrismetLeaderboardMetric? = nil,
        leaderboardPeriod: PrismetLeaderboardPeriod = .lifetime,
        visibleInLaunchReview: Bool = true
    ) {
        precondition(support.count == PrismetPlatform.allCases.count)
        precondition(Set(support.map(\.platform)) == Set(PrismetPlatform.allCases))
        precondition(support.allSatisfy { record in
            if record.presentationDisposition == .mirrored {
                return record.legacyID?.isEmpty == false
            }
            return record.presentationRationale?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
        })
        self.canonicalID = canonicalID
        self.title = title
        self.category = category
        self.support = support
        self.leaderboardMetric = leaderboardMetric
        self.leaderboardPeriod = leaderboardPeriod
        self.visibleInLaunchReview = visibleInLaunchReview
    }

    public var iOSID: String? { platformID(for: .iOS) }
    public var macOSID: String? { platformID(for: .macOS) }

    public func support(for platform: PrismetPlatform) -> PrismetPlatformSupport? {
        support.first { $0.platform == platform }
    }

    public func platformID(for platform: PrismetPlatform) -> String? {
        support(for: platform)?.legacyID
    }
}

public enum PrismetFeatureCatalog {
    public static let all: [PrismetFeature] = [
        PrismetFeature(
            canonicalID: .game2048,
            title: "2048",
            category: .puzzles,
            support: platformSupport(
                iOSID: "2048",
                macOSID: "2048",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard],
                macAvailable: [.soloPlay, .localSave, .leaderboard],
                macDebt: [(.cloudSave, cloudSaveDebtRationale)]
            ),
            leaderboardMetric: .highScore
        ),
        PrismetFeature(
            canonicalID: .snake,
            title: "Snake",
            category: .puzzles,
            support: platformSupport(
                iOSID: "snake",
                macOSID: "snake",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard],
                macAvailable: [.soloPlay, .localSave, .leaderboard],
                macDebt: [(.cloudSave, cloudSaveDebtRationale)]
            ),
            leaderboardMetric: .highScore
        ),
        PrismetFeature(
            canonicalID: .minesweeper,
            title: "Minesweeper",
            category: .puzzles,
            support: platformSupport(
                iOSID: "minesweeper",
                macOSID: "minesweeper",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [(.cloudSave, cloudSaveDebtRationale)]
            ),
            leaderboardMetric: .fastestTime
        ),
        PrismetFeature(
            canonicalID: .sudoku,
            title: "Sudoku",
            category: .puzzles,
            support: platformSupport(
                iOSID: "sudoku",
                macOSID: "sudoku",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [(.cloudSave, cloudSaveDebtRationale)]
            )
        ),
        PrismetFeature(
            canonicalID: .rubiksCube,
            title: "Rubik's Cube",
            category: .puzzles,
            support: platformSupport(
                iOSID: "rubiks",
                macOSID: "rubiks-cube",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [
                    (.cloudSave, cloudSaveDebtRationale),
                    (.leaderboard, leaderboardDebtRationale)
                ]
            ),
            leaderboardMetric: .fewestMoves
        ),
        PrismetFeature(
            canonicalID: .lightsOut,
            title: "Lights Out",
            category: .puzzles,
            support: platformSupport(
                iOSID: "lightsout",
                macOSID: "lights-out",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [
                    (.cloudSave, cloudSaveDebtRationale),
                    (.leaderboard, leaderboardDebtRationale)
                ]
            ),
            leaderboardMetric: .fewestMoves
        ),
        PrismetFeature(
            canonicalID: .slidingPuzzle,
            title: "Sliding Puzzle",
            category: .puzzles,
            support: platformSupport(
                iOSID: "sliding",
                macOSID: "sliding-15",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [
                    (.cloudSave, cloudSaveDebtRationale),
                    (.leaderboard, leaderboardDebtRationale)
                ]
            ),
            leaderboardMetric: .fewestMoves
        ),
        PrismetFeature(
            canonicalID: .nonogram,
            title: "Nonogram",
            category: .puzzles,
            support: platformSupport(
                iOSID: "nonogram",
                macOSID: "nonogram",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [(.cloudSave, cloudSaveDebtRationale)]
            )
        ),
        PrismetFeature(
            canonicalID: .wordgame,
            title: "Wordgame",
            category: .daily,
            support: platformSupport(
                iOSID: "wordle",
                macOSID: "wordle",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [
                    (.cloudSave, cloudSaveDebtRationale),
                    (.leaderboard, leaderboardDebtRationale)
                ]
            ),
            leaderboardMetric: .fewestMoves,
            leaderboardPeriod: .daily
        ),
        PrismetFeature(
            canonicalID: .chess,
            title: "Chess",
            category: .board,
            support: platformSupport(
                iOSID: "chess",
                macOSID: "chess",
                iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [
                    (.localTwoPlayer, missingChessLocalRationale),
                    (.onlineFriend, onlineFriendDebtRationale),
                    (.cloudSave, cloudSaveDebtRationale)
                ]
            )
        ),
        PrismetFeature(
            canonicalID: .reversi,
            title: "Reversi",
            category: .board,
            support: platformSupport(
                iOSID: "reversi",
                macOSID: "reversi",
                iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave],
                macAvailable: [.localTwoPlayer, .localSave],
                macDebt: [
                    (.soloPlay, missingSoloRationale),
                    (.onlineFriend, onlineFriendDebtRationale),
                    (.cloudSave, cloudSaveDebtRationale)
                ]
            )
        ),
        PrismetFeature(
            canonicalID: .checkers,
            title: "Checkers",
            category: .board,
            support: platformSupport(
                iOSID: "checkers",
                macOSID: "checkers",
                iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave, .leaderboard],
                macAvailable: [.localTwoPlayer, .localSave, .leaderboard],
                macDebt: [
                    (.soloPlay, missingSoloRationale),
                    (.onlineFriend, onlineFriendDebtRationale),
                    (.cloudSave, cloudSaveDebtRationale)
                ]
            ),
            leaderboardMetric: .highScore
        ),
        PrismetFeature(
            canonicalID: .connectFour,
            title: "Connect Four",
            category: .board,
            support: platformSupport(
                iOSID: "connectfour",
                macOSID: "connect-four",
                iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave],
                macAvailable: [.localTwoPlayer, .localSave, .leaderboard],
                macDebt: [
                    (.soloPlay, missingSoloRationale),
                    (.onlineFriend, onlineFriendDebtRationale),
                    (.cloudSave, cloudSaveDebtRationale)
                ]
            ),
            leaderboardMetric: .highScore
        ),
        PrismetFeature(
            canonicalID: .gomoku,
            title: "Gomoku",
            category: .board,
            support: platformSupport(
                iOSID: "gomoku",
                macOSID: "gomoku",
                iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localTwoPlayer, .localSave],
                macDebt: [
                    (.onlineFriend, onlineFriendDebtRationale),
                    (.cloudSave, cloudSaveDebtRationale)
                ]
            )
        ),
        PrismetFeature(
            canonicalID: .seaBattle,
            title: "Sea Battle",
            category: .board,
            support: platformSupport(
                iOSID: "seabattle",
                macOSID: "sea-battle",
                iOSAvailable: [.soloPlay, .onlineFriend, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [
                    (.onlineFriend, onlineFriendDebtRationale),
                    (.cloudSave, cloudSaveDebtRationale)
                ]
            )
        ),
        PrismetFeature(
            canonicalID: .catan,
            title: "Catan",
            category: .board,
            support: platformSupport(
                iOSID: "catan",
                macOSID: nil,
                iOSAvailable: [.soloPlay, .localSave, .cloudSave],
                macAvailable: [],
                macDebt: [
                    (.soloPlay, catanPlayableDebtRationale),
                    (.localSave, catanPlayableDebtRationale),
                    (.cloudSave, cloudSaveDebtRationale)
                ],
                macPresentationDisposition: .trackedDebt,
                macPresentationRationale: catanPresentationRationale
            )
        ),
        PrismetFeature(
            canonicalID: .solitaire,
            title: "Solitaire",
            category: .cards,
            support: platformSupport(
                iOSID: "solitaire",
                macOSID: "solitaire",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localSave, .leaderboard],
                macDebt: [(.cloudSave, cloudSaveDebtRationale)]
            )
        ),
        PrismetFeature(
            canonicalID: .spider,
            title: "Spider",
            category: .cards,
            support: platformSupport(
                iOSID: "spider",
                macOSID: "spider",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [(.cloudSave, cloudSaveDebtRationale)]
            )
        ),
        PrismetFeature(
            canonicalID: .crazyEight,
            title: "Crazy 8",
            category: .cards,
            support: platformSupport(
                iOSID: "crazyeight",
                macOSID: "crazy-8",
                iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localTwoPlayer, .localSave],
                macDebt: [
                    (.onlineFriend, onlineFriendDebtRationale),
                    (.cloudSave, cloudSaveDebtRationale)
                ]
            )
        ),
        PrismetFeature(
            canonicalID: .brickBench,
            title: "Brick Bench",
            category: .workshop,
            support: platformSupport(
                iOSID: "brickbench",
                macOSID: "brick-bench",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave],
                macAvailable: [.soloPlay, .localSave],
                macDebt: [(.cloudSave, cloudSaveDebtRationale)]
            )
        ),
        PrismetFeature(
            canonicalID: .oracle,
            title: "Oracle",
            category: .lenses,
            support: platformSupport(
                iOSID: "oracle",
                macOSID: "oracle",
                iOSAvailable: [.soloPlay, .localSave, .cloudSave, .lens],
                macAvailable: [.lens],
                macDebt: [
                    (.soloPlay, missingSoloRationale),
                    (.localSave, oracleLocalSaveDebtRationale),
                    (.cloudSave, cloudSaveDebtRationale)
                ]
            )
        ),
        PrismetFeature(
            canonicalID: .debtClock,
            title: "Debt Clock",
            category: .lenses,
            support: platformSupport(
                iOSID: "debtclock",
                macOSID: "debt-clock",
                iOSAvailable: [.lens],
                macAvailable: [.lens],
                macDebt: []
            )
        ),
        PrismetFeature(
            canonicalID: .steamRewind,
            title: "Steam Rewind",
            category: .lenses,
            support: platformSupport(
                iOSID: "steamrewind",
                macOSID: "steam-rewind",
                iOSAvailable: [.lens],
                macAvailable: [.lens],
                macDebt: []
            )
        )
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

    private static let nativeMacCapabilityRationale = "Native Mac implementation."
    private static let nativeMacPresentationRationale = "Native Mac input and layout."
    private static let cloudSaveDebtRationale = "Account-scoped cloud save is not wired on macOS."
    private static let onlineFriendDebtRationale = "Online friend play is not wired on macOS."
    private static let leaderboardDebtRationale = "The iOS leaderboard surface is not wired for this game on macOS."
    private static let missingSoloRationale = "The iOS solo opponent mode has no Mac route."
    private static let missingChessLocalRationale = "The model supports local Chess internally, but no current Mac route exposes it."
    private static let catanPlayableDebtRationale = "The active Catan Mac lane has not released its playable route and persistence."
    private static let catanPresentationRationale = "The active Catan Mac lane has not released its route."
    private static let oracleLocalSaveDebtRationale = "Canonical Oracle state is not saved on macOS; only the decree archive persists."

    private static func platformSupport(
        iOSID: String,
        macOSID: String?,
        iOSAvailable: [PrismetFeatureCapability],
        macAvailable: [PrismetFeatureCapability],
        macDebt: [(PrismetFeatureCapability, String)],
        macPresentationDisposition: PrismetPlatformDisposition = .adapted,
        macPresentationRationale: String = nativeMacPresentationRationale
    ) -> [PrismetPlatformSupport] {
        let iOSStatuses = iOSAvailable.map {
            PrismetCapabilityStatus(capability: $0, disposition: .mirrored)
        }
        let macAvailableStatuses = macAvailable.map {
            PrismetCapabilityStatus(
                capability: $0,
                disposition: .adapted,
                rationale: nativeMacCapabilityRationale
            )
        }
        let macDebtStatuses = macDebt.map {
            PrismetCapabilityStatus(
                capability: $0.0,
                disposition: .trackedDebt,
                rationale: $0.1
            )
        }

        return [
            PrismetPlatformSupport(
                platform: .iOS,
                legacyID: iOSID,
                presentationDisposition: .mirrored,
                capabilityStatuses: iOSStatuses
            ),
            PrismetPlatformSupport(
                platform: .macOS,
                legacyID: macOSID,
                presentationDisposition: macPresentationDisposition,
                presentationRationale: macPresentationRationale,
                capabilityStatuses: macAvailableStatuses + macDebtStatuses
            )
        ]
    }
}

/// Compatibility facade for callers that still use the original manifest name.
/// Prefer `PrismetFeatureCatalog` for new code.
public enum PrismetFeatureManifest {
    public static let all = PrismetFeatureCatalog.all

    public static func feature(for canonicalID: PrismetFeatureID) -> PrismetFeature? {
        PrismetFeatureCatalog.feature(for: canonicalID)
    }

    public static func feature(platformID: String, platform: PrismetPlatform) -> PrismetFeature? {
        PrismetFeatureCatalog.feature(platformID: platformID, platform: platform)
    }

    public static func platformID(for canonicalID: PrismetFeatureID, platform: PrismetPlatform) -> String? {
        PrismetFeatureCatalog.platformID(for: canonicalID, platform: platform)
    }
}
