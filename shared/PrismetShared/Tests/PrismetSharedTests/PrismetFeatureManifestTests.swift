import XCTest
import PrismetShared

final class PrismetFeatureManifestTests: XCTestCase {
    func testCatalogInventoryMatchesCanonicalFeatureTable() {
        XCTAssertEqual(
            PrismetFeatureCategory.allCases.map(\.rawValue),
            ["Daily", "Puzzles", "Board", "Cards", "Workshop", "Lenses"]
        )
        XCTAssertEqual(PrismetFeatureID.allCases.count, 23)
        XCTAssertEqual(PrismetFeatureCatalog.all.count, 23)
        XCTAssertEqual(Set(PrismetFeatureCatalog.all.map(\.canonicalID)).count, 23)

        let actual = PrismetFeatureCatalog.all.map {
            ExpectedFeature(
                canonicalID: $0.canonicalID,
                title: $0.title,
                category: $0.category,
                iOSID: $0.iOSID,
                macOSID: $0.macOSID
            )
        }
        XCTAssertEqual(actual, expectedFeatures)

        XCTAssertEqual(PrismetFeatureCatalog.platformID(for: .rubiksCube, platform: .iOS), "rubiks")
        XCTAssertEqual(PrismetFeatureCatalog.platformID(for: .rubiksCube, platform: .macOS), "rubiks-cube")
        XCTAssertEqual(PrismetFeatureCatalog.platformID(for: .slidingPuzzle, platform: .macOS), "sliding-15")
        XCTAssertEqual(PrismetFeatureCatalog.platformID(for: .crazyEight, platform: .macOS), "crazy-8")
        XCTAssertNil(PrismetFeatureCatalog.platformID(for: .catan, platform: .macOS))
    }

    func testEveryNonNilPlatformIDIsUniqueAndRoundTrips() {
        for platform in PrismetPlatform.allCases {
            let platformIDs = PrismetFeatureCatalog.all.compactMap { $0.platformID(for: platform) }
            XCTAssertEqual(Set(platformIDs).count, platformIDs.count, "\(platform.rawValue) ids must stay unique")

            for feature in PrismetFeatureCatalog.all {
                guard let platformID = feature.platformID(for: platform) else { continue }
                XCTAssertEqual(
                    PrismetFeatureCatalog.feature(platformID: platformID, platform: platform)?.canonicalID,
                    feature.canonicalID
                )
            }
        }
    }

    func testCapabilityMatrixMatchesObservedPlatformBehavior() throws {
        XCTAssertEqual(Set(capabilityMatrix.keys), Set(PrismetFeatureID.allCases))

        for canonicalID in PrismetFeatureID.allCases {
            let row = try XCTUnwrap(capabilityMatrix[canonicalID])
            let feature = try XCTUnwrap(PrismetFeatureCatalog.feature(for: canonicalID))
            let iOSSupport = try XCTUnwrap(feature.support(for: .iOS))
            let macSupport = try XCTUnwrap(feature.support(for: .macOS))

            XCTAssertEqual(iOSSupport.capabilities, row.iOSAvailable, "\(canonicalID.rawValue) iOS availability")
            XCTAssertEqual(iOSSupport.capabilityStatuses.count, row.iOSAvailable.count)
            XCTAssertEqual(macSupport.capabilities, row.macAvailable, "\(canonicalID.rawValue) Mac availability")
            XCTAssertEqual(macSupport.capabilityStatuses.count, row.macAvailable.count + row.macDebt.count)

            for capability in PrismetFeatureCapability.allCases {
                if row.iOSAvailable.contains(capability) {
                    let status = try XCTUnwrap(
                        iOSSupport.status(for: capability),
                        "Missing \(canonicalID.rawValue) iOS \(capability.rawValue)"
                    )
                    XCTAssertEqual(status.disposition, .mirrored)
                    XCTAssertNil(status.rationale)
                } else {
                    XCTAssertNil(iOSSupport.status(for: capability))
                }

                if row.macAvailable.contains(capability) {
                    let status = try XCTUnwrap(
                        macSupport.status(for: capability),
                        "Missing \(canonicalID.rawValue) Mac \(capability.rawValue)"
                    )
                    XCTAssertEqual(status.disposition, .adapted)
                    XCTAssertEqual(status.rationale, "Native Mac implementation.")
                } else if row.macDebt.contains(capability) {
                    let status = try XCTUnwrap(
                        macSupport.status(for: capability),
                        "Missing \(canonicalID.rawValue) Mac debt \(capability.rawValue)"
                    )
                    XCTAssertEqual(status.disposition, .trackedDebt)
                    XCTAssertEqual(status.rationale, expectedDebtRationale(for: canonicalID, capability: capability))
                } else {
                    XCTAssertNil(macSupport.status(for: capability))
                }
            }
        }
    }

    func testPresentationStatusIsSeparateFromCapabilityDebt() throws {
        for feature in PrismetFeatureCatalog.all {
            let iOSSupport = try XCTUnwrap(feature.support(for: .iOS))
            XCTAssertEqual(iOSSupport.presentationDisposition, .mirrored)
            XCTAssertNil(iOSSupport.presentationRationale)
            XCTAssertNotNil(iOSSupport.legacyID)

            let macSupport = try XCTUnwrap(feature.support(for: .macOS))
            if feature.canonicalID == .catan {
                XCTAssertEqual(macSupport.presentationDisposition, .trackedDebt)
                XCTAssertEqual(macSupport.presentationRationale, "The active Catan Mac lane has not released its route.")
                XCTAssertNil(macSupport.legacyID)
            } else {
                XCTAssertEqual(macSupport.presentationDisposition, .adapted)
                XCTAssertEqual(macSupport.presentationRationale, "Native Mac input and layout.")
                XCTAssertNotNil(macSupport.legacyID)
            }
        }

        let rubiksMac = try XCTUnwrap(PrismetFeatureCatalog.feature(for: .rubiksCube)?.support(for: .macOS))
        XCTAssertEqual(rubiksMac.presentationDisposition, .adapted)
        XCTAssertEqual(rubiksMac.status(for: .cloudSave)?.disposition, .trackedDebt)
        XCTAssertEqual(rubiksMac.status(for: .leaderboard)?.disposition, .trackedDebt)
    }

    func testEveryNonMirroredRecordHasANonEmptyRationale() {
        for feature in PrismetFeatureCatalog.all {
            for support in feature.support where support.presentationDisposition != .mirrored {
                XCTAssertFalse(
                    support.presentationRationale?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
                    "\(feature.canonicalID.rawValue) \(support.platform.rawValue) presentation needs a rationale"
                )
            }

            for support in feature.support {
                for status in support.capabilityStatuses where status.disposition != .mirrored {
                    XCTAssertFalse(
                        status.rationale?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
                        "\(feature.canonicalID.rawValue) \(support.platform.rawValue) \(status.capability.rawValue) needs a rationale"
                    )
                }
            }
        }
    }

    func testCompatibilityFacadeForwardsCatalog() {
        XCTAssertEqual(PrismetFeatureManifest.all, PrismetFeatureCatalog.all)

        for feature in PrismetFeatureCatalog.all {
            XCTAssertEqual(
                PrismetFeatureManifest.feature(for: feature.canonicalID),
                PrismetFeatureCatalog.feature(for: feature.canonicalID)
            )

            for platform in PrismetPlatform.allCases {
                XCTAssertEqual(
                    PrismetFeatureManifest.platformID(for: feature.canonicalID, platform: platform),
                    PrismetFeatureCatalog.platformID(for: feature.canonicalID, platform: platform)
                )

                guard let platformID = feature.platformID(for: platform) else { continue }
                XCTAssertEqual(
                    PrismetFeatureManifest.feature(platformID: platformID, platform: platform),
                    PrismetFeatureCatalog.feature(platformID: platformID, platform: platform)
                )
            }
        }
    }

    func testWordgameLaunchReviewAndLeaderboardCompatibilityMetadataAreShared() throws {
        let wordgame = try XCTUnwrap(PrismetFeatureCatalog.feature(for: .wordgame))
        XCTAssertEqual(wordgame.category, .daily)
        XCTAssertTrue(wordgame.visibleInLaunchReview)
        XCTAssertEqual(wordgame.leaderboardMetric, .fewestMoves)
        XCTAssertEqual(wordgame.leaderboardPeriod, .daily)
        XCTAssertFalse(PrismetLeaderboardMetric.fewestMoves.higherIsBetter)
    }

    func testPublicCatalogValueTypesCanBeConstructed() {
        let iOSStatus = PrismetCapabilityStatus(capability: .soloPlay, disposition: .mirrored)
        let macStatus = PrismetCapabilityStatus(
            capability: .soloPlay,
            disposition: .adapted,
            rationale: "Native Mac implementation."
        )
        let iOSSupport = PrismetPlatformSupport(
            platform: .iOS,
            legacyID: "2048",
            presentationDisposition: .mirrored,
            capabilityStatuses: [iOSStatus]
        )
        let macSupport = PrismetPlatformSupport(
            platform: .macOS,
            legacyID: "2048",
            presentationDisposition: .adapted,
            presentationRationale: "Native Mac input and layout.",
            capabilityStatuses: [macStatus]
        )
        let feature = PrismetFeature(
            canonicalID: .game2048,
            title: "2048",
            category: .puzzles,
            support: [iOSSupport, macSupport]
        )

        XCTAssertEqual(feature.id, "2048")
        XCTAssertEqual(feature.iOSID, "2048")
        XCTAssertEqual(feature.macOSID, "2048")
    }
}

private struct ExpectedFeature: Equatable {
    let canonicalID: PrismetFeatureID
    let title: String
    let category: PrismetFeatureCategory
    let iOSID: String?
    let macOSID: String?
}

private struct CapabilityRow {
    let iOSAvailable: Set<PrismetFeatureCapability>
    let macAvailable: Set<PrismetFeatureCapability>
    let macDebt: Set<PrismetFeatureCapability>
}

private extension PrismetFeatureManifestTests {
    var expectedFeatures: [ExpectedFeature] {
        [
            ExpectedFeature(canonicalID: .game2048, title: "2048", category: .puzzles, iOSID: "2048", macOSID: "2048"),
            ExpectedFeature(canonicalID: .snake, title: "Snake", category: .puzzles, iOSID: "snake", macOSID: "snake"),
            ExpectedFeature(canonicalID: .minesweeper, title: "Minesweeper", category: .puzzles, iOSID: "minesweeper", macOSID: "minesweeper"),
            ExpectedFeature(canonicalID: .sudoku, title: "Sudoku", category: .puzzles, iOSID: "sudoku", macOSID: "sudoku"),
            ExpectedFeature(canonicalID: .rubiksCube, title: "Rubik's Cube", category: .puzzles, iOSID: "rubiks", macOSID: "rubiks-cube"),
            ExpectedFeature(canonicalID: .lightsOut, title: "Lights Out", category: .puzzles, iOSID: "lightsout", macOSID: "lights-out"),
            ExpectedFeature(canonicalID: .slidingPuzzle, title: "Sliding Puzzle", category: .puzzles, iOSID: "sliding", macOSID: "sliding-15"),
            ExpectedFeature(canonicalID: .nonogram, title: "Nonogram", category: .puzzles, iOSID: "nonogram", macOSID: "nonogram"),
            ExpectedFeature(canonicalID: .wordgame, title: "Wordgame", category: .daily, iOSID: "wordle", macOSID: "wordle"),
            ExpectedFeature(canonicalID: .chess, title: "Chess", category: .board, iOSID: "chess", macOSID: "chess"),
            ExpectedFeature(canonicalID: .reversi, title: "Reversi", category: .board, iOSID: "reversi", macOSID: "reversi"),
            ExpectedFeature(canonicalID: .checkers, title: "Checkers", category: .board, iOSID: "checkers", macOSID: "checkers"),
            ExpectedFeature(canonicalID: .connectFour, title: "Connect Four", category: .board, iOSID: "connectfour", macOSID: "connect-four"),
            ExpectedFeature(canonicalID: .gomoku, title: "Gomoku", category: .board, iOSID: "gomoku", macOSID: "gomoku"),
            ExpectedFeature(canonicalID: .seaBattle, title: "Sea Battle", category: .board, iOSID: "seabattle", macOSID: "sea-battle"),
            ExpectedFeature(canonicalID: .catan, title: "Catan", category: .board, iOSID: "catan", macOSID: nil),
            ExpectedFeature(canonicalID: .solitaire, title: "Solitaire", category: .cards, iOSID: "solitaire", macOSID: "solitaire"),
            ExpectedFeature(canonicalID: .spider, title: "Spider", category: .cards, iOSID: "spider", macOSID: "spider"),
            ExpectedFeature(canonicalID: .crazyEight, title: "Crazy 8", category: .cards, iOSID: "crazyeight", macOSID: "crazy-8"),
            ExpectedFeature(canonicalID: .brickBench, title: "Brick Bench", category: .workshop, iOSID: "brickbench", macOSID: "brick-bench"),
            ExpectedFeature(canonicalID: .oracle, title: "Oracle", category: .lenses, iOSID: "oracle", macOSID: "oracle"),
            ExpectedFeature(canonicalID: .debtClock, title: "Debt Clock", category: .lenses, iOSID: "debtclock", macOSID: "debt-clock"),
            ExpectedFeature(canonicalID: .steamRewind, title: "Steam Rewind", category: .lenses, iOSID: "steamrewind", macOSID: "steam-rewind")
        ]
    }

    var capabilityMatrix: [PrismetFeatureID: CapabilityRow] {
        [
            .game2048: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard], macAvailable: [.soloPlay, .localSave, .leaderboard], macDebt: [.cloudSave]),
            .snake: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard], macAvailable: [.soloPlay, .localSave, .leaderboard], macDebt: [.cloudSave]),
            .minesweeper: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave], macAvailable: [.soloPlay, .localSave], macDebt: [.cloudSave]),
            .sudoku: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave], macAvailable: [.soloPlay, .localSave], macDebt: [.cloudSave]),
            .rubiksCube: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard], macAvailable: [.soloPlay, .localSave], macDebt: [.cloudSave, .leaderboard]),
            .lightsOut: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard], macAvailable: [.soloPlay, .localSave], macDebt: [.cloudSave, .leaderboard]),
            .slidingPuzzle: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard], macAvailable: [.soloPlay, .localSave], macDebt: [.cloudSave, .leaderboard]),
            .nonogram: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave], macAvailable: [.soloPlay, .localSave], macDebt: [.cloudSave]),
            .wordgame: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave, .leaderboard], macAvailable: [.soloPlay, .localSave], macDebt: [.cloudSave, .leaderboard]),
            .chess: CapabilityRow(iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave], macAvailable: [.soloPlay, .localSave], macDebt: [.localTwoPlayer, .onlineFriend, .cloudSave]),
            .reversi: CapabilityRow(iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave], macAvailable: [.localTwoPlayer, .localSave], macDebt: [.soloPlay, .onlineFriend, .cloudSave]),
            .checkers: CapabilityRow(iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave, .leaderboard], macAvailable: [.localTwoPlayer, .localSave, .leaderboard], macDebt: [.soloPlay, .onlineFriend, .cloudSave]),
            .connectFour: CapabilityRow(iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave], macAvailable: [.localTwoPlayer, .localSave, .leaderboard], macDebt: [.soloPlay, .onlineFriend, .cloudSave]),
            .gomoku: CapabilityRow(iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave], macAvailable: [.soloPlay, .localTwoPlayer, .localSave], macDebt: [.onlineFriend, .cloudSave]),
            .seaBattle: CapabilityRow(iOSAvailable: [.soloPlay, .onlineFriend, .localSave, .cloudSave], macAvailable: [.soloPlay, .localSave], macDebt: [.onlineFriend, .cloudSave]),
            .catan: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave], macAvailable: [], macDebt: [.soloPlay, .localSave, .cloudSave]),
            .solitaire: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave], macAvailable: [.soloPlay, .localSave, .leaderboard], macDebt: [.cloudSave]),
            .spider: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave], macAvailable: [.soloPlay, .localSave], macDebt: [.cloudSave]),
            .crazyEight: CapabilityRow(iOSAvailable: [.soloPlay, .localTwoPlayer, .onlineFriend, .localSave, .cloudSave], macAvailable: [.soloPlay, .localTwoPlayer, .localSave], macDebt: [.onlineFriend, .cloudSave]),
            .brickBench: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave], macAvailable: [.soloPlay, .localSave], macDebt: [.cloudSave]),
            .oracle: CapabilityRow(iOSAvailable: [.soloPlay, .localSave, .cloudSave, .lens], macAvailable: [.lens], macDebt: [.soloPlay, .localSave, .cloudSave]),
            .debtClock: CapabilityRow(iOSAvailable: [.lens], macAvailable: [.lens], macDebt: []),
            .steamRewind: CapabilityRow(iOSAvailable: [.lens], macAvailable: [.lens], macDebt: [])
        ]
    }

    func expectedDebtRationale(
        for canonicalID: PrismetFeatureID,
        capability: PrismetFeatureCapability
    ) -> String {
        switch (canonicalID, capability) {
        case (_, .cloudSave):
            return "Account-scoped cloud save is not wired on macOS."
        case (_, .onlineFriend):
            return "Online friend play is not wired on macOS."
        case (_, .leaderboard):
            return "The iOS leaderboard surface is not wired for this game on macOS."
        case (.catan, .soloPlay), (.catan, .localSave):
            return "The active Catan Mac lane has not released its playable route and persistence."
        case (.oracle, .localSave):
            return "Canonical Oracle state is not saved on macOS; only the decree archive persists."
        case (_, .soloPlay):
            return "The iOS solo opponent mode has no Mac route."
        case (.chess, .localTwoPlayer):
            return "The model supports local Chess internally, but no current Mac route exposes it."
        default:
            XCTFail("Missing expected rationale for \(canonicalID.rawValue) \(capability.rawValue)")
            return ""
        }
    }
}
