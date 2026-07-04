import Foundation
import Supabase

@MainActor
final class ProfileStore: ObservableObject {
    @Published var me: Profile?
    @Published var loaded = false
    @Published var lastError: String?

    private var client: SupabaseClient? { Backend.client }

    func loadMine(userID: UUID) async {
        guard let client else { loaded = true; return }
        do {
            let profile: Profile = try await client
                .from("profiles")
                .select(Profile.selectedColumns)
                .eq("id", value: userID.uuidString)
                .single()
                .execute()
                .value
            me = profile
        } catch {
            me = nil
        }
        loaded = true
    }

    @discardableResult
    func upsert(_ profile: Profile) async -> Bool {
        guard let client else { lastError = "Account backend is not configured."; return false }
        do {
            try await client.from("profiles").upsert(profile).execute()
            me = profile
            lastError = nil
            loaded = true
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func reset() {
        me = nil
        loaded = false
    }
}
