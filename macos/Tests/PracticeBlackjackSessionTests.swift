import XCTest
import PrismetShared
@testable import Prismet

@MainActor
final class PracticeBlackjackSessionTests: XCTestCase {
    private enum InjectedFileFailure: Error {
        case read
        case preserve
    }

    func testHitDelegatesToSharedEngineAndPublishesItsObservation() async throws {
        let seed = try activeSeed(requiring: .hit)
        let session = makeSession(seed: seed)
        await session.restoreOrDeal()
        let initialCount = session.table.playerCards.count
        let expected = try PrismetBlackjackAuditedSession.start(seed: seed)
            .applying(.hit)

        session.hit()

        XCTAssertEqual(session.table.playerCards.count, initialCount + 1)
        XCTAssertEqual(session.table, expected.observation)
    }

    func testConcealedAuditedStateHasNoModuleInternalGetter() throws {
        let source = try String(contentsOf: casinoSourceURL("PracticeBlackjackSession.swift"))

        XCTAssertTrue(source.contains("private var auditedSession:"))
        XCTAssertFalse(source.contains("private(set) var auditedSession:"))
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

    func testScheduledActionSavesRemainOrderedAfterSessionDeallocation() async throws {
        let seed = try activeSeed(requiring: [.hit, .hit])
        let store = temporaryStore()
        var expected = try PrismetBlackjackAuditedSession.start(seed: seed)
        var session: PracticeBlackjackSession? = PracticeBlackjackSession(
            previewSeed: seed,
            store: store
        )
        await session?.restoreOrDeal()

        session?.hit()
        expected = try expected.applying(.hit)
        session?.hit()
        expected = try expected.applying(.hit)
        XCTAssertEqual(session?.table, expected.observation)

        weak var releasedSession = session
        session = nil

        XCTAssertNil(releasedSession)
        releasedSession = nil
        try await waitForStoredObservation(expected.observation, in: store)
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

    func testReadFailureQuarantinesOriginalBeforeStartFreshReplacement() async throws {
        let fileURL = temporaryFileURL()
        let original = Data("unreadable practice hand".utf8)
        try original.write(to: fileURL, options: .atomic)
        let store = PracticeBlackjackStore(
            fileURL: fileURL,
            readData: { _ in throw InjectedFileFailure.read }
        )
        let session = PracticeBlackjackSession(previewSeed: 23, store: store)

        await session.restoreOrDeal()

        XCTAssertEqual(session.loadState, .recoveryRequired(.corrupt))
        XCTAssertEqual(try Data(contentsOf: fileURL), original)

        await session.startFresh()

        XCTAssertEqual(session.loadState, .ready)
        XCTAssertNotEqual(try Data(contentsOf: fileURL), original)
        let diagnosticURL = try XCTUnwrap(
            diagnosticFiles(beside: fileURL).first
        )
        XCTAssertEqual(try Data(contentsOf: diagnosticURL), original)
        XCTAssertNoThrow(try storedObservation(at: fileURL))
    }

    func testStartFreshRefusesOverwriteWhenQuarantineFails() async throws {
        let fileURL = temporaryFileURL()
        let original = Data("damaged practice hand".utf8)
        try original.write(to: fileURL, options: .atomic)
        let store = PracticeBlackjackStore(
            fileURL: fileURL,
            preserveFile: { _, _ in throw InjectedFileFailure.preserve }
        )
        let session = PracticeBlackjackSession(previewSeed: 29, store: store)
        await session.restoreOrDeal()

        await session.startFresh()

        XCTAssertEqual(session.loadState, .recoveryRequired(.corrupt))
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
        XCTAssertTrue(diagnosticFiles(beside: fileURL).isEmpty)
        XCTAssertNotNil(session.errorMessage)
    }

    private func activeSeed(requiring command: PrismetBlackjackCommand) throws -> UInt64 {
        try activeSeed(requiring: [command])
    }

    private func activeSeed(
        requiring commands: [PrismetBlackjackCommand]
    ) throws -> UInt64 {
        for seed in UInt64(1)...UInt64(2_000) {
            var session = try PrismetBlackjackAuditedSession.start(seed: seed)
            var supportsSequence = true
            for command in commands {
                guard session.observation.legalCommands.contains(command) else {
                    supportsSequence = false
                    break
                }
                session = try session.applying(command)
            }
            if supportsSequence {
                return seed
            }
        }
        throw XCTSkip("No deterministic seed supports the requested command sequence.")
    }

    private func makeSession(seed: UInt64) -> PracticeBlackjackSession {
        PracticeBlackjackSession(previewSeed: seed, store: temporaryStore())
    }

    private func temporaryStore() -> PracticeBlackjackStore {
        PracticeBlackjackStore(fileURL: temporaryFileURL())
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismet-blackjack-mac-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("hand.json")
    }

    private func casinoSourceURL(_ file: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Casino", isDirectory: true)
            .appendingPathComponent(file)
    }

    private func waitForStoredObservation(
        _ expected: PrismetBlackjackObservation,
        in store: PracticeBlackjackStore
    ) async throws {
        for _ in 0..<100 {
            if let observation = try? storedObservation(at: store.fileURL),
               observation == expected {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("The final queued observation was not persisted before timeout.")
    }

    private func storedObservation(at fileURL: URL) throws -> PrismetBlackjackObservation {
        let data = try Data(contentsOf: fileURL)
        let state = try PrismetVersionedGameStateCodec.decodeSupported(
            data,
            support: PrismetVersionSupport(
                versions: [
                    PrismetSupportedGameVersion(
                        gameID: PrismetBlackjackRulesV1.canonicalGameID,
                        rulesVersion: PrismetBlackjackRulesV1.rulesVersion,
                        payloadVersion: PrismetBlackjackRulesV1.payloadVersion,
                        randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
                        hashAlgorithm: .fnv1a64V1
                    )
                ]
            )
        )
        return try PrismetBlackjackAuditedSession.restore(from: state).observation
    }

    private func diagnosticFiles(beside fileURL: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: fileURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        ))?.filter {
            $0.lastPathComponent.hasPrefix("practice-blackjack-diagnostic-")
        } ?? []
    }
}
