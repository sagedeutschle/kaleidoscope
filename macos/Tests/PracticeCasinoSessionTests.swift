import XCTest
import PrismetShared
@testable import Prismet

@MainActor
final class PracticeCasinoSessionTests: XCTestCase {
    private let studyLabIDs: [PrismetPracticeCasinoGameID] = [
        .threeCardPokerLab, .texasHoldemLab, .caribbeanStudQualificationLab,
        .paiGowSplitLab, .omahaHandLab, .miniBaccaratPractice,
        .casinoWarPractice, .crapsPointLab, .sicBoOutcomeLab,
        .europeanRouletteLab,
    ]

    func testMacSessionRoutesEverySharedCatalogEntry() {
        let session = PracticeCasinoSession(seedSource: { 12 })

        for descriptor in PrismetPracticeCasinoCatalog.all {
            session.select(descriptor.id)
            XCTAssertEqual(session.selectedGameID, descriptor.id)
            XCTAssertNil(session.roundResult)
        }
    }

    func testCatalogContainsTwentyOneTablesAcrossTheFourKinds() {
        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.count, 21)
        XCTAssertEqual(Set(PrismetPracticeCasinoCatalog.all.map(\.id)), Set(PrismetPracticeCasinoGameID.allCases))
        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.filter { $0.kind == .blackjack }.map(\.id), [.blackjack])
        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.filter { $0.kind == .poker }.map(\.id), [.fiveCardDraw])
        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.filter { $0.kind == .fairChance }.count, 9)
        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.filter { $0.kind == .studyLab }.map(\.id), studyLabIDs)
    }

    func testStudyLabAdapterSupportsExactlyTheTenStudyTables() throws {
        XCTAssertEqual(PrismetCasinoStudyLabAdapter.supportedGameIDs, studyLabIDs)
        for id in studyLabIDs {
            XCTAssertEqual(try PrismetCasinoStudyLabAdapter(gameID: id).phase, .unstarted)
        }
    }

    func testPlayRoundDoesNotConsumeSeedsOrAlterStudyLabVisitState() throws {
        for id in studyLabIDs {
            var seedCalls = 0
            let session = PracticeCasinoSession(seedSource: { seedCalls += 1; return 12 })
            session.select(id)
            let snapshot = try XCTUnwrap(session.studyLabSnapshot, "Expected a Study Lab snapshot for \(id)")

            session.playRound()

            XCTAssertEqual(seedCalls, 0, "playRound must not consume a seed for \(id)")
            XCTAssertEqual(session.completedRoundCount, 0, "playRound must not complete \(id)")
            XCTAssertNil(session.roundResult, "playRound must not create a generic result for \(id)")
            XCTAssertEqual(session.studyLabSnapshot, snapshot, "playRound must preserve the Study Lab adapter snapshot for \(id)")
        }
    }

    func testStudyLabAdapterSelectionAndNewRoundAreSeedless() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        try adapter.perform(.deal, seed: 7)
        try adapter.perform(.togglePaiGowCard(index: 0))

        XCTAssertEqual(adapter.snapshot.selectedPaiGowCardIndices, [1], "Action indexes are zero-based; display positions are one-based.")
        XCTAssertThrowsError(try adapter.perform(.togglePaiGowCard(index: 1), seed: 8))

        try adapter.perform(.newRound)
        XCTAssertEqual(adapter.phase, .unstarted)
        XCTAssertThrowsError(try adapter.perform(.newRound, seed: 8))
    }

    func testMacNewRoundAndResetNeverCreateAnOutcome() {
        let session = PracticeCasinoSession(seedSource: { 12 })
        session.select(.oddEven)
        session.toggleChoice("odd")
        session.playRound()
        XCTAssertNotNil(session.roundResult)

        session.newRound()
        XCTAssertNil(session.roundResult)

        XCTAssertFalse(session.resetSession())
        XCTAssertNil(session.roundResult)
        XCTAssertTrue(session.resetSession(confirming: true))
        XCTAssertNil(session.roundResult)
        XCTAssertEqual(session.completedRoundCount, 0)
    }

    func testUnconfirmedResetPreservesLiveChancePokerAndStudyLabVisitState() throws {
        let chance = PracticeCasinoSession(seedSource: { 12 })
        chance.select(.oddEven)
        chance.toggleChoice("odd")
        chance.playRound()
        let chanceResult = try XCTUnwrap(chance.roundResult)
        XCTAssertFalse(chance.resetSession())
        XCTAssertEqual(chance.roundResult, chanceResult)
        XCTAssertEqual(chance.completedRoundCount, 1)

        let poker = PracticeCasinoSession(seedSource: { 12 })
        poker.select(.fiveCardDraw)
        poker.dealPoker()
        let pokerVisit = try XCTUnwrap(poker.pokerState)
        XCTAssertFalse(poker.resetSession())
        XCTAssertEqual(poker.pokerState, pokerVisit)

        let study = PracticeCasinoSession(seedSource: { 12 })
        study.select(.threeCardPokerLab)
        study.performStudyLabPrimary()
        let studyVisit = try XCTUnwrap(study.studyLabSnapshot)
        XCTAssertFalse(study.resetSession())
        XCTAssertEqual(study.studyLabSnapshot, studyVisit)
    }

    func testSelectingAnotherTableClearsUnfinishedTableState() {
        let session = PracticeCasinoSession(seedSource: { 7 })
        session.select(.fiveCardDraw)
        session.dealPoker()
        XCTAssertNotNil(session.pokerState)

        session.select(.coinCall)
        XCTAssertNil(session.pokerState)
        XCTAssertNil(session.roundResult)
    }

    func testReselectingTheCurrentTablePreservesItsVisitState() {
        let session = PracticeCasinoSession(seedSource: { 7 })
        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()
        let result = session.roundResult

        session.select(.coinCall)
        XCTAssertEqual(session.roundResult, result)
        XCTAssertEqual(session.completedRoundCount, 1)
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

    func testHigherLowerUsesTypedPreviewThenResolvesTheSameShownCard() throws {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: { seedCalls += 1; return 42 })
        session.select(.higherLower)
        session.showHigherLowerCard()
        let preview = try XCTUnwrap(session.higherLowerPreview)
        XCTAssertEqual(seedCalls, 1)

        session.toggleChoice("higher")
        session.playRound()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.roundResult?.tokens.first, preview.shownCard)
    }

    func testInvalidAndRepeatedCompactActionsConsumeNoSeeds() {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: { seedCalls += 1; return 7 })
        session.select(.coinCall)
        session.toggleChoice("not-a-choice")
        session.playRound()
        XCTAssertEqual(seedCalls, 0)

        session.toggleChoice("heads")
        session.playRound()
        session.playRound()
        XCTAssertEqual(seedCalls, 1)
    }

    func testPreviewSeedSequenceSuppliesDistinctPredictableWrappingSeedsForLaterRandomActions() throws {
        let session = PracticeCasinoSession(previewSeed: .max)

        session.select(.coinCall)
        session.toggleChoice("heads")
        session.playRound()
        XCTAssertEqual(try XCTUnwrap(session.roundResult).seed, .max)

        session.newRound()
        session.select(.oddEven)
        session.toggleChoice("odd")
        session.playRound()
        XCTAssertEqual(try XCTUnwrap(session.roundResult).seed, 0)
    }

    func testMacPokerRequiresExplicitDealHoldAndDraw() throws {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: { seedCalls += 1; return 91 })
        session.select(.fiveCardDraw)
        XCTAssertNil(session.pokerState)
        session.dealPoker()
        let opening = try XCTUnwrap(session.pokerState)
        XCTAssertEqual(opening.phase, .choosingHolds)
        XCTAssertEqual(seedCalls, 1)

        session.togglePokerHold(at: 0)
        session.drawPoker()
        XCTAssertEqual(session.pokerState?.phase, .complete)
        XCTAssertEqual(session.pokerState?.cards[0], opening.cards[0])
        XCTAssertEqual(session.completedRoundCount, 1)

        session.drawPoker()
        session.dealPoker()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testPokerCountsAreCompleteAndMutuallyExclusive() {
        let counts = PrismetFiveCardPokerEngine.exactCategoryCounts
        XCTAssertEqual(counts.count, PrismetPokerCategory.allCases.count)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactCount(for: .royalFlush), 4)
        XCTAssertEqual(PrismetFiveCardPokerEngine.exactCount(for: .straightFlush), 36)
        XCTAssertEqual(counts.reduce(0) { $0 + $1.count }, PrismetFiveCardPokerEngine.exactTotalHandCount)
    }

    func testStudyLabSessionSourcePinsSeedValidationAndValueReassignment() throws {
        let source = try casinoSource("PracticeCasinoSession.swift")
        for required in [
            "PrismetCasinoStudyLabAdapter?", "studyLabSnapshot", "func performStudyLabPrimary",
            "func newRound()", "func togglePaiGowCard(at zeroBasedIndex: Int)",
            "primary.requiresSeed", "seedSource()", "adapter.perform", "studyLabAdapter = adapter",
        ] {
            XCTAssertTrue(source.contains(required), "Missing Study Lab session contract: \(required)")
        }
        XCTAssertFalse(source.contains("PrismetCasinoStudyLabAdapter(gameID: selectedGameID, seed:"))
    }

    func testPlayRoundRetainsTheFairChanceKindGuard() throws {
        let source = try casinoSource("PracticeCasinoSession.swift")
        XCTAssertTrue(source.contains("guard descriptor.kind == .fairChance else { return }"))
    }

    func testStudyLabSessionSourceClearsVisitStateOnSwitchAndConfirmedResetWithoutAutoDeal() throws {
        let source = try casinoSource("PracticeCasinoSession.swift")
        XCTAssertTrue(source.contains("studyLabAdapter = nil"))
        XCTAssertTrue(source.contains("studyLabSnapshot = nil"))
        XCTAssertTrue(source.contains("Fair Chance, Poker, and Study Lab visit state"))
        XCTAssertFalse(source.localizedCaseInsensitiveContains("auto-deal"))
    }

    func testStudyLabEnabledPrimaryUsesExactlyOneSeedAndCompletesExactlyOnce() throws {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: { seedCalls += 1; return 77 })
        session.select(.threeCardPokerLab)

        XCTAssertEqual(session.studyLabSnapshot?.phase, .unstarted)
        XCTAssertEqual(session.studyLabSnapshot?.primaryAction?.title, "Deal")
        session.performStudyLabPrimary()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.studyLabSnapshot?.phase, .dealt)
        XCTAssertEqual(session.studyLabSnapshot?.audit.seeds.count, 1)

        session.performStudyLabPrimary()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.studyLabSnapshot?.phase, .complete)
        XCTAssertEqual(session.completedRoundCount, 1)

        session.performStudyLabPrimary()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.completedRoundCount, 1)
    }

    func testCasinoWarTieReusesItsOpeningSeedWithoutAnotherSourceCall() throws {
        let tieSeed = try firstCasinoWarTieSeed()
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: { seedCalls += 1; return tieSeed })
        session.select(.casinoWarPractice)

        session.performStudyLabPrimary()
        XCTAssertEqual(session.studyLabSnapshot?.phase, .warReady)
        XCTAssertEqual(seedCalls, 1)

        session.performStudyLabPrimary()
        let audit = try XCTUnwrap(session.studyLabSnapshot?.audit.seeds)
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(audit.map(\.seed), [tieSeed, tieSeed])
        XCTAssertEqual(audit.map(\.seedUsage), [.newSeed, .reusedOriginalDealSeed])
    }

    func testCrapsContinuationConsumesQueuedOpeningAndContinuationSeeds() throws {
        let openingSeed = try firstCrapsPointSeed()
        let continuationSeed: UInt64 = 9_999
        var queuedSeeds = [openingSeed, continuationSeed]
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: {
            seedCalls += 1
            return queuedSeeds.removeFirst()
        })
        session.select(.crapsPointLab)

        session.performStudyLabPrimary()
        XCTAssertEqual(session.studyLabSnapshot?.phase, .point)
        session.performStudyLabPrimary()

        XCTAssertEqual(seedCalls, 2)
        XCTAssertEqual(session.studyLabSnapshot?.audit.seeds.map(\.seed), [openingSeed, continuationSeed])
    }

    func testStudyLabDisabledPrimaryConsumesNoSeedAndNewRoundIsSeedless() throws {
        var seedCalls = 0
        let session = PracticeCasinoSession(seedSource: { seedCalls += 1; return 88 })
        session.select(.paiGowSplitLab)
        session.performStudyLabPrimary()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.studyLabSnapshot?.phase, .dealt)
        XCTAssertEqual(session.studyLabSnapshot?.primaryAction?.enabled, false)

        session.performStudyLabPrimary()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.completedRoundCount, 0)

        session.newRound()
        XCTAssertEqual(seedCalls, 1)
        XCTAssertEqual(session.studyLabSnapshot?.phase, .unstarted)
        XCTAssertTrue(session.studyLabSnapshot?.audit.seeds.isEmpty ?? false)
    }

    private func casinoSource(_ file: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Casino/\(file)"), encoding: .utf8)
    }

    private func firstCasinoWarTieSeed() throws -> UInt64 {
        for seed in UInt64(0)...10_000 {
            var adapter = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice)
            try adapter.perform(.deal, seed: seed)
            if adapter.phase == .warReady { return seed }
        }
        throw XCTSkip("No deterministic Casino War tie seed found")
    }

    private func firstCrapsPointSeed() throws -> UInt64 {
        for seed in UInt64(0)...1_000 {
            var adapter = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab)
            try adapter.perform(.roll, seed: seed)
            if adapter.phase == .point { return seed }
        }
        throw XCTSkip("No deterministic Craps point seed found")
    }
}
