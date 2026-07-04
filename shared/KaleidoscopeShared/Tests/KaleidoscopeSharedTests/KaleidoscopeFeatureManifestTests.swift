import XCTest
@testable import KaleidoscopeShared

final class KaleidoscopeFeatureManifestTests: XCTestCase {
    func testCategoryOrderMatchesLaunchGrouping() {
        XCTAssertEqual(KaleidoscopeFeatureCategory.allCases.map(\.rawValue),
                       ["Daily", "Puzzles", "Board", "Cards", "Oracle"])
    }

    func testManifestHasUniqueCanonicalAndPlatformIDs() {
        XCTAssertEqual(Set(KaleidoscopeFeatureManifest.all.map(\.canonicalID)).count,
                       KaleidoscopeFeatureManifest.all.count)

        for platform in KaleidoscopePlatform.allCases {
            let platformIDs = KaleidoscopeFeatureManifest.all.compactMap { $0.platformID(for: platform) }
            XCTAssertEqual(Set(platformIDs).count, platformIDs.count, "\(platform.rawValue) ids must stay unique")
        }
    }

    func testCurrentLegacyIDsMapToSameCanonicalFeatures() {
        XCTAssertEqual(KaleidoscopeFeatureManifest.feature(platformID: "rubiks", platform: .iOS)?.canonicalID, .rubiksCube)
        XCTAssertEqual(KaleidoscopeFeatureManifest.feature(platformID: "rubiks-cube", platform: .macOS)?.canonicalID, .rubiksCube)
        XCTAssertEqual(KaleidoscopeFeatureManifest.platformID(for: .lightsOut, platform: .iOS), "lightsout")
        XCTAssertEqual(KaleidoscopeFeatureManifest.platformID(for: .lightsOut, platform: .macOS), "lights-out")
        XCTAssertEqual(KaleidoscopeFeatureManifest.platformID(for: .brickBench, platform: .iOS), "brickbench")
        XCTAssertEqual(KaleidoscopeFeatureManifest.platformID(for: .brickBench, platform: .macOS), "brick-bench")
    }

    func testWordgameLaunchReviewAndLeaderboardPolicyAreShared() throws {
        let wordgame = try XCTUnwrap(KaleidoscopeFeatureManifest.feature(for: .wordgame))
        XCTAssertEqual(wordgame.category.rawValue, "Daily")
        XCTAssertTrue(wordgame.visibleInLaunchReview)
        XCTAssertEqual(wordgame.leaderboardMetric, .fewestMoves)
        XCTAssertEqual(wordgame.leaderboardPeriod, .daily)
    }

    func testManifestUsesRequestedLaunchCategories() throws {
        XCTAssertEqual(try XCTUnwrap(KaleidoscopeFeatureManifest.feature(for: .game2048)).category.rawValue, "Puzzles")
        XCTAssertEqual(try XCTUnwrap(KaleidoscopeFeatureManifest.feature(for: .snake)).category.rawValue, "Puzzles")
        XCTAssertEqual(try XCTUnwrap(KaleidoscopeFeatureManifest.feature(for: .chess)).category.rawValue, "Board")
        XCTAssertEqual(try XCTUnwrap(KaleidoscopeFeatureManifest.feature(for: .solitaire)).category.rawValue, "Cards")
        XCTAssertEqual(try XCTUnwrap(KaleidoscopeFeatureManifest.feature(for: .brickBench)).category.rawValue, "Oracle")
        XCTAssertEqual(try XCTUnwrap(KaleidoscopeFeatureManifest.feature(for: .oracle)).category.rawValue, "Oracle")
        XCTAssertEqual(try XCTUnwrap(KaleidoscopeFeatureManifest.feature(for: .debtClock)).category.rawValue, "Oracle")
    }
}
