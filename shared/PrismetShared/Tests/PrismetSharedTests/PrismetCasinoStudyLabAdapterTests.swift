import XCTest
@testable import PrismetShared

final class PrismetCasinoStudyLabAdapterTests: XCTestCase {
    // MARK: - Lifecycle and action safety

    func testPrimaryActionIsStateDerivedForAllTenStudyLabs() throws {
        let opening: [(PrismetPracticeCasinoGameID, PrismetCasinoStudyLabAdapter.Action, String)] = [
            (.threeCardPokerLab, .deal, "Deal"), (.texasHoldemLab, .deal, "Deal"),
            (.caribbeanStudQualificationLab, .deal, "Deal"), (.paiGowSplitLab, .deal, "Deal"),
            (.omahaHandLab, .deal, "Deal"), (.miniBaccaratPractice, .deal, "Deal"),
            (.casinoWarPractice, .deal, "Deal"), (.crapsPointLab, .roll, "Roll"),
            (.sicBoOutcomeLab, .roll, "Roll"), (.europeanRouletteLab, .spin, "Spin")
        ]

        for (id, action, title) in opening {
            let adapter = try PrismetCasinoStudyLabAdapter(gameID: id)
            XCTAssertEqual(adapter.snapshot.primaryAction?.action, action, "\(id)")
            XCTAssertEqual(adapter.snapshot.primaryAction?.title, title, "\(id)")
            XCTAssertEqual(adapter.snapshot.primaryAction?.enabled, true, "\(id)")
            XCTAssertEqual(adapter.snapshot.primaryAction?.requiresSeed, true, "\(id)")
        }
    }

    func testPrimaryActionStepsCardAndTableauLifecycles() throws {
        var three = try PrismetCasinoStudyLabAdapter(gameID: .threeCardPokerLab)
        try three.perform(.deal, seed: 1)
        assertPrimary(three, .reveal, "Reveal", requiresSeed: false)
        try three.perform(.reveal)
        XCTAssertNil(three.snapshot.primaryAction)

        var holdem = try PrismetCasinoStudyLabAdapter(gameID: .texasHoldemLab)
        try holdem.perform(.deal, seed: 2); assertPrimary(holdem, .flop, "Show Flop", requiresSeed: false)
        try holdem.perform(.flop); assertPrimary(holdem, .turn, "Show Turn", requiresSeed: false)
        try holdem.perform(.turn); assertPrimary(holdem, .river, "Show River", requiresSeed: false)
        try holdem.perform(.river); assertPrimary(holdem, .complete, "Classify", requiresSeed: false)
        try holdem.perform(.complete); XCTAssertNil(holdem.snapshot.primaryAction)

        var caribbean = try PrismetCasinoStudyLabAdapter(gameID: .caribbeanStudQualificationLab)
        try caribbean.perform(.deal, seed: 3); assertPrimary(caribbean, .reveal, "Reveal", requiresSeed: false)
        try caribbean.perform(.reveal); XCTAssertNil(caribbean.snapshot.primaryAction)

        var omaha = try PrismetCasinoStudyLabAdapter(gameID: .omahaHandLab)
        try omaha.perform(.deal, seed: 4); assertPrimary(omaha, .flop, "Show Flop", requiresSeed: false)
        try omaha.perform(.flop); assertPrimary(omaha, .turn, "Show Turn", requiresSeed: false)
        try omaha.perform(.turn); assertPrimary(omaha, .river, "Show River", requiresSeed: false)
        try omaha.perform(.river); assertPrimary(omaha, .complete, "Classify", requiresSeed: false)
        try omaha.perform(.complete); XCTAssertNil(omaha.snapshot.primaryAction)
    }

    func testPrimaryActionStepsBaccaratWarAndDiceLifecycles() throws {
        var baccarat = try PrismetCasinoStudyLabAdapter(gameID: .miniBaccaratPractice)
        try baccarat.perform(.deal, seed: 14)
        while baccarat.phase != .complete {
            assertPrimary(baccarat, .advance, "Advance", requiresSeed: false)
            try baccarat.perform(.advance)
        }
        XCTAssertNil(baccarat.snapshot.primaryAction)

        var war = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice)
        let tieSeed = try firstWarTieSeed()
        try war.perform(.deal, seed: tieSeed)
        assertPrimary(war, .reveal, "Reveal", requiresSeed: false)
        try war.perform(.reveal)
        XCTAssertNil(war.snapshot.primaryAction)

        var craps = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab)
        try craps.perform(.roll, seed: try firstCrapsPointSeed())
        assertPrimary(craps, .roll, "Roll", requiresSeed: true)
        try craps.perform(.roll, seed: 99)

        var sicBo = try PrismetCasinoStudyLabAdapter(gameID: .sicBoOutcomeLab)
        try sicBo.perform(.roll, seed: 6)
        XCTAssertNil(sicBo.snapshot.primaryAction)

        var roulette = try PrismetCasinoStudyLabAdapter(gameID: .europeanRouletteLab)
        try roulette.perform(.spin, seed: 7)
        XCTAssertNil(roulette.snapshot.primaryAction)
    }

    func testInvalidActionsAndSeedPolicyPreserveExactPriorState() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .threeCardPokerLab)
        let unstarted = adapter
        assertError(.missingSeed) { try adapter.perform(.deal) }
        XCTAssertEqual(adapter, unstarted)
        try adapter.perform(.deal, seed: 40)
        let dealt = adapter
        assertError(.invalidAction(.deal)) { try adapter.perform(.deal, seed: 41) }
        XCTAssertEqual(adapter, dealt)
        assertError(.unexpectedSeed) { try adapter.perform(.reveal, seed: 42) }
        XCTAssertEqual(adapter, dealt)
        try adapter.perform(.reveal)
        let complete = adapter
        assertError(.invalidAction(.reveal)) { try adapter.perform(.reveal) }
        XCTAssertEqual(adapter, complete)
        try adapter.perform(.newRound)
        XCTAssertEqual(adapter.phase, .unstarted)
        XCTAssertNil(adapter.snapshot.audit.seed)

        var roulette = try PrismetCasinoStudyLabAdapter(gameID: .europeanRouletteLab)
        try roulette.perform(.spin, seed: 11)
        let spun = roulette
        assertError(.invalidAction(.spin)) { try roulette.perform(.spin, seed: 12) }
        XCTAssertEqual(roulette, spun)
    }

    func testPaiGowDraftValidationAnalysisAndChangeSplitLifecycle() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        try adapter.perform(.deal, seed: 83)
        XCTAssertEqual(adapter.snapshot.primaryAction?.title, "Analyze Split")
        XCTAssertEqual(adapter.snapshot.primaryAction?.enabled, false)
        let dealt = adapter
        assertError(.invalidPaiGowSelection) { try adapter.perform(.togglePaiGowCard(index: 7)) }
        XCTAssertEqual(adapter, dealt)
        assertError(.invalidPaiGowSelection) { try adapter.perform(.changePaiGowSplit(indices: [-1, 0])) }
        XCTAssertEqual(adapter, dealt)

        let first = try firstAnalyzableDraft(for: adapter)
        try adapter.perform(.changePaiGowSplit(indices: first))
        assertPrimary(adapter, .analyzeSplit, "Analyze Split", requiresSeed: false)
        try adapter.perform(.analyzeSplit)
        XCTAssertEqual(adapter.phase, .complete)
        XCTAssertEqual(adapter.snapshot.primaryAction?.title, "Update Split")
        XCTAssertEqual(adapter.snapshot.primaryAction?.enabled, false)

        let selected = adapter.snapshot.selectedPaiGowCardIndices.map { $0 - 1 }
        let replacement = try firstChangedAnalyzableDraft(for: adapter, excluding: selected)
        for index in selected where !replacement.contains(index) {
            try adapter.perform(.togglePaiGowCard(index: index))
        }
        for index in replacement where !selected.contains(index) {
            try adapter.perform(.togglePaiGowCard(index: index))
        }
        XCTAssertEqual(adapter.snapshot.selectedPaiGowCardIndices, replacement.map { $0 + 1 })
        assertPrimary(adapter, .changePaiGowSplit(indices: replacement), "Update Split", requiresSeed: false)
        try adapter.perform(.changePaiGowSplit(indices: replacement))
        XCTAssertEqual(adapter.snapshot.primaryAction?.enabled, false)
        let analyzed = adapter
        assertError(.invalidAction(.analyzeSplit)) { try adapter.perform(.analyzeSplit) }
        XCTAssertEqual(adapter, analyzed)
        try adapter.perform(.newRound)
        XCTAssertEqual(adapter.phase, .unstarted)
    }

    func testPaiGowChangedLegalDraftPublishesPendingReanalysisInsteadOfStaleAnalysis() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        try adapter.perform(.deal, seed: 83)
        let committed = try firstAnalyzableDraft(for: adapter)
        try adapter.perform(.changePaiGowSplit(indices: committed))
        try adapter.perform(.analyzeSplit)
        let analyzedCategory = try XCTUnwrap(adapter.snapshot.category)

        let replacement = try firstChangedAnalyzableDraft(for: adapter, excluding: committed)
        for index in committed where !replacement.contains(index) {
            try adapter.perform(.togglePaiGowCard(index: index))
        }
        for index in replacement where !committed.contains(index) {
            try adapter.perform(.togglePaiGowCard(index: index))
        }

        let snapshot = adapter.snapshot
        XCTAssertEqual(snapshot.selectedPaiGowCardIndices, replacement.map { $0 + 1 })
        XCTAssertEqual(snapshot.status, "Split changed; selected positions \(replacement.map { String($0 + 1) }.joined(separator: ", ")) are ready to reanalyze")
        XCTAssertNil(snapshot.category)
        XCTAssertNotEqual(snapshot.category, analyzedCategory)
        XCTAssertEqual(snapshot.summaryRows.first(where: { $0.label == "Stage" })?.value, "Reanalysis pending")
        XCTAssertEqual(snapshot.summaryRows.first(where: { $0.label == "Analysis" })?.value, "Pending reanalysis")
        assertPrimary(adapter, .changePaiGowSplit(indices: replacement), "Update Split", requiresSeed: false)
    }

    func testPaiGowReselectingCommittedDraftRestoresCurrentAnalysis() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        try adapter.perform(.deal, seed: 83)
        let committed = try firstAnalyzableDraft(for: adapter)
        try adapter.perform(.changePaiGowSplit(indices: committed))
        try adapter.perform(.analyzeSplit)
        let analyzedSnapshot = adapter.snapshot
        let removedIndex = try XCTUnwrap(committed.first)

        try adapter.perform(.togglePaiGowCard(index: removedIndex))
        XCTAssertNil(adapter.snapshot.category)
        XCTAssertEqual(adapter.snapshot.status, "Split changed; select two low-hand cards to reanalyze")
        XCTAssertEqual(adapter.snapshot.summaryRows.first(where: { $0.label == "Analysis" })?.value, "Pending reanalysis")

        try adapter.perform(.togglePaiGowCard(index: removedIndex))
        let restoredSnapshot = adapter.snapshot
        XCTAssertEqual(restoredSnapshot.selectedPaiGowCardIndices, committed.map { $0 + 1 })
        XCTAssertEqual(restoredSnapshot.category, analyzedSnapshot.category)
        XCTAssertEqual(restoredSnapshot.status, analyzedSnapshot.status)
        XCTAssertEqual(restoredSnapshot.summaryRows.first(where: { $0.label == "Stage" })?.value, "Split analyzed")
        XCTAssertEqual(restoredSnapshot.summaryRows.first(where: { $0.label == "Analysis" })?.value, analyzedSnapshot.category)
        XCTAssertEqual(restoredSnapshot.primaryAction?.enabled, false)
    }

    private func assertPrimary(
        _ adapter: PrismetCasinoStudyLabAdapter,
        _ action: PrismetCasinoStudyLabAdapter.Action,
        _ title: String,
        requiresSeed: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(adapter.snapshot.primaryAction?.action, action, file: file, line: line)
        XCTAssertEqual(adapter.snapshot.primaryAction?.title, title, file: file, line: line)
        XCTAssertEqual(adapter.snapshot.primaryAction?.enabled, true, file: file, line: line)
        XCTAssertEqual(adapter.snapshot.primaryAction?.requiresSeed, requiresSeed, file: file, line: line)
    }

    private func assertError(
        _ expected: PrismetCasinoStudyLabAdapterError,
        _ body: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual(error as? PrismetCasinoStudyLabAdapterError, expected, file: file, line: line)
        }
    }

    private func firstCrapsPointSeed() throws -> UInt64 {
        for seed in 0...1_000 {
            var adapter = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab)
            try adapter.perform(.roll, seed: UInt64(seed))
            if adapter.phase == .point { return UInt64(seed) }
        }
        throw XCTSkip("No deterministic Craps point seed found")
    }

    private func firstWarTieSeed() throws -> UInt64 {
        for seed in 0...10_000 {
            var adapter = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice)
            try adapter.perform(.deal, seed: UInt64(seed))
            if adapter.phase == .warReady { return UInt64(seed) }
        }
        throw XCTSkip("No deterministic Casino War tie seed found")
    }

    private func firstAnalyzableDraft(for adapter: PrismetCasinoStudyLabAdapter) throws -> [Int] {
        for first in 0..<7 {
            for second in (first + 1)..<7 {
                var candidate = adapter
                guard (try? candidate.perform(.changePaiGowSplit(indices: [first, second]))) != nil else { continue }
                if (try? candidate.perform(.analyzeSplit)) != nil { return [first, second] }
            }
        }
        throw XCTSkip("No valid Pai Gow split found")
    }

    private func firstChangedAnalyzableDraft(for adapter: PrismetCasinoStudyLabAdapter, excluding selected: [Int]) throws -> [Int] {
        for first in 0..<7 {
            for second in (first + 1)..<7 where [first, second] != selected {
                var candidate = adapter
                if (try? candidate.perform(.changePaiGowSplit(indices: [first, second]))) != nil { return [first, second] }
            }
        }
        throw XCTSkip("No changed valid Pai Gow split found")
    }
    func testOnlyStudyLabIDsStartUnstartedAndOriginalElevenAreRejected() throws {
        let expected = Set(PrismetPracticeCasinoCatalog.all.filter { $0.kind == .studyLab }.map(\.id))
        XCTAssertEqual(expected.count, 10)
        XCTAssertEqual(Set(PrismetCasinoStudyLabAdapter.supportedGameIDs), expected)
        for id in expected {
            let adapter = try PrismetCasinoStudyLabAdapter(gameID: id)
            XCTAssertEqual(adapter.phase, .unstarted)
            XCTAssertNil(adapter.snapshot.audit.seed)
        }
        XCTAssertThrowsError(try PrismetCasinoStudyLabAdapter(gameID: .blackjack))
    }

    func testHoldemFullLifecycleAndDeterministicReplay() throws {
        let id: PrismetPracticeCasinoGameID = .texasHoldemLab
        var first = try PrismetCasinoStudyLabAdapter(gameID: id)
        XCTAssertThrowsError(try first.perform(.deal, seed: nil))
        try first.perform(.deal, seed: 42)
        try first.perform(.flop)
        try first.perform(.turn)
        try first.perform(.river)
        try first.perform(.complete)
        XCTAssertEqual(first.phase, .complete)
        XCTAssertEqual(first.snapshot.cards.count, 2)
        XCTAssertEqual(first.snapshot.cards[1].cards.count, 5)
        XCTAssertNotNil(first.snapshot.result)

        var second = try PrismetCasinoStudyLabAdapter(gameID: id)
        try second.perform(.deal, seed: 42)
        try second.perform(.flop)
        try second.perform(.turn)
        try second.perform(.river)
        try second.perform(.complete)
        XCTAssertEqual(first, second)
    }

    func testPaiGowRequiresExactlyTwoTogglesBeforeAnalyzeAndNewRoundDoesNotStart() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        try adapter.perform(.deal, seed: 7)
        XCTAssertThrowsError(try adapter.perform(.analyzeSplit))
        try adapter.perform(.togglePaiGowCard(index: 0))
        try adapter.perform(.togglePaiGowCard(index: 1))
        XCTAssertEqual(adapter.snapshot.selectedPaiGowCardIndices, [1, 2])
        try adapter.perform(.analyzeSplit)
        XCTAssertEqual(adapter.phase, .complete)
        try adapter.perform(.newRound)
        XCTAssertEqual(adapter.phase, .unstarted)
        XCTAssertNil(adapter.snapshot.audit.seed)
    }

    func testDiceAndWheelSnapshotsExposeOrderedValuesAndExactLedger() throws {
        var craps = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab)
        try craps.perform(.roll, seed: 12)
        XCTAssertEqual(craps.snapshot.dice?.values.count, 2)
        XCTAssertEqual(craps.snapshot.dice?.total, craps.snapshot.dice?.values.reduce(0, +))
        XCTAssertFalse(craps.snapshot.ledger.isEmpty)

        var sicBo = try PrismetCasinoStudyLabAdapter(gameID: .sicBoOutcomeLab)
        try sicBo.perform(.roll, seed: 12)
        XCTAssertEqual(sicBo.snapshot.dice?.values.count, 3)
        XCTAssertNotNil(sicBo.snapshot.dice?.pattern)

        var roulette = try PrismetCasinoStudyLabAdapter(gameID: .europeanRouletteLab)
        try roulette.perform(.spin, seed: 12)
        XCTAssertNotNil(roulette.snapshot.wheel?.pocket)
        XCTAssertNotNil(roulette.snapshot.wheel?.color)
    }

    func testEveryLabStartsFromAnExplicitSeedAndCompletesItsTypedLifecycle() throws {
        var three = try PrismetCasinoStudyLabAdapter(gameID: .threeCardPokerLab); try three.perform(.deal, seed: 1); try three.perform(.reveal); XCTAssertEqual(three.phase, .complete)
        var caribbean = try PrismetCasinoStudyLabAdapter(gameID: .caribbeanStudQualificationLab); try caribbean.perform(.deal, seed: 2); try caribbean.perform(.reveal); XCTAssertEqual(caribbean.phase, .complete)
        var omaha = try PrismetCasinoStudyLabAdapter(gameID: .omahaHandLab); try omaha.perform(.deal, seed: 3); try omaha.perform(.flop); try omaha.perform(.turn); try omaha.perform(.river); try omaha.perform(.complete); XCTAssertEqual(omaha.phase, .complete)
        var baccarat = try PrismetCasinoStudyLabAdapter(gameID: .miniBaccaratPractice); try baccarat.perform(.deal, seed: 4); while baccarat.phase != .complete { try baccarat.perform(.advance) }; XCTAssertEqual(baccarat.phase, .complete)
        var war = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice); try war.perform(.deal, seed: 5); if war.phase == .warReady { try war.perform(.reveal) }; XCTAssertEqual(war.phase, .complete)
        var craps = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab); for seed in 6...100 where craps.phase != .complete { try craps.perform(.roll, seed: UInt64(seed)) }; XCTAssertEqual(craps.phase, .complete)
        var sicBo = try PrismetCasinoStudyLabAdapter(gameID: .sicBoOutcomeLab); try sicBo.perform(.roll, seed: 7); XCTAssertEqual(sicBo.phase, .complete)
    }

    func testInvalidActionsAreImmutableAndLaterRevealsDoNotConsumeSeeds() throws {
        var holdem = try PrismetCasinoStudyLabAdapter(gameID: .texasHoldemLab)
        try holdem.perform(.deal, seed: 303)
        let before = holdem
        XCTAssertThrowsError(try holdem.perform(.reveal))
        XCTAssertEqual(holdem, before)
        XCTAssertThrowsError(try holdem.perform(.flop, seed: 404))
        try holdem.perform(.flop)
        XCTAssertEqual(holdem.snapshot.audit.seed, 303)

        var craps = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab)
        try craps.perform(.roll, seed: 101)
        if craps.phase == .point { try craps.perform(.roll, seed: 202) }
        XCTAssertTrue(craps.snapshot.audit.seed == 101 || craps.snapshot.audit.seed == 202)
    }

    // MARK: - Presentation contract

    func testEveryStudyLabLedgerUsesAnExplicitTypedValueAndSharedDisplayText() throws {
        let probabilities: Set<PrismetPracticeCasinoGameID> = [
            .threeCardPokerLab, .texasHoldemLab, .miniBaccaratPractice,
            .casinoWarPractice, .crapsPointLab, .sicBoOutcomeLab,
            .europeanRouletteLab,
        ]

        for gameID in PrismetCasinoStudyLabAdapter.supportedGameIDs {
            let ledger = try PrismetCasinoStudyLabAdapter(gameID: gameID).snapshot.ledger
            XCTAssertFalse(ledger.isEmpty, "\(gameID) must explicitly provide a ledger")
            if probabilities.contains(gameID) {
                XCTAssertTrue(ledger.allSatisfy { if case .probability = $0.value { return true }; return false }, "\(gameID) must use probability values")
            }
        }

        let caribbean = try PrismetCasinoStudyLabAdapter(gameID: .caribbeanStudQualificationLab).snapshot.ledger
        XCTAssertEqual(caribbean.map(\.value), [.count(PrismetCaribbeanStudLab.exactLabeledDealCount)])
        XCTAssertEqual(caribbean.first?.displayText, "\(PrismetCaribbeanStudLab.exactLabeledDealCount)")
        XCTAssertFalse(caribbean.first?.displayText.contains("/") ?? true)

        let paiGow = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab).snapshot.ledger
        XCTAssertTrue(paiGow.allSatisfy { if case .formula = $0.value { return true }; return false })

        let omaha = try PrismetCasinoStudyLabAdapter(gameID: .omahaHandLab).snapshot.ledger
        XCTAssertEqual(omaha.map(\.value), [.formula("C(4, 2) × C(5, 3) = \(PrismetOmahaHandLab.legalCandidateCount)")])
        XCTAssertEqual(omaha.first?.displayText, "C(4, 2) × C(5, 3) = \(PrismetOmahaHandLab.legalCandidateCount)")
        XCTAssertFalse(omaha.first?.displayText.contains("/") ?? true)

        let threeCard = try PrismetCasinoStudyLabAdapter(gameID: .threeCardPokerLab).snapshot.ledger
        XCTAssertEqual(threeCard.first?.displayText, "16440/22100")
    }

    func testPresentationLedgerContractsAreExactAndStable() throws {
        let three = try PrismetCasinoStudyLabAdapter(gameID: .threeCardPokerLab).snapshot.ledger
        XCTAssertEqual(three.map(\.label), ["High card", "One pair", "Flush", "Straight", "Three of a kind", "Straight flush"])
        XCTAssertEqual(three.map(\.numerator), [16_440, 3_744, 1_096, 720, 52, 48])
        XCTAssertTrue(three.allSatisfy { $0.denominator == 22_100 })

        let holdem = try PrismetCasinoStudyLabAdapter(gameID: .texasHoldemLab).snapshot.ledger
        XCTAssertEqual(holdem.map(\.label), ["High card", "One pair", "Two pair", "Three of a kind", "Straight", "Flush", "Full house", "Four of a kind", "Straight flush", "Royal flush"])
        XCTAssertEqual(holdem.map(\.numerator), [23_294_460, 58_627_800, 31_433_400, 6_461_620, 6_180_020, 4_047_644, 3_473_184, 224_848, 37_260, 4_324])
        XCTAssertTrue(holdem.allSatisfy { $0.denominator == 133_784_560 })

        let caribbean = try PrismetCasinoStudyLabAdapter(gameID: .caribbeanStudQualificationLab).snapshot.ledger
        XCTAssertEqual(caribbean, [.init(label: "Labeled five-card deals", value: .count(3_986_646_103_440))])

        let war = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice).snapshot.ledger
        XCTAssertEqual(war, [
            .init(label: "Learner higher", numerator: 10_376, denominator: 20_825),
            .init(label: "Reference higher", numerator: 10_376, denominator: 20_825),
            .init(label: "Tie", numerator: 73, denominator: 20_825),
        ])

        let craps = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab).snapshot.ledger
        XCTAssertEqual(craps.map(\.label), ["Natural", "Craps", "Point", "Point 4 before seven", "Point 5 before seven", "Point 6 before seven", "Point 8 before seven", "Point 9 before seven", "Point 10 before seven"])
        XCTAssertEqual(craps.map(\.numerator), [8, 4, 24, 3, 4, 5, 5, 4, 3])
        XCTAssertEqual(craps.map(\.denominator), [36, 36, 36, 9, 10, 11, 11, 10, 9])

        let sicBo = try PrismetCasinoStudyLabAdapter(gameID: .sicBoOutcomeLab).snapshot.ledger
        XCTAssertEqual(sicBo.map(\.label), (3...18).map { "Total \($0)" } + ["All distinct", "One pair", "Triple"])
        XCTAssertEqual(sicBo.map(\.numerator), [1, 3, 6, 10, 15, 21, 25, 27, 27, 25, 21, 15, 10, 6, 3, 1, 120, 90, 6])
        XCTAssertTrue(sicBo.allSatisfy { $0.denominator == 216 })
    }

    func testPresentationModelsAndRendererAccessibilityStayAligned() throws {
        let paiGow = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab).snapshot.ledger
        XCTAssertEqual(paiGow, [.init(label: "Seven-card deals", exactText: "C(53, 7) = 154143080; C(7, 2) = 21")])
        let omaha = try PrismetCasinoStudyLabAdapter(gameID: .omahaHandLab).snapshot.ledger
        XCTAssertEqual(omaha, [.init(label: "Legal Omaha candidates", numerator: 60, denominator: 60, exactText: "C(4, 2) × C(5, 3) = 60")])

        var three = try PrismetCasinoStudyLabAdapter(gameID: .threeCardPokerLab)
        try three.perform(.deal, seed: 8)
        XCTAssertNotNil(three.snapshot.category)
        XCTAssertNil(three.snapshot.referenceCategory)
        XCTAssertNil(three.snapshot.comparison)
        XCTAssertEqual(Array(three.snapshot.cards[1].accessibilityLabels.dropFirst()), Array(repeating: "Face-down card", count: 2))
        try three.perform(.reveal)
        XCTAssertNotNil(three.snapshot.category)
        XCTAssertNotNil(three.snapshot.referenceCategory)
        XCTAssertNotEqual(three.snapshot.category, three.snapshot.comparison)

        var paiGowRound = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        try paiGowRound.perform(.deal, seed: 1)
        let sevenCardGroup = try XCTUnwrap(paiGowRound.snapshot.cards.first)
        XCTAssertEqual(sevenCardGroup.cards.count, sevenCardGroup.accessibilityLabels.count)
        if let jokerIndex = sevenCardGroup.cards.firstIndex(of: .joker) {
            XCTAssertEqual(sevenCardGroup.accessibilityLabels[jokerIndex], "Joker")
        }

        var sicBo = try PrismetCasinoStudyLabAdapter(gameID: .sicBoOutcomeLab)
        try sicBo.perform(.roll, seed: 12)
        XCTAssertEqual(sicBo.snapshot.dice?.total, sicBo.snapshot.dice?.values.reduce(0, +))
        var roulette = try PrismetCasinoStudyLabAdapter(gameID: .europeanRouletteLab)
        try roulette.perform(.spin, seed: 12)
        XCTAssertEqual(roulette.snapshot.result, roulette.snapshot.wheel.map { "Pocket \($0.pocket)" })
    }

    // MARK: - Regression coverage outside the lifecycle and presentation slices

    func testEverySeededStudyLabReplaysItsInitialRandomStateExactly() throws {
        let cases: [(PrismetPracticeCasinoGameID, PrismetCasinoStudyLabAdapter.Action)] = [
            (.threeCardPokerLab, .deal), (.texasHoldemLab, .deal),
            (.caribbeanStudQualificationLab, .deal), (.paiGowSplitLab, .deal),
            (.omahaHandLab, .deal), (.miniBaccaratPractice, .deal),
            (.casinoWarPractice, .deal), (.crapsPointLab, .roll),
            (.sicBoOutcomeLab, .roll), (.europeanRouletteLab, .spin),
        ]

        for (offset, testCase) in cases.enumerated() {
            let seed = UInt64(9_000 + offset)
            var first = try PrismetCasinoStudyLabAdapter(gameID: testCase.0)
            var second = try PrismetCasinoStudyLabAdapter(gameID: testCase.0)
            try first.perform(testCase.1, seed: seed)
            try second.perform(testCase.1, seed: seed)
            XCTAssertEqual(first, second, "\(testCase.0.rawValue) did not replay from one seed")
            XCTAssertEqual(first.snapshot, second.snapshot, "\(testCase.0.rawValue) snapshot did not replay from one seed")
        }
    }

    func testCasinoWarTieSnapshotRedactsCardsUntilTheWarReveal() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice)
        try adapter.perform(.deal, seed: try firstWarTieSeed())
        XCTAssertEqual(adapter.phase, .warReady)
        XCTAssertTrue(adapter.snapshot.cards.flatMap(\.cards).contains(.hidden))
        XCTAssertTrue(adapter.snapshot.cards.flatMap(\.accessibilityLabels).contains("Face-down card"))

        try adapter.perform(.reveal)
        XCTAssertEqual(adapter.phase, .complete)
        XCTAssertEqual(adapter.snapshot.cards.flatMap(\.cards).filter { $0 == .hidden }.count, 6)
        XCTAssertEqual(adapter.snapshot.cards.flatMap(\.accessibilityLabels).filter { $0 == "Face-down card" }.count, 6)
    }

    func testCasinoWarTieAuditReusesTheOriginalDealSeedWithoutDrawingANewSeed() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice)
        try adapter.perform(.deal, seed: try firstWarTieSeed())
        try adapter.perform(.reveal)

        let auditSeeds = adapter.snapshot.audit.seeds
        XCTAssertEqual(auditSeeds.map(\.seedUsage), [.newSeed, .reusedOriginalDealSeed])
        XCTAssertEqual(auditSeeds.map(\.seed), [auditSeeds[0].seed, auditSeeds[0].seed])
        XCTAssertEqual(PrismetCasinoStudyLabAuditSeedUsage.newSeed.displayText, "A new seed is drawn.")
        XCTAssertEqual(PrismetCasinoStudyLabAuditSeedUsage.reusedOriginalDealSeed.displayText, "The original deal seed is reused; no new seed is drawn.")
    }

    func testPaiGowJokerFixtureSurfacesAnAccessibleJokerCard() throws {
        var matching: PrismetCasinoStudyLabAdapter?
        for seed in 0...2_000 {
            var candidate = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
            try candidate.perform(.deal, seed: UInt64(seed))
            if candidate.snapshot.cards.flatMap(\.cards).contains(.joker) {
                matching = candidate
                break
            }
        }
        let adapter = try XCTUnwrap(matching, "Expected a deterministic Pai Gow joker fixture")
        let cards = try XCTUnwrap(adapter.snapshot.cards.first)
        let jokerIndex = try XCTUnwrap(cards.cards.firstIndex(of: .joker))
        XCTAssertEqual(cards.accessibilityLabels[jokerIndex], "Joker")
    }

    func testEveryOpeningRandomActionRejectsNilSeedAndPreservesState() throws {
        let cases: [(PrismetPracticeCasinoGameID, PrismetCasinoStudyLabAdapter.Action)] = [
            (.threeCardPokerLab, .deal), (.texasHoldemLab, .deal),
            (.caribbeanStudQualificationLab, .deal), (.paiGowSplitLab, .deal),
            (.omahaHandLab, .deal), (.miniBaccaratPractice, .deal),
            (.casinoWarPractice, .deal), (.crapsPointLab, .roll),
            (.sicBoOutcomeLab, .roll), (.europeanRouletteLab, .spin),
        ]
        for testCase in cases {
            var adapter = try PrismetCasinoStudyLabAdapter(gameID: testCase.0)
            let before = adapter
            assertError(.missingSeed) { try adapter.perform(testCase.1) }
            XCTAssertEqual(adapter, before, "\(testCase.0.rawValue) changed after a missing seed")
        }
    }

    func testBaccaratAndRouletteLedgersKeepAllExactOrderedRows() throws {
        let baccarat = try PrismetCasinoStudyLabAdapter(gameID: .miniBaccaratPractice).snapshot.ledger
        XCTAssertEqual(baccarat, [
            .init(label: "Banker", numerator: 2_292_252_566_437_888, denominator: 4_998_398_275_503_360),
            .init(label: "Player", numerator: 2_230_518_282_592_256, denominator: 4_998_398_275_503_360),
            .init(label: "Tie", numerator: 475_627_426_473_216, denominator: 4_998_398_275_503_360),
        ])
        let roulette = try PrismetCasinoStudyLabAdapter(gameID: .europeanRouletteLab).snapshot.ledger
        XCTAssertEqual(roulette, [
            .init(label: "Red", numerator: 18, denominator: 37),
            .init(label: "Black", numerator: 18, denominator: 37),
            .init(label: "Zero", numerator: 1, denominator: 37),
        ])
    }

    func testBaccaratPresentationUsesExactStageTotalsAndOrderedSummaryRows() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .miniBaccaratPractice)
        try adapter.perform(.deal, seed: 1)

        XCTAssertEqual(adapter.snapshot.status, "Initial deal: Player \(adapter.snapshot.summaryRows[1].value), Banker \(adapter.snapshot.summaryRows[2].value)")
        XCTAssertEqual(adapter.snapshot.summaryRows.map(\.label), ["Stage", "Player total", "Banker total"])
        XCTAssertEqual(adapter.snapshot.summaryRows.first?.value, "Initial deal")

        while adapter.phase != .complete { try adapter.perform(.advance) }
        XCTAssertTrue(adapter.snapshot.status.hasPrefix("Resolved: "))
        XCTAssertEqual(adapter.snapshot.summaryRows.first?.value, "Resolved")
        XCTAssertEqual(adapter.snapshot.summaryRows.map(\.label), ["Stage", "Player total", "Banker total", "Outcome"])
    }

    func testBaccaratTableauStatusesNameTheCurrentRuleStage() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .miniBaccaratPractice)
        for seed in 0...200 {
            try adapter.perform(.deal, seed: UInt64(seed))
            try adapter.perform(.advance)
            if adapter.snapshot.status.hasPrefix("Player tableau: ") { break }
            try adapter.perform(.newRound)
        }
        XCTAssertTrue(adapter.snapshot.status.hasPrefix("Player tableau: "))
        XCTAssertEqual(adapter.snapshot.summaryRows.first?.value, "Player tableau")

        try adapter.perform(.advance)
        XCTAssertTrue(adapter.snapshot.status.hasPrefix("Banker tableau: "))
        XCTAssertEqual(adapter.snapshot.summaryRows.first?.value, "Banker tableau")
    }

    func testAuditSeedsPreserveEveryCrapsRollInOrderAndRollbackDoesNotAppend() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab)
        try adapter.perform(.roll, seed: try firstCrapsPointSeed())
        let firstSeeds = adapter.snapshot.audit.seeds
        XCTAssertEqual(firstSeeds.map(\.action), ["Roll"])
        XCTAssertEqual(firstSeeds.map(\.seed), [firstSeeds[0].seed])

        let before = adapter
        assertError(.missingSeed) { try adapter.perform(.roll) }
        XCTAssertEqual(adapter, before)
        XCTAssertEqual(adapter.snapshot.audit.seeds, firstSeeds)

        try adapter.perform(.roll, seed: 99)
        XCTAssertEqual(adapter.snapshot.audit.seeds.map(\.action), ["Roll", "Roll"])
        XCTAssertEqual(adapter.snapshot.audit.seeds.map(\.seed), [firstSeeds[0].seed, 99])
        XCTAssertEqual(adapter.snapshot.audit.seed, 99)
    }

    func testCasinoWarOmitsWarGroupsForAnOrdinaryResolvedRound() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice)
        for seed in 0...2_000 {
            try adapter.perform(.deal, seed: UInt64(seed))
            if adapter.phase == .complete { break }
            try adapter.perform(.newRound)
        }
        XCTAssertEqual(adapter.phase, .complete)
        XCTAssertEqual(adapter.snapshot.cards.map(\.title), ["Learner", "Reference"])
        XCTAssertEqual(adapter.snapshot.cards.map { $0.cards.count }, [1, 1])
    }

    func testEveryStartedGameReportsAStateDerivedHumanStatus() throws {
        let cases: [(PrismetPracticeCasinoGameID, PrismetCasinoStudyLabAdapter.Action)] = [
            (.threeCardPokerLab, .deal), (.texasHoldemLab, .deal),
            (.caribbeanStudQualificationLab, .deal), (.paiGowSplitLab, .deal),
            (.omahaHandLab, .deal), (.miniBaccaratPractice, .deal),
            (.casinoWarPractice, .deal), (.crapsPointLab, .roll),
            (.sicBoOutcomeLab, .roll), (.europeanRouletteLab, .spin),
        ]
        for (offset, testCase) in cases.enumerated() {
            var adapter = try PrismetCasinoStudyLabAdapter(gameID: testCase.0)
            try adapter.perform(testCase.1, seed: UInt64(4_000 + offset))
            XCTAssertNotEqual(adapter.snapshot.status, "Practice observation", "\(testCase.0.rawValue)")
            XCTAssertFalse(adapter.snapshot.status.isEmpty, "\(testCase.0.rawValue)")
        }
    }

    // MARK: - Independent-review regression coverage

    func testPaiGowFoulingDraftIsVisibleButDisabledWithActionableCopyAndTypedRollback() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        let foulingDraft = try firstFoulingPaiGowDraft(for: &adapter)

        for index in foulingDraft {
            try adapter.perform(.togglePaiGowCard(index: index))
        }
        XCTAssertEqual(adapter.snapshot.selectedPaiGowCardIndices, foulingDraft.map { $0 + 1 })
        XCTAssertEqual(adapter.snapshot.primaryAction?.action, .analyzeSplit)
        XCTAssertEqual(adapter.snapshot.primaryAction?.enabled, false)
        XCTAssertEqual(adapter.snapshot.status, "Selected pair fouls the split; choose another pair")

        let beforeRejectedChange = adapter
        assertError(.invalidPaiGowSelection) { try adapter.perform(.changePaiGowSplit(indices: foulingDraft)) }
        XCTAssertEqual(adapter, beforeRejectedChange)

        let validDraft = try firstAnalyzableDraft(for: adapter)
        try adapter.perform(.changePaiGowSplit(indices: validDraft))
        assertPrimary(adapter, .analyzeSplit, "Analyze Split", requiresSeed: false)
    }

    func testPaiGowSelectedCardSummaryUsesOneBasedPositionsWhileActionsStayZeroBased() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
        try adapter.perform(.deal, seed: 7)
        let validDraft = try firstAnalyzableDraft(for: adapter)

        try adapter.perform(.changePaiGowSplit(indices: validDraft))
        XCTAssertEqual(adapter.snapshot.selectedPaiGowCardIndices, validDraft.map { $0 + 1 })
        XCTAssertEqual(
            adapter.snapshot.summaryRows.first(where: { $0.label == "Selected positions" })?.value,
            validDraft.map { String($0 + 1) }.joined(separator: ", ")
        )
        guard case .paiGow(_, let internalDraft) = adapter.state else {
            return XCTFail("Expected a Pai Gow adapter state")
        }
        XCTAssertEqual(internalDraft, validDraft)
    }

    func testBaccaratExposesInitialPlayerAndBankerTableauAsDistinctSnapshotPhases() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .miniBaccaratPractice)
        let seed = try firstBaccaratPlayerThenBankerTableauSeed()

        try adapter.perform(.deal, seed: seed)
        XCTAssertEqual(adapter.phase.rawValue, "initialDeal")
        try adapter.perform(.advance)
        XCTAssertEqual(adapter.phase.rawValue, "playerTableau")
        try adapter.perform(.advance)
        XCTAssertEqual(adapter.phase.rawValue, "bankerTableau")
    }

    func testOrdinaryCasinoWarReportsComparisonResolutionRatherThanWar() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice)
        try adapter.perform(.deal, seed: try firstOrdinaryWarSeed())

        XCTAssertEqual(adapter.phase, .complete)
        let result = adapter.snapshot.result ?? "pending"
        XCTAssertEqual(adapter.snapshot.status, "Comparison resolved: \(result)")
        XCTAssertFalse(adapter.snapshot.status.localizedCaseInsensitiveContains("war"))
    }

    func testCrapsDistinguishesNewlyEstablishedPointFromPointContinuation() throws {
        var adapter = try PrismetCasinoStudyLabAdapter(gameID: .crapsPointLab)
        try adapter.perform(.roll, seed: try firstCrapsPointSeed())
        let point = try XCTUnwrap(adapter.snapshot.summaryRows.first?.value.split(separator: " ").last.map(String.init))
        XCTAssertEqual(adapter.snapshot.status, "Point \(point) established; roll again")

        try adapter.perform(.roll, seed: try firstCrapsContinuationSeed(after: adapter))
        XCTAssertEqual(adapter.phase, .point)
        XCTAssertEqual(adapter.snapshot.status, "Point \(point) continues; roll again")
    }

    private func firstFoulingPaiGowDraft(for adapter: inout PrismetCasinoStudyLabAdapter) throws -> [Int] {
        for seed in 0...1_000 {
            var candidate = try PrismetCasinoStudyLabAdapter(gameID: .paiGowSplitLab)
            try candidate.perform(.deal, seed: UInt64(seed))
            guard case .paiGow(let dealt, _) = candidate.state else { continue }
            for first in 0..<7 {
                for second in (first + 1)..<7 {
                    let draft = [first, second]
                    if (try? PrismetPaiGowSplitLab.analyze(cards: dealt.cards, lowCardIndices: draft)) == nil {
                        adapter = candidate
                        return draft
                    }
                }
            }
        }
        throw XCTSkip("No deterministic fouling Pai Gow draft found")
    }

    private func firstBaccaratPlayerThenBankerTableauSeed() throws -> UInt64 {
        for seed in 0...1_000 {
            var adapter = try PrismetCasinoStudyLabAdapter(gameID: .miniBaccaratPractice)
            try adapter.perform(.deal, seed: UInt64(seed))
            try adapter.perform(.advance)
            guard case .baccarat(let playerTableau) = adapter.state,
                  playerTableau.phase == .playerTableau else { continue }
            try adapter.perform(.advance)
            guard case .baccarat(let bankerTableau) = adapter.state,
                  bankerTableau.phase == .bankerTableau else { continue }
            return UInt64(seed)
        }
        throw XCTSkip("No deterministic Baccarat player/banker tableau sequence found")
    }

    private func firstOrdinaryWarSeed() throws -> UInt64 {
        for seed in 0...1_000 {
            var adapter = try PrismetCasinoStudyLabAdapter(gameID: .casinoWarPractice)
            try adapter.perform(.deal, seed: UInt64(seed))
            if adapter.phase == .complete { return UInt64(seed) }
        }
        throw XCTSkip("No deterministic ordinary Casino War round found")
    }

    private func firstCrapsContinuationSeed(after adapter: PrismetCasinoStudyLabAdapter) throws -> UInt64 {
        for seed in 0...1_000 {
            var candidate = adapter
            try candidate.perform(.roll, seed: UInt64(seed))
            guard case .craps(let state) = candidate.state,
                  state.phase == .point,
                  state.resolution == .pointContinues else { continue }
            return UInt64(seed)
        }
        throw XCTSkip("No deterministic Craps point-continuation roll found")
    }

    func testAdapterSourceContainsNoForceUnwrapOrProcessTerminatingConstruct() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/PrismetShared/PrismetCasinoStudyLabAdapter.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        for forbidden in ["fatalError(", "precondition("] {
            XCTAssertFalse(source.contains(forbidden), "Adapter must not contain \(forbidden)")
        }
        XCTAssertNil(source.range(of: #"\b[A-Za-z_][A-Za-z0-9_]*!"#, options: .regularExpression), "Adapter must not force unwrap")
    }
}
