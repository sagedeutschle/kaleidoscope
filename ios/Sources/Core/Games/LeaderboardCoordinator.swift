import Foundation

/// App-wide entry point for posting scores to the global leaderboards.
///
/// Any game view (or Codex's account-scoped sessions) can call
/// `LeaderboardCoordinator.shared.submit(.snake, score: best)` on game-over — it's a
/// no-op if the player isn't signed in or the game isn't ranked, and it only keeps
/// each player's best per the game's metric.
@MainActor
final class LeaderboardCoordinator: ObservableObject {
    static let shared = LeaderboardCoordinator()

    private(set) var accountID: UUID?
    private(set) var gcAccountID: UUID?
    private var displayName = "Player"
    private var avatarEmoji = "🎴"
    private var avatarColor = "B88A2E"

    private let store = LeaderboardStore.shared

    /// Set the signed-in identity so submitted scores show the right name/avatar
    /// and carry the durable Game Center id for cross-device/friend matching.
    func configure(accountID: UUID?, gcAccountID: UUID? = nil, displayName: String?, avatarEmoji: String?, avatarColor: String?) {
        self.accountID = accountID
        self.gcAccountID = gcAccountID
        if let displayName, !displayName.isEmpty { self.displayName = displayName }
        if let avatarEmoji, !avatarEmoji.isEmpty { self.avatarEmoji = avatarEmoji }
        if let avatarColor, !avatarColor.isEmpty { self.avatarColor = avatarColor }
    }

    /// Fire-and-forget best-score submission.
    func submit(_ game: CanonicalGameID, score: Int) {
        guard let accountID, LeaderboardCatalog.metric(for: game) != nil else { return }
        let row = LeaderboardRow(
            userID: accountID,
            gameID: game.rawValue,
            score: score,
            displayName: displayName,
            avatarEmoji: avatarEmoji,
            avatarColor: avatarColor,
            gcAccountID: gcAccountID
        )
        Task { try? await store.submitBest(row, game: game) }
    }
}
