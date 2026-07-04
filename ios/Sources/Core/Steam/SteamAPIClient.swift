// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — SteamRewind fold-in (Lens)
import Foundation

// Thin async client over the Steam Web API + storefront appdetails. Codable shapes and gotchas are
// exactly per the verified accuracy spec: numeric ids arrive as JSON strings, playtime_2weeks is absent
// when zero, private profiles return an empty {"response":{}}, appdetails is a top-level appid->envelope
// map, global achievement percentages need no key (param is `gameid`), deck minutes are already inside
// the linux bucket, and price_overview is the CURRENT store price (never what the user paid).
struct SteamAPIClient {
    let apiKey: String
    var cc = "us"
    var lang = "english"
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    // MARK: transport

    private func makeURL(_ base: String, _ query: [String: String]) -> URL {
        var comps = URLComponents(string: base)!
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return comps.url!
    }

    private func fetch<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw SteamDataError.network
        }
        guard let http = response as? HTTPURLResponse else { throw SteamDataError.network }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw SteamDataError.invalidKey
        case 429: throw SteamDataError.rateLimited
        default: throw SteamDataError.network
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SteamDataError.network
        }
    }

    private let webBase = "https://api.steampowered.com"
    private let storeBase = "https://store.steampowered.com/api/appdetails"

    // MARK: identity

    func resolveVanity(_ vanity: String) async throws -> String? {
        let url = makeURL("\(webBase)/ISteamUser/ResolveVanityURL/v1/", ["key": apiKey, "vanityurl": vanity, "url_type": "1"])
        let env = try await fetch(url, as: Envelope<VanityResponse>.self)
        return env.response.success == 1 ? env.response.steamid : nil
    }

    func playerSummary(steamID: String) async throws -> PlayerDTO? {
        let url = makeURL("\(webBase)/ISteamUser/GetPlayerSummaries/v2/", ["key": apiKey, "steamids": steamID])
        let env = try await fetch(url, as: Envelope<PlayersResponse>.self)
        return env.response.players.first { $0.steamid == steamID } ?? env.response.players.first
    }

    func steamLevel(steamID: String) async throws -> Int? {
        let url = makeURL("\(webBase)/IPlayerService/GetSteamLevel/v1/", ["key": apiKey, "steamid": steamID])
        let env = try await fetch(url, as: Envelope<LevelResponse>.self)
        return env.response.player_level
    }

    // MARK: library

    /// Returns nil when the profile's game details are private (empty {"response":{}}).
    func ownedGames(steamID: String) async throws -> [OwnedGameDTO]? {
        let url = makeURL("\(webBase)/IPlayerService/GetOwnedGames/v1/", [
            "key": apiKey, "steamid": steamID, "include_appinfo": "1", "include_played_free_games": "1",
        ])
        let env = try await fetch(url, as: Envelope<OwnedGamesResponse>.self)
        return env.response.games
    }

    // MARK: achievements

    struct AchievementResult { let total: Int; let unlocked: Int; let unlockedApiNames: [String] }

    /// nil when the game has no achievements, the profile is private, or any error — caller just skips it.
    func playerAchievements(steamID: String, appid: Int) async -> AchievementResult? {
        let url = makeURL("\(webBase)/ISteamUserStats/GetPlayerAchievements/v1/", ["key": apiKey, "steamid": steamID, "appid": String(appid)])
        guard let env = try? await fetch(url, as: PlayerAchievementsResponse.self) else { return nil }
        guard env.playerstats.success, let achievements = env.playerstats.achievements, !achievements.isEmpty else { return nil }
        let unlocked = achievements.filter { $0.achieved == 1 }
        return AchievementResult(total: achievements.count, unlocked: unlocked.count, unlockedApiNames: unlocked.map { $0.apiname })
    }

    /// Global unlock rates keyed by achievement apiname. No key required. Empty on error.
    func globalPercentages(appid: Int) async -> [String: Double] {
        let url = makeURL("\(webBase)/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/", ["gameid": String(appid)])
        guard let env = try? await fetch(url, as: GlobalPercentagesResponse.self) else { return [:] }
        var map: [String: Double] = [:]
        for a in env.achievementpercentages.achievements { map[a.name] = a.percent }
        return map
    }

    // MARK: store metadata

    func appDetails(appid: Int) async -> AppDataDTO? {
        let url = makeURL(storeBase, ["appids": String(appid), "cc": cc, "l": lang])
        guard let map = try? await fetch(url, as: [String: AppDetailsEnvelope].self) else { return nil }
        let env = map[String(appid)]
        return (env?.success == true) ? env?.data : nil
    }

    /// Regular (list) price in cents for the whole library, via the multi-appid price_overview batch.
    /// Parsed leniently with JSONSerialization because Steam's `data` is sometimes `{}`/`[]` for free or
    /// delisted apps. Free/unpriced apps are simply absent from the result.
    func libraryPrices(appids: [Int]) async -> [Int: Int] {
        var out: [Int: Int] = [:]
        let chunkSize = 50
        var index = 0
        while index < appids.count {
            let chunk = Array(appids[index..<min(index + chunkSize, appids.count)])
            index += chunkSize
            let csv = chunk.map(String.init).joined(separator: ",")
            let url = makeURL(storeBase, ["appids": csv, "filters": "price_overview", "cc": cc])
            guard
                let (data, response) = try? await session.data(from: url),
                let http = response as? HTTPURLResponse, http.statusCode == 200,
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            for (key, value) in object {
                guard
                    let appid = Int(key),
                    let entry = value as? [String: Any],
                    (entry["success"] as? Bool) == true,
                    let dataObject = entry["data"] as? [String: Any],
                    let price = dataObject["price_overview"] as? [String: Any],
                    let initial = price["initial"] as? Int
                else { continue }
                out[appid] = initial
            }
        }
        return out
    }
}

// MARK: - Decodable DTOs (JSON shapes verified against the accuracy spec)

struct Envelope<T: Decodable>: Decodable { let response: T }

struct VanityResponse: Decodable {
    let success: Int
    let steamid: String?
    let message: String?
}

struct PlayersResponse: Decodable { let players: [PlayerDTO] }

struct PlayerDTO: Decodable {
    let steamid: String
    let personaname: String
    let profileurl: String?
    let avatarfull: String?
    let communityvisibilitystate: Int
    let timecreated: Int?
    let loccountrycode: String?
}

struct LevelResponse: Decodable { let player_level: Int? }

struct OwnedGamesResponse: Decodable {
    let game_count: Int?
    let games: [OwnedGameDTO]?
}

struct OwnedGameDTO: Decodable {
    let appid: Int
    let name: String?
    let img_icon_url: String?
    let playtime_forever: Int
    let playtime_2weeks: Int?
    let playtime_deck_forever: Int?
    let rtime_last_played: Int?
    let has_community_visible_stats: Bool?
}

struct PlayerAchievementsResponse: Decodable { let playerstats: PlayerStatsDTO }

struct PlayerStatsDTO: Decodable {
    let success: Bool
    let error: String?
    let achievements: [PlayerAchDTO]?
}

struct PlayerAchDTO: Decodable {
    let apiname: String
    let achieved: Int
}

struct GlobalPercentagesResponse: Decodable { let achievementpercentages: GlobalPctDTO }
struct GlobalPctDTO: Decodable { let achievements: [GlobalAchDTO] }
struct GlobalAchDTO: Decodable {
    let name: String
    let percent: Double
    enum CodingKeys: String, CodingKey { case name, percent }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        // Steam encodes this as a quoted string ("72.0"), not a number — tolerate both.
        if let d = try? c.decode(Double.self, forKey: .percent) {
            percent = d
        } else if let s = try? c.decode(String.self, forKey: .percent), let d = Double(s) {
            percent = d
        } else {
            percent = 0
        }
    }
}

struct AppDetailsEnvelope: Decodable {
    let success: Bool
    let data: AppDataDTO?
}

struct AppDataDTO: Decodable {
    let type: String?
    let name: String?
    let is_free: Bool?
    let genres: [GenreDTO]?
    let release_date: ReleaseDateDTO?
    let price_overview: PriceOverviewDTO?
    let metacritic: MetacriticDTO?
}

struct GenreDTO: Decodable { let description: String }
struct ReleaseDateDTO: Decodable { let coming_soon: Bool?; let date: String? }
struct PriceOverviewDTO: Decodable {
    let currency: String?
    let initial: Int?
    let final: Int?
    let discount_percent: Int?
}
struct MetacriticDTO: Decodable { let score: Int? }
