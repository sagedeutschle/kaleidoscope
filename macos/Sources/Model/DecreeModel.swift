import Foundation

/// A bundled snapshot of the Wizard King's Decree — a self-grading model-council
/// forecasting experiment. Exported from the live `fun.db` via
/// `tools/export_decrees_json.py` and shipped as `decrees.json` in the app bundle.
struct DecreeChronicle: Codable, Equatable {
    var generated: String
    var record: DecreeRecord
    var decrees: [Decree]
    var divided: [DividedMatter]

    static let empty = DecreeChronicle(generated: "—", record: DecreeRecord(),
                                       decrees: [], divided: [])

    /// Loads the bundled `decrees.json` snapshot (falls back to empty if absent).
    static func loadBundled() -> DecreeChronicle {
        guard let url = Bundle.main.url(forResource: "decrees", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let chronicle = try? JSONDecoder().decode(DecreeChronicle.self, from: data)
        else { return .empty }
        return chronicle
    }
}

struct DecreeRecord: Codable, Equatable {
    var total = 0
    var standing = 0
    var vindicated = 0
    var cliffnotes = 0
    var apology = 0
    var cancellation = 0
    var divided = 0
    var ruled = 0

    /// Vindicated ÷ ruled — nil until at least one decree has been judged.
    var hitRate: Double? { ruled > 0 ? Double(vindicated) / Double(ruled) : nil }
    /// All non-vindicated rulings (the King had to correct the record).
    var corrected: Int { cliffnotes + apology + cancellation }
}

struct Decree: Codable, Identifiable, Equatable {
    var id: Int
    var title: String
    var regal: String        // the King's absolute, theatrical proclamation
    var claim: String        // the underlying falsifiable claim
    var status: String       // standing / vindicated / cliffnotes / apology / cancelled
    var confidence: Double   // the council's PRIVATE probability (public decree is absolute)
    var resolves: String     // ISO date the matter settles
    var domain: String
    var verdict: String?     // the Court Historian's ruling, once judged
    var correction: String?  // the correction copy (cliffnotes / apology / cancellation)
    var criteria: String?    // how the Historian judges it (resolution criteria)
    var source: String?      // "harvested" or "free-pick" (the King web-searched it)

    /// The tier currently in force: the Historian's verdict once ruled, else the status.
    var tier: String { verdict ?? status }
}

struct DividedMatter: Codable, Identifiable, Equatable {
    var title: String
    var resolves: String
    var id: String { title }
}

// MARK: - Oracle tab categorization (shared verbatim with the iOS app)

extension Decree {
    /// A live prophecy the Court Historian hasn't ruled on yet.
    var isStanding: Bool { tier == "standing" }
    /// The King was right.
    var isVindicated: Bool { tier == "vindicated" }
    /// The King had to walk it back (cliffnotes / apology / cancellation).
    var isCorrected: Bool {
        ["cliffnotes", "apology", "cancellation", "cancelled"].contains(tier)
    }
    /// The matter has been reckoned — vindicated or corrected.
    var isReckoned: Bool { isVindicated || isCorrected }

    /// The resolution date parsed from `resolves` ("yyyy-MM-dd"), if valid.
    var resolveDate: Date? {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: resolves)
    }

    /// A still-`standing` decree whose resolution date has already passed: the
    /// Court Historian simply hasn't graded it yet. Surfaced as "awaiting ruling".
    func isAwaitingRuling(asOf today: Date = Date()) -> Bool {
        guard isStanding, let resolveDate else { return false }
        return resolveDate < Calendar.current.startOfDay(for: today)
    }

    /// Free-text match across the fields a reader would search.
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return title.lowercased().contains(q)
            || regal.lowercased().contains(q)
            || claim.lowercased().contains(q)
            || domain.lowercased().contains(q)
            || (verdict?.lowercased().contains(q) ?? false)
            || (correction?.lowercased().contains(q) ?? false)
            || (criteria?.lowercased().contains(q) ?? false)
    }
}

/// Ways to order the Oracle's decrees. Congruent across both apps.
enum DecreeSort: String, CaseIterable, Identifiable {
    case expirationSoon
    case expirationLate
    case confidenceHigh
    case newest
    case domain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expirationSoon: return "Expiration (soonest)"
        case .expirationLate: return "Expiration (latest)"
        case .confidenceHigh: return "Confidence (high→low)"
        case .newest:         return "Newest first"
        case .domain:         return "Domain (A→Z)"
        }
    }

    var systemImage: String {
        switch self {
        case .expirationSoon: return "calendar"
        case .expirationLate: return "calendar.badge.clock"
        case .confidenceHigh: return "lock"
        case .newest:         return "sparkles"
        case .domain:         return "tag"
        }
    }
}

extension Array where Element == Decree {
    /// Free-text filter, then the chosen ordering. Decrees without a valid
    /// resolution date sort to the end of the date orderings.
    func searchedAndSorted(query: String, by sort: DecreeSort) -> [Decree] {
        let filtered = filter { $0.matches(query) }
        switch sort {
        case .expirationSoon:
            return filtered.sorted { ($0.resolveDate ?? .distantFuture) < ($1.resolveDate ?? .distantFuture) }
        case .expirationLate:
            return filtered.sorted { ($0.resolveDate ?? .distantPast) > ($1.resolveDate ?? .distantPast) }
        case .confidenceHigh:
            return filtered.sorted { $0.confidence > $1.confidence }
        case .newest:
            return filtered.sorted { $0.id > $1.id }
        case .domain:
            return filtered.sorted { $0.domain.localizedCaseInsensitiveCompare($1.domain) == .orderedAscending }
        }
    }
}
