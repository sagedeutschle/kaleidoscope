import GameKit
#if canImport(UIKit)
import UIKit
#endif

/// Game Center friends — presents Apple's native "add friend" flow so players can
/// send Game Center friend requests to each other. Uses the system UI, so no
/// contact data or accounts are handled by the app itself.
enum GameCenterFriends {
    struct FriendReference: Hashable {
        var accountID: UUID
        var displayName: String?
        var isLocalPlayer: Bool
    }

    enum Result: Equatable {
        case presented
        case notSignedIn        // player isn't signed into Game Center
        case unavailable(String)
    }

    /// Whether Game Center is ready for a friend request.
    static var isAvailable: Bool { GKLocalPlayer.local.isAuthenticated }

    /// Account IDs for a friend-scoped leaderboard: the local player + their Game
    /// Center friends (those who've authorized friend sharing), mapped to the same
    /// deterministic UUIDs the app stores scores under. Empty if not signed in.
    @MainActor
    static func loadFriendAccountIDs() async -> [UUID] {
        await loadFriendReferences().map(\.accountID)
    }

    /// Friend identities for matching Game Center friends against leaderboard rows.
    /// Rows are keyed by Supabase auth uid today, so display name is a compatibility
    /// fallback until the backend has a durable Game Center -> auth uid map.
    @MainActor
    static func loadFriendReferences() async -> [FriendReference] {
        guard GKLocalPlayer.local.isAuthenticated else { return [] }
        var references: [FriendReference] = []
        let local = GKLocalPlayer.local
        if !local.teamPlayerID.isEmpty {
            references.append(FriendReference(
                accountID: GameCenterIdentity.stableUUID(fromTeamPlayerID: local.teamPlayerID),
                displayName: resolvedDisplayName(local),
                isLocalPlayer: true
            ))
        }
        if let friends = try? await GKLocalPlayer.local.loadFriends() {
            for friend in friends where !friend.teamPlayerID.isEmpty {
                references.append(FriendReference(
                    accountID: GameCenterIdentity.stableUUID(fromTeamPlayerID: friend.teamPlayerID),
                    displayName: resolvedDisplayName(friend),
                    isLocalPlayer: false
                ))
            }
        }
        return references
    }

    /// Present the native Game Center friend-request composer.
    @discardableResult
    @MainActor
    static func presentAddFriend() -> Result {
        #if canImport(UIKit)
        guard GKLocalPlayer.local.isAuthenticated else { return .notSignedIn }
        guard let presenter = topViewController() else {
            return .unavailable("No window to present from.")
        }
        do {
            try GKLocalPlayer.local.presentFriendRequestCreator(from: presenter)
            return .presented
        } catch {
            return .unavailable(error.localizedDescription)
        }
        #else
        return .unavailable("Game Center friends require iOS.")
        #endif
    }

    /// Present the native Game Center friends list (the player's friends).
    @discardableResult
    @MainActor
    static func presentFriendsList() -> Result {
        #if canImport(UIKit)
        guard GKLocalPlayer.local.isAuthenticated else { return .notSignedIn }
        guard let presenter = topViewController() else {
            return .unavailable("No window to present from.")
        }
        let controller: GKGameCenterViewController
        if #available(iOS 17.2, *) {
            controller = GKGameCenterViewController(state: .localPlayerFriendsList)
        } else {
            controller = GKGameCenterViewController(state: .dashboard)
        }
        controller.gameCenterDelegate = GameCenterDismissDelegate.shared
        presenter.present(controller, animated: true)
        return .presented
        #else
        return .unavailable("Game Center friends require iOS.")
        #endif
    }

    #if canImport(UIKit)
    /// Top-most presented view controller of the key window.
    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #endif

    private static func resolvedDisplayName(_ player: GKPlayer) -> String? {
        if !player.displayName.isEmpty { return player.displayName }
        if !player.alias.isEmpty { return player.alias }
        return nil
    }
}

#if canImport(UIKit)
/// Dismisses a presented `GKGameCenterViewController` when the player taps Done.
private final class GameCenterDismissDelegate: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDismissDelegate()
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
#endif
