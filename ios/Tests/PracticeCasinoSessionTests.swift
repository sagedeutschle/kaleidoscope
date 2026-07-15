import XCTest
import PrismetShared
@testable import Prismet

@MainActor
final class PracticeCasinoSessionTests: XCTestCase {
    func testEveryCatalogGameCanBeSelectedWithoutStartingARound() {
        let session = PracticeCasinoSession(seedSource: { 7 })

        for game in PrismetPracticeCasinoCatalog.all {
            session.select(game.id)
            XCTAssertEqual(session.selectedGameID, game.id)
            XCTAssertNil(session.roundResult)
            XCTAssertNil(session.pokerState)
        }
    }

    func testCompactRoundRequiresExplicitPlayAndNewRoundDoesNotAutoplay() {
        let session = PracticeCasinoSession(seedSource: { 42 })
        session.select(.coinCall)
        session.toggleChoice("heads")

        XCTAssertNil(session.roundResult)
        session.playRound()
        XCTAssertEqual(session.roundResult?.seed, 42)
        XCTAssertEqual(session.completedRoundCount, 1)

        session.newRound()
        XCTAssertNil(session.roundResult)
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testPokerHoldDrawAndResetStaySessionOnly() throws {
        let session = PracticeCasinoSession(seedSource: { 91 })
        session.select(.fiveCardDraw)
        session.dealPoker()
        let opening = try XCTUnwrap(session.pokerState)

        session.togglePokerHold(at: 0)
        session.drawPoker()

        XCTAssertEqual(session.pokerState?.cards[0], opening.cards[0])
        XCTAssertEqual(session.completedRoundCount, 1)

        session.resetSession()
        XCTAssertNil(session.pokerState)
        XCTAssertEqual(session.completedRoundCount, 0)
    }

    func testSwitchingTablesClearsTransientStateWithoutStartingTheNewTable() {
        let session = PracticeCasinoSession(seedSource: { 12 })
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()

        session.select(.fairWheel)

        XCTAssertEqual(session.selectedGameID, .fairWheel)
        XCTAssertTrue(session.selectedChoiceIDs.isEmpty)
        XCTAssertNil(session.roundResult)
        XCTAssertNil(session.pokerState)
    }

    func testReselectingTheCurrentTablePreservesItsVisitState() {
        let session = PracticeCasinoSession(seedSource: { 12 })
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()
        let result = session.roundResult

        session.select(.coinCall)

        XCTAssertEqual(session.roundResult, result)
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testHigherLowerPreviewConsumesOneSeedAndRevealReusesIt() throws {
        var seeds: [UInt64] = [41, 99]
        let session = PracticeCasinoSession(seedSource: { seeds.removeFirst() })
        session.select(.higherLower)

        session.showHigherLowerCard()
        let preview = try XCTUnwrap(session.higherLowerPreview)
        XCTAssertEqual(preview.seed, 41)
        XCTAssertEqual(seeds, [99])
        XCTAssertNil(session.roundResult)

        session.toggleChoice("higher")
        session.revealHigherLower()
        XCTAssertEqual(session.roundResult?.seed, 41)
        XCTAssertEqual(seeds, [99])
    }

    func testHigherLowerRejectsChoicesUntilThePreviewExists() {
        let session = PracticeCasinoSession(seedSource: { 41 })
        session.select(.higherLower)

        session.toggleChoice("higher")
        XCTAssertTrue(session.selectedChoiceIDs.isEmpty)

        session.showHigherLowerCard()
        session.toggleChoice("higher")
        XCTAssertEqual(session.selectedChoiceIDs, ["higher"])
    }

    func testChoiceLimitsReplaceSingleChoiceAndCapNumberDrawAtThree() {
        let session = PracticeCasinoSession(seedSource: { 7 })
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.toggleChoice("tails")
        XCTAssertEqual(session.selectedChoiceIDs, ["tails"])

        session.select(.numberDraw)
        ["1", "2", "3", "4"].forEach(session.toggleChoice)
        XCTAssertEqual(session.selectedChoiceIDs, ["1", "2", "3"])
    }

    func testInvalidAndRepeatedActionsDoNotConsumeSeeds() {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 50
        })
        session.select(.coinCall)

        session.playRound()
        XCTAssertEqual(seedCalls, 0)

        session.toggleChoice("heads")
        session.playRound()
        session.playRound()
        XCTAssertEqual(seedCalls, 1)

        session.newRound()
        session.select(.higherLower)
        session.revealHigherLower()
        XCTAssertEqual(seedCalls, 1)
    }

    func testRepeatedPokerDrawAndDealCompleteExactlyOneRoundWithoutNewRound() {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 73
        })
        session.select(.fiveCardDraw)
        session.dealPoker()
        session.drawPoker()
        let terminalState = session.pokerState

        session.drawPoker()
        session.dealPoker()

        XCTAssertEqual(session.pokerState, terminalState)
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testInvalidPokerHoldPreservesTheValidHand() throws {
        let session = PracticeCasinoSession(seedSource: { 73 })
        session.select(.fiveCardDraw)
        session.dealPoker()
        let opening = try XCTUnwrap(session.pokerState)

        session.togglePokerHold(at: 99)

        XCTAssertEqual(session.pokerState, opening)
    }

    func testStudyLabAdapterSupportsExactlyTheTenStudyTablesAndRejectsElevenLegacyTables() throws {
        let studyLabIDs = Set(PrismetPracticeCasinoCatalog.all
            .filter { $0.kind == .studyLab }
            .map(\.id))
        let legacyIDs = Set(PrismetPracticeCasinoCatalog.all
            .filter { $0.kind != .studyLab }
            .map(\.id))

        XCTAssertEqual(studyLabIDs.count, 10)
        XCTAssertEqual(legacyIDs.count, 11)
        XCTAssertEqual(Set(PrismetCasinoStudyLabAdapter.supportedGameIDs), studyLabIDs)

        for id in studyLabIDs {
            let adapter = try PrismetCasinoStudyLabAdapter(gameID: id)
            XCTAssertEqual(adapter.phase, .unstarted)
            XCTAssertNil(adapter.snapshot.audit.seed)
        }
        for id in legacyIDs {
            XCTAssertThrowsError(try PrismetCasinoStudyLabAdapter(gameID: id))
        }
    }

    func testStudyLabEntrySelectionAndSeedlessActionsDoNotCreateAuditSeeds() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        XCTAssertNil(adapter.snapshot.audit.seed)
        XCTAssertTrue(adapter.snapshot.audit.seeds.isEmpty)

        try adapter.perform(.newRound)
        XCTAssertEqual(adapter.phase, .unstarted)
        XCTAssertTrue(adapter.snapshot.audit.seeds.isEmpty)

        try adapter.perform(.deal, seed: 81)
        let dealt = adapter.snapshot
        try adapter.perform(.togglePaiGowCard(index: 0))
        try adapter.perform(.togglePaiGowCard(index: 1))

        XCTAssertEqual(adapter.snapshot.audit.seeds, dealt.audit.seeds)
        XCTAssertEqual(adapter.snapshot.selectedPaiGowCardIndices, [1, 2])
    }

    func testDisabledAndInvalidStudyLabActionsAreImmutableAndNeverCreateAnAuditSeed() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        let opening = adapter.snapshot

        XCTAssertThrowsError(try adapter.perform(.analyzeSplit))
        XCTAssertEqual(adapter.snapshot, opening)

        try adapter.perform(.deal, seed: 19)
        let dealt = adapter.snapshot
        XCTAssertFalse(dealt.primaryControlEnabled)
        XCTAssertThrowsError(try adapter.perform(.analyzeSplit))
        XCTAssertThrowsError(try adapter.perform(.deal, seed: 20))
        XCTAssertEqual(adapter.snapshot, dealt)
        XCTAssertEqual(adapter.snapshot.audit.seeds, [.init(sequence: 1, action: "Deal", seed: 19)])
    }

    func testEverySeedRequiringOpeningPrimaryActionAddsExactlyOneAuditSeed() throws {
        for id in PrismetCasinoStudyLabAdapter.supportedGameIDs {
            var adapter = try PrismetCasinoStudyLabAdapter(gameID: id)
            let primary = try XCTUnwrap(adapter.snapshot.primaryAction)
            XCTAssertTrue(primary.enabled)
            XCTAssertTrue(primary.requiresSeed)

            try adapter.perform(primary.action, seed: 300)

            XCTAssertEqual(adapter.snapshot.audit.seeds.count, 1, "\(id.rawValue)")
            XCTAssertEqual(adapter.snapshot.audit.seeds.first?.seed, 300, "\(id.rawValue)")
            if id != .crapsPointLab || adapter.phase != .point {
                XCTAssertThrowsError(try adapter.perform(primary.action, seed: 301), "\(id.rawValue)")
                XCTAssertEqual(adapter.snapshot.audit.seeds.count, 1, "\(id.rawValue)")
            }
        }
    }

    func testCrapsContinuationRollConsumesExactlyOneAdditionalSeed() throws {
        var craps: PrismetCasinoStudyLabAdapter?
        var openingSeed: UInt64 = 0
        for seed in 1...500 {
            var candidate = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab)
            try candidate.perform(.roll, seed: UInt64(seed))
            if candidate.phase == .point {
                craps = candidate
                openingSeed = UInt64(seed)
                break
            }
        }
        var adapter = try XCTUnwrap(craps)
        XCTAssertEqual(adapter.snapshot.audit.seeds, [.init(sequence: 1, action: "Roll", seed: openingSeed)])

        try adapter.perform(.roll, seed: 9_999)

        XCTAssertEqual(adapter.snapshot.audit.seeds.map(\.seed), [openingSeed, 9_999])
        XCTAssertEqual(adapter.snapshot.audit.seeds.map(\.sequence), [1, 2])
    }

    func testStudyLabNewRoundClearsOnlyTheCurrentVisitWithoutSeedOrAutodeal() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .sicBoOutcomeLab)
        try adapter.perform(.roll, seed: 66)
        XCTAssertEqual(adapter.phase, .complete)

        try adapter.perform(.newRound)

        XCTAssertEqual(adapter.phase, .unstarted)
        XCTAssertNil(adapter.snapshot.audit.seed)
        XCTAssertTrue(adapter.snapshot.audit.seeds.isEmpty)
        XCTAssertNil(adapter.snapshot.dice)
        XCTAssertEqual(adapter.snapshot.primaryAction?.action, .roll)
    }

    func testSessionCreatesAnUnstartedStudyLabOnlyOnStudyLabSelectionWithoutASeed() throws {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 404
        })

        XCTAssertNil(session.studyLabAdapter)
        session.select(.threeCardPokerLab)

        let snapshot = try XCTUnwrap(session.studyLabSnapshot)
        XCTAssertEqual(snapshot.phase, .unstarted)
        XCTAssertEqual(session.studyLabAdapter?.gameID, .threeCardPokerLab)
        XCTAssertNil(snapshot.audit.seed)
        XCTAssertEqual(seedCalls, 0)
    }

    func testSessionRequestsOneSeedOnlyForAnEnabledSeededStudyLabPrimaryAction() throws {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 707
        })
        session.select(.paiGowSplitLab)

        session.performStudyLabPrimaryAction()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.studyLabSnapshot?.audit.seeds.map(\.seed), [707])

        session.performStudyLabPrimaryAction()
        XCTAssertEqual(seedCalls, 1, "A disabled Analyze Split control must not ask for a seed")

        session.toggleStudyLabPaiGowCard(at: 0)
        session.toggleStudyLabPaiGowCard(at: 1)
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.studyLabSnapshot?.selectedPaiGowCardIndices, [1, 2])
    }

    func testImmediatelyCompletingStudyLabPrimaryActionCountsOneCompletedRound() {
        let session = PracticeCasinoSession(seedSource: { 707 })
        session.select(.sicBoOutcomeLab)

        session.performStudyLabPrimaryAction()

        XCTAssertEqual(session.studyLabSnapshot?.phase, .complete)
        XCTAssertEqual(session.studyLabSnapshot?.audit.seeds.map(\.seed), [707])
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testTerminalStudyLabPrimaryActionDoesNotDoubleCountCompletedRound() {
        let session = PracticeCasinoSession(seedSource: { 707 })
        session.select(.sicBoOutcomeLab)
        session.performStudyLabPrimaryAction()

        session.performStudyLabPrimaryAction()

        XCTAssertEqual(session.studyLabSnapshot?.phase, .complete)
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testSessionStudyLabNewRoundAndSelectionSwitchClearVisitStateWithoutSeeds() throws {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return 808
        })
        session.select(.sicBoOutcomeLab)
        session.performStudyLabPrimaryAction()
        XCTAssertEqual(seedCalls, 1)

        session.newRound()
        XCTAssertEqual(session.studyLabSnapshot?.phase, .unstarted)
        XCTAssertNil(session.studyLabSnapshot?.audit.seed)
        XCTAssertEqual(seedCalls, 1)

        session.select(.coinCall)
        XCTAssertNil(session.studyLabAdapter)
        XCTAssertNil(session.studyLabSnapshot)

        session.select(.texasHoldemLab)
        XCTAssertEqual(session.studyLabSnapshot?.phase, .unstarted)
        session.resetSession()
        XCTAssertNil(session.studyLabAdapter)
        XCTAssertNil(session.studyLabSnapshot)
        XCTAssertEqual(seedCalls, 1)
    }

    func testSessionCasinoWarTieReusesTheOriginalDealSeedWithoutAnotherSeedSourceCall() throws {
        let tieSeed = try XCTUnwrap((1...10_000).lazy.first { seed in
            guard let state = try? PrismetCasinoWarLab.deal(seed: UInt64(seed)) else { return false }
            return state.phase == .warReady
        })
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return UInt64(tieSeed)
        })
        session.select(.casinoWarPractice)

        session.performStudyLabPrimaryAction()
        XCTAssertEqual(session.studyLabSnapshot?.phase, .warReady)
        session.performStudyLabPrimaryAction()

        let audit = try XCTUnwrap(session.studyLabSnapshot?.audit.seeds)
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(audit.map(\.sequence), [1, 2])
        XCTAssertEqual(audit.map(\.seed), [UInt64(tieSeed), UInt64(tieSeed)])
        XCTAssertEqual(audit.map(\.seedUsage), [.newSeed, .reusedOriginalDealSeed])
    }

    func testSessionCrapsPointRollsUseDistinctQueuedOpeningAndContinuationSeeds() throws {
        let openingSeed = try XCTUnwrap((1...500).lazy.first { seed in
            guard let state = try? PrismetCrapsPointLabEngine.roll(seed: UInt64(seed), in: .ready) else { return false }
            return state.phase == .point
        })
        var queuedSeeds: [UInt64] = [UInt64(openingSeed), 9_999]
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return queuedSeeds.removeFirst()
        })
        session.select(.crapsPointLab)

        session.performStudyLabPrimaryAction()
        XCTAssertEqual(session.studyLabSnapshot?.phase, .point)
        session.performStudyLabPrimaryAction()

        XCTAssertEqual(seedCalls, 2)
        XCTAssertTrue(queuedSeeds.isEmpty)
        XCTAssertEqual(session.studyLabSnapshot?.audit.seeds.map(\.seed), [UInt64(openingSeed), 9_999])
        XCTAssertEqual(session.studyLabSnapshot?.audit.seeds.map(\.sequence), [1, 2])
    }

    func testPreviewSeedProducesAStatefulPredictableSequenceForTwoRandomActions() {
        let session = PracticeCasinoSession(previewSeed: 41)
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()
        let firstSeed = session.roundResult?.seed

        session.newRound()
        session.toggleChoice("heads")
        session.playRound()

        XCTAssertEqual(firstSeed, 41)
        XCTAssertEqual(session.roundResult?.seed, 42)
    }

    func testPreviewSeedWrapsAndAdvancesExactlyOnceForEachSeedRequest() {
        let session = PracticeCasinoSession(previewSeed: .max)
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()
        XCTAssertEqual(session.roundResult?.seed, .max)

        session.newRound()
        session.toggleChoice("heads")
        session.playRound()
        XCTAssertEqual(session.roundResult?.seed, 0)
    }

    func testPreviewInitializerRequiresAnExplicitSeedAndNilKeepsProductionRandomness() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Casino/PracticeCasinoSession.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertTrue(source.contains("convenience init(previewSeed: UInt64?)"))
        XCTAssertFalse(source.contains("convenience init(previewSeed: UInt64? = nil)"))
        XCTAssertTrue(source.contains("guard let previewSeed else {\n            self.init()"))

        let session = PracticeCasinoSession(previewSeed: nil)
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()

        XCTAssertNotNil(session.roundResult?.seed)
    }
}
