import Foundation
import Supabase
import GameKit

/// Identity for Kaleidoscope. Apple Game Center supplies the display name when
/// available; a Supabase anonymous session can back cloud leaderboards/saves with
/// a real `auth.uid()` so existing RLS keeps working. If cloud identity is not
/// available, the player still gets in as a local guest.
@MainActor
final class AuthManager: ObservableObject {
    enum State: Equatable {
        case loading
        case signedIn(UUID)
    }

    @Published var state: State = .signedIn(AuthManager.localGuestID())
    /// Game Center alias, when the player is signed into Game Center.
    @Published var displayName: String?
    /// Deterministic UUID derived from the Game Center teamPlayerID — the same
    /// human resolves to the same id on every device, which is what leaderboard
    /// rows and friend filters key on. Nil until (unless) Game Center signs in.
    @Published var gcAccountID: UUID?
    /// True when a real Supabase session exists (cloud sync works). Guest = false.
    @Published var isCloudBacked = false

    private var client: SupabaseClient? { Backend.client }

    /// Establish identity on launch. Never blocks on a login screen.
    ///
    /// The UI is already playable before this runs (state defaults to a local
    /// guest and RootView drops straight into Home), so this only upgrades the
    /// session in the background. Game Center auth can present its own UI / hang,
    /// so we kick it off CONCURRENTLY with the Supabase session rather than
    /// serializing it in front — GC latency must never postpone cloud identity.
    func restore() async {
        // 1) Resolve the Game Center display name in a DETACHED background task. Its
        //    only product is the alias, failure just means "guest", and GameKit may
        //    never invoke its handler at all — so it must neither gate the session
        //    below nor keep `restore()` suspended. (An `async let` would be awaited at
        //    scope exit and could hang here; an unstructured Task cannot.) It folds
        //    the name in whenever it arrives, or harmlessly never.
        Task { @MainActor [weak self] in
            let identity = await Self.authenticateGameCenter()
            self?.displayName = identity.displayName
            self?.gcAccountID = identity.accountID
        }

        // 2) Backend session for cloud sync: reuse an existing session, else sign in
        //    anonymously. If neither works (anonymous identities disabled / offline),
        //    fall back to a persisted local id so there is NEVER a wall. This is the
        //    only thing `restore()` waits on, and the UI is already playable meanwhile.
        if let client {
            if let uid = try? await client.auth.session.user.id {
                state = .signedIn(uid); isCloudBacked = true
            } else if let uid = try? await client.auth.signInAnonymously().user.id {
                state = .signedIn(uid); isCloudBacked = true
            } else {
                state = .signedIn(Self.localGuestID()); isCloudBacked = false
            }
        } else {
            state = .signedIn(Self.localGuestID())
            isCloudBacked = false
        }
    }

    /// Leave the cloud session but stay in as a local guest.
    func signOut() async {
        try? await client?.auth.signOut()
        state = .signedIn(Self.localGuestID())
        gcAccountID = nil
        displayName = nil
        isCloudBacked = false
    }

    // MARK: - Game Center

    private static func authenticateGameCenter() async -> (displayName: String?, accountID: UUID?) {
        await withCheckedContinuation { (cont: CheckedContinuation<(displayName: String?, accountID: UUID?), Never>) in
            let local = GKLocalPlayer.local
            var resumed = false
            local.authenticateHandler = { _, _ in
                // The handler can fire again on account changes; only resolve once.
                guard !resumed else { return }
                resumed = true
                if local.isAuthenticated {
                    let name = local.displayName.isEmpty ? local.alias : local.displayName
                    let teamID = local.teamPlayerID
                    cont.resume(returning: (
                        displayName: name.isEmpty ? nil : name,
                        accountID: teamID.isEmpty ? nil : GameCenterIdentity.stableUUID(fromTeamPlayerID: teamID)
                    ))
                } else {
                    cont.resume(returning: (displayName: nil, accountID: nil))
                }
            }
        }
    }

    // MARK: - Local guest id (stable per install)

    private static let guestKey = "kaleido.guestID"
    private static func localGuestID() -> UUID {
        if let s = UserDefaults.standard.string(forKey: guestKey), let id = UUID(uuidString: s) { return id }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: guestKey)
        return id
    }
}
