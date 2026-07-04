// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — SteamRewind fold-in (Lens); LensCatalog moved into the engine (Foundation-only)
import Foundation

// The "lenses" — the fun ways to re-sort a library. Foundation-only (a lens is data + closures),
// so this stays in the reusable layer; the SwiftUI views just render what evaluate() returns.

enum Tone {
    case neutral, good, bad
}

struct LensStat {
    var big: String
    var sub: String
    var bar: Double
    var tone: Tone
}

enum LensKind {
    case list(filter: (OwnedGame) -> Bool, sort: (OwnedGame, OwnedGame) -> Bool, stat: (OwnedGame) -> LensStat)
    case genre
    case platform
}

struct Lens: Identifiable {
    var id: String
    var title: String
    var symbol: String
    var note: String?
    var blurb: (SteamProfileSnapshot) -> String
    var kind: LensKind
}

struct LensRowData: Identifiable {
    var id: Int
    var rank: Int
    var name: String
    var stat: LensStat
    var fraction: Double
}

struct BarDatum: Identifiable {
    var id: String
    var label: String
    var symbol: String?
    var fraction: Double
    var detail: String
}

enum LensResult {
    case list([LensRowData])
    case bars([BarDatum])
}

enum LensCatalog {
    static let all: [Lens] = [
        Lens(id: "played", title: "Most played", symbol: "flame.fill", note: nil,
             blurb: { s in
                guard let top = SteamMetrics.mostPlayed(s) else { return "Your library, ranked by the hours you'll never get back." }
                return "Where your life actually went — \(top.name ?? "your #1") alone is \(Fmt.days(top.hoursForever)) awake at a keyboard. No notes."
             },
             kind: .list(
                filter: { _ in true },
                sort: { $0.hoursForever > $1.hoursForever },
                stat: { g in LensStat(big: Fmt.hours(g.hoursForever), sub: Fmt.days(g.hoursForever), bar: g.hoursForever, tone: .neutral) }
             )),

        Lens(id: "value", title: "Cost per hour", symbol: "dollarsign.circle", note: "Value = current store price ÷ lifetime hours — an estimate, since Steam never says what you actually paid.",
             blurb: { s in
                guard let best = SteamMetrics.bestValue(s) else { return "Sorted by how little each hour cost you." }
                let c = SteamMetrics.costPerHour(best)
                let t = c < 0.01 ? "basically free" : String(format: "about $%.2f", c)
                return "Best money you ever spent, up top — \(best.name ?? "your top pick") works out to \(t) an hour. The bottom of this list owes you an apology."
             },
             kind: .list(
                filter: { $0.hoursForever > 0.5 },
                sort: { SteamMetrics.costPerHour($0) < SteamMetrics.costPerHour($1) },
                stat: { g in
                    let c = SteamMetrics.costPerHour(g)
                    let big = c < 0.01 ? "~free" : String(format: "$%.2f/hr", c)
                    let tone: Tone = c < 0.2 ? .good : (c > 3 ? .bad : .neutral)
                    return LensStat(big: big, sub: "\(Fmt.money(g.priceEstimate ?? 0)) · \(Fmt.hours(g.hoursForever))", bar: 1.0 / (c + 0.02), tone: tone)
                }
             )),

        Lens(id: "shame", title: "Backlog of shame", symbol: "eye.slash", note: nil,
             blurb: { s in
                "The pile of shame: \(Fmt.money(SteamMetrics.pileOfShameValue(s))) of games you've owned for years and never opened. We're not judging. (We're judging a little.)"
             },
             kind: .list(
                filter: { $0.hoursForever < 0.5 },
                sort: { ($0.priceEstimate ?? 0) > ($1.priceEstimate ?? 0) },
                stat: { g in
                    let played = g.hoursForever == 0 ? "never launched" : Fmt.minutes(g.hoursForever)
                    return LensStat(big: Fmt.money(g.priceEstimate ?? 0), sub: "\(Fmt.ownedFor(days: g.ownedSinceDays)) · \(played)", bar: g.priceEstimate ?? 0, tone: .bad)
                }
             )),

        Lens(id: "rarest", title: "Rarest flex", symbol: "sparkles", note: nil,
             blurb: { s in
                let r = SteamMetrics.rarestUnlockPercent(s).map { Fmt.percent($0) } ?? "—"
                return "Your flex shelf, sorted by how few players pulled it off. Only \(r) of humans share your rarest unlock — go ahead, screenshot it."
             },
             kind: .list(
                filter: { $0.rarestAchievementGlobalPercent != nil },
                sort: { ($0.rarestAchievementGlobalPercent ?? 100) < ($1.rarestAchievementGlobalPercent ?? 100) },
                stat: { g in
                    let p = g.rarestAchievementGlobalPercent ?? 100
                    return LensStat(big: Fmt.percent(p), sub: "of players have this", bar: 1.0 / max(0.1, p), tone: p < 2 ? .good : .neutral)
                }
             )),

        Lens(id: "hundred", title: "100% club", symbol: "trophy.fill", note: nil,
             blurb: { _ in "The finish-line club — every achievement, cleared. Certified completionist behavior, and honestly kind of unhinged (respectfully)." },
             kind: .list(
                filter: { $0.achievementPercent == 100 },
                sort: { $0.hoursForever > $1.hoursForever },
                stat: { g in LensStat(big: "100%", sub: "\(Fmt.hours(g.hoursForever)) to platinum", bar: g.hoursForever, tone: .good) }
             )),

        Lens(id: "dna", title: "Gaming DNA", symbol: "waveform", note: nil,
             blurb: { s in "Your fingerprint by hours played. You are, fundamentally, a \(SteamMetrics.topGenre(s)) person — with a suspicious amount of 'just one more run.'" },
             kind: .genre),

        Lens(id: "recent", title: "Lately", symbol: "clock", note: nil,
             blurb: { _ in "What's had its hooks in you these two weeks. This is the only near-real-time window Steam actually hands us." },
             kind: .list(
                filter: { $0.hours2Weeks > 0 },
                sort: { $0.hours2Weeks > $1.hours2Weeks },
                stat: { g in LensStat(big: Fmt.hours(g.hours2Weeks), sub: "last 2 weeks", bar: g.hours2Weeks, tone: .good) }
             )),

        Lens(id: "speed", title: "Speed daters", symbol: "heart.slash", note: nil,
             blurb: { _ in "Tried it, bailed in under half an hour, never called back. Everyone has a type; yours is apparently 'not this one.'" },
             kind: .list(
                filter: { $0.hoursForever > 0 && $0.hoursForever < 0.5 },
                sort: { $0.hoursForever < $1.hoursForever },
                stat: { g in LensStat(big: Fmt.minutes(g.hoursForever), sub: "then never again", bar: 1.0 / (g.hoursForever + 0.05), tone: .bad) }
             )),

        Lens(id: "decade", title: "By era", symbol: "calendar", note: nil,
             blurb: { _ in "From dusty classics to this year's releases — your taste refuses to pick a decade, and that's a compliment." },
             kind: .list(
                filter: { _ in true },
                sort: { ($0.releaseYear ?? 0) < ($1.releaseYear ?? 0) },
                stat: { g in LensStat(big: "\(g.releaseYear ?? 0)", sub: "\(g.genre ?? "—") · \(Fmt.hours(g.hoursForever))", bar: g.hoursForever, tone: .neutral) }
             )),

        Lens(id: "rated", title: "Top rated", symbol: "star.fill", note: nil,
             blurb: { _ in "Ranked by how the world scores them. Nice to know your backlog has excellent taste, even if you never touch it." },
             kind: .list(
                filter: { $0.reviewScore != nil },
                sort: { ($0.reviewScore ?? 0) > ($1.reviewScore ?? 0) },
                stat: { g in LensStat(big: "\(g.reviewScore ?? 0)", sub: "review score", bar: Double(g.reviewScore ?? 0), tone: (g.reviewScore ?? 0) >= 94 ? .good : .neutral) }
             )),

        Lens(id: "deck", title: "Deck vs desk", symbol: "gamecontroller", note: nil,
             blurb: { _ in "Couch versus command chair. Steam gives us lifetime hours per device, so this split is real (just not dated)." },
             kind: .platform)
    ]

    static func lens(id: String) -> Lens {
        all.first { $0.id == id } ?? all[0]
    }

    static func evaluate(_ lens: Lens, _ s: SteamProfileSnapshot) -> LensResult {
        switch lens.kind {
        case let .list(filter, sort, stat):
            let filtered = s.ownedGames.filter(filter).sorted(by: sort)
            let stats = filtered.map(stat)
            let maxBar = stats.map { $0.bar.isFinite ? $0.bar : 0 }.max() ?? 1
            let rows = zip(filtered, stats).prefix(9).enumerated().map { index, pair -> LensRowData in
                let raw = pair.1.bar.isFinite ? pair.1.bar : 0
                let fraction = maxBar > 0 ? max(0.04, raw / maxBar) : 0.04
                return LensRowData(id: pair.0.appid, rank: index + 1, name: pair.0.name ?? "App \(pair.0.appid)", stat: pair.1, fraction: fraction)
            }
            return .list(Array(rows))

        case .genre:
            let gh = SteamMetrics.genreHours(s)
            let total = gh.reduce(0.0) { $0 + $1.hours }
            let mx = gh.first?.hours ?? 1
            let bars = gh.prefix(7).map { item -> BarDatum in
                let pct = total > 0 ? Int((item.hours / total * 100).rounded()) : 0
                return BarDatum(id: item.genre, label: item.genre, symbol: nil, fraction: mx > 0 ? item.hours / mx : 0, detail: "\(Int(item.hours.rounded()))h · \(pct)%")
            }
            return .bars(Array(bars))

        case .platform:
            let split = SteamMetrics.deckDeskSplit(s)
            let total = max(0.0001, split.deck + split.desk)
            let rows: [(String, Double, String)] = [("Desktop", split.desk, "desktopcomputer"), ("Steam Deck", split.deck, "gamecontroller")]
            let bars = rows.map { row -> BarDatum in
                let pct = Int((row.1 / total * 100).rounded())
                return BarDatum(id: row.0, label: row.0, symbol: row.2, fraction: row.1 / total, detail: "\(Int(row.1.rounded()))h · \(pct)%")
            }
            return .bars(bars)
        }
    }
}
