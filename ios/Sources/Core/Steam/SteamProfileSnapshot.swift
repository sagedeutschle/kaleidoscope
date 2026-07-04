// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — SteamRewind fold-in (Lens)
import Foundation

// PRISM: Agent-A first-pass of the shared seam. Foundation-only + package-shaped so Codex can lift
// Sources/Core into the SteamKit SPM package later and bump these to `public`. Field names track the
// agreed SteamProfileSnapshot contract; ping before renaming.

struct SteamProfileSnapshot: Codable, Equatable {
    var resolvedId: String
    var player: PlayerSummary
    var steamLevel: Int?
    var ownedGames: [OwnedGame]
    var achievementsTotal: Int?
    var snapshotGeneratedAt: Date
    var visibility: Visibility

    enum Visibility: String, Codable {
        case publicProfile = "public"
        case privateProfile = "private"
        case partial
        case rateLimited
    }
}

struct PlayerSummary: Codable, Equatable {
    var personaName: String
    var avatarInitials: String
    var profileUrl: String?
    var memberSinceYear: Int?
    var country: String?
}

struct OwnedGame: Codable, Equatable, Identifiable {
    var appid: Int
    var name: String?
    var playtimeForeverMinutes: Int
    var playtime2WeeksMinutes: Int
    var playtimeDeckMinutes: Int?
    var lastPlayedAt: Date?
    // Store-metadata enrichment (optional + volatile — price is a labeled estimate, never a ranking primitive).
    var priceEstimateCents: Int?
    var genre: String?
    var reviewScore: Int?
    var releaseYear: Int?
    // Achievement rollups (nil when a game has no achievement schema).
    var achievementPercent: Double?
    var rarestAchievementGlobalPercent: Double?
    var ownedSinceDays: Int?

    var id: Int { appid }
    var hoursForever: Double { Double(playtimeForeverMinutes) / 60.0 }
    var hours2Weeks: Double { Double(playtime2WeeksMinutes) / 60.0 }
    var hoursOnDeck: Double { Double(playtimeDeckMinutes ?? 0) / 60.0 }
    var priceEstimate: Double? { priceEstimateCents.map { Double($0) / 100.0 } }
}
