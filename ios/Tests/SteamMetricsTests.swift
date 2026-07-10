// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — SteamRewind fold-in (Lens) engine tests.
import XCTest
@testable import Prismet

final class SteamMetricsTests: XCTestCase {
    private let fixture = Fixtures.sage

    func testFixtureLibraryIsSubstantial() {
        XCTAssertEqual(fixture.ownedGames.count, 32)
        XCTAssertGreaterThan(SteamMetrics.totalHours(fixture), 3_000)
        XCTAssertEqual(fixture.visibility, .publicProfile)
    }

    func testMostPlayedIsCounterStrike() throws {
        let top = try XCTUnwrap(SteamMetrics.mostPlayed(fixture))
        XCTAssertEqual(top.appid, 730)
        XCTAssertEqual(top.hoursForever, 1_240, accuracy: 0.01)
    }

    func testCostPerHourMath() {
        let sixtyForSixty = Fixtures.game(1, "t", hf: 60, h2: 0, price: 60, review: 90,
                                          ach: nil, rare: nil, genre: "Test", year: 2020,
                                          deck: 0, ownedDays: 10, lastDays: nil)
        XCTAssertEqual(SteamMetrics.costPerHour(sixtyForSixty), 1.0, accuracy: 0.001)
        // Zero hours → documented guard: infinity (never divide by zero).
        let unplayed = Fixtures.game(2, "u", hf: 0, h2: 0, price: 60, review: 90,
                                     ach: nil, rare: nil, genre: "Test", year: 2020,
                                     deck: 0, ownedDays: 10, lastDays: nil)
        XCTAssertEqual(SteamMetrics.costPerHour(unplayed), .infinity)
    }

    func testPileOfShameCountsSub30MinuteGames() {
        // <0.5h games in the fixture: PAYDAY 2 ($10) + Getting Over It ($8) +
        // Skyrim ($40) + Cyberpunk ($60) + Ghost of Tsushima ($60) + Death Stranding ($40).
        XCTAssertEqual(SteamMetrics.pileOfShameValue(fixture), 218, accuracy: 0.01)
    }

    func testGenreAggregationAndTopGenre() {
        let genres = SteamMetrics.genreHours(fixture)
        XCTAssertEqual(genres.first?.genre, "Shooter")
        XCTAssertEqual(SteamMetrics.topGenre(fixture), "Shooter")
        let shooterHours = genres.first?.hours ?? 0
        XCTAssertEqual(shooterHours, 1_440.4, accuracy: 0.5)
    }

    func testRarestUnlockIsBaldursGate() {
        XCTAssertEqual(SteamMetrics.rarestUnlockPercent(fixture) ?? 0, 0.8, accuracy: 0.001)
    }

    func testDeckDeskSplit() {
        let split = SteamMetrics.deckDeskSplit(fixture)
        XCTAssertEqual(split.deck, 126, accuracy: 0.5)   // Stardew 60 + VS 22 + DRG 44
        XCTAssertEqual(split.deck + split.desk, SteamMetrics.totalHours(fixture), accuracy: 0.5)
    }

    func testEveryLensEvaluatesOnFixture() {
        // No lens may crash or return a malformed result on the demo library.
        for lens in LensCatalog.all {
            switch LensCatalog.evaluate(lens, fixture) {
            case .list(let rows):
                XCTAssertLessThanOrEqual(rows.count, 9, "lens \(lens.id) over row cap")
                for row in rows {
                    XCTAssertTrue(row.fraction.isFinite, "lens \(lens.id) row \(row.rank) fraction not finite")
                    XCTAssertGreaterThan(row.fraction, 0)
                }
            case .bars(let bars):
                XCTAssertFalse(bars.isEmpty, "lens \(lens.id) returned no bars")
                for bar in bars {
                    XCTAssertTrue(bar.fraction.isFinite)
                }
            }
            _ = lens.blurb(fixture)   // blurbs must not crash either
        }
    }

    func testCredentialsRoundTripOnDevice() throws {
        // Env var takes precedence over storage — skip if the runner has one set.
        try XCTSkipIf(ProcessInfo.processInfo.environment["STEAM_WEB_API_KEY"] != nil,
                      "env key present; storage path not observable")
        let original = UserDefaults.standard.string(forKey: SteamCredentials.defaultsKey)
        addTeardownBlock {
            if let original {
                UserDefaults.standard.set(original, forKey: SteamCredentials.defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: SteamCredentials.defaultsKey)
            }
        }
        try SteamCredentials.saveAPIKey("  ABC123TESTKEY  ")
        XCTAssertEqual(SteamCredentials.apiKey(), "ABC123TESTKEY")   // trimmed
        XCTAssertTrue(SteamCredentials.hasKey())
        SteamCredentials.clear()
        XCTAssertNil(SteamCredentials.apiKey())
        XCTAssertFalse(SteamCredentials.hasKey())
    }
}
