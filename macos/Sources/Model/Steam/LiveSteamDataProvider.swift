import Foundation

// Real data: resolve the input → fetch summary/level/library → enrich the most-played games with store
// metadata + achievements (bounded concurrency, staying well under Steam's rate limits) → map to the
// app's SteamProfileSnapshot. Store/achievement enrichment is capped for speed; the footer says so.
struct LiveSteamDataProvider: SteamDataProvider {
    let apiKey: String

    // How many games get the expensive per-app enrichment. Kept modest so a first load is seconds, not
    // minutes, and stays far under the storefront ~200 req / 5 min per-IP limit.
    var storeEnrichLimit = 60
    var achievementEnrichLimit = 30

    func snapshot(forQuery query: String) async throws -> SteamProfileSnapshot {
        let client = SteamAPIClient(apiKey: apiKey)
        let steamID = try await resolve(query, client)

        async let summaryTask = client.playerSummary(steamID: steamID)
        async let levelTask = client.steamLevel(steamID: steamID)
        async let ownedTask = client.ownedGames(steamID: steamID)

        let summary = try await summaryTask
        let level = try await levelTask
        let owned = try await ownedTask

        let isPublic = summary?.communityvisibilitystate == 3
        let player = mapPlayer(summary, steamID: steamID)

        guard let rawGames = owned, !rawGames.isEmpty else {
            // owned == nil → game details private; owned == [] → public but empty library.
            return SteamProfileSnapshot(
                resolvedId: steamID, player: player, steamLevel: level, ownedGames: [],
                achievementsTotal: nil, snapshotGeneratedAt: Date(),
                visibility: owned == nil ? .privateProfile : .publicProfile
            )
        }

        let byPlaytime = rawGames.sorted { $0.playtime_forever > $1.playtime_forever }
        let storeTargets = Array(byPlaytime.prefix(storeEnrichLimit))
        let achTargets = Array(byPlaytime.filter { $0.has_community_visible_stats == true }.prefix(achievementEnrichLimit))

        // Regular price for the ENTIRE library (cheap batch) so library value, cost-per-hour, and the
        // backlog/pile-of-shame include unplayed games — not just the most-played ones.
        async let pricesTask = client.libraryPrices(appids: rawGames.map { $0.appid })

        // Full store metadata (genre / year / review) only for the most-played games.
        let storeByApp = await concurrentDict(storeTargets, limit: 6) { game -> (Int, AppDataDTO)? in
            guard let data = await client.appDetails(appid: game.appid) else { return nil }
            return (game.appid, data)
        }

        let achByApp = await concurrentDict(achTargets, limit: 6) { game -> (Int, AchievementFacts)? in
            guard let result = await client.playerAchievements(steamID: steamID, appid: game.appid), result.total > 0 else { return nil }
            let globals = await client.globalPercentages(appid: game.appid)
            let rarest = result.unlockedApiNames.compactMap { globals[$0] }.min()
            let percent = Double(result.unlocked) / Double(result.total) * 100
            return (game.appid, AchievementFacts(percent: percent, rarest: rarest))
        }

        let pricesByApp = await pricesTask
        let games = rawGames.map { map($0, price: pricesByApp[$0.appid], store: storeByApp[$0.appid], ach: achByApp[$0.appid]) }

        return SteamProfileSnapshot(
            resolvedId: steamID, player: player, steamLevel: level, ownedGames: games,
            achievementsTotal: nil, snapshotGeneratedAt: Date(), visibility: isPublic ? .publicProfile : .partial
        )
    }

    // MARK: input parsing

    private func resolve(_ query: String, _ client: SteamAPIClient) async throws -> String {
        let classified = SteamInputParser.classify(query)
        switch classified {
        case .steamID64(let id):
            return id
        case .vanity(let name):
            if let id = try await client.resolveVanity(name) { return id }
            throw SteamDataError.notFound
        case .empty:
            throw SteamDataError.empty
        }
    }

    // MARK: mapping

    private struct AchievementFacts { let percent: Double; let rarest: Double? }

    private func mapPlayer(_ dto: PlayerDTO?, steamID: String) -> PlayerSummary {
        let name = dto?.personaname ?? "Steam user"
        return PlayerSummary(
            personaName: name,
            avatarInitials: initials(from: name),
            profileUrl: dto?.profileurl,
            memberSinceYear: dto?.timecreated.map { yearOf(unix: $0) },
            country: dto?.loccountrycode
        )
    }

    private func map(_ dto: OwnedGameDTO, price: Int?, store: AppDataDTO?, ach: AchievementFacts?) -> OwnedGame {
        // Whole-library batch price wins; fall back to the full-appdetails price if the batch missed it.
        var priceCents = price
        if priceCents == nil, store?.is_free != true, let po = store?.price_overview {
            priceCents = po.initial ?? po.final
        }
        let last: Date? = {
            guard let ts = dto.rtime_last_played, ts > 0 else { return nil }
            return Date(timeIntervalSince1970: TimeInterval(ts))
        }()
        return OwnedGame(
            appid: dto.appid,
            name: dto.name ?? "App \(dto.appid)",
            playtimeForeverMinutes: dto.playtime_forever,
            playtime2WeeksMinutes: dto.playtime_2weeks ?? 0,
            playtimeDeckMinutes: dto.playtime_deck_forever,
            lastPlayedAt: last,
            priceEstimateCents: priceCents,
            genre: store?.genres?.first?.description,
            reviewScore: store?.metacritic?.score,
            releaseYear: store?.release_date?.date.flatMap(yearFromReleaseString),
            achievementPercent: ach?.percent,
            rarestAchievementGlobalPercent: ach?.rarest,
            ownedSinceDays: nil
        )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(whereSeparator: { $0 == " " || $0 == "_" || $0 == "-" }).prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        if !letters.isEmpty { return letters.uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    private func yearOf(unix: Int) -> Int {
        Calendar(identifier: .gregorian).component(.year, from: Date(timeIntervalSince1970: TimeInterval(unix)))
    }

    private func yearFromReleaseString(_ raw: String) -> Int? {
        guard let match = raw.range(of: "(19|20)\\d{2}", options: .regularExpression) else { return nil }
        return Int(raw[match])
    }

    // Runs `transform` over items with at most `limit` in flight; collects (appid, value) into a dict.
    private func concurrentDict<Value>(
        _ items: [OwnedGameDTO], limit: Int,
        _ transform: @escaping (OwnedGameDTO) async -> (Int, Value)?
    ) async -> [Int: Value] {
        var out: [Int: Value] = [:]
        var next = 0
        await withTaskGroup(of: (Int, Value)?.self) { group in
            let starting = min(limit, items.count)
            for _ in 0..<starting {
                let game = items[next]; next += 1
                group.addTask { await transform(game) }
            }
            while let result = await group.next() {
                if let (key, value) = result { out[key] = value }
                if next < items.count {
                    let game = items[next]; next += 1
                    group.addTask { await transform(game) }
                }
            }
        }
        return out
    }
}

enum SteamInputParser {
    enum Result: Equatable {
        case steamID64(String)
        case vanity(String)
        case empty
    }

    static func classify(_ raw: String) -> Result {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return .empty }
        if let schemeRange = s.range(of: "://") { s = String(s[schemeRange.upperBound...]) }

        if let range = s.range(of: "/profiles/") {
            let rest = s[range.upperBound...]
            let digits = String(rest.prefix { $0.isNumber })
            if isID64(digits) { return .steamID64(digits) }
        }
        if let range = s.range(of: "/id/") {
            let rest = s[range.upperBound...]
            let vanity = String(rest.prefix { $0 != "/" && $0 != "?" && $0 != "#" })
            if !vanity.isEmpty { return .vanity(vanity) }
        }
        if isID64(s) { return .steamID64(s) }
        // Bare handle: strip any trailing path/query and treat as a vanity name.
        let handle = String(s.prefix { $0 != "/" && $0 != "?" && $0 != "#" })
        return handle.isEmpty ? .empty : .vanity(handle)
    }

    static func isID64(_ s: String) -> Bool {
        s.count == 17 && s.hasPrefix("7656119") && s.allSatisfy { $0.isNumber }
    }
}
