import Foundation
import Supabase
import GameKit

@MainActor
final class AuthManager: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(UUID)
    }

    @Published var state: State = .loading
    @Published var lastError: String?
    @Published var displayName: String?
    @Published var isCloudBacked = false

    private var client: SupabaseClient? { Backend.client }

    func restore() async {
        displayName = await Self.authenticateGameCenter()

        if let client {
            if let uid = try? await client.auth.session.user.id {
                state = .signedIn(uid)
                isCloudBacked = true
                lastError = nil
                return
            }

            if let uid = try? await client.auth.signInAnonymously().user.id {
                state = .signedIn(uid)
                isCloudBacked = true
                lastError = nil
                return
            }
        }

        state = .signedIn(Self.localAccountID())
        isCloudBacked = false
        lastError = nil
    }

    func signOut() async {
        try? await client?.auth.signOut()
        state = .signedIn(Self.localAccountID())
        isCloudBacked = false
    }

    private static func authenticateGameCenter() async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            let local = GKLocalPlayer.local
            var resumed = false
            local.authenticateHandler = { _, _ in
                guard !resumed else { return }
                resumed = true
                guard local.isAuthenticated else {
                    cont.resume(returning: nil)
                    return
                }
                let name = local.displayName.isEmpty ? local.alias : local.displayName
                cont.resume(returning: name.isEmpty ? nil : name)
            }
        }
    }

    private static let accountKey = "kaleidoscope.desktop.accountID"

    private static func localAccountID() -> UUID {
        if let stored = UserDefaults.standard.string(forKey: accountKey),
           let id = UUID(uuidString: stored) {
            return id
        }

        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: accountKey)
        return id
    }
}
