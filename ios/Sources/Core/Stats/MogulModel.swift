// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — "The Moguls" board (Debt Clock lens).
// Data shapes for the billionaire/CEO vibe-check ledger. The council pipeline runs
// offline (Claude + Codex + DeepSeek CLIs/APIs on the source laptop), publishes
// moguls.json to a public gist, and the app reads it — same serve pattern as decrees.
// Verdicts are SATIRE (AI comedy bits, not factual claims); the view carries the
// disclaimer. Figures are public estimates (Forbes/Bloomberg/proxy filings).
import Foundation

/// The Council's comedic ruling on a mogul. Raw values are stable JSON keys;
/// display text/stamps live on the enum so every surface agrees.
enum MogulVerdict: String, Codable, CaseIterable, Hashable {
    case fraud
    case aight
    case gaming

    /// The stamp as it appears on the board.
    var stamp: String {
        switch self {
        case .fraud: return "FRAUD!"
        case .aight: return "Aight..."
        case .gaming: return "GAMING!!!!"
        }
    }

    /// Sort weight: the board can rank the vibe-checked above the busted.
    var weight: Int {
        switch self {
        case .gaming: return 2
        case .aight: return 1
        case .fraud: return 0
        }
    }
}

/// One councilor's take: who they are, their verdict, and the roast line.
struct CouncilOpinion: Codable, Hashable {
    /// Display name of the bot ("Claude", "Codex", "DeepSeek").
    let councilor: String
    /// Model identifier as reported by the pipeline (informational).
    let model: String?
    let verdict: MogulVerdict
    /// One comedic line. Satire only — the pipeline instructs the bots:
    /// roast the vibe, never allege actual crimes.
    let quip: String
}

/// A person on the board: a billionaire, a top-paid CEO, or both.
struct Mogul: Codable, Identifiable, Hashable {
    enum Category: String, Codable, CaseIterable, Hashable {
        case billionaire
        case ceo
        case both

        var label: String {
            switch self {
            case .billionaire: return "Billionaire"
            case .ceo: return "CEO"
            case .both: return "Billionaire · CEO"
            }
        }
    }

    let id: String
    let name: String
    /// Role + companies, e.g. "Tesla, SpaceX — CEO".
    let title: String
    let category: Category
    /// Estimated net worth in USD (nil when not meaningfully public).
    let netWorthUSD: Double?
    /// Latest disclosed annual total compensation in USD (nil for pure billionaires).
    let annualCompUSD: Double?
    /// Year the compensation figure was disclosed for.
    let compYear: Int?
    /// Latest disclosed MEDIAN employee annual pay at their primary company
    /// (SEC Dodd-Frank pay-ratio disclosures; nil for private/no-disclosure).
    /// Optional key — older published boards without it still decode.
    let medianWorkerPayUSD: Double?
    let knownFor: String
    /// Where the figures came from, e.g. "Forbes Real-Time 2026-07-04".
    let source: String
    let council: [CouncilOpinion]
    /// The pipeline stores the final ruling so every install agrees even if
    /// tie-break rules evolve; `Mogul.majority(of:)` is the reference logic.
    let finalVerdict: MogulVerdict

    /// Boss-to-median-worker pay multiple (the Dodd-Frank pay ratio) — the
    /// absurdity number. nil unless both figures are disclosed.
    var payRatio: Double? {
        guard let comp = annualCompUSD,
              let worker = medianWorkerPayUSD, worker > 0 else { return nil }
        return comp / worker
    }

    /// Majority ruling across council opinions. Ties (including a full three-way
    /// split) land on `.aight` — when the council can't agree, the vibe is
    /// officially mid. Empty councils are also mid by definition.
    static func majority(of opinions: [CouncilOpinion]) -> MogulVerdict {
        guard !opinions.isEmpty else { return .aight }
        var tally: [MogulVerdict: Int] = [:]
        for opinion in opinions { tally[opinion.verdict, default: 0] += 1 }
        let top = tally.values.max() ?? 0
        let leaders = MogulVerdict.allCases.filter { tally[$0] == top }
        return leaders.count == 1 ? leaders[0] : .aight
    }
}

/// The published board: an as-of date plus the ranked roster.
struct MogulLedger: Codable, Hashable {
    let asOf: String
    let moguls: [Mogul]

    /// Roster sorted for display: net worth descending, compensation as the
    /// fallback axis so salary-list CEOs interleave sensibly.
    var ranked: [Mogul] {
        moguls.sorted {
            ($0.netWorthUSD ?? $0.annualCompUSD ?? 0) > ($1.netWorthUSD ?? $1.annualCompUSD ?? 0)
        }
    }
}
