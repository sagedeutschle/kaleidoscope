import XCTest
@testable import PrismetShared

final class PrismetFeatureManifestTests: XCTestCase {
    func testCategoryOrderMatchesLaunchGrouping() {
        XCTAssertEqual(PrismetFeatureCategory.allCases.map(\.rawValue),
                       ["Daily", "Puzzles", "Board", "Cards", "Oracle"])
    }

    func testManifestHasUniqueCanonicalAndPlatformIDs() {
        XCTAssertEqual(Set(PrismetFeatureManifest.all.map(\.canonicalID)).count,
                       PrismetFeatureManifest.all.count)

        for platform in PrismetPlatform.allCases {
            let platformIDs = PrismetFeatureManifest.all.compactMap { $0.platformID(for: platform) }
            XCTAssertEqual(Set(platformIDs).count, platformIDs.count, "\(platform.rawValue) ids must stay unique")
        }
    }

    func testCurrentLegacyIDsMapToSameCanonicalFeatures() {
        XCTAssertEqual(PrismetFeatureManifest.feature(platformID: "rubiks", platform: .iOS)?.canonicalID, .rubiksCube)
        XCTAssertEqual(PrismetFeatureManifest.feature(platformID: "rubiks-cube", platform: .macOS)?.canonicalID, .rubiksCube)
        XCTAssertEqual(PrismetFeatureManifest.platformID(for: .lightsOut, platform: .iOS), "lightsout")
        XCTAssertEqual(PrismetFeatureManifest.platformID(for: .lightsOut, platform: .macOS), "lights-out")
        XCTAssertEqual(PrismetFeatureManifest.platformID(for: .brickBench, platform: .iOS), "brickbench")
        XCTAssertEqual(PrismetFeatureManifest.platformID(for: .brickBench, platform: .macOS), "brick-bench")
    }

    func testWordgameLaunchReviewAndLeaderboardPolicyAreShared() throws {
        let wordgame = try XCTUnwrap(PrismetFeatureManifest.feature(for: .wordgame))
        XCTAssertEqual(wordgame.category.rawValue, "Daily")
        XCTAssertTrue(wordgame.visibleInLaunchReview)
        XCTAssertEqual(wordgame.leaderboardMetric, .fewestMoves)
        XCTAssertEqual(wordgame.leaderboardPeriod, .daily)
    }

    func testManifestUsesRequestedLaunchCategories() throws {
        XCTAssertEqual(try XCTUnwrap(PrismetFeatureManifest.feature(for: .game2048)).category.rawValue, "Puzzles")
        XCTAssertEqual(try XCTUnwrap(PrismetFeatureManifest.feature(for: .snake)).category.rawValue, "Puzzles")
        XCTAssertEqual(try XCTUnwrap(PrismetFeatureManifest.feature(for: .chess)).category.rawValue, "Board")
        XCTAssertEqual(try XCTUnwrap(PrismetFeatureManifest.feature(for: .solitaire)).category.rawValue, "Cards")
        XCTAssertEqual(try XCTUnwrap(PrismetFeatureManifest.feature(for: .brickBench)).category.rawValue, "Oracle")
        XCTAssertEqual(try XCTUnwrap(PrismetFeatureManifest.feature(for: .oracle)).category.rawValue, "Oracle")
        XCTAssertEqual(try XCTUnwrap(PrismetFeatureManifest.feature(for: .debtClock)).category.rawValue, "Oracle")
    }
}
