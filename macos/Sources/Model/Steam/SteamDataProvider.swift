import Foundation

// The one seam between the data spine (Codex) and the UI (Claude). The app depends only on this
// protocol; swapping FixtureSteamDataProvider for a live ProxySteamDataProvider is a one-line change.
protocol SteamDataProvider {
    func snapshot(forQuery query: String) async throws -> SteamProfileSnapshot
}

enum SteamDataError: Error {
    case empty
    case notFound
    case privateProfile
    case rateLimited
    case invalidKey
    case network

    var userMessage: String {
        switch self {
        case .empty:
            return "Type a Steam ID, vanity name, or profile URL to get started."
        case .notFound:
            return "Couldn't find that profile. Check the ID or the vanity URL and try again."
        case .privateProfile:
            return "That profile is private. In Steam privacy settings, set Game details to Public — then try again."
        case .rateLimited:
            return "Steam is throttling requests right now. Give it a minute and retry."
        case .invalidKey:
            return "Steam rejected the API key. Double-check the key in Settings — it should be the one from steamcommunity.com/dev/apikey."
        case .network:
            return "Couldn't reach Steam. Check your connection and try again."
        }
    }
}
