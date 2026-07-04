import XCTest
@testable import Kaleidoscope

final class AllGamePersistenceTests: XCTestCase {
    func testEveryCanonicalGameHasSaveCoverage() {
        XCTAssertEqual(Set(GameSaveSnapshotRegistry.coveredGameIDs), Set(CanonicalGameID.allCases))
    }

    func testAllGameSnapshotsRoundTripThroughSharedCodec() throws {
        let samples = GameSaveSnapshotRegistry.sampleSnapshots()

        XCTAssertEqual(Set(samples.map(\.gameID)), Set(CanonicalGameID.allCases))

        for sample in samples {
            let encoded = try sample.encode()
            let decoded = try sample.decode(encoded)
            XCTAssertEqual(decoded, sample.fingerprint, "Snapshot did not round-trip for \(sample.gameID.rawValue)")
        }
    }

    func testCheckersSnapshotDecodesOldSavesWithResultDefaults() throws {
        let gameJSON = try GameSaveCodec.encodeSnapshot(CheckersGame())
        let compatibleOldSaveJSON = """
        {
          "game": \(gameJSON),
          "selected": null
        }
        """

        let decoded = try GameSaveCodec.decodeSnapshot(CheckersSnapshot.self, from: compatibleOldSaveJSON)

        XCTAssertTrue(decoded.undoStack.isEmpty)
        XCTAssertFalse(decoded.didSubmitResult)
    }

    func testSeaBattleSnapshotDecodesOldSavesWithNormalDifficulty() throws {
        let gameJSON = try GameSaveCodec.encodeSnapshot(SeaBattleGame.newGame(seed: 31))
        let compatibleOldSaveJSON = """
        {
          "game": \(gameJSON)
        }
        """

        let decoded = try GameSaveCodec.decodeSnapshot(SeaBattleSnapshot.self, from: compatibleOldSaveJSON)

        XCTAssertEqual(decoded.difficulty, .normal)
    }

    func testSeaBattleSnapshotDecodesOldSavesAsReadyForBattle() throws {
        let gameJSON = try GameSaveCodec.encodeSnapshot(SeaBattleGame.newGame(seed: 31))
        let compatibleOldSaveJSON = """
        {
          "game": \(gameJSON)
        }
        """

        let decoded = try GameSaveCodec.decodeSnapshot(SeaBattleSnapshot.self, from: compatibleOldSaveJSON)

        XCTAssertTrue(decoded.setup.isComplete)
    }

    func testSeaBattleSetupTracksBothReadyDeployments() {
        var setup = SeaBattleSetupState.empty
        let host = Self.standardHorizontalDeployment()
        let guest = SeaBattleFleetDeployment.random(seed: 44)

        setup.setDeployment(host, for: .host, ready: true)
        XCTAssertFalse(setup.isComplete)

        setup.setDeployment(guest, for: .guest, ready: true)
        XCTAssertTrue(setup.isComplete)
    }

    @MainActor
    func testGenericSessionPersistsAnyCodableGameSnapshot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountID = UUID()
        let session = PersistedGameSession<MinesweeperSnapshot>(gameID: .minesweeper)

        session.configure(accountID: accountID, store: store)
        var snapshot = MinesweeperSnapshot(
            seed: 123,
            game: MinesweeperGame(width: 9, height: 9, mineCount: 10, seed: 123),
            styleRawValue: MinesweeperStyle.cyber.rawValue,
            flagMode: true
        )
        snapshot.game.toggleFlag(row: 0, col: 0)
        session.save(snapshot: snapshot, score: nil, forceCloud: true)

        let loaded = try XCTUnwrap(store.load(accountID: accountID, gameID: .minesweeper))
        let decoded = try GameSaveCodec.decodeSnapshot(MinesweeperSnapshot.self, from: loaded.stateJSON)
        XCTAssertEqual(decoded, snapshot)
    }

    private static func standardHorizontalDeployment() -> SeaBattleFleetDeployment {
        var deployment = SeaBattleFleetDeployment()
        _ = deployment.place(length: 5, at: SeaBattlePoint(row: 0, col: 0), orientation: .horizontal)
        _ = deployment.place(length: 4, at: SeaBattlePoint(row: 2, col: 0), orientation: .horizontal)
        _ = deployment.place(length: 3, at: SeaBattlePoint(row: 4, col: 0), orientation: .horizontal)
        _ = deployment.place(length: 3, at: SeaBattlePoint(row: 6, col: 0), orientation: .horizontal)
        _ = deployment.place(length: 2, at: SeaBattlePoint(row: 8, col: 0), orientation: .horizontal)
        return deployment
    }
}
