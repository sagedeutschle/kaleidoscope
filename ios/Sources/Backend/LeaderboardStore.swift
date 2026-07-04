import Foundation
import Supabase

/// A row in the global `leaderboard_scores` table. Denormalized display fields so
/// the board reads publicly without exposing the profiles table.
///
/// Rows are written under the device's Supabase auth uid (`userID`, which RLS
/// enforces) and additionally tagged with the player's Game Center-derived
/// `gcAccountID` when signed in. The GC id is the durable cross-device identity:
/// the same human on iPhone + iPad produces rows with different `userID`s but the
/// same `gcAccountID`, and friend boards match on it.
struct LeaderboardRow: Codable, Hashable {
    var userID: UUID
    var gameID: String
    var score: Int
    var displayName: String
    var avatarEmoji: String
    var avatarColor: String
    var gcAccountID: UUID?

    init(
        userID: UUID,
        gameID: String,
        score: Int,
        displayName: String,
        avatarEmoji: String,
        avatarColor: String,
        gcAccountID: UUID? = nil
    ) {
        self.userID = userID
        self.gameID = gameID
        self.score = score
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.avatarColor = avatarColor
        self.gcAccountID = gcAccountID
    }

    /// One identity per human: the Game Center id when present, else the device
    /// account id. Boards dedupe on this so multi-device players show once.
    var canonicalPlayerID: UUID { gcAccountID ?? userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case gameID = "game_id"
        case score
        case displayName = "display_name"
        case avatarEmoji = "avatar_emoji"
        case avatarColor = "avatar_color"
        case gcAccountID = "gc_account_id"
    }
}

/// How a game's score is ranked. Some games are "high score wins", others are
/// "fewest moves" / "fastest time" (lower wins).
enum LeaderboardMetric: Equatable {
    case highScore      // higher is better
    case fewestMoves    // lower is better
    case fastestTime    // lower is better (seconds)

    var higherIsBetter: Bool { self == .highScore }
    var unit: String {
        switch self {
        case .highScore: return "pts"
        case .fewestMoves: return "moves"
        case .fastestTime: return "s"
        }
    }
    var blurb: String {
        switch self {
        case .highScore: return "Highest score"
        case .fewestMoves: return "Fewest moves"
        case .fastestTime: return "Fastest time"
        }
    }
}

/// How long a game's board lasts against friends: `daily` boards reset every day
/// (a fresh board per date), `lifetime` boards keep a permanent best score.
enum LeaderboardPeriod: Equatable {
    case daily
    case lifetime
    var label: String { self == .daily ? "Daily" : "All-Time" }
}

/// Which games carry a single-player leaderboard, and how they're ranked.
/// Hot-seat board games, AI Chess, and the lore/build facets are mostly not
/// ranked. Checkers is ranked only in human-vs-AI mode from the game view.
enum LeaderboardCatalog {
    static func metric(for game: CanonicalGameID) -> LeaderboardMetric? {
        switch game {
        case .wordle: return .fewestMoves
        case .game2048, .snake, .checkers: return .highScore
        case .lightsOut, .slidingPuzzle, .rubiks: return .fewestMoves
        default: return nil
        }
    }

    /// The games that appear in the leaderboard browser, in display order.
    private static let globallyRanked: [CanonicalGameID] = [.game2048, .snake, .checkers, .lightsOut, .slidingPuzzle, .rubiks]

    static func ranked(friendsOnly: Bool) -> [CanonicalGameID] {
        friendsOnly ? [.wordle] + globallyRanked : globallyRanked
    }

    static func isRanked(_ game: CanonicalGameID, friendsOnly: Bool) -> Bool {
        ranked(friendsOnly: friendsOnly).contains(game)
    }

    static func title(for game: CanonicalGameID) -> String {
        switch game {
        case .game2048: return "2048"
        case .snake: return "Snake"
        case .lightsOut: return "Lights Out"
        case .slidingPuzzle: return "Sliding Puzzle"
        case .rubiks: return "Rubik's Cube"
        case .wordle: return "Wordgame"
        case .checkers: return "Checkers"
        default: return game.rawValue.capitalized
        }
    }

    /// Daily boards reset each day; lifetime boards are permanent. Only Wordgame
    /// (the daily word game) is daily for now — everything else is all-time.
    static func period(for game: CanonicalGameID) -> LeaderboardPeriod {
        game == .wordle ? .daily : .lifetime
    }

    /// Storage key for a game's rows. Daily games encode the date so each day is its
    /// own board (auto-reset, no schema needed); lifetime games use the plain id.
    static func storageID(for game: CanonicalGameID, on date: Date = Date()) -> String {
        switch period(for: game) {
        case .daily:    return "\(game.rawValue)#\(dailyKey(date))"
        case .lifetime: return game.rawValue
        }
    }

    static func dailyKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func canonicalGameID(fromStorageID storageID: String) -> CanonicalGameID? {
        let rawID = storageID.split(separator: "#", maxSplits: 1).first.map(String.init) ?? storageID
        return CanonicalGameID(rawValue: rawID)
    }
}

/// Reads/writes the global `leaderboard_scores` table via the shared Supabase client.
final class LeaderboardStore {
    typealias RemoteSubmitter = (LeaderboardRow, CanonicalGameID) async throws -> Void

    static let shared = LeaderboardStore()

    private let clientProvider: () -> SupabaseClient?
    private let localStore: LocalLeaderboardStore
    private let remoteSubmitter: RemoteSubmitter?
    private let rateLimiter: SecurityRateLimiter

    init(
        clientProvider: @escaping () -> SupabaseClient? = { Backend.client },
        localStore: LocalLeaderboardStore = .shared,
        remoteSubmitter: RemoteSubmitter? = nil,
        rateLimiter: SecurityRateLimiter = AppSecurity.clientRateLimiter
    ) {
        self.clientProvider = clientProvider
        self.localStore = localStore
        self.remoteSubmitter = remoteSubmitter
        self.rateLimiter = rateLimiter
    }

    private var client: SupabaseClient? { clientProvider() }

    /// Top entries for a game, ordered by the metric. Pass `friendIDs` (the local
    /// player's ids + Game Center friend ids) to scope the board to friends only;
    /// nil / empty = global. Rows match a friend id on either `gc_account_id`
    /// (durable, cross-device) or `user_id` (device account).
    func top(
        game: CanonicalGameID,
        friendIDs: [UUID]? = nil,
        limit: Int = 25
    ) async throws -> [LeaderboardRow] {
        guard let metric = LeaderboardCatalog.metric(for: game) else { return [] }
        let friendSet = (friendIDs?.isEmpty == false) ? Set(friendIDs!) : nil
        guard LeaderboardCatalog.isRanked(game, friendsOnly: friendSet != nil) else { return [] }
        await syncPendingUploads(game: game)
        let storageID = LeaderboardCatalog.storageID(for: game)
        let localRows = Self.filter((try? await localStore.top(game: game, limit: limit)) ?? [], friendSet: friendSet)
        guard let client else {
            return Self.bestRows(localRows, game: game, storageID: storageID, limit: limit)
        }
        let base = client
            .from("leaderboard_scores")
            .select()
            .eq("game_id", value: storageID)
        let scoped: PostgrestTransformBuilder
        if let friendSet {
            let idList = friendSet.map(\.uuidString).joined(separator: ",")
            scoped = base.or("user_id.in.(\(idList)),gc_account_id.in.(\(idList))")
        } else {
            scoped = base
        }
        // Over-fetch so client-side canonical dedupe (one row per human across
        // devices) still fills the board.
        let remoteRows: [LeaderboardRow] = try await scoped
            .order("score", ascending: !metric.higherIsBetter)
            .limit(max(limit * 4, 100))
            .execute()
            .value
        return Self.bestRows(remoteRows + localRows, game: game, storageID: storageID, limit: limit)
    }

    func myRow(accountID: UUID, gcAccountID: UUID? = nil, game: CanonicalGameID) async throws -> LeaderboardRow? {
        let storageID = LeaderboardCatalog.storageID(for: game)
        let localRow = try? await localStore.myRow(accountID: accountID, gcAccountID: gcAccountID, game: game)
        guard let client else { return localRow }
        var identityFilters = ["user_id.eq.\(accountID.uuidString)"]
        if let gcAccountID {
            identityFilters.append("gc_account_id.eq.\(gcAccountID.uuidString)")
        }
        let rows: [LeaderboardRow] = try await client
            .from("leaderboard_scores")
            .select()
            .eq("game_id", value: storageID)
            .or(identityFilters.joined(separator: ","))
            .limit(10)
            .execute()
            .value
        let candidates = rows + (localRow.map { [$0] } ?? [])
        return candidates.max { lhs, rhs in
            Self.isBetter(rhs.score, than: lhs.score, game: game)
        }
    }

    /// Submit a score, keeping only the player's *best* per the game's metric.
    func submitBest(_ row: LeaderboardRow, game: CanonicalGameID) async throws {
        guard LeaderboardCatalog.metric(for: game) != nil else { return }
        var storedRow = row.sanitizedForClientUpload()
        storedRow.gameID = LeaderboardCatalog.storageID(for: game)
        try await localStore.submitBest(storedRow, game: game)
        await syncPendingUploads(game: game)
    }

    func syncPendingUploads(game: CanonicalGameID? = nil) async {
        guard remoteSubmitter != nil || client != nil else { return }
        let pendingRows = (try? await localStore.pendingUploads(game: game)) ?? []
        for row in pendingRows {
            guard let gameID = LeaderboardCatalog.canonicalGameID(fromStorageID: row.gameID) else { continue }
            do {
                try await upload(row, game: gameID)
                try await localStore.markUploaded(row)
            } catch {
                continue
            }
        }
    }

    private func upload(_ row: LeaderboardRow, game: CanonicalGameID) async throws {
        guard await AppSecurity.allowClientAction(
            .leaderboardSubmit,
            scope: "\(row.userID.uuidString):\(row.gameID)",
            rateLimiter: rateLimiter
        ) else { throw AppSecurityError.rateLimited }
        if let remoteSubmitter {
            try await remoteSubmitter(row, game)
            return
        }
        guard let client else { return }
        if let existing = try? await remoteRow(accountID: row.userID, game: game),
           !Self.isBetter(row.score, than: existing.score, game: game) {
            return
        }
        try await client
            .from("leaderboard_scores")
            .upsert(row, onConflict: "user_id,game_id")
            .execute()
    }

    private func remoteRow(accountID: UUID, game: CanonicalGameID) async throws -> LeaderboardRow? {
        guard let client else { return nil }
        let storageID = LeaderboardCatalog.storageID(for: game)
        let rows: [LeaderboardRow] = try await client
            .from("leaderboard_scores")
            .select()
            .eq("user_id", value: accountID.uuidString)
            .eq("game_id", value: storageID)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    fileprivate static func bestRows(
        _ rows: [LeaderboardRow],
        game: CanonicalGameID,
        storageID: String = "",
        limit: Int
    ) -> [LeaderboardRow] {
        let boardID = storageID.isEmpty ? LeaderboardCatalog.storageID(for: game) : storageID
        // Key on the canonical player id so one human's rows from several devices
        // collapse into a single entry showing their overall best.
        var bestByPlayer: [UUID: LeaderboardRow] = [:]
        for row in rows where row.gameID == boardID {
            if let existing = bestByPlayer[row.canonicalPlayerID],
               !isBetter(row.score, than: existing.score, game: game) {
                continue
            }
            bestByPlayer[row.canonicalPlayerID] = row
        }

        return Array(bestByPlayer.values)
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return isBetter(lhs.score, than: rhs.score, game: game)
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    fileprivate static func isBetter(_ candidate: Int, than existing: Int, game: CanonicalGameID) -> Bool {
        guard let metric = LeaderboardCatalog.metric(for: game) else { return false }
        return metric.higherIsBetter ? candidate > existing : candidate < existing
    }

    private static func filter(
        _ rows: [LeaderboardRow],
        friendSet: Set<UUID>?
    ) -> [LeaderboardRow] {
        guard let friendSet else { return rows }
        return rows.filter { row in
            friendSet.contains(row.userID)
                || row.gcAccountID.map(friendSet.contains) == true
        }
    }
}

actor LocalLeaderboardStore {
    static let shared = LocalLeaderboardStore()

    private let fileURL: URL
    private let fileManager: FileManager
    private var pendingFileURL: URL {
        fileURL.deletingPathExtension().appendingPathExtension("pending.json")
    }

    init(
        fileURL: URL = LocalLeaderboardStore.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func top(game: CanonicalGameID, limit: Int = 25) throws -> [LeaderboardRow] {
        try LeaderboardStore.bestRows(
            loadRows(),
            game: game,
            storageID: LeaderboardCatalog.storageID(for: game),
            limit: limit
        )
    }

    func myRow(accountID: UUID, gcAccountID: UUID? = nil, game: CanonicalGameID) throws -> LeaderboardRow? {
        try top(game: game, limit: Int.max).first {
            $0.userID == accountID || ($0.gcAccountID != nil && $0.gcAccountID == gcAccountID)
        }
    }

    func submitBest(_ row: LeaderboardRow, game: CanonicalGameID) throws {
        guard LeaderboardCatalog.metric(for: game) != nil else { return }
        let storageID = LeaderboardCatalog.storageID(for: game)
        var storedRow = row
        storedRow.gameID = storageID
        var rows = try loadRows()
        if let index = rows.firstIndex(where: { $0.userID == storedRow.userID && $0.gameID == storageID }) {
            guard LeaderboardStore.isBetter(storedRow.score, than: rows[index].score, game: game) else { return }
            rows[index] = storedRow
        } else {
            rows.append(storedRow)
        }
        try saveRows(rows)
        var pendingKeys = try loadPendingKeys()
        pendingKeys.insert(Self.uploadKey(storedRow))
        try savePendingKeys(pendingKeys)
    }

    func pendingUploads(game: CanonicalGameID? = nil) throws -> [LeaderboardRow] {
        let pendingKeys = try loadPendingKeys()
        return try loadRows().filter { row in
            guard pendingKeys.contains(Self.uploadKey(row)) else { return false }
            guard let game else { return true }
            return LeaderboardCatalog.canonicalGameID(fromStorageID: row.gameID) == game
        }
    }

    func markUploaded(_ row: LeaderboardRow) throws {
        var pendingKeys = try loadPendingKeys()
        pendingKeys.remove(Self.uploadKey(row))
        try savePendingKeys(pendingKeys)
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Kaleidoscope/Leaderboards.json", isDirectory: false)
    }

    private func loadRows() throws -> [LeaderboardRow] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([LeaderboardRow].self, from: data)
    }

    private func saveRows(_ rows: [LeaderboardRow]) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rows).write(to: fileURL, options: [.atomic])
    }

    private func loadPendingKeys() throws -> Set<String> {
        guard fileManager.fileExists(atPath: pendingFileURL.path) else { return [] }
        let data = try Data(contentsOf: pendingFileURL)
        return Set(try JSONDecoder().decode([String].self, from: data))
    }

    private func savePendingKeys(_ keys: Set<String>) throws {
        try fileManager.createDirectory(at: pendingFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(keys.sorted()).write(to: pendingFileURL, options: [.atomic])
    }

    private static func uploadKey(_ row: LeaderboardRow) -> String {
        "\(row.gameID)|\(row.userID.uuidString)"
    }
}
