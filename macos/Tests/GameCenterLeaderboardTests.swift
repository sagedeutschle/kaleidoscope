import XCTest
@testable import Kaleidoscope

final class GameCenterLeaderboardTests: XCTestCase {

    func testGameCenterCatalogMapsSupportedModes() {
        XCTAssertEqual(GameCenterLeaderboardCatalog.leaderboardID(for: "2048", mode: "standard"), "kaleidoscope.2048.best")
        XCTAssertEqual(GameCenterLeaderboardCatalog.leaderboardID(for: "snake", mode: "standard"), "kaleidoscope.snake.best")
        XCTAssertEqual(GameCenterLeaderboardCatalog.leaderboardID(for: "minesweeper", mode: "beginner"), "kaleidoscope.minesweeper.beginner.time")
        XCTAssertEqual(GameCenterLeaderboardCatalog.leaderboardID(for: "lights-out", mode: "standard"), "kaleidoscope.lightsout.presses")
        XCTAssertEqual(GameCenterLeaderboardCatalog.leaderboardID(for: "rubiks-cube", mode: "standard"), "kaleidoscope.rubiks.time")
        XCTAssertEqual(GameCenterLeaderboardCatalog.leaderboardID(for: "connect-four", mode: "standard"), "kaleidoscope.connectfour.best")
        XCTAssertEqual(GameCenterLeaderboardCatalog.leaderboardID(for: "checkers", mode: "standard"), "kaleidoscope.checkers.best")
        XCTAssertNil(GameCenterLeaderboardCatalog.leaderboardID(for: "chess", mode: "standard"))
    }

    func testCompositeServiceSubmitsSupportedResultToLocalAndGameCenter() async throws {
        let local = LocalLeaderboardService(fileURL: tempFileURL())
        let submitter = RecordingGameCenterSubmitter()
        let service = KaleidoscopeLeaderboardService(localService: local, gameCenterSubmitter: submitter)
        let result = gameResult(facetID: "2048", mode: "standard", score: 4096)

        try await service.submit(result)

        let entries = try await service.entries(facetID: "2048", mode: "standard", scope: .local, limit: 10)
        let submissions = await submitter.recordedSubmissions()

        XCTAssertEqual(entries.map(\.score), [4096])
        XCTAssertEqual(submissions, [
            GameCenterScoreSubmission(leaderboardID: "kaleidoscope.2048.best", score: 4096, context: 0)
        ])
    }

    func testCompositeServiceKeepsLocalResultWhenGameCenterSubmissionFails() async throws {
        let local = LocalLeaderboardService(fileURL: tempFileURL())
        let submitter = RecordingGameCenterSubmitter(error: TestGameCenterError.offline)
        let service = KaleidoscopeLeaderboardService(localService: local, gameCenterSubmitter: submitter)
        let result = gameResult(facetID: "snake", mode: "standard", score: 12)

        try await service.submit(result)

        let entries = try await service.entries(facetID: "snake", mode: "standard", scope: .local, limit: 10)
        let submissions = await submitter.recordedSubmissions()

        XCTAssertEqual(entries.map(\.score), [12])
        XCTAssertEqual(submissions, [])
    }

    func testCompositeServiceDoesNotSubmitUnsupportedResultToGameCenter() async throws {
        let local = LocalLeaderboardService(fileURL: tempFileURL())
        let submitter = RecordingGameCenterSubmitter()
        let service = KaleidoscopeLeaderboardService(localService: local, gameCenterSubmitter: submitter)
        let result = gameResult(facetID: "chess", mode: "standard", score: 1)

        try await service.submit(result)

        let entries = try await service.entries(facetID: "chess", mode: "standard", scope: .local, limit: 10)
        let submissions = await submitter.recordedSubmissions()

        XCTAssertEqual(entries.map(\.score), [1])
        XCTAssertEqual(submissions, [])
    }

    func testAuthenticationResolverReportsAuthenticatedPlayer() {
        let state = GameCenterAuthenticationStateResolver.state(errorMessage: nil,
                                                                isAuthenticated: true,
                                                                displayName: "Player One",
                                                                hasPresentedAuthenticationViewController: false)

        XCTAssertEqual(state, .authenticated(displayName: "Player One"))
    }

    func testAuthenticationResolverWaitsWhileSystemViewControllerIsPresented() {
        let state = GameCenterAuthenticationStateResolver.state(errorMessage: nil,
                                                                isAuthenticated: false,
                                                                displayName: "",
                                                                hasPresentedAuthenticationViewController: true)

        XCTAssertEqual(state, .authenticating)
    }

    func testAuthenticationResolverReportsErrorBeforeFallbackMessage() {
        let state = GameCenterAuthenticationStateResolver.state(errorMessage: "Network unavailable",
                                                                isAuthenticated: false,
                                                                displayName: "",
                                                                hasPresentedAuthenticationViewController: false)

        XCTAssertEqual(state, .unauthenticated(message: "Network unavailable"))
    }

    private func gameResult(id: UUID = UUID(),
                            facetID: String,
                            mode: String,
                            score: Int64) -> GameResult {
        GameResult(id: id,
                   facetID: facetID,
                   mode: mode,
                   outcome: .completed,
                   score: score,
                   durationSeconds: nil,
                   moveCount: nil,
                   completedAt: Date(timeIntervalSince1970: 1_800_001_000),
                   metadata: [:])
    }

    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kaleidoscope-gamecenter-\(UUID().uuidString)")
            .appendingPathExtension("json")
    }
}

private enum TestGameCenterError: Error {
    case offline
}

private actor RecordingGameCenterSubmitter: GameCenterScoreSubmitting {
    private var submissions: [GameCenterScoreSubmission] = []
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func submit(_ submission: GameCenterScoreSubmission) async throws {
        if let error { throw error }
        submissions.append(submission)
    }

    func recordedSubmissions() -> [GameCenterScoreSubmission] {
        submissions
    }
}
