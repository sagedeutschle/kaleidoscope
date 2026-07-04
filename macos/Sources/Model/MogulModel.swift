// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — "The Moguls" board (Debt Clock lens) — macOS mirror.
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
/// (v1 shape — kept both for old published boards and as the flat fallback list.)
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

// MARK: - The bench (Council v2)

/// A senior Justice's seat: verdict plus a written 2-3 sentence opinion.
struct JusticeOpinion: Codable, Hashable {
    /// Display name ("Opus", "GPT-5.5").
    let councilor: String
    let model: String?
    let verdict: MogulVerdict
    /// The considered judicial take — detailed, cites their actual numbers.
    let opinion: String
}

/// One juror's vote inside a mini-jury, in persona.
struct JurorVote: Codable, Hashable {
    /// Persona name ("The Skeptic", "The Butler", …).
    let persona: String
    let verdict: MogulVerdict
    let quip: String
}

/// A three-seat mini-jury. Its collective verdict occupies ONE bench seat.
struct MogulJury: Codable, Hashable {
    /// "The Sonnet Jury" / "The Mini Jury".
    let name: String
    let model: String?
    let jurors: [JurorVote]
    /// Stored by the pipeline; `MogulJury.deliberate(_:)` is the reference logic.
    let juryVerdict: MogulVerdict

    /// Majority of jurors wins the jury's seat; a full split hangs the jury → `.aight`.
    static func deliberate(_ votes: [JurorVote]) -> MogulVerdict {
        guard !votes.isEmpty else { return .aight }
        var tally: [MogulVerdict: Int] = [:]
        for vote in votes { tally[vote.verdict, default: 0] += 1 }
        let top = tally.values.max() ?? 0
        let leaders = MogulVerdict.allCases.filter { tally[$0] == top }
        return (leaders.count == 1 && top * 2 > votes.count) ? leaders[0] : .aight
    }
}

/// The full bench: two Justices + two mini-juries = four voting seats.
struct MogulBench: Codable, Hashable {
    let justices: [JusticeOpinion]
    let juries: [MogulJury]

    /// The voting system:
    /// 1. Each Justice holds one seat; each jury's collective verdict holds one seat.
    /// 2. A strict majority of seats (3+ of 4) rules.
    /// 3. On a tie, Justices who AGREE with each other prevail (senior precedence).
    /// 4. If the Justices split too, the bench is divided — officially mid (`.aight`).
    var ruling: MogulVerdict {
        let justiceVerdicts = justices.map(\.verdict)
        let seats = justiceVerdicts + juries.map(\.juryVerdict)
        guard !seats.isEmpty else { return .aight }
        var tally: [MogulVerdict: Int] = [:]
        for seat in seats { tally[seat, default: 0] += 1 }
        let top = tally.values.max() ?? 0
        let leaders = MogulVerdict.allCases.filter { tally[$0] == top }
        if leaders.count == 1, top * 2 > seats.count { return leaders[0] }
        if !justiceVerdicts.isEmpty, Set(justiceVerdicts).count == 1 { return justiceVerdicts[0] }
        return .aight
    }
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
    /// Flat list of every voice (v1 shape) — decode fallback for old boards and
    /// the compatibility surface old builds render from new boards.
    let council: [CouncilOpinion]
    /// The full bench (Council v2): Justices + juries. nil on v1 boards.
    let bench: MogulBench?
    /// Pipeline-computed tally line, e.g. "SEATS 3–1 · Sonnet Jury 2–1 gaming · Mini Jury hung".
    let voteSummary: String?
    /// The court reporter's written consensus — the bench's discourse in 2-4
    /// sentences, dissents named. nil on v1 boards.
    let consensus: String?
    /// The pipeline stores the final ruling so every install agrees even if
    /// tie-break rules evolve; `MogulBench.ruling` / `Mogul.majority(of:)` are
    /// the reference logic (v2 / v1).
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
