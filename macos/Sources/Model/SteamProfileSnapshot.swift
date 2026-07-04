import Foundation

enum SteamProfileInputKind: String, Codable, Hashable {
    case steamID64
    case vanity
    case profileURL
}

enum SteamSnapshotVisibility: String, Codable, Hashable {
    case `public`
    case `private`
    case partial
    case rateLimited
}

struct SteamResolvedID: Codable, Hashable {
    var originalInput: String
    var inputKind: SteamProfileInputKind
    var steamID64: String
    var vanityName: String?
    var profileURL: URL?
}

struct SteamPlayerSummary: Codable, Hashable {
    var steamID64: String
    var personaName: String
    var profileURL: URL?
    var avatarFullURL: URL?
    var countryCode: String?
    var createdAt: Date?
    var lastLogoffAt: Date?
}

struct SteamOwnedGame: Codable, Hashable, Identifiable {
    var appID: Int
    var name: String?
    var playtimeForeverMinutes: Int
    var playtimeTwoWeeksMinutes: Int
    var lastPlayedAt: Date?
    var iconHash: String?

    var id: Int { appID }

    enum CodingKeys: String, CodingKey {
        case appID = "appid"
        case name
        case playtimeForeverMinutes = "playtime_forever"
        case playtimeTwoWeeksMinutes = "playtime_2weeks"
        case lastPlayedAt = "last_played_at"
        case iconHash = "img_icon_url"
    }
}

struct SteamGameAchievementSummary: Codable, Hashable, Identifiable {
    var appID: Int
    var total: Int
    var unlocked: Int
    var rarestUnlockedPercent: Double?

    var id: Int { appID }

    enum CodingKeys: String, CodingKey {
        case appID = "appid"
        case total
        case unlocked
        case rarestUnlockedPercent
    }
}

struct SteamStoreMetadata: Codable, Hashable {
    var name: String
    var genres: [String]
    var tags: [String]
    var releaseDate: String?
    var price: String?
    var header: URL?
}

struct SteamProfileSnapshot: Codable, Hashable {
    var resolvedID: SteamResolvedID
    var snapshotGeneratedAt: Date
    var visibility: SteamSnapshotVisibility
    var playerSummary: SteamPlayerSummary
    var ownedGames: [SteamOwnedGame]
    var achievements: [SteamGameAchievementSummary]
    var steamLevel: Int?
    var storeMetadata: [Int: SteamStoreMetadata]

    var totalLifetimePlaytimeMinutes: Int {
        ownedGames.reduce(0) { $0 + $1.playtimeForeverMinutes }
    }

    var totalRecentPlaytimeMinutes: Int {
        ownedGames.reduce(0) { $0 + $1.playtimeTwoWeeksMinutes }
    }

    var unplayedGames: [SteamOwnedGame] {
        ownedGames.filter { $0.playtimeForeverMinutes == 0 }
    }

    var hundredPercentClub: [SteamGameAchievementSummary] {
        achievements.filter { $0.total > 0 && $0.unlocked == $0.total }
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
