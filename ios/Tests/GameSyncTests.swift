import XCTest
@testable import Kaleidoscope

final class GameSyncTests: XCTestCase {
    func testGame2048SnapshotCodableForCrossPlatformSaves() throws {
        let snapshot = Game2048Snapshot(
            game: Game2048(
                grid: [
                    2, 4, 8, 16,
                    0, 0, 0, 0,
                    0, 0, 0, 0,
                    0, 0, 0, 0
                ],
                score: 30
            ),
            rng: SeededGenerator(seed: 42),
            best: 512
        )

        let encoded = try GameSaveCodec.encodeSnapshot(snapshot)
        let decoded = try GameSaveCodec.decodeSnapshot(Game2048Snapshot.self, from: encoded)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertTrue(encoded.contains("\"score\""))
        XCTAssertTrue(encoded.contains("\"grid\""))
    }

    func testGame2048SnapshotDecodesOldSavesWithShuffleDefaults() throws {
        let oldSaveJSON = """
        {
          "game": {
            "grid": [2,4,8,16,0,0,0,0,0,0,0,0,0,0,0,0],
            "score": 30
          },
          "rng": {
            "state": 42
          },
          "best": 512
        }
        """

        let decoded = try GameSaveCodec.decodeSnapshot(Game2048Snapshot.self, from: oldSaveJSON)

        XCTAssertEqual(decoded.shuffleUsesPerGame, 1)
        XCTAssertEqual(decoded.shufflePowerUps.remainingUses, 1)
        XCTAssertEqual(decoded.visualShuffleSeed, 4)
        XCTAssertTrue(decoded.shuffleAnimationEnabled)
    }

    func testLocalStoreKeepsSavesSeparatedByAccountAndGame() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountA = UUID()
        let accountB = UUID()

        let saveA = try GameSaveRecord.make(
            accountID: accountA,
            gameID: .game2048,
            score: 64,
            snapshot: Game2048Snapshot(game: Game2048(grid: Array(repeating: 2, count: 16), score: 64),
                                       rng: SeededGenerator(seed: 1),
                                       best: 64)
        )
        let saveB = try GameSaveRecord.make(
            accountID: accountB,
            gameID: .game2048,
            score: 128,
            snapshot: Game2048Snapshot(game: Game2048(grid: Array(repeating: 4, count: 16), score: 128),
                                       rng: SeededGenerator(seed: 2),
                                       best: 128)
        )

        try store.save(saveA)
        try store.save(saveB)

        XCTAssertEqual(try store.load(accountID: accountA, gameID: .game2048), saveA)
        XCTAssertEqual(try store.load(accountID: accountB, gameID: .game2048), saveB)
    }

    func testCloudRowPreservesCanonicalGameStateAndScore() throws {
        let accountID = UUID()
        let record = try GameSaveRecord.make(
            accountID: accountID,
            gameID: .game2048,
            score: 256,
            snapshot: Game2048Snapshot(game: Game2048(grid: Array(repeating: 8, count: 16), score: 256),
                                       rng: SeededGenerator(seed: 9),
                                       best: 512)
        )

        let row = CloudGameSaveRow(record: record)
        let restored = try row.record()
        let snapshot = try GameSaveCodec.decodeSnapshot(Game2048Snapshot.self, from: restored.stateJSON)

        XCTAssertEqual(row.userID, accountID)
        XCTAssertEqual(row.gameID, "2048")
        XCTAssertEqual(row.score, 256)
        XCTAssertEqual(restored, record)
        XCTAssertEqual(snapshot.best, 512)
    }

    func testCloudPushPolicyThrottlesFrequentGameplaySaves() {
        let policy = GameCloudPushPolicy(minimumInterval: 2)
        let start = Date(timeIntervalSince1970: 100)

        XCTAssertTrue(policy.shouldPush(lastPushAt: nil, now: start, force: false))
        XCTAssertFalse(policy.shouldPush(lastPushAt: start, now: start.addingTimeInterval(1), force: false))
        XCTAssertTrue(policy.shouldPush(lastPushAt: start, now: start.addingTimeInterval(1), force: true))
        XCTAssertTrue(policy.shouldPush(lastPushAt: start, now: start.addingTimeInterval(2.1), force: false))
    }

    @MainActor
    func testGame2048SessionLoadsSavedStateForAccount() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountID = UUID()
        let snapshot = Game2048Snapshot(
            game: Game2048(grid: [
                2, 4, 8, 16,
                32, 64, 128, 256,
                0, 0, 0, 0,
                0, 0, 0, 0
            ], score: 510),
            rng: SeededGenerator(seed: 42),
            best: 1024
        )
        let record = try GameSaveRecord.make(accountID: accountID, gameID: .game2048, score: 510, snapshot: snapshot)
        try store.save(record)

        let session = Game2048Session()
        session.configure(accountID: accountID, store: store)

        XCTAssertEqual(session.snapshot(), snapshot)
    }

    @MainActor
    func testGame2048SessionPersistsMovesForAccount() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountID = UUID()
        let session = Game2048Session()
        session.configure(accountID: accountID, store: store)
        session.restore(
            Game2048Snapshot(
                game: Game2048(grid: [
                    2, 2, 0, 0,
                    0, 0, 0, 0,
                    0, 0, 0, 0,
                    0, 0, 0, 0
                ]),
                rng: SeededGenerator(seed: 3),
                best: 0
            )
        )

        XCTAssertTrue(session.apply(.left))

        let record = try XCTUnwrap(store.load(accountID: accountID, gameID: .game2048))
        let saved = try GameSaveCodec.decodeSnapshot(Game2048Snapshot.self, from: record.stateJSON)
        XCTAssertEqual(record.score, session.game.score)
        XCTAssertEqual(saved, session.snapshot())
        XCTAssertEqual(saved.best, session.game.score)
    }

    @MainActor
    func testSimplePhoneSessionsPersistToSharedStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountID = UUID()

        let snake = SnakeSession()
        snake.configure(accountID: accountID, store: store)
        snake.turn(.down)
        snake.saveNow()

        let savedSnakeRecord = try XCTUnwrap(store.load(accountID: accountID, gameID: .snake))
        let savedSnake = try GameSaveCodec.decodeSnapshot(SnakeSnapshot.self, from: savedSnakeRecord.stateJSON)
        XCTAssertEqual(savedSnake.game.direction, .right)
        XCTAssertEqual(savedSnake.game.pendingDirection, .down)

        let lights = LightsOutSession()
        lights.configure(accountID: accountID, store: store)
        lights.press(row: 0, col: 0)

        let savedLightsRecord = try XCTUnwrap(store.load(accountID: accountID, gameID: .lightsOut))
        let savedLights = try GameSaveCodec.decodeSnapshot(LightsOutSnapshot.self, from: savedLightsRecord.stateJSON)
        XCTAssertEqual(savedLights.moves, 1)
        XCTAssertEqual(savedLights.game, lights.game)
    }

    @MainActor
    func testSessionSaveNowFlushesCurrentStateWhenLeavingPanel() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountID = UUID()

        let game2048 = Game2048Session()
        game2048.configure(accountID: accountID, store: store)
        game2048.game = Game2048(grid: [
            2, 4, 8, 16,
            32, 64, 128, 256,
            0, 0, 0, 0,
            0, 0, 0, 0
        ], score: 510)
        game2048.best = 1024
        game2048.saveNow()

        let saved2048Record = try XCTUnwrap(store.load(accountID: accountID, gameID: .game2048))
        let saved2048 = try GameSaveCodec.decodeSnapshot(Game2048Snapshot.self, from: saved2048Record.stateJSON)
        XCTAssertEqual(saved2048, game2048.snapshot())
        XCTAssertEqual(saved2048Record.score, 510)

        let lights = LightsOutSession()
        lights.configure(accountID: accountID, store: store)
        lights.moves = 7
        lights.seed = 44
        lights.game = LightsOut.newPuzzle(seed: 44)
        lights.saveNow()

        let savedLightsRecord = try XCTUnwrap(store.load(accountID: accountID, gameID: .lightsOut))
        let savedLights = try GameSaveCodec.decodeSnapshot(LightsOutSnapshot.self, from: savedLightsRecord.stateJSON)
        XCTAssertEqual(savedLights, lights.snapshot())
        XCTAssertEqual(savedLightsRecord.score, 7)
    }
}
