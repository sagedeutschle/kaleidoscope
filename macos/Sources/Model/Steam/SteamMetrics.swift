import Foundation

// Pure, Foundation-only metrics over a snapshot. No SwiftUI, no I/O — this is the reusable engine
// that ports unchanged to iOS / the Prismet tab.
enum SteamMetrics {
    static func totalHours(_ s: SteamProfileSnapshot) -> Double {
        s.ownedGames.reduce(0.0) { (acc: Double, g: OwnedGame) in acc + g.hoursForever }
    }

    static func estLibraryValue(_ s: SteamProfileSnapshot) -> Double {
        s.ownedGames.reduce(0.0) { (acc: Double, g: OwnedGame) in acc + (g.priceEstimate ?? 0) }
    }

    static func pileOfShameValue(_ s: SteamProfileSnapshot) -> Double {
        s.ownedGames
            .filter { $0.hoursForever < 0.5 }
            .reduce(0.0) { (acc: Double, g: OwnedGame) in acc + (g.priceEstimate ?? 0) }
    }

    static func rarestUnlockPercent(_ s: SteamProfileSnapshot) -> Double? {
        s.ownedGames.compactMap { $0.rarestAchievementGlobalPercent }.min()
    }

    static func mostPlayed(_ s: SteamProfileSnapshot) -> OwnedGame? {
        s.ownedGames.max { $0.hoursForever < $1.hoursForever }
    }

    static func costPerHour(_ g: OwnedGame) -> Double {
        g.hoursForever > 0 ? (g.priceEstimate ?? 0) / g.hoursForever : .infinity
    }

    static func bestValue(_ s: SteamProfileSnapshot) -> OwnedGame? {
        s.ownedGames.filter { $0.hoursForever > 1 }.min { costPerHour($0) < costPerHour($1) }
    }

    static func genreHours(_ s: SteamProfileSnapshot) -> [(genre: String, hours: Double)] {
        var buckets: [String: Double] = [:]
        for g in s.ownedGames {
            buckets[g.genre ?? "Other", default: 0] += g.hoursForever
        }
        return buckets
            .map { (genre: $0.key, hours: $0.value) }
            .sorted { $0.hours > $1.hours }
    }

    static func topGenre(_ s: SteamProfileSnapshot) -> String {
        genreHours(s).first?.genre ?? "eclectic"
    }

    static func deckDeskSplit(_ s: SteamProfileSnapshot) -> (deck: Double, desk: Double) {
        let deck = s.ownedGames.reduce(0.0) { $0 + $1.hoursOnDeck }
        return (deck, max(0, totalHours(s) - deck))
    }
}
