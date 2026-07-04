import Foundation
import GameKit
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

/// Game Center identity as the source of a unique per-player identifier.
/// Silently authenticates the local player and exposes a stable id + display name.
///
/// `GKLocalPlayer.teamPlayerID` is Apple's recommended stable identifier for a
/// player within a developer team (stable across the team's apps and across the
/// player's devices), which makes it the right anchor for a cross-device account.
/// We hash it into a deterministic UUID (`accountID`) so the existing Supabase
/// schema — which keys every row on a `uuid` — keeps working with the same shape,
/// whichever backend-authorization path we land on (anonymous session vs custom JWT).
@MainActor
final class GameCenterIdentity: ObservableObject {
    enum State: Equatable {
        case idle
        case authenticating
        /// Signed in. `accountID` is the deterministic UUID derived from `teamPlayerID`.
        case authenticated(accountID: UUID, teamPlayerID: String, displayName: String)
        /// Game Center is off / the player declined / running where GC is unavailable.
        case unavailable(reason: String)
    }

    @Published private(set) var state: State = .idle

    /// Set by the hosting view so Game Center can present its sign-in sheet when the
    /// player isn't signed in yet. Kept UIKit-typed and optional so this file stays
    /// testable and platform-flexible.
    #if canImport(UIKit)
    var presentAuthController: ((UIViewController) -> Void)?
    #endif

    /// Convenience accessors for the signed-in identity (nil until authenticated).
    var accountID: UUID? {
        if case let .authenticated(accountID, _, _) = state { return accountID }
        return nil
    }
    var displayName: String? {
        if case let .authenticated(_, _, name) = state { return name }
        return nil
    }
    var isAuthenticated: Bool { accountID != nil }

    /// Kick off Game Center authentication. Idempotent — Game Center invokes the
    /// handler again on account changes, and we re-derive state each time.
    func authenticate() {
        if case .authenticating = state { return }
        state = .authenticating
        let local = GKLocalPlayer.local
        local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            Task { @MainActor in
                #if canImport(UIKit)
                if let viewController {
                    // Player needs to sign in — surface Apple's Game Center sheet.
                    self.presentAuthController?(viewController)
                    return
                }
                #endif
                if local.isAuthenticated {
                    let teamID = local.teamPlayerID
                    let name = Self.resolveDisplayName(local)
                    self.state = .authenticated(
                        accountID: Self.stableUUID(fromTeamPlayerID: teamID),
                        teamPlayerID: teamID,
                        displayName: name
                    )
                } else {
                    self.state = .unavailable(
                        reason: error?.localizedDescription ?? "Game Center isn't signed in on this device."
                    )
                }
            }
        }
    }

    private static func resolveDisplayName(_ player: GKLocalPlayer) -> String {
        if !player.displayName.isEmpty { return player.displayName }
        if !player.alias.isEmpty { return player.alias }
        return "Player"
    }

    // MARK: - Deterministic UUID

    /// Fixed namespace so the mapping teamPlayerID → UUID is stable forever.
    /// (A random v4 UUID used purely as a namespace constant for our RFC-4122 v5 hash.)
    nonisolated private static let namespace = UUID(uuidString: "6B0F1E2C-7A4D-4C9E-9B3A-1F5E8C2D7A60")!

    /// RFC-4122 v5 (SHA-1, name-based) UUID from the Game Center team player id.
    /// Deterministic: the same player always maps to the same account UUID.
    nonisolated static func stableUUID(fromTeamPlayerID teamPlayerID: String) -> UUID {
        var hasher = Insecure.SHA1()
        withUnsafeBytes(of: namespaceBytes()) { hasher.update(bufferPointer: $0) }
        hasher.update(data: Data(teamPlayerID.utf8))
        var digest = Array(hasher.finalize())            // 20 bytes; use first 16

        // Set version (5) and RFC-4122 variant bits.
        digest[6] = (digest[6] & 0x0F) | 0x50
        digest[8] = (digest[8] & 0x3F) | 0x80

        let b = digest
        let uuidT: uuid_t = (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                             b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])
        return UUID(uuid: uuidT)
    }

    /// The namespace UUID as its 16 raw bytes, for hashing.
    nonisolated private static func namespaceBytes() -> uuid_t { namespace.uuid }
}
