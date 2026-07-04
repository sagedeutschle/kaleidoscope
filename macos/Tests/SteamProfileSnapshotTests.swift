import XCTest
@testable import Kaleidoscope

final class SteamProfileSnapshotTests: XCTestCase {
    func testFixtureDecodesSharedSteamSnapshotContract() throws {
        let snapshot = try decodeFixture()

        XCTAssertEqual(snapshot.resolvedID.steamID64, "76561198000000001")
        XCTAssertEqual(snapshot.resolvedID.inputKind, .vanity)
        XCTAssertEqual(snapshot.visibility, .public)
        XCTAssertEqual(snapshot.playerSummary.personaName, "FixtureFox")
        XCTAssertEqual(snapshot.ownedGames.count, 6)
        XCTAssertEqual(snapshot.steamLevel, 42)
        XCTAssertEqual(snapshot.storeMetadata[730]?.genres, ["Action", "Free to Play"])
        XCTAssertEqual(snapshot.ownedGames.first(where: { $0.appID == 620 })?.lastPlayedAt,
                       Date(timeIntervalSince1970: 1_772_323_200))
    }

    func testSnapshotDerivedTotalsIgnoreVolatileStorePrices() throws {
        let snapshot = try decodeFixture()

        XCTAssertEqual(snapshot.totalLifetimePlaytimeMinutes, 41_205)
        XCTAssertEqual(snapshot.totalRecentPlaytimeMinutes, 810)
        XCTAssertEqual(snapshot.unplayedGames.map(\.appID), [489830])
        XCTAssertEqual(snapshot.hundredPercentClub.map(\.appID), [620])
    }

    private func fixtureURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Resources/SteamProfileSnapshotFixture.json")
    }

    private func decodeFixture() throws -> SteamProfileSnapshot {
        let data = try Data(contentsOf: fixtureURL())
        return try SteamProfileSnapshot.decoder.decode(SteamProfileSnapshot.self, from: data)
    }
}
