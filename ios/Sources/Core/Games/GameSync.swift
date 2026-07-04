import Foundation

enum CanonicalGameID: String, CaseIterable, Codable, Hashable {
    case game2048 = "2048"
    case snake
    case minesweeper
    case sudoku
    case rubiks = "rubiks"
    case chess
    case lightsOut = "lightsout"
    case slidingPuzzle = "sliding"
    case nonogram
    case wordle
    case reversi
    case checkers
    case connectFour = "connectfour"
    case gomoku
    case seaBattle = "seabattle"
    case solitaire
    case spider
    case crazyEight = "crazyeight"
    case brickBench = "brickbench"
    case oracle
}

enum GameSaveCodec {
    static let schemaVersion = 1

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    static func encodeSnapshot<T: Encodable>(_ snapshot: T) throws -> String {
        let data = try encoder.encode(snapshot)
        guard let json = String(data: data, encoding: .utf8) else {
            throw GameSaveError.invalidUTF8
        }
        return json
    }

    static func decodeSnapshot<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw GameSaveError.invalidUTF8
        }
        return try decoder.decode(T.self, from: data)
    }

    static func encodeRecord(_ record: GameSaveRecord) throws -> Data {
        try encoder.encode(record)
    }

    static func decodeRecord(from data: Data) throws -> GameSaveRecord {
        try decoder.decode(GameSaveRecord.self, from: data)
    }
}

enum GameSaveError: Error {
    case invalidUTF8
}

struct GameCloudPushPolicy: Equatable {
    var minimumInterval: TimeInterval

    static let immediate = GameCloudPushPolicy(minimumInterval: 0)
    static let highFrequencyGameplay = GameCloudPushPolicy(minimumInterval: 2)

    func shouldPush(lastPushAt: Date?, now: Date = Date(), force: Bool = false) -> Bool {
        if force { return true }
        guard let lastPushAt else { return true }
        return now.timeIntervalSince(lastPushAt) >= minimumInterval
    }
}

struct GameSaveRecord: Codable, Equatable {
    var accountID: UUID
    var gameID: CanonicalGameID
    var schemaVersion: Int
    var score: Int?
    var stateJSON: String
    var updatedAt: Date
    var sourcePlatform: String

    static func make<T: Encodable>(
        accountID: UUID,
        gameID: CanonicalGameID,
        score: Int?,
        snapshot: T,
        updatedAt: Date = Date(),
        sourcePlatform: String = "ios"
    ) throws -> GameSaveRecord {
        GameSaveRecord(
            accountID: accountID,
            gameID: gameID,
            schemaVersion: GameSaveCodec.schemaVersion,
            score: score,
            stateJSON: try GameSaveCodec.encodeSnapshot(snapshot),
            updatedAt: updatedAt,
            sourcePlatform: sourcePlatform
        )
    }

    static func == (lhs: GameSaveRecord, rhs: GameSaveRecord) -> Bool {
        lhs.accountID == rhs.accountID &&
        lhs.gameID == rhs.gameID &&
        lhs.schemaVersion == rhs.schemaVersion &&
        lhs.score == rhs.score &&
        lhs.stateJSON == rhs.stateJSON &&
        lhs.updatedAt.timeIntervalSince(rhs.updatedAt).magnitude < 0.001 &&
        lhs.sourcePlatform == rhs.sourcePlatform
    }
}

struct CloudGameSaveRow: Codable, Equatable {
    var userID: UUID
    var gameID: String
    var schemaVersion: Int
    var score: Int?
    var stateJSON: String
    var updatedAt: Date
    var sourcePlatform: String

    init(record: GameSaveRecord) {
        self.userID = record.accountID
        self.gameID = record.gameID.rawValue
        self.schemaVersion = record.schemaVersion
        self.score = record.score
        self.stateJSON = record.stateJSON
        self.updatedAt = record.updatedAt
        self.sourcePlatform = record.sourcePlatform
    }

    func record() throws -> GameSaveRecord {
        guard let gameID = CanonicalGameID(rawValue: gameID) else {
            throw CloudGameSaveRowError.unknownGameID(gameID)
        }
        return GameSaveRecord(
            accountID: userID,
            gameID: gameID,
            schemaVersion: schemaVersion,
            score: score,
            stateJSON: stateJSON,
            updatedAt: updatedAt,
            sourcePlatform: sourcePlatform
        )
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case gameID = "game_id"
        case schemaVersion = "schema_version"
        case score
        case stateJSON = "state_json"
        case updatedAt = "updated_at"
        case sourcePlatform = "source_platform"
    }
}

enum CloudGameSaveRowError: Error {
    case unknownGameID(String)
}

final class GameSaveStore {
    static let shared = GameSaveStore()

    private let rootURL: URL
    private let fileManager: FileManager

    init(
        rootURL: URL = GameSaveStore.defaultRootURL(),
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    func save(_ record: GameSaveRecord) throws {
        let fileURL = url(accountID: record.accountID, gameID: record.gameID)
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try GameSaveCodec.encodeRecord(record).write(to: fileURL, options: [.atomic])
    }

    func load(accountID: UUID, gameID: CanonicalGameID) throws -> GameSaveRecord? {
        let fileURL = url(accountID: accountID, gameID: gameID)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try GameSaveCodec.decodeRecord(from: data)
    }

    static func defaultRootURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Kaleidoscope/GameSaves", isDirectory: true)
    }

    private func url(accountID: UUID, gameID: CanonicalGameID) -> URL {
        rootURL
            .appendingPathComponent(accountID.uuidString, isDirectory: true)
            .appendingPathComponent("\(gameID.rawValue).json", isDirectory: false)
    }
}

struct Game2048Snapshot: Codable, Equatable, Hashable {
    var game: Game2048
    var rng: SeededGenerator
    var best: Int
    var visualShuffleSeed: UInt64
    var shuffleAnimationEnabled: Bool
    var shuffleUsesPerGame: Int
    var shufflePowerUps: Game2048ShufflePowerUps

    init(
        game: Game2048,
        rng: SeededGenerator,
        best: Int,
        visualShuffleSeed: UInt64 = 4,
        shuffleAnimationEnabled: Bool = true,
        shuffleUsesPerGame: Int = 1,
        shufflePowerUps: Game2048ShufflePowerUps = Game2048ShufflePowerUps()
    ) {
        self.game = game
        self.rng = rng
        self.best = best
        self.visualShuffleSeed = visualShuffleSeed
        self.shuffleAnimationEnabled = shuffleAnimationEnabled
        self.shuffleUsesPerGame = min(max(shuffleUsesPerGame, 0), Game2048ShufflePowerUps.maxUsesPerGame)
        self.shufflePowerUps = shufflePowerUps
    }

    private enum CodingKeys: String, CodingKey {
        case game
        case rng
        case best
        case visualShuffleSeed
        case shuffleAnimationEnabled
        case shuffleUsesPerGame
        case shufflePowerUps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decode(Game2048.self, forKey: .game)
        rng = try container.decode(SeededGenerator.self, forKey: .rng)
        best = try container.decode(Int.self, forKey: .best)
        visualShuffleSeed = try container.decodeIfPresent(UInt64.self, forKey: .visualShuffleSeed) ?? 4
        shuffleAnimationEnabled = try container.decodeIfPresent(Bool.self, forKey: .shuffleAnimationEnabled) ?? true
        let decodedUses = try container.decodeIfPresent(Int.self, forKey: .shuffleUsesPerGame) ?? 1
        shuffleUsesPerGame = min(max(decodedUses, 0), Game2048ShufflePowerUps.maxUsesPerGame)
        shufflePowerUps = try container.decodeIfPresent(Game2048ShufflePowerUps.self, forKey: .shufflePowerUps)
            ?? Game2048ShufflePowerUps(usesPerGame: shuffleUsesPerGame)
    }
}

struct SnakeSnapshot: Codable, Equatable, Hashable {
    var game: SnakeGame
    var rng: SeededGenerator
    var best: Int
}

struct LightsOutSnapshot: Codable, Equatable, Hashable {
    var game: LightsOut
    var seed: UInt64
    var moves: Int
}

@MainActor
final class Game2048Session: ObservableObject {
    @Published var game: Game2048
    @Published var rng: SeededGenerator
    @Published var best = 0
    @Published var visualShuffleSeed: UInt64 = 4
    @Published var visualShuffle: Game2048VisualShuffle?
    @Published var shuffleAnimationEnabled = true
    @Published var shuffleUsesPerGame = 1
    @Published var shufflePowerUps = Game2048ShufflePowerUps()

    private var accountID: UUID?
    private var store: GameSaveStore?
    private var cloudStore: GameCloudSyncStore?
    private let cloudPushPolicy = GameCloudPushPolicy.immediate
    private var lastCloudPushAt: Date?

    init(seed: UInt64 = 1) {
        var initialRNG = SeededGenerator(seed: seed)
        self.game = Game2048.newGame(rng: &initialRNG)
        self.rng = initialRNG
    }

    func configure(
        accountID: UUID,
        store: GameSaveStore = .shared,
        cloudStore: GameCloudSyncStore? = nil
    ) {
        self.accountID = accountID
        self.store = store
        self.cloudStore = cloudStore

        var hadLocalSave = false
        do {
            if let record = try store.load(accountID: accountID, gameID: .game2048) {
                let saved = try GameSaveCodec.decodeSnapshot(Game2048Snapshot.self, from: record.stateJSON)
                restore(saved, persist: false)
                hadLocalSave = true
            } else {
                save()
            }
        } catch {
            save()
        }

        if cloudStore != nil {
            Task { await syncFromCloud(preferCloud: !hadLocalSave) }
        }
    }

    func snapshot() -> Game2048Snapshot {
        Game2048Snapshot(
            game: game,
            rng: rng,
            best: best,
            visualShuffleSeed: visualShuffleSeed,
            shuffleAnimationEnabled: shuffleAnimationEnabled,
            shuffleUsesPerGame: shuffleUsesPerGame,
            shufflePowerUps: shufflePowerUps
        )
    }

    func restore(_ snapshot: Game2048Snapshot, persist: Bool = true) {
        game = snapshot.game
        rng = snapshot.rng
        best = snapshot.best
        visualShuffleSeed = snapshot.visualShuffleSeed
        shuffleAnimationEnabled = snapshot.shuffleAnimationEnabled
        shuffleUsesPerGame = min(max(snapshot.shuffleUsesPerGame, 0), Game2048ShufflePowerUps.maxUsesPerGame)
        shufflePowerUps = snapshot.shufflePowerUps
        visualShuffle = nil
        if persist { save() }
    }

    @discardableResult
    func apply(_ direction: Game2048.Direction) -> Bool {
        guard game.move(direction, rng: &rng) else { return false }
        best = max(best, game.score)
        save()
        return true
    }

    func newGame() {
        let seed = UInt64.random(in: 1...UInt64.max)
        rng = SeededGenerator(seed: seed)
        game = Game2048.newGame(rng: &rng)
        visualShuffle = nil
        shufflePowerUps = Game2048ShufflePowerUps(usesPerGame: shuffleUsesPerGame)
        save(forceCloud: true)
    }

    func setShuffleUsesPerGame(_ uses: Int) {
        shuffleUsesPerGame = min(max(uses, 0), Game2048ShufflePowerUps.maxUsesPerGame)
        shufflePowerUps = Game2048ShufflePowerUps(usesPerGame: shuffleUsesPerGame)
        save(forceCloud: true)
    }

    func setShuffleAnimationEnabled(_ enabled: Bool) {
        shuffleAnimationEnabled = enabled
        save(forceCloud: true)
    }

    func shuffleTilesForPowerUp() -> Game2048VisualShuffle? {
        guard !game.isGameOver, shufflePowerUps.remainingUses > 0 else { return nil }

        var nextGame = game
        var shuffleRNG = SeededGenerator(seed: visualShuffleSeed)
        guard nextGame.shuffleTiles(rng: &shuffleRNG) else { return nil }

        var nextPowerUps = shufflePowerUps
        guard nextPowerUps.use() else { return nil }

        game = nextGame
        shufflePowerUps = nextPowerUps
        let shuffle = Game2048VisualShuffle(seed: visualShuffleSeed, slotCount: game.grid.count)
        visualShuffle = shuffle
        visualShuffleSeed &+= 1
        save()
        return shuffle
    }

    func saveNow() {
        save(forceCloud: true)
    }

    private func save(forceCloud: Bool = false) {
        guard let accountID, let store else { return }
        do {
            let record = try makeRecord(accountID: accountID)
            try store.save(record)
            pushToCloud(record, force: forceCloud)
        } catch {
            return
        }
    }

    private func syncFromCloud(preferCloud: Bool) async {
        guard let accountID, let store, let cloudStore else { return }
        do {
            guard let cloudRecord = try await cloudStore.pull(accountID: accountID, gameID: .game2048) else { return }
            let localRecord = try store.load(accountID: accountID, gameID: .game2048)
            guard preferCloud || localRecord == nil || cloudRecord.updatedAt > localRecord!.updatedAt else { return }
            let saved = try GameSaveCodec.decodeSnapshot(Game2048Snapshot.self, from: cloudRecord.stateJSON)
            restore(saved, persist: false)
            try store.save(cloudRecord)
        } catch {
            return
        }
    }

    private func makeRecord(accountID: UUID) throws -> GameSaveRecord {
        try GameSaveRecord.make(
            accountID: accountID,
            gameID: .game2048,
            score: game.score,
            snapshot: snapshot()
        )
    }

    private func pushToCloud(_ record: GameSaveRecord, force: Bool) {
        guard let cloudStore else { return }
        let now = Date()
        guard cloudPushPolicy.shouldPush(lastPushAt: lastCloudPushAt, now: now, force: force) else { return }
        lastCloudPushAt = now
        Task { try? await cloudStore.push(record) }
    }
}

struct SnakeStepResult: Equatable {
    var ateApple: Bool
    var died: Bool
}

@MainActor
final class SnakeSession: ObservableObject {
    @Published var game = SnakeGame(width: 14, height: 14)
    @Published var rng = SeededGenerator(seed: 11)
    @Published var best = 0

    private var accountID: UUID?
    private var store: GameSaveStore?
    private var cloudStore: GameCloudSyncStore?
    private let cloudPushPolicy = GameCloudPushPolicy.highFrequencyGameplay
    private var lastCloudPushAt: Date?

    func configure(accountID: UUID, store: GameSaveStore = .shared, cloudStore: GameCloudSyncStore? = nil) {
        self.accountID = accountID
        self.store = store
        self.cloudStore = cloudStore

        var hadLocalSave = false
        do {
            if let record = try store.load(accountID: accountID, gameID: .snake) {
                let saved = try GameSaveCodec.decodeSnapshot(SnakeSnapshot.self, from: record.stateJSON)
                restore(saved, persist: false)
                hadLocalSave = true
            } else {
                save()
            }
        } catch {
            save()
        }

        if cloudStore != nil {
            Task { await syncFromCloud(preferCloud: !hadLocalSave) }
        }
    }

    func snapshot() -> SnakeSnapshot {
        SnakeSnapshot(game: game, rng: rng, best: best)
    }

    func restore(_ snapshot: SnakeSnapshot, persist: Bool = true) {
        game = snapshot.game
        rng = snapshot.rng
        best = snapshot.best
        if persist { save() }
    }

    func turn(_ direction: SnakeGame.Direction) {
        game.turn(direction)
        save()
    }

    func step() -> SnakeStepResult {
        let prevScore = game.score
        let prevStatus = game.status
        game.step(rng: &rng)
        best = max(best, game.score)
        let result = SnakeStepResult(
            ateApple: game.score > prevScore,
            died: prevStatus == .playing && game.status == .lost
        )
        save(forceCloud: result.ateApple || result.died)
        return result
    }

    func newGame() {
        rng = SeededGenerator(seed: UInt64.random(in: 1...UInt64.max))
        game = SnakeGame(width: 14, height: 14)
        save(forceCloud: true)
    }

    func saveNow() {
        save(forceCloud: true)
    }

    private func save(forceCloud: Bool = false) {
        guard let accountID, let store else { return }
        do {
            let record = try GameSaveRecord.make(accountID: accountID, gameID: .snake, score: game.score, snapshot: snapshot())
            try store.save(record)
            pushToCloud(record, force: forceCloud)
        } catch {
            return
        }
    }

    private func syncFromCloud(preferCloud: Bool) async {
        guard let accountID, let store, let cloudStore else { return }
        do {
            guard let cloudRecord = try await cloudStore.pull(accountID: accountID, gameID: .snake) else { return }
            let localRecord = try store.load(accountID: accountID, gameID: .snake)
            guard preferCloud || localRecord == nil || cloudRecord.updatedAt > localRecord!.updatedAt else { return }
            let saved = try GameSaveCodec.decodeSnapshot(SnakeSnapshot.self, from: cloudRecord.stateJSON)
            restore(saved, persist: false)
            try store.save(cloudRecord)
        } catch {
            return
        }
    }

    private func pushToCloud(_ record: GameSaveRecord, force: Bool) {
        guard let cloudStore else { return }
        let now = Date()
        guard cloudPushPolicy.shouldPush(lastPushAt: lastCloudPushAt, now: now, force: force) else { return }
        lastCloudPushAt = now
        Task { try? await cloudStore.push(record) }
    }
}

@MainActor
final class LightsOutSession: ObservableObject {
    @Published var game = LightsOut.newPuzzle(seed: 1)
    @Published var seed: UInt64 = 1
    @Published var moves = 0

    private var accountID: UUID?
    private var store: GameSaveStore?
    private var cloudStore: GameCloudSyncStore?
    private let cloudPushPolicy = GameCloudPushPolicy.immediate
    private var lastCloudPushAt: Date?

    func configure(accountID: UUID, store: GameSaveStore = .shared, cloudStore: GameCloudSyncStore? = nil) {
        self.accountID = accountID
        self.store = store
        self.cloudStore = cloudStore

        var hadLocalSave = false
        do {
            if let record = try store.load(accountID: accountID, gameID: .lightsOut) {
                let saved = try GameSaveCodec.decodeSnapshot(LightsOutSnapshot.self, from: record.stateJSON)
                restore(saved, persist: false)
                hadLocalSave = true
            } else {
                save()
            }
        } catch {
            save()
        }

        if cloudStore != nil {
            Task { await syncFromCloud(preferCloud: !hadLocalSave) }
        }
    }

    func snapshot() -> LightsOutSnapshot {
        LightsOutSnapshot(game: game, seed: seed, moves: moves)
    }

    func restore(_ snapshot: LightsOutSnapshot, persist: Bool = true) {
        game = snapshot.game
        seed = snapshot.seed
        moves = snapshot.moves
        if persist { save() }
    }

    func press(row: Int, col: Int) {
        game.press(row: row, col: col)
        moves += 1
        save()
    }

    func newGame() {
        let fresh = UInt64.random(in: UInt64.min...UInt64.max)
        seed = fresh
        game = LightsOut.newPuzzle(seed: fresh)
        moves = 0
        save(forceCloud: true)
    }

    func saveNow() {
        save(forceCloud: true)
    }

    private func save(forceCloud: Bool = false) {
        guard let accountID, let store else { return }
        do {
            let record = try GameSaveRecord.make(accountID: accountID, gameID: .lightsOut, score: moves, snapshot: snapshot())
            try store.save(record)
            pushToCloud(record, force: forceCloud)
        } catch {
            return
        }
    }

    private func syncFromCloud(preferCloud: Bool) async {
        guard let accountID, let store, let cloudStore else { return }
        do {
            guard let cloudRecord = try await cloudStore.pull(accountID: accountID, gameID: .lightsOut) else { return }
            let localRecord = try store.load(accountID: accountID, gameID: .lightsOut)
            guard preferCloud || localRecord == nil || cloudRecord.updatedAt > localRecord!.updatedAt else { return }
            let saved = try GameSaveCodec.decodeSnapshot(LightsOutSnapshot.self, from: cloudRecord.stateJSON)
            restore(saved, persist: false)
            try store.save(cloudRecord)
        } catch {
            return
        }
    }

    private func pushToCloud(_ record: GameSaveRecord, force: Bool) {
        guard let cloudStore else { return }
        let now = Date()
        guard cloudPushPolicy.shouldPush(lastPushAt: lastCloudPushAt, now: now, force: force) else { return }
        lastCloudPushAt = now
        Task { try? await cloudStore.push(record) }
    }
}
