import Combine
import Foundation

#if canImport(GameKit)
import GameKit
#endif

// PRISM: RELEASE Agent-B 2026-06-28 — Game Center leaderboard adapter boundary.

struct GameCenterScoreSubmission: Equatable, Sendable {
    var leaderboardID: String
    var score: Int64
    var context: UInt64
}

protocol GameCenterScoreSubmitting: Sendable {
    func submit(_ submission: GameCenterScoreSubmission) async throws
}

enum GameCenterSubmissionError: Error, Equatable {
    case unavailable
    case notAuthenticated
    case scoreOutOfRange(Int64)
}

enum GameCenterLeaderboardCatalog {
    private static let leaderboardIDs: [String: String] = [
        "2048:standard": "kaleidoscope.2048.best",
        "snake:standard": "kaleidoscope.snake.best",
        "minesweeper:beginner": "kaleidoscope.minesweeper.beginner.time",
        "lights-out:standard": "kaleidoscope.lightsout.presses",
        "rubiks-cube:standard": "kaleidoscope.rubiks.time",
        "connect-four:standard": "kaleidoscope.connectfour.best",
        "checkers:standard": "kaleidoscope.checkers.best"
    ]

    static func leaderboardID(for facetID: String, mode: String) -> String? {
        leaderboardIDs["\(facetID):\(mode)"]
    }

    static func submission(for result: GameResult) -> GameCenterScoreSubmission? {
        guard let score = result.score,
              let leaderboardID = leaderboardID(for: result.facetID, mode: result.mode)
        else { return nil }

        return GameCenterScoreSubmission(leaderboardID: leaderboardID,
                                         score: score,
                                         context: 0)
    }
}

actor KaleidoscopeLeaderboardService: LeaderboardService {
    static let shared = KaleidoscopeLeaderboardService(localService: .shared,
                                                       gameCenterSubmitter: GameKitScoreSubmitter())

    private let localService: LocalLeaderboardService
    private let gameCenterSubmitter: any GameCenterScoreSubmitting
    private var lastGameCenterErrorDescription: String?

    init(localService: LocalLeaderboardService, gameCenterSubmitter: any GameCenterScoreSubmitting) {
        self.localService = localService
        self.gameCenterSubmitter = gameCenterSubmitter
    }

    func submit(_ result: GameResult) async throws {
        try await localService.submit(result)

        guard let submission = GameCenterLeaderboardCatalog.submission(for: result) else { return }

        do {
            try await gameCenterSubmitter.submit(submission)
            lastGameCenterErrorDescription = nil
        } catch {
            lastGameCenterErrorDescription = error.localizedDescription
        }
    }

    func entries(facetID: String,
                 mode: String,
                 scope: LeaderboardScope,
                 limit: Int) async throws -> [LeaderboardEntry] {
        guard scope == .local else { return [] }
        return try await localService.entries(facetID: facetID, mode: mode, scope: scope, limit: limit)
    }

    func personalBest(facetID: String, mode: String) async throws -> LeaderboardEntry? {
        try await localService.personalBest(facetID: facetID, mode: mode)
    }

    func latestGameCenterErrorDescription() -> String? {
        lastGameCenterErrorDescription
    }
}

#if canImport(GameKit)
struct GameKitScoreSubmitter: GameCenterScoreSubmitting {
    func submit(_ submission: GameCenterScoreSubmission) async throws {
        guard GKLocalPlayer.local.isAuthenticated else {
            throw GameCenterSubmissionError.notAuthenticated
        }

        guard submission.score >= Int64(Int.min),
              submission.score <= Int64(Int.max)
        else {
            throw GameCenterSubmissionError.scoreOutOfRange(submission.score)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            GKLeaderboard.submitScore(Int(submission.score),
                                      context: Int(submission.context),
                                      player: GKLocalPlayer.local,
                                      leaderboardIDs: [submission.leaderboardID]) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
#else
struct GameKitScoreSubmitter: GameCenterScoreSubmitting {
    func submit(_ submission: GameCenterScoreSubmission) async throws {
        throw GameCenterSubmissionError.unavailable
    }
}
#endif

enum GameCenterAuthenticationState: Equatable {
    case notStarted
    case authenticating
    case authenticated(displayName: String)
    case unauthenticated(message: String)
}

enum GameCenterAuthenticationStateResolver {
    static func state(errorMessage: String?,
                      isAuthenticated: Bool,
                      displayName: String,
                      hasPresentedAuthenticationViewController: Bool) -> GameCenterAuthenticationState {
        if let errorMessage {
            return .unauthenticated(message: errorMessage)
        }
        if isAuthenticated {
            return .authenticated(displayName: displayName)
        }
        if hasPresentedAuthenticationViewController {
            return .authenticating
        }
        return .unauthenticated(message: "Game Center sign-in was not completed.")
    }
}

@MainActor
final class GameCenterAuthenticationController: ObservableObject {
    @Published private(set) var state: GameCenterAuthenticationState = .notStarted

    func startAuthentication() {
        #if canImport(GameKit)
        state = .authenticating
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                self.state = GameCenterAuthenticationStateResolver.state(
                    errorMessage: error?.localizedDescription,
                    isAuthenticated: GKLocalPlayer.local.isAuthenticated,
                    displayName: GKLocalPlayer.local.displayName,
                    hasPresentedAuthenticationViewController: viewController != nil
                )
            }
        }
        #else
        state = .unauthenticated(message: "Game Center is unavailable on this platform.")
        #endif
    }
}
