import Foundation

enum GameOutcome: String, Codable, Hashable {
    case won
    case lost
    case solved
    case completed
    case abandoned
}

enum LeaderboardScope: String, Codable, Hashable, CaseIterable {
    case local
    case friends
    case global
}

enum LeaderboardSortOrder: String, Codable, Hashable {
    case higherIsBetter
    case lowerIsBetter
}

struct GameResult: Codable, Hashable, Identifiable {
    var id: UUID
    var facetID: String
    var mode: String
    var outcome: GameOutcome
    var score: Int64?
    var durationSeconds: Int?
    var moveCount: Int?
    var completedAt: Date
    var metadata: [String: String]
}

struct LeaderboardMode: Codable, Hashable {
    var facetID: String
    var mode: String
    var title: String
    var sortOrder: LeaderboardSortOrder
}

struct LeaderboardEntry: Codable, Hashable, Identifiable {
    var id: String
    var rank: Int
    var displayName: String
    var score: Int64
    var detail: String?
    var submittedAt: Date
    var scope: LeaderboardScope
}

enum LeaderboardCatalog {
    private static let modes: [LeaderboardMode] = [
        LeaderboardMode(facetID: "2048", mode: "standard", title: "2048", sortOrder: .higherIsBetter),
        LeaderboardMode(facetID: "snake", mode: "standard", title: "Snake", sortOrder: .higherIsBetter),
        LeaderboardMode(facetID: "minesweeper", mode: "beginner", title: "Minesweeper Beginner", sortOrder: .lowerIsBetter),
        LeaderboardMode(facetID: "minesweeper", mode: "intermediate", title: "Minesweeper Intermediate", sortOrder: .lowerIsBetter),
        LeaderboardMode(facetID: "minesweeper", mode: "expert", title: "Minesweeper Expert", sortOrder: .lowerIsBetter),
        LeaderboardMode(facetID: "lights-out", mode: "standard", title: "Lights Out", sortOrder: .lowerIsBetter),
        LeaderboardMode(facetID: "rubiks-cube", mode: "standard", title: "Rubik's Cube", sortOrder: .lowerIsBetter),
        LeaderboardMode(facetID: "connect-four", mode: "standard", title: "Connect Four", sortOrder: .higherIsBetter),
        LeaderboardMode(facetID: "checkers", mode: "standard", title: "Checkers", sortOrder: .higherIsBetter)
    ]

    static func mode(for facetID: String, mode: String) -> LeaderboardMode? {
        modes.first { $0.facetID == facetID && $0.mode == mode }
    }
}

protocol LeaderboardService {
    func submit(_ result: GameResult) async throws
    func entries(facetID: String, mode: String, scope: LeaderboardScope, limit: Int) async throws -> [LeaderboardEntry]
    func personalBest(facetID: String, mode: String) async throws -> LeaderboardEntry?
}

actor LocalLeaderboardService: LeaderboardService {
    static let shared = LocalLeaderboardService(fileURL: LocalLeaderboardService.defaultFileURL())

    private struct Store: Codable {
        var results: [GameResult] = []
    }

    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    func submit(_ result: GameResult) async throws {
        var store = try loadStore()
        guard !store.results.contains(where: { $0.id == result.id }) else { return }
        store.results.append(result)
        try saveStore(store)
    }

    func entries(facetID: String,
                 mode: String,
                 scope: LeaderboardScope = .local,
                 limit: Int = 10) async throws -> [LeaderboardEntry] {
        guard scope == .local, limit > 0 else { return [] }

        let sortOrder = LeaderboardCatalog.mode(for: facetID, mode: mode)?.sortOrder ?? .higherIsBetter
        let rankedResults = try loadStore().results
            .filter { $0.facetID == facetID && $0.mode == mode && $0.score != nil }
            .sorted { first, second in
                guard let firstScore = first.score, let secondScore = second.score else { return false }
                if firstScore == secondScore {
                    return first.completedAt < second.completedAt
                }
                switch sortOrder {
                case .higherIsBetter: return firstScore > secondScore
                case .lowerIsBetter: return firstScore < secondScore
                }
            }
            .prefix(limit)

        return rankedResults.enumerated().compactMap { index, result in
            guard let score = result.score else { return nil }
            return LeaderboardEntry(id: result.id.uuidString,
                                    rank: index + 1,
                                    displayName: "You",
                                    score: score,
                                    detail: entryDetail(for: result),
                                    submittedAt: result.completedAt,
                                    scope: .local)
        }
    }

    func personalBest(facetID: String, mode: String) async throws -> LeaderboardEntry? {
        try await entries(facetID: facetID, mode: mode, scope: .local, limit: 1).first
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("Kaleidoscope", isDirectory: true)
            .appendingPathComponent("Leaderboards", isDirectory: true)
            .appendingPathComponent("local-results.json")
    }

    private func loadStore() throws -> Store {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return Store() }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else { return Store() }
        return try decoder.decode(Store.self, from: data)
    }

    private func saveStore(_ store: Store) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(store)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func entryDetail(for result: GameResult) -> String? {
        if let durationSeconds = result.durationSeconds {
            return "\(durationSeconds)s"
        }
        if let moveCount = result.moveCount {
            return "\(moveCount) moves"
        }
        return nil
    }
}
