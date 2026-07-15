import XCTest
import PrismetShared
@testable import Prismet

@MainActor
final class PracticeBlackjackSessionTests: XCTestCase {
    func testHitDelegatesToSharedEngineAndPublishesItsObservation() async throws {
        let seed = try activeSeed(requiring: .hit)
        let session = makeSession(seed: seed)
        await session.restoreOrDeal()
        let initialCount = session.table.playerCards.count

        session.hit()

        XCTAssertEqual(session.table.playerCards.count, initialCount + 1)
        XCTAssertEqual(session.table, session.auditedSession.observation)
    }

    func testNewHandDoesNothingWhileCurrentHandIsActive() async throws {
        let seed = try activeSeed(requiring: .stand)
        let session = makeSession(seed: seed)
        await session.restoreOrDeal()
        let activeTable = session.table

        session.newHand()

        XCTAssertEqual(session.table, activeTable)
        XCTAssertFalse(session.canStartNewHand)
    }

    func testStandLeavesTerminalResultUntilPlayerExplicitlyStartsAgain() async throws {
        let seed = try activeSeed(requiring: .stand)
        let session = makeSession(seed: seed)
        await session.restoreOrDeal()

        session.stand()
        let terminalTable = session.table

        XCTAssertNotNil(terminalTable.resolution)
        XCTAssertTrue(terminalTable.legalCommands.isEmpty)
        XCTAssertEqual(session.table, terminalTable)
        XCTAssertTrue(session.canStartNewHand)
    }

    func testAuditIsUnavailableDuringPlayAndAvailableAfterCompletion() async throws {
        let seed = try activeSeed(requiring: .stand)
        let session = makeSession(seed: seed)
        await session.restoreOrDeal()

        XCTAssertNil(session.auditDisclosure)
        XCTAssertNil(session.auditPresentation)

        session.stand()

        XCTAssertNotNil(session.auditDisclosure)
        let audit = try XCTUnwrap(session.auditPresentation)
        XCTAssertEqual(audit.seed, String(seed))
        XCTAssertEqual(audit.rulesVersion, String(PrismetBlackjackRulesV1.rulesVersion))
        XCTAssertFalse(audit.revealedDrawOrder.isEmpty)
        XCTAssertFalse(audit.stateHashes.isEmpty)
        XCTAssertFalse(audit.resolution.isEmpty)
    }

    func testEndHandProducesNeutralTerminalStateAndReplayRemainsPlayerTriggered() async throws {
        let seed = try activeSeed(requiring: .hit)
        let session = makeSession(seed: seed)
        await session.restoreOrDeal()

        session.showReplay()
        XCTAssertNil(session.presentedSheet)

        session.endHand()

        XCTAssertEqual(session.table.phase, .abandoned)
        XCTAssertEqual(session.table.resolution?.outcome, .abandoned)
        XCTAssertNotNil(session.auditDisclosure)

        session.showReplay()
        XCTAssertEqual(session.presentedSheet, .replay)
    }

    func testPersistedActiveHandRestoresTheExactFutureDeck() async throws {
        let seed = try activeSeed(requiring: .hit)
        let store = temporaryStore()
        let original = PracticeBlackjackSession(previewSeed: seed, store: store)
        await original.restoreOrDeal()
        await original.persist()

        let restored = PracticeBlackjackSession(previewSeed: seed &+ 1, store: store)
        await restored.restoreOrDeal()

        XCTAssertEqual(restored.table, original.table)

        original.hit()
        restored.hit()

        XCTAssertEqual(restored.table, original.table)
    }

    func testProductionNewHandRequestsANewSystemSeed() async throws {
        let firstSeed = try activeSeed(requiring: .stand)
        let secondSeed = firstSeed &+ 91
        var suppliedSeeds = [firstSeed, secondSeed]
        let session = PracticeBlackjackSession(
            previewSeed: nil,
            store: temporaryStore(),
            seedSource: { suppliedSeeds.removeFirst() }
        )
        await session.restoreOrDeal()
        session.stand()

        session.newHand()

        XCTAssertEqual(suppliedSeeds, [])
        XCTAssertEqual(
            session.table,
            try PrismetBlackjackAuditedSession.start(seed: secondSeed).observation
        )
    }

    func testPreviewNewHandUsesARepeatableSequenceWithoutTheSystemSeedSource() async throws {
        let previewSeed = try activeSeed(requiring: .stand)
        var systemSeedRequests = 0
        let session = PracticeBlackjackSession(
            previewSeed: previewSeed,
            store: temporaryStore(),
            seedSource: {
                systemSeedRequests += 1
                return 1
            }
        )
        await session.restoreOrDeal()
        session.stand()

        session.newHand()

        XCTAssertEqual(systemSeedRequests, 0)
        XCTAssertEqual(
            session.table,
            try PrismetBlackjackAuditedSession.start(
                seed: previewSeed &+ 0x9e3779b97f4a7c15
            ).observation
        )
    }

    func testCorruptSaveIsNotOverwrittenUntilStartFresh() async throws {
        let store = temporaryStore()
        let corrupt = Data("not blackjack state".utf8)
        try corrupt.write(to: store.fileURL, options: .atomic)
        let session = PracticeBlackjackSession(previewSeed: 17, store: store)

        await session.restoreOrDeal()

        XCTAssertEqual(session.loadState, .recoveryRequired(.corrupt))
        XCTAssertEqual(try Data(contentsOf: store.fileURL), corrupt)

        await session.startFresh()

        XCTAssertEqual(session.loadState, .ready)
        XCTAssertNotEqual(try Data(contentsOf: store.fileURL), corrupt)
        XCTAssertTrue(
            try FileManager.default.contentsOfDirectory(
                at: store.fileURL.deletingLastPathComponent(),
                includingPropertiesForKeys: nil
            ).contains { $0.lastPathComponent.hasPrefix("practice-blackjack-diagnostic-") }
        )
    }

    private func activeSeed(requiring command: PrismetBlackjackCommand) throws -> UInt64 {
        for seed in UInt64(1)...UInt64(2_000) {
            let session = try PrismetBlackjackAuditedSession.start(seed: seed)
            if session.observation.legalCommands.contains(command) {
                return seed
            }
        }
        throw XCTSkip("No deterministic active-hand seed was found in the fixture range.")
    }

    private func makeSession(seed: UInt64) -> PracticeBlackjackSession {
        PracticeBlackjackSession(previewSeed: seed, store: temporaryStore())
    }

    private func temporaryStore() -> PracticeBlackjackStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismet-blackjack-mac-tests-\(UUID().uuidString)", isDirectory: true)
        return PracticeBlackjackStore(fileURL: directory.appendingPathComponent("hand.json"))
    }
}
