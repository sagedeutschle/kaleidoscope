import XCTest
@testable import Prismet

final class GameLeaderboardTests: XCTestCase {

    func testLocalLeaderboardKeepsBestHighScorePerFacetAndMode() async throws {
        let service = LocalLeaderboardService(fileURL: tempFileURL())
        let first = result(facetID: "2048", score: 512, secondsOffset: 1)
        let second = result(facetID: "2048", score: 2048, secondsOffset: 2)

        try await service.submit(first)
        try await service.submit(second)

        let entries = try await service.entries(facetID: "2048", mode: "standard", scope: .local, limit: 10)
        let personalBest = try await service.personalBest(facetID: "2048", mode: "standard")

        XCTAssertEqual(entries.map(\.score), [2048, 512])
        XCTAssertEqual(personalBest?.score, 2048)
    }

    func testLocalLeaderboardLowerScoreWinsForTimedModes() async throws {
        let service = LocalLeaderboardService(fileURL: tempFileURL())
        try await service.submit(result(facetID: "minesweeper", mode: "beginner", score: 87, secondsOffset: 1))
        try await service.submit(result(facetID: "minesweeper", mode: "beginner", score: 42, secondsOffset: 2))

        let entries = try await service.entries(facetID: "minesweeper", mode: "beginner", scope: .local, limit: 10)
        XCTAssertEqual(entries.map(\.score), [42, 87])
        XCTAssertEqual(entries.first?.rank, 1)
    }

    func testLocalLeaderboardIgnoresDuplicateResultIDs() async throws {
        let service = LocalLeaderboardService(fileURL: tempFileURL())
        let id = UUID()
        try await service.submit(result(id: id, facetID: "snake", score: 8))
        try await service.submit(result(id: id, facetID: "snake", score: 8))

        let entries = try await service.entries(facetID: "snake", mode: "standard", scope: .local, limit: 10)
        XCTAssertEqual(entries.count, 1)
    }

    func testLocalLeaderboardPersistsResultsToDisk() async throws {
        let url = tempFileURL()
        let firstService = LocalLeaderboardService(fileURL: url)
        try await firstService.submit(result(facetID: "snake", score: 12))

        let secondService = LocalLeaderboardService(fileURL: url)
        let entries = try await secondService.entries(facetID: "snake", mode: "standard", scope: .local, limit: 10)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.score, 12)
        XCTAssertEqual(entries.first?.displayName, "You")
    }

    func testCatalogDefinesFirstSliceModes() {
        XCTAssertEqual(LeaderboardCatalog.mode(for: "2048", mode: "standard")?.title, "2048")
        XCTAssertEqual(LeaderboardCatalog.mode(for: "2048", mode: "standard")?.sortOrder, .higherIsBetter)
        XCTAssertEqual(LeaderboardCatalog.mode(for: "snake", mode: "standard")?.title, "Snake")
        XCTAssertEqual(LeaderboardCatalog.mode(for: "snake", mode: "standard")?.sortOrder, .higherIsBetter)
        XCTAssertEqual(LeaderboardCatalog.mode(for: "minesweeper", mode: "beginner")?.sortOrder, .lowerIsBetter)
        XCTAssertEqual(LeaderboardCatalog.mode(for: "connect-four", mode: "standard")?.title, "Connect Four")
        XCTAssertEqual(LeaderboardCatalog.mode(for: "connect-four", mode: "standard")?.sortOrder, .higherIsBetter)
        XCTAssertEqual(LeaderboardCatalog.mode(for: "checkers", mode: "standard")?.title, "Checkers")
        XCTAssertEqual(LeaderboardCatalog.mode(for: "checkers", mode: "standard")?.sortOrder, .higherIsBetter)
    }

    private func result(id: UUID = UUID(),
                        facetID: String,
                        mode: String = "standard",
                        score: Int64,
                        secondsOffset: TimeInterval = 0) -> GameResult {
        GameResult(id: id,
                   facetID: facetID,
                   mode: mode,
                   outcome: .completed,
                   score: score,
                   durationSeconds: nil,
                   moveCount: nil,
                   completedAt: Date(timeIntervalSince1970: 1_800_000_000 + secondsOffset),
                   metadata: [:])
    }

    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kaleidoscope-leaderboard-\(UUID().uuidString)")
            .appendingPathExtension("json")
    }
}
