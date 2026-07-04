import Foundation
import Supabase

/// Loads and saves the signed-in user's `profiles` row.
@MainActor
final class ProfileStore: ObservableObject {
    @Published var me: Profile?
    @Published var loaded = false
    @Published var lastError: String?

    private var client: SupabaseClient? { Backend.client }

    /// Load my profile (nil `me` means "no profile yet → run setup").
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
        guard let client else { lastError = "Backend not configured."; return false }
        let sanitized = profile.sanitizedForClientUpload()
        guard await AppSecurity.allowClientAction(.profileWrite, scope: sanitized.id.uuidString) else {
            lastError = AppSecurityError.rateLimited.localizedDescription
            return false
        }
        do {
            try await client.from("profiles").upsert(sanitized).execute()
            me = sanitized
            lastError = nil
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

    /// Show an identity immediately (no setup wall): seed a local profile from the
    /// Game Center name, then — when cloud-backed — load the stored profile or create
    /// one on first run. Called once per signed-in account id.
    func bootstrap(userID: UUID, fallbackName: String, cloud: Bool) async {
        if me == nil || me?.id != userID {
            me = Profile(id: userID, phone: nil,
                         displayName: AppSecurity.sanitizedDisplayName(fallbackName),
                         avatarEmoji: "🎴", avatarColor: "B88A2E")
        }
        loaded = true
        guard cloud, let client else { return }
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
            // No row yet → create one from the Game Center name.
            await upsert(Profile(id: userID, phone: nil,
                                 displayName: AppSecurity.sanitizedDisplayName(fallbackName),
                                 avatarEmoji: "🎴", avatarColor: "B88A2E"))
        }
    }
}
