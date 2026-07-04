import Foundation

enum WordleMode: CaseIterable, Codable, Hashable {
    case daily
    case localDaily
    case practice

    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .localDaily:
            return "Local Daily"
        case .practice:
            return "Practice"
        }
    }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        let legacyDailyRawValue = ["ny", "tDaily"].joined()
        switch rawValue {
        case "daily", legacyDailyRawValue:
            self = .daily
        case "localDaily":
            self = .localDaily
        case "practice":
            self = .practice
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown Wordle mode")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .daily:
            try container.encode("daily")
        case .localDaily:
            try container.encode("localDaily")
        case .practice:
            try container.encode("practice")
        }
    }
}

struct WordleLeaderboardEntry: Codable, Hashable, Identifiable {
    var id: UUID
    var accountID: UUID
    var mode: WordleMode
    var sourceName: String
    var dateLabel: String
    var guesses: Int
    var maxGuesses: Int
    var submittedAt: Date

    init(
        id: UUID = UUID(),
        accountID: UUID,
        mode: WordleMode,
        sourceName: String,
        dateLabel: String,
        guesses: Int,
        maxGuesses: Int,
        submittedAt: Date = Date()
    ) {
        self.id = id
        self.accountID = accountID
        self.mode = mode
        self.sourceName = sourceName
        self.dateLabel = dateLabel
        self.guesses = guesses
        self.maxGuesses = maxGuesses
        self.submittedAt = submittedAt
    }
}

actor WordleLeaderboardStore {
    static let shared = WordleLeaderboardStore()

    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileURL: URL = WordleLeaderboardStore.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func submit(_ entry: WordleLeaderboardEntry) throws {
        var allEntries = try loadEntries()
        if !allEntries.contains(entry) {
            allEntries.append(entry)
        }
        try saveEntries(allEntries)
    }

    func entries(mode: WordleMode? = nil, limit: Int = 20) throws -> [WordleLeaderboardEntry] {
        let allEntries = try loadEntries()
        let filtered = mode.map { selected in
            allEntries.filter { $0.mode == selected }
        } ?? allEntries

        return Array(filtered.sorted(by: Self.sortEntries).prefix(limit))
    }

    func personalBest(mode: WordleMode, accountID: UUID? = nil) throws -> WordleLeaderboardEntry? {
        try entries(mode: mode, limit: Int.max)
            .filter { accountID == nil || $0.accountID == accountID }
            .first
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Kaleidoscope/WordleLeaderboard.json", isDirectory: false)
    }

    private static func sortEntries(_ lhs: WordleLeaderboardEntry, _ rhs: WordleLeaderboardEntry) -> Bool {
        if lhs.guesses != rhs.guesses { return lhs.guesses < rhs.guesses }
        if lhs.maxGuesses != rhs.maxGuesses { return lhs.maxGuesses < rhs.maxGuesses }
        return lhs.submittedAt < rhs.submittedAt
    }

    private func loadEntries() throws -> [WordleLeaderboardEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode([WordleLeaderboardEntry].self, from: data)
    }

    private func saveEntries(_ entries: [WordleLeaderboardEntry]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        try encoder.encode(entries.sorted(by: Self.sortEntries)).write(to: fileURL, options: [.atomic])
    }
}
