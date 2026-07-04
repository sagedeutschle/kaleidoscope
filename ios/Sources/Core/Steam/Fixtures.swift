// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — SteamRewind fold-in (Lens)
import Foundation

// A believable canned library so the app is delightful on first launch with zero backend.
// PRISM: Codex's SteamProfileSnapshotFixture.json is the canonical sample; next slice this decodes
// that JSON instead of hand-building. Kept in Core so it lifts into SteamKit with the models.
enum Fixtures {
    static func game(
        _ appid: Int, _ name: String, hf: Double, h2: Double, price: Double, review: Int,
        ach: Double?, rare: Double?, genre: String, year: Int, deck: Double, ownedDays: Int, lastDays: Int?
    ) -> OwnedGame {
        OwnedGame(
            appid: appid,
            name: name,
            playtimeForeverMinutes: Int(hf * 60),
            playtime2WeeksMinutes: Int(h2 * 60),
            playtimeDeckMinutes: Int(deck * 60),
            lastPlayedAt: lastDays.map { Date(timeIntervalSinceNow: -Double($0) * 86_400) },
            priceEstimateCents: Int(price * 100),
            genre: genre,
            reviewScore: review,
            releaseYear: year,
            achievementPercent: ach,
            rarestAchievementGlobalPercent: rare,
            ownedSinceDays: ownedDays
        )
    }

    static var sage: SteamProfileSnapshot {
        SteamProfileSnapshot(
            resolvedId: "76561198000000000",
            player: PlayerSummary(
                personaName: "Sage",
                avatarInitials: "SG",
                profileUrl: "https://steamcommunity.com/id/sage",
                memberSinceYear: 2013,
                country: "US"
            ),
            steamLevel: 47,
            ownedGames: [
                game(730, "Counter-Strike 2", hf: 1240, h2: 6, price: 0, review: 83, ach: 42, rare: 1.2, genre: "Shooter", year: 2023, deck: 0, ownedDays: 3800, lastDays: 2),
                game(413150, "Stardew Valley", hf: 412, h2: 0, price: 15, review: 89, ach: 78, rare: 4.5, genre: "Sim", year: 2016, deck: 60, ownedDays: 2100, lastDays: 40),
                game(427520, "Factorio", hf: 268, h2: 12, price: 35, review: 96, ach: 55, rare: 3.0, genre: "Strategy", year: 2020, deck: 0, ownedDays: 1400, lastDays: 5),
                game(105600, "Terraria", hf: 190, h2: 0, price: 10, review: 92, ach: 40, rare: 6, genre: "Sandbox", year: 2011, deck: 0, ownedDays: 2400, lastDays: 300),
                game(1086940, "Baldur's Gate 3", hf: 143, h2: 22, price: 60, review: 96, ach: 61, rare: 0.8, genre: "RPG", year: 2023, deck: 0, ownedDays: 500, lastDays: 1),
                game(252950, "Rocket League", hf: 120, h2: 0, price: 0, review: 86, ach: 22, rare: 2.0, genre: "Sports", year: 2015, deck: 0, ownedDays: 1900, lastDays: 250),
                game(1245620, "Elden Ring", hf: 112, h2: 0, price: 60, review: 94, ach: 47, rare: 1.9, genre: "RPG", year: 2022, deck: 0, ownedDays: 800, lastDays: 300),
                game(1174180, "Red Dead Redemption 2", hf: 96, h2: 0, price: 60, review: 93, ach: 34, rare: 2.1, genre: "Action", year: 2019, deck: 0, ownedDays: 900, lastDays: 120),
                game(292030, "The Witcher 3", hf: 88, h2: 0, price: 40, review: 95, ach: 36, rare: 2.5, genre: "RPG", year: 2015, deck: 0, ownedDays: 1700, lastDays: 400),
                game(1145360, "Hades", hf: 87, h2: 0, price: 25, review: 93, ach: 100, rare: 6.5, genre: "Roguelike", year: 2020, deck: 0, ownedDays: 1200, lastDays: 200),
                game(440, "Team Fortress 2", hf: 71, h2: 0, price: 0, review: 92, ach: 20, rare: 5, genre: "Shooter", year: 2007, deck: 0, ownedDays: 3600, lastDays: 300),
                game(255710, "Cities: Skylines", hf: 63, h2: 0, price: 30, review: 90, ach: 18, rare: 9, genre: "Sim", year: 2015, deck: 0, ownedDays: 1600, lastDays: 350),
                game(1794680, "Vampire Survivors", hf: 63, h2: 3, price: 5, review: 96, ach: 88, rare: 9, genre: "Roguelike", year: 2022, deck: 22, ownedDays: 700, lastDays: 30),
                game(646570, "Slay the Spire", hf: 58, h2: 2, price: 25, review: 96, ach: 45, rare: 4, genre: "Roguelike", year: 2019, deck: 0, ownedDays: 800, lastDays: 20),
                game(548430, "Deep Rock Galactic", hf: 55, h2: 8, price: 30, review: 94, ach: 33, rare: 7, genre: "Shooter", year: 2020, deck: 44, ownedDays: 900, lastDays: 4),
                game(374320, "Dark Souls III", hf: 46, h2: 0, price: 60, review: 89, ach: 30, rare: 3.5, genre: "Action", year: 2016, deck: 0, ownedDays: 1300, lastDays: 600),
                game(367520, "Hollow Knight", hf: 41, h2: 0, price: 15, review: 95, ach: 52, rare: 5, genre: "Metroidvania", year: 2017, deck: 0, ownedDays: 1600, lastDays: 250),
                game(550, "Left 4 Dead 2", hf: 34, h2: 0, price: 10, review: 96, ach: 25, rare: 8, genre: "Shooter", year: 2009, deck: 0, ownedDays: 3200, lastDays: 700),
                game(264710, "Subnautica", hf: 27, h2: 0, price: 30, review: 94, ach: 33, rare: 7, genre: "Survival", year: 2018, deck: 0, ownedDays: 1000, lastDays: 450),
                game(620, "Portal 2", hf: 24, h2: 0, price: 10, review: 95, ach: 100, rare: 8, genre: "Puzzle", year: 2011, deck: 0, ownedDays: 3000, lastDays: 900),
                game(782330, "DOOM Eternal", hf: 22, h2: 0, price: 40, review: 93, ach: 28, rare: 4.5, genre: "Shooter", year: 2020, deck: 0, ownedDays: 700, lastDays: 500),
                game(220, "Half-Life 2", hf: 18, h2: 0, price: 10, review: 96, ach: 66, rare: 12, genre: "Shooter", year: 2004, deck: 0, ownedDays: 3500, lastDays: 1500),
                game(504230, "Celeste", hf: 12, h2: 0, price: 20, review: 94, ach: 40, rare: 6, genre: "Platformer", year: 2018, deck: 0, ownedDays: 900, lastDays: 500),
                game(400, "Portal", hf: 8, h2: 0, price: 10, review: 90, ach: 100, rare: 20, genre: "Puzzle", year: 2007, deck: 0, ownedDays: 3000, lastDays: 1200),
                game(814380, "Sekiro", hf: 3, h2: 0, price: 60, review: 90, ach: 12, rare: 4, genre: "Action", year: 2019, deck: 0, ownedDays: 700, lastDays: 500),
                game(632470, "Disco Elysium", hf: 2.1, h2: 0, price: 40, review: 91, ach: 8, rare: 15, genre: "RPG", year: 2019, deck: 0, ownedDays: 600, lastDays: 400),
                game(218620, "PAYDAY 2", hf: 0.4, h2: 0, price: 10, review: 80, ach: 4, rare: 25, genre: "Shooter", year: 2013, deck: 0, ownedDays: 1500, lastDays: 1400),
                game(240720, "Getting Over It", hf: 0.3, h2: 0, price: 8, review: 75, ach: 5, rare: 30, genre: "Platformer", year: 2017, deck: 0, ownedDays: 500, lastDays: 480),
                game(489830, "The Elder Scrolls V: Skyrim", hf: 0.2, h2: 0, price: 40, review: 94, ach: 3, rare: 22, genre: "RPG", year: 2016, deck: 0, ownedDays: 2190, lastDays: 2189),
                game(1091500, "Cyberpunk 2077", hf: 0, h2: 0, price: 60, review: 79, ach: 0, rare: nil, genre: "RPG", year: 2020, deck: 0, ownedDays: 1500, lastDays: nil),
                game(2215430, "Ghost of Tsushima", hf: 0, h2: 0, price: 60, review: 90, ach: 0, rare: nil, genre: "Action", year: 2024, deck: 0, ownedDays: 200, lastDays: nil),
                game(1190460, "Death Stranding", hf: 0, h2: 0, price: 40, review: 82, ach: 0, rare: nil, genre: "Action", year: 2020, deck: 0, ownedDays: 400, lastDays: nil)
            ],
            achievementsTotal: nil,
            snapshotGeneratedAt: Date(),
            visibility: .publicProfile
        )
    }
}

struct FixtureSteamDataProvider: SteamDataProvider {
    func snapshot(forQuery query: String) async throws -> SteamProfileSnapshot {
        try? await Task.sleep(nanoseconds: 350_000_000)
        return Fixtures.sage
    }
}
