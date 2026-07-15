import PrismetShared
import XCTest
@testable import Prismet

@MainActor
final class PracticeBlackjackSessionTests: XCTestCase {
    func testHitAndStandDelegateToSharedAuditedSession() throws {
        let seed = try seedWithTwoHitsAvailable()
        let session = PracticeBlackjackSession(previewSeed: seed, store: makeStore())
        let sharedStart = try PrismetBlackjackAuditedSession.start(seed: seed)

        XCTAssertEqual(session.table, sharedStart.observation)
        XCTAssertTrue(session.canHit)
        XCTAssertTrue(session.canStand)

        session.hit()

        let expectedAfterHit = try sharedStart.applying(.hit)
        XCTAssertEqual(session.table, expectedAfterHit.observation)

        session.stand()

        let expectedAfterStand = try expectedAfterHit.applying(.stand)
        XCTAssertEqual(session.table, expectedAfterStand.observation)
    }

    func testNewHandRequiresDeliberateActionAfterTerminalState() throws {
        let seed = try activeSeedWithActiveSuccessor()
        let session = PracticeBlackjackSession(previewSeed: seed, store: makeStore())
        let activeTable = session.table

        session.newHand()

        XCTAssertEqual(session.table, activeTable)
        XCTAssertFalse(session.canStartNewHand)

        session.stand()

        let completedTable = session.table
        XCTAssertEqual(completedTable.phase, .completed)
        XCTAssertTrue(session.canStartNewHand)

        session.newHand()

        XCTAssertEqual(session.table.phase, .playerTurn)
        XCTAssertFalse(session.canStartNewHand)
        XCTAssertNotEqual(session.table, activeTable, "A deliberate New Hand request must use a fresh preview sequence seed")
        XCTAssertNotEqual(session.table, completedTable)
    }

    func testPersistAndRestorePreserveTheExactFutureDeck() async throws {
        let seed = try seedWithTwoHitsAvailable()
        let store = makeStore()
        let original = PracticeBlackjackSession(previewSeed: seed, store: store)

        original.hit()
        XCTAssertTrue(original.canHit)
        await original.persist()

        let restored = PracticeBlackjackSession(previewSeed: seed &+ 1, store: store)
        await restored.restoreOrDeal()

        XCTAssertEqual(restored.loadState, .ready)
        XCTAssertEqual(restored.table, original.table)

        original.hit()
        restored.hit()

        XCTAssertEqual(restored.table, original.table)
    }

    func testCorruptSaveRemainsUntouchedUntilExplicitStartFresh() async throws {
        let store = makeStore()
        let corruptData = Data("not a blackjack save".utf8)
        try await store.save(corruptData)
        let session = PracticeBlackjackSession(previewSeed: try activeSeed(), store: store)

        await session.restoreOrDeal()

        XCTAssertEqual(session.loadState, .corruptSave)
        session.endHand()
        session.hit()
        session.stand()
        session.newHand()
        XCTAssertEqual(session.loadState, .corruptSave)
        let stillSavedData = try await store.load()
        XCTAssertEqual(stillSavedData, corruptData)

        await session.startFresh()

        XCTAssertEqual(session.loadState, .ready)
        let freshData = try await store.load()
        let diagnosticCopies = try await store.diagnosticCopies()
        XCTAssertNotEqual(freshData, corruptData)
        XCTAssertEqual(diagnosticCopies, [corruptData])
    }

    func testAuditIsUnavailableUntilTheHandEnds() throws {
        let session = PracticeBlackjackSession(previewSeed: try activeSeed(), store: makeStore())

        XCTAssertNil(session.auditSummary)

        session.stand()

        XCTAssertNotNil(session.auditSummary)
        XCTAssertEqual(session.table.phase, .completed)
    }

    func testEndHandUsesNeutralAbandonedStateWithoutStartingAnotherHand() throws {
        let session = PracticeBlackjackSession(previewSeed: try activeSeed(), store: makeStore())

        session.endHand()

        XCTAssertEqual(session.table.phase, .abandoned)
        XCTAssertEqual(session.table.resolution?.outcome, .abandoned)
        XCTAssertTrue(session.canStartNewHand)
    }

    private func makeStore() -> PracticeBlackjackStore {
        PracticeBlackjackStore(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("practice-blackjack-tests-\(UUID().uuidString)", isDirectory: true)
        )
    }

    private func activeSeed() throws -> UInt64 {
        for seed in UInt64(1)...UInt64(2_048) {
            let session = try PrismetBlackjackAuditedSession.start(seed: seed)
            if session.observation.legalCommands.contains(.stand) {
                return seed
            }
        }
        throw SeedFixtureError.notFound
    }

    private func seedWithTwoHitsAvailable() throws -> UInt64 {
        for seed in UInt64(1)...UInt64(4_096) {
            let started = try PrismetBlackjackAuditedSession.start(seed: seed)
            guard started.observation.legalCommands.contains(.hit) else { continue }
            let afterHit = try started.applying(.hit)
            if afterHit.observation.legalCommands.contains(.hit) {
                return seed
            }
        }
        throw SeedFixtureError.notFound
    }

    private func activeSeedWithActiveSuccessor() throws -> UInt64 {
        for seed in UInt64(1)..<UInt64(2_048) {
            let current = try PrismetBlackjackAuditedSession.start(seed: seed)
            let next = try PrismetBlackjackAuditedSession.start(seed: seed &+ 1)
            if current.observation.phase == .playerTurn,
               next.observation.phase == .playerTurn {
                return seed
            }
        }
        throw SeedFixtureError.notFound
    }

    private enum SeedFixtureError: Error {
        case notFound
    }
}
