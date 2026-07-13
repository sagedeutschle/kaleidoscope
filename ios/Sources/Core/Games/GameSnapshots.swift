import Foundation

@MainActor
final class PersistedGameSession<Snapshot: Codable>: ObservableObject {
    private let gameID: CanonicalGameID
    private let cloudPushPolicy: GameCloudPushPolicy
    private var accountID: UUID?
    private var store: GameSaveStore?
    private var cloudStore: GameCloudSyncStore?
    private var lastCloudPushAt: Date?

    init(gameID: CanonicalGameID, cloudPushPolicy: GameCloudPushPolicy = .immediate) {
        self.gameID = gameID
        self.cloudPushPolicy = cloudPushPolicy
    }

    func configure(
        accountID: UUID?,
        store: GameSaveStore = .shared,
        cloudStore: GameCloudSyncStore? = nil,
        restore: ((Snapshot) -> Void)? = nil
    ) {
        guard let accountID else { return }
        self.accountID = accountID
        self.store = store
        self.cloudStore = cloudStore

        var hadLocalSave = false
        do {
            if let record = try store.load(accountID: accountID, gameID: gameID) {
                let saved = try GameSaveCodec.decodeSnapshot(Snapshot.self, from: record.stateJSON)
                restore?(saved)
                hadLocalSave = true
            }
        } catch {
            return
        }

        if cloudStore != nil {
            Task { await syncFromCloud(preferCloud: !hadLocalSave, restore: restore) }
        }
    }

    func save(snapshot: Snapshot, score: Int? = nil, forceCloud: Bool = false) {
        guard let accountID, let store else { return }
        do {
            let record = try GameSaveRecord.make(
                accountID: accountID,
                gameID: gameID,
                score: score,
                snapshot: snapshot
            )
            try store.save(record)
            pushToCloud(record, force: forceCloud)
        } catch {
            return
        }
    }

    func loadSnapshot(accountID: UUID? = nil) throws -> Snapshot? {
        guard let resolvedAccountID = accountID ?? self.accountID,
              let resolvedStore = store ?? Optional(GameSaveStore.shared),
              let record = try resolvedStore.load(accountID: resolvedAccountID, gameID: gameID)
        else { return nil }
        return try GameSaveCodec.decodeSnapshot(Snapshot.self, from: record.stateJSON)
    }

    private func syncFromCloud(preferCloud: Bool, restore: ((Snapshot) -> Void)?) async {
        guard let accountID, let store, let cloudStore else { return }
        do {
            guard let cloudRecord = try await cloudStore.pull(accountID: accountID, gameID: gameID) else { return }
            let localRecord = try store.load(accountID: accountID, gameID: gameID)
            guard preferCloud || localRecord == nil || cloudRecord.updatedAt > localRecord!.updatedAt else { return }
            let saved = try GameSaveCodec.decodeSnapshot(Snapshot.self, from: cloudRecord.stateJSON)
            restore?(saved)
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

struct MinesweeperSnapshot: Codable, Equatable, Hashable {
    var seed: UInt64
    var game: MinesweeperGame
    var styleRawValue: String
    var flagMode: Bool
}

struct SudokuSnapshot: Codable, Equatable, Hashable {
    var game: SudokuGame
    var rng: SeededGenerator
    var selectedRow: Int?
    var selectedCol: Int?
}

struct RubiksSnapshot: Codable, Equatable, Hashable {
    var game: RubiksCube
    var rng: SeededGenerator
    var moveCount: Int
    var tiltX: Double
    var tiltY: Double
}

struct ChessSnapshot: Codable, Equatable, Hashable {
    var position: Position
    var selected: Square?
    var targets: Set<Int>
    var status: GameStatus
    var lastFrom: Int?
    var lastTo: Int?
}

struct SlidingPuzzleSnapshot: Codable, Equatable, Hashable {
    var game: SlidingPuzzle
    var moves: Int
    var seed: UInt64
}

struct NonogramSnapshot: Codable, Equatable, Hashable {
    var game: NonogramGame
}

struct WordleSnapshot: Codable, Equatable, Hashable {
    var dailyWord: DailyWord
    var game: WordPuzzleGame
    var currentGuess: String
    var mode: WordleMode
    var didSubmitResult: Bool
}

struct ReversiSnapshot: Codable, Equatable, Hashable {
    var game: ReversiGame
}

struct CheckersSnapshot: Codable, Equatable, Hashable {
    var game: CheckersGame
    var selected: CheckersPoint?
    var undoStack: [CheckersGame]
    var didSubmitResult: Bool

    init(game: CheckersGame,
         selected: CheckersPoint?,
         undoStack: [CheckersGame] = [],
         didSubmitResult: Bool = false) {
        self.game = game
        self.selected = selected
        self.undoStack = undoStack
        self.didSubmitResult = didSubmitResult
    }

    private enum CodingKeys: String, CodingKey {
        case game, selected, undoStack, didSubmitResult
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decode(CheckersGame.self, forKey: .game)
        selected = try container.decodeIfPresent(CheckersPoint.self, forKey: .selected)
        undoStack = try container.decodeIfPresent([CheckersGame].self, forKey: .undoStack) ?? []
        didSubmitResult = try container.decodeIfPresent(Bool.self, forKey: .didSubmitResult) ?? false
    }
}

struct ConnectFourSnapshot: Codable, Equatable, Hashable {
    var game: ConnectFourGame
}

struct GomokuSnapshot: Codable, Equatable, Hashable {
    var game: GomokuGame
}

struct SeaBattleSnapshot: Codable, Equatable, Hashable {
    var game: SeaBattleGame
    var difficulty: SeaBattleAIDifficulty
    var setup: SeaBattleSetupState

    init(game: SeaBattleGame, difficulty: SeaBattleAIDifficulty = .normal, setup: SeaBattleSetupState = .complete) {
        self.game = game
        self.difficulty = difficulty
        self.setup = setup
    }

    private enum CodingKeys: String, CodingKey {
        case game, difficulty, setup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decode(SeaBattleGame.self, forKey: .game)
        difficulty = try container.decodeIfPresent(SeaBattleAIDifficulty.self, forKey: .difficulty) ?? .normal
        setup = try container.decodeIfPresent(SeaBattleSetupState.self, forKey: .setup) ?? .complete
    }
}

struct SeaBattleSetupState: Codable, Equatable, Hashable {
    var hostDeployment: SeaBattleFleetDeployment?
    var guestDeployment: SeaBattleFleetDeployment?
    var hostReady: Bool
    var guestReady: Bool

    static let empty = SeaBattleSetupState(
        hostDeployment: nil,
        guestDeployment: nil,
        hostReady: false,
        guestReady: false
    )

    static let complete = SeaBattleSetupState(
        hostDeployment: nil,
        guestDeployment: nil,
        hostReady: true,
        guestReady: true
    )

    var isComplete: Bool {
        hostReady && guestReady
            && (hostDeployment?.isComplete ?? true)
            && (guestDeployment?.isComplete ?? true)
    }

    var isDeploymentPhase: Bool {
        !isComplete
    }

    func deployment(for player: SeaBattlePlayer) -> SeaBattleFleetDeployment? {
        player == .host ? hostDeployment : guestDeployment
    }

    func isReady(_ player: SeaBattlePlayer) -> Bool {
        player == .host ? hostReady : guestReady
    }

    mutating func setDeployment(_ deployment: SeaBattleFleetDeployment, for player: SeaBattlePlayer, ready: Bool) {
        if player == .host {
            hostDeployment = deployment
            hostReady = ready && deployment.isComplete
        } else {
            guestDeployment = deployment
            guestReady = ready && deployment.isComplete
        }
    }

    mutating func markUnready(_ player: SeaBattlePlayer) {
        if player == .host {
            hostReady = false
        } else {
            guestReady = false
        }
    }
}

struct SolitaireSnapshot: Codable, Hashable {
    var game: SolitaireGame
    var seed: UInt64
}

struct SpiderSnapshot: Codable, Equatable, Hashable {
    var game: SpiderGame
    var seed: UInt64
}

struct CrazyEightSnapshot: Codable, Equatable, Hashable {
    var game: CrazyEightGame
    var seed: UInt64
}

struct BrickBenchSnapshot: Codable, Hashable {
    var document: LegoBuildDocument
    var selectedKind: LegoElementKind
    var selectedSize: LegoBrickSize
    var selectedColor: LegoBrickColor
    var selectedLayer: Int
    var selectedBrickID: UUID?
}

struct OracleSnapshot: Codable {
    var chronicle: DecreeChronicle
    var loaded: Bool
    var current: Decree?
    var consultCount: Int
    var rng: SeededGenerator
}

struct CatanSnapshot: Codable, Equatable {
    var game: CatanGame
    var difficulty: CatanBotDifficulty

    init(game: CatanGame, difficulty: CatanBotDifficulty = .cozy) {
        self.game = game
        self.difficulty = difficulty
    }

    private enum CodingKeys: String, CodingKey {
        case game, difficulty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decode(CatanGame.self, forKey: .game)
        difficulty = try container.decodeIfPresent(CatanBotDifficulty.self, forKey: .difficulty) ?? .cozy
    }
}

struct GameSaveSnapshotSample {
    var gameID: CanonicalGameID
    var fingerprint: String
    var encode: () throws -> String
    var decode: (String) throws -> String
}

enum GameSaveSnapshotRegistry {
    static let coveredGameIDs: [CanonicalGameID] = CanonicalGameID.allCases

    static func sampleSnapshots() -> [GameSaveSnapshotSample] {
        var game2048RNG = SeededGenerator(seed: 1)
        let game2048 = Game2048.newGame(rng: &game2048RNG)

        return [
            sample(.game2048, Game2048Snapshot(game: game2048, rng: game2048RNG, best: 0)),
            sample(.snake, SnakeSnapshot(game: SnakeGame(width: 14, height: 14), rng: SeededGenerator(seed: 11), best: 0)),
            sample(.minesweeper, MinesweeperSnapshot(
                seed: 1,
                game: MinesweeperGame(width: 9, height: 9, mineCount: 10, seed: 1),
                styleRawValue: MinesweeperStyle.modern.rawValue,
                flagMode: false
            )),
            sample(.sudoku, SudokuSnapshot(
                game: SudokuGame.standardPuzzle(),
                rng: SeededGenerator(seed: 9),
                selectedRow: nil,
                selectedCol: nil
            )),
            sample(.rubiks, RubiksSnapshot(
                game: RubiksCube(),
                rng: SeededGenerator(seed: 13),
                moveCount: 0,
                tiltX: -0.35,
                tiltY: 0.45
            )),
            sample(.chess, ChessSnapshot(
                position: .initial,
                selected: nil,
                targets: [],
                status: .ongoing,
                lastFrom: nil,
                lastTo: nil
            )),
            sample(.lightsOut, LightsOutSnapshot(game: LightsOut.newPuzzle(seed: 1), seed: 1, moves: 0)),
            sample(.slidingPuzzle, SlidingPuzzleSnapshot(
                game: SlidingPuzzle.shuffled(seed: 5),
                moves: 0,
                seed: 5
            )),
            sample(.nonogram, NonogramSnapshot(game: NonogramGame.crossPuzzle())),
            sample(.wordle, WordleSnapshot(
                dailyWord: DailyWord(answer: "crane", dateLabel: "Practice", source: .random),
                game: WordPuzzleGame(answer: "crane", allowedWords: WordleWords.all),
                currentGuess: "",
                mode: .practice,
                didSubmitResult: false
            )),
            sample(.reversi, ReversiSnapshot(game: ReversiGame())),
            sample(.checkers, CheckersSnapshot(game: CheckersGame(), selected: nil)),
            sample(.connectFour, ConnectFourSnapshot(game: ConnectFourGame())),
            sample(.gomoku, GomokuSnapshot(game: GomokuGame())),
            sample(.seaBattle, SeaBattleSnapshot(game: SeaBattleGame.newGame(seed: 31))),
            sample(.solitaire, SolitaireSnapshot(game: SolitaireGame.newGame(seed: 21), seed: 21)),
            sample(.spider, SpiderSnapshot(game: SpiderGame.newGame(seed: 41), seed: 41)),
            sample(.crazyEight, CrazyEightSnapshot(game: CrazyEightGame.newGame(seed: 51), seed: 51)),
            sample(.brickBench, BrickBenchSnapshot(
                document: LegoBuildDocument(),
                selectedKind: .brick,
                selectedSize: .twoByFour,
                selectedColor: .classicRed,
                selectedLayer: 0,
                selectedBrickID: nil
            )),
            sample(.oracle, OracleSnapshot(
                chronicle: .empty,
                loaded: false,
                current: nil,
                consultCount: 0,
                rng: SeededGenerator(seed: 77)
            )),
            sample(.catan, CatanSnapshot(game: CatanGame.newGame(seed: 61)))
        ]
    }

    private static func sample<T: Codable>(_ gameID: CanonicalGameID, _ snapshot: T) -> GameSaveSnapshotSample {
        let fingerprint = String(reflecting: T.self)
        return GameSaveSnapshotSample(
            gameID: gameID,
            fingerprint: fingerprint,
            encode: { try GameSaveCodec.encodeSnapshot(snapshot) },
            decode: { json in
                _ = try GameSaveCodec.decodeSnapshot(T.self, from: json)
                return fingerprint
            }
        )
    }
}
