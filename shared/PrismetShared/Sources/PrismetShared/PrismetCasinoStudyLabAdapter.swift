import Foundation

public enum PrismetCasinoStudyLabAdapterError: Error, Equatable, Sendable {
    case unsupportedGame(PrismetPracticeCasinoGameID)
    case missingSeed
    case unexpectedSeed
    case invalidAction(PrismetCasinoStudyLabAdapter.Action)
    case invalidPaiGowSelection
    case engineRejected
}

public enum PrismetCasinoStudyLabCard: Equatable, Hashable, Sendable {
    case standard(PrismetPlayingCard)
    case hidden
    case joker
}

public struct PrismetCasinoStudyLabCardGroup: Equatable, Hashable, Sendable {
    public let title: String
    public let cards: [PrismetCasinoStudyLabCard]
    public let accessibilityLabels: [String]

    public init(title: String, cards: [PrismetCasinoStudyLabCard], accessibilityLabels: [String]) {
        self.title = title
        self.cards = cards
        self.accessibilityLabels = accessibilityLabels
    }
}

public struct PrismetCasinoStudyLabDiceSnapshot: Equatable, Hashable, Sendable {
    public let values: [Int]
    public let total: Int
    public let pattern: String?
}

public struct PrismetCasinoStudyLabWheelSnapshot: Equatable, Hashable, Sendable {
    public let pocket: Int
    public let color: String
}

public enum PrismetCasinoStudyLabLedgerValue: Equatable, Hashable, Sendable {
    case probability(numerator: Int, denominator: Int)
    case count(Int)
    case formula(String)

    /// The sole display formatter for Study Lab exact values.
    public var displayText: String {
        switch self {
        case .probability(let numerator, let denominator): return "\(numerator)/\(denominator)"
        case .count(let count): return "\(count)"
        case .formula(let formula): return formula
        }
    }
}

public struct PrismetCasinoStudyLabLedgerRow: Equatable, Hashable, Sendable {
    public let label: String
    public let value: PrismetCasinoStudyLabLedgerValue

    public init(label: String, value: PrismetCasinoStudyLabLedgerValue) {
        self.label = label
        self.value = value
    }

    /// Compatibility accessors for existing consumers; new rendering must use `displayText`.
    public var numerator: Int? {
        guard case .probability(let numerator, _) = value else { return nil }
        return numerator
    }

    public var denominator: Int? {
        guard case .probability(_, let denominator) = value else { return nil }
        return denominator
    }

    public var exactText: String? {
        switch value {
        case .probability: return nil
        case .count, .formula: return displayText
        }
    }

    public var displayText: String { value.displayText }

    public init(label: String, numerator: Int? = nil, denominator: Int? = nil, exactText: String? = nil) {
        self.label = label
        if let exactText {
            self.value = .formula(exactText)
        } else if let numerator, let denominator {
            self.value = .probability(numerator: numerator, denominator: denominator)
        } else {
            self.value = .formula("")
        }
    }
}

public struct PrismetCasinoStudyLabSummaryRow: Equatable, Hashable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public enum PrismetCasinoStudyLabAuditSeedUsage: Equatable, Hashable, Sendable {
    case newSeed
    case reusedOriginalDealSeed

    public var displayText: String {
        switch self {
        case .newSeed:
            return "A new seed is drawn."
        case .reusedOriginalDealSeed:
            return "The original deal seed is reused; no new seed is drawn."
        }
    }
}

public struct PrismetCasinoStudyLabAuditSeed: Equatable, Hashable, Sendable {
    public let sequence: Int
    public let action: String
    public let seed: UInt64
    public let seedUsage: PrismetCasinoStudyLabAuditSeedUsage

    public init(sequence: Int, action: String, seed: UInt64, seedUsage: PrismetCasinoStudyLabAuditSeedUsage = .newSeed) {
        self.sequence = sequence
        self.action = action
        self.seed = seed
        self.seedUsage = seedUsage
    }
}

public struct PrismetCasinoStudyLabAudit: Equatable, Hashable, Sendable {
    public let seed: UInt64?
    public let rulesVersion: Int?
    public let randomizerVersion: Int?
    public let seeds: [PrismetCasinoStudyLabAuditSeed]

    public init(seed: UInt64?, rulesVersion: Int?, randomizerVersion: Int?, seeds: [PrismetCasinoStudyLabAuditSeed] = []) {
        self.seed = seed
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.seeds = seeds
    }
}

public struct PrismetCasinoStudyLabSnapshot: Equatable, Hashable, Sendable {
    public let phase: PrismetCasinoStudyLabAdapter.Phase
    public let title: String
    public let status: String
    public let primaryAction: PrismetCasinoStudyLabPrimaryAction?
    public let primaryControlTitle: String
    public let primaryControlEnabled: Bool
    public let primaryControlRequiresSeed: Bool
    public let secondaryNewRoundTitle: String?
    public let cards: [PrismetCasinoStudyLabCardGroup]
    public let dice: PrismetCasinoStudyLabDiceSnapshot?
    public let wheel: PrismetCasinoStudyLabWheelSnapshot?
    public let ledger: [PrismetCasinoStudyLabLedgerRow]
    public let summaryRows: [PrismetCasinoStudyLabSummaryRow]
    public let audit: PrismetCasinoStudyLabAudit
    public let result: String?
    public let comparison: String?
    public let category: String?
    public let referenceCategory: String?
    /// Display positions for the selected cards (one-based); action indices remain zero-based.
    public let selectedPaiGowCardIndices: [Int]
}

public struct PrismetCasinoStudyLabPrimaryAction: Equatable, Hashable, Sendable {
    public let action: PrismetCasinoStudyLabAdapter.Action
    public let title: String
    public let enabled: Bool
    public let requiresSeed: Bool

    public init(action: PrismetCasinoStudyLabAdapter.Action, title: String, enabled: Bool = true, requiresSeed: Bool) {
        self.action = action
        self.title = title
        self.enabled = enabled
        self.requiresSeed = requiresSeed
    }
}

public struct PrismetCasinoStudyLabAdapter: Equatable, Sendable {
    public enum Phase: String, Equatable, Hashable, Sendable {
        case unstarted, ready, dealt, revealReady, flop, turn, river, tableau, initialDeal, playerTableau, bankerTableau, point, warReady, complete
    }

    public enum Action: Equatable, Hashable, Sendable {
        case deal, reveal, flop, turn, river, complete, analyzeSplit, advance, roll, spin, newRound
        case togglePaiGowCard(index: Int)
        case changePaiGowSplit(indices: [Int])
    }

    public enum EngineState: Equatable, Sendable {
        case unstarted
        case threeCard(PrismetThreeCardPokerLabState)
        case holdem(PrismetHoldemHandLabState)
        case caribbean(PrismetCaribbeanStudLabState)
        case paiGow(PrismetPaiGowSplitLabState, draftLowCardIndices: [Int])
        case omaha(PrismetOmahaHandLabState)
        case baccarat(PrismetMiniBaccaratLabState)
        case casinoWar(PrismetCasinoWarLabState)
        case craps(PrismetCrapsPointLabState)
        case sicBo(PrismetSicBoOutcomeLabState)
        case roulette(PrismetEuropeanRouletteLabState)
    }

    public let gameID: PrismetPracticeCasinoGameID
    public private(set) var state: EngineState

    public static let supportedGameIDs: [PrismetPracticeCasinoGameID] = [
        .threeCardPokerLab, .texasHoldemLab, .caribbeanStudQualificationLab, .paiGowSplitLab,
        .omahaHandLab, .miniBaccaratPractice, .casinoWarPractice, .crapsPointLab,
        .sicBoOutcomeLab, .europeanRouletteLab
    ]

    public init(gameID: PrismetPracticeCasinoGameID) throws {
        guard Self.supportedGameIDs.contains(gameID) else { throw PrismetCasinoStudyLabAdapterError.unsupportedGame(gameID) }
        self.gameID = gameID
        self.state = .unstarted
    }

    public var phase: Phase {
        switch state {
        case .unstarted: return .unstarted
        case .threeCard(let s): return s.phase == .dealt ? .dealt : .complete
        case .holdem(let s): return Self.holdemPhase(s.phase)
        case .caribbean(let s): return s.phase == .dealt ? .dealt : .complete
        case .paiGow(let s, _): return s.phase == .dealt ? .dealt : .complete
        case .omaha(let s): return Self.omahaPhase(s.phase)
        case .baccarat(let s):
            switch s.phase {
            case .ready: return .ready
            case .initialDeal: return .initialDeal
            case .playerTableau: return .playerTableau
            case .bankerTableau: return .bankerTableau
            case .complete: return .complete
            }
        case .casinoWar(let s): return s.phase == .warReady ? .warReady : (s.phase == .complete ? .complete : .dealt)
        case .craps(let s): return s.phase == .ready ? .ready : (s.phase == .point ? .point : .complete)
        case .sicBo(let s): return s.phase == .ready ? .ready : .complete
        case .roulette(let s): return s.phase == .ready ? .ready : .complete
        }
    }

    public var snapshot: PrismetCasinoStudyLabSnapshot { makeSnapshot() }

    public mutating func perform(_ action: Action, seed: UInt64? = nil) throws {
        let old = state
        do {
            if action == .newRound {
                guard seed == nil else { throw PrismetCasinoStudyLabAdapterError.unexpectedSeed }
                state = .unstarted
                return
            }

            if case .togglePaiGowCard = action {
                guard seed == nil else { throw PrismetCasinoStudyLabAdapterError.unexpectedSeed }
                try performPaiGowToggle(action)
                return
            }
            if case .changePaiGowSplit = action {
                guard seed == nil else { throw PrismetCasinoStudyLabAdapterError.unexpectedSeed }
                try performPaiGowSplitChange(action)
                return
            }

            guard let primary = primaryAction, primary.action == action, primary.enabled else {
                throw invalid(action)
            }
            if primary.requiresSeed {
                guard seed != nil else { throw PrismetCasinoStudyLabAdapterError.missingSeed }
            } else {
                guard seed == nil else { throw PrismetCasinoStudyLabAdapterError.unexpectedSeed }
            }
            switch (gameID, action) {
            case (.threeCardPokerLab, .deal): state = .threeCard(try PrismetThreeCardPokerLab.deal(seed: requiredSeed(seed)))
            case (.threeCardPokerLab, .reveal): if case .threeCard(let s) = state, s.phase == .dealt { state = .threeCard(try PrismetThreeCardPokerLab.revealComparison(in: s)) } else { throw invalid(action) }
            case (.texasHoldemLab, .deal): state = .holdem(try PrismetHoldemHandLabEngine.deal(seed: requiredSeed(seed)))
            case (.texasHoldemLab, .flop): if case .holdem(let s) = state, s.phase == .holeCards { state = .holdem(try PrismetHoldemHandLabEngine.revealFlop(in: s)) } else { throw invalid(action) }
            case (.texasHoldemLab, .turn): if case .holdem(let s) = state, s.phase == .flop { state = .holdem(try PrismetHoldemHandLabEngine.revealTurn(in: s)) } else { throw invalid(action) }
            case (.texasHoldemLab, .river): if case .holdem(let s) = state, s.phase == .turn { state = .holdem(try PrismetHoldemHandLabEngine.revealRiver(in: s)) } else { throw invalid(action) }
            case (.texasHoldemLab, .complete): if case .holdem(let s) = state, s.phase == .river { state = .holdem(try PrismetHoldemHandLabEngine.complete(s)) } else { throw invalid(action) }
            case (.caribbeanStudQualificationLab, .deal): state = .caribbean(try PrismetCaribbeanStudLab.deal(seed: requiredSeed(seed)))
            case (.caribbeanStudQualificationLab, .reveal): if case .caribbean(let s) = state, s.phase == .dealt { state = .caribbean(try PrismetCaribbeanStudLab.revealComparison(in: s)) } else { throw invalid(action) }
            case (.paiGowSplitLab, .deal): state = .paiGow(try PrismetPaiGowSplitLab.dealSeven(seed: requiredSeed(seed)), draftLowCardIndices: [])
            case (.paiGowSplitLab, .analyzeSplit):
                guard case .paiGow(let s, let draft) = state,
                      s.phase == .dealt,
                      isLegalPaiGowDraft(draft, in: s) else { throw PrismetCasinoStudyLabAdapterError.invalidPaiGowSelection }
                state = .paiGow(try PrismetPaiGowSplitLab.selectLowCards(at: draft, in: s), draftLowCardIndices: draft)
            case (.omahaHandLab, .deal): state = .omaha(try PrismetOmahaHandLab.dealFour(seed: requiredSeed(seed)))
            case (.omahaHandLab, .flop): if case .omaha(let s) = state, s.phase == .holeCards { state = .omaha(try PrismetOmahaHandLab.revealFlop(in: s)) } else { throw invalid(action) }
            case (.omahaHandLab, .turn): if case .omaha(let s) = state, s.phase == .flop { state = .omaha(try PrismetOmahaHandLab.revealTurn(in: s)) } else { throw invalid(action) }
            case (.omahaHandLab, .river): if case .omaha(let s) = state, s.phase == .turn { state = .omaha(try PrismetOmahaHandLab.revealRiver(in: s)) } else { throw invalid(action) }
            case (.omahaHandLab, .complete): if case .omaha(let s) = state, s.phase == .river { state = .omaha(try PrismetOmahaHandLab.classify(s)) } else { throw invalid(action) }
            case (.miniBaccaratPractice, .deal): state = .baccarat(try PrismetMiniBaccaratLabEngine.deal(seed: requiredSeed(seed)))
            case (.miniBaccaratPractice, .advance): if case .baccarat(let s) = state, s.phase != .ready, s.phase != .complete { state = .baccarat(try PrismetMiniBaccaratLabEngine.advance(s)) } else { throw invalid(action) }
            case (.casinoWarPractice, .deal): state = .casinoWar(try PrismetCasinoWarLab.deal(seed: requiredSeed(seed)))
            case (.casinoWarPractice, .reveal): if case .casinoWar(let s) = state, s.phase == .warReady { state = .casinoWar(try PrismetCasinoWarLab.revealWar(in: s)) } else { throw invalid(action) }
            case (.crapsPointLab, .roll): if case .craps(let s) = state, s.phase == .point { state = .craps(try PrismetCrapsPointLabEngine.roll(seed: requiredSeed(seed), in: s)) } else if case .unstarted = state { state = .craps(try PrismetCrapsPointLabEngine.roll(seed: requiredSeed(seed), in: .ready)) } else { throw invalid(action) }
            case (.sicBoOutcomeLab, .roll): if case .unstarted = state { state = .sicBo(try PrismetSicBoOutcomeLab.roll(.ready, seed: requiredSeed(seed))) } else { throw invalid(action) }
            case (.europeanRouletteLab, .spin): if case .unstarted = state { state = .roulette(try PrismetEuropeanRouletteLab.spin(seed: requiredSeed(seed))) } else { throw invalid(action) }
            default: throw invalid(action)
            }
        } catch let error as PrismetCasinoStudyLabAdapterError { state = old; throw error }
        catch { state = old; throw PrismetCasinoStudyLabAdapterError.engineRejected }
    }

    private func invalid(_ action: Action) -> PrismetCasinoStudyLabAdapterError { .invalidAction(action) }

    private func requiredSeed(_ seed: UInt64?) throws -> UInt64 {
        guard let seed else { throw PrismetCasinoStudyLabAdapterError.missingSeed }
        return seed
    }

    private func isValidPaiGowDraft(_ indices: [Int]) -> Bool {
        indices.count == 2 && Set(indices).count == 2 && indices.allSatisfy { (0..<7).contains($0) }
    }

    private func isLegalPaiGowDraft(_ indices: [Int], in state: PrismetPaiGowSplitLabState) -> Bool {
        guard isValidPaiGowDraft(indices) else { return false }
        return (try? PrismetPaiGowSplitLab.analyze(cards: state.cards, lowCardIndices: indices)) != nil
    }

    private mutating func performPaiGowToggle(_ action: Action) throws {
        guard case .togglePaiGowCard(let index) = action,
              case .paiGow(let state, var draft) = self.state,
              (0..<7).contains(index) else { throw PrismetCasinoStudyLabAdapterError.invalidPaiGowSelection }
        if draft.contains(index) {
            draft.removeAll { $0 == index }
        } else if draft.count < 2 {
            draft.append(index)
            draft.sort()
        } else {
            throw PrismetCasinoStudyLabAdapterError.invalidPaiGowSelection
        }
        self.state = .paiGow(state, draftLowCardIndices: draft)
    }

    private mutating func performPaiGowSplitChange(_ action: Action) throws {
        guard case .changePaiGowSplit(let indices) = action,
              isValidPaiGowDraft(indices),
              case .paiGow(let state, _) = self.state,
              isLegalPaiGowDraft(indices, in: state) else { throw PrismetCasinoStudyLabAdapterError.invalidPaiGowSelection }
        let sorted = indices.sorted()
        switch state.phase {
        case .dealt:
            self.state = .paiGow(state, draftLowCardIndices: sorted)
        case .splitSelected:
            guard state.lowCardIndices != sorted else { throw PrismetCasinoStudyLabAdapterError.invalidPaiGowSelection }
            self.state = .paiGow(try PrismetPaiGowSplitLab.changingSplit(to: sorted, in: state), draftLowCardIndices: sorted)
        }
    }

    private var primaryAction: PrismetCasinoStudyLabPrimaryAction? {
        func make(_ action: Action, _ title: String, requiresSeed: Bool = false, enabled: Bool = true) -> PrismetCasinoStudyLabPrimaryAction {
            .init(action: action, title: title, enabled: enabled, requiresSeed: requiresSeed)
        }
        switch state {
        case .unstarted:
            switch gameID {
            case .crapsPointLab, .sicBoOutcomeLab: return make(.roll, "Roll", requiresSeed: true)
            case .europeanRouletteLab: return make(.spin, "Spin", requiresSeed: true)
            default: return make(.deal, "Deal", requiresSeed: true)
            }
        case .threeCard(let state): return state.phase == .dealt ? make(.reveal, "Reveal") : nil
        case .holdem(let state):
            switch state.phase {
            case .holeCards: return make(.flop, "Show Flop")
            case .flop: return make(.turn, "Show Turn")
            case .turn: return make(.river, "Show River")
            case .river: return make(.complete, "Classify")
            case .ready, .complete: return nil
            }
        case .caribbean(let state): return state.phase == .dealt ? make(.reveal, "Reveal") : nil
        case .paiGow(let state, let draft):
            switch state.phase {
            case .dealt: return make(.analyzeSplit, "Analyze Split", enabled: isLegalPaiGowDraft(draft, in: state))
            case .splitSelected: return make(.changePaiGowSplit(indices: draft), "Update Split", enabled: isLegalPaiGowDraft(draft, in: state) && state.lowCardIndices != draft)
            }
        case .omaha(let state):
            switch state.phase {
            case .holeCards: return make(.flop, "Show Flop")
            case .flop: return make(.turn, "Show Turn")
            case .turn: return make(.river, "Show River")
            case .river: return make(.complete, "Classify")
            case .complete: return nil
            }
        case .baccarat(let state): return state.phase == .ready || state.phase == .complete ? nil : make(.advance, "Advance")
        case .casinoWar(let state): return state.phase == .warReady ? make(.reveal, "Reveal") : nil
        case .craps(let state): return state.phase == .point ? make(.roll, "Roll", requiresSeed: true) : nil
        case .sicBo, .roulette: return nil
        }
    }

    private static func holdemPhase(_ phase: PrismetHoldemHandLabPhase) -> Phase { switch phase { case .ready: .ready; case .holeCards: .dealt; case .flop: .flop; case .turn: .turn; case .river: .river; case .complete: .complete } }
    private static func omahaPhase(_ phase: PrismetOmahaHandLabPhase) -> Phase { switch phase { case .holeCards: .dealt; case .flop: .flop; case .turn: .turn; case .river: .river; case .complete: .complete } }

    private func makeSnapshot() -> PrismetCasinoStudyLabSnapshot {
        let descriptor = PrismetPracticeCasinoCatalog[gameID]
        var cards: [PrismetCasinoStudyLabCardGroup] = []
        var dice: PrismetCasinoStudyLabDiceSnapshot?
        var wheel: PrismetCasinoStudyLabWheelSnapshot?
        var audit = PrismetCasinoStudyLabAudit(seed: nil, rulesVersion: nil, randomizerVersion: nil)
        var result: String?
        var comparison: String?
        var category: String?
        var referenceCategory: String?
        var selectedPaiGowCardIndices: [Int] = []
        var summaryRows: [PrismetCasinoStudyLabSummaryRow] = []
        var status: String
        func group(_ title: String, _ values: [PrismetCasinoStudyLabCard]) { cards.append(.init(title: title, cards: values, accessibilityLabels: values.map { cardLabel($0) })) }
        switch state {
        case .unstarted:
            status = "Ready to \(openingActionTitle(for: gameID))"
            summaryRows = [.init(label: "Stage", value: "Ready")]
        case .threeCard(let s):
            audit = .init(seed: s.seed, rulesVersion: s.rulesVersion, randomizerVersion: s.randomizerVersion, seeds: auditSeeds(seed: s.seed, action: "Deal", seedUsage: .newSeed))
            group("Learner", s.learnerCards.map { .standard($0) })
            group("Reference", s.referenceCards.map { $0.card.map(PrismetCasinoStudyLabCard.standard) ?? .hidden })
            comparison = s.comparison.map(presentationLabel)
            category = (try? PrismetThreeCardPokerHandValue(cards: s.learnerCards)).map { presentationLabel($0.category) }
            let revealedReferenceCards = s.referenceCards.compactMap(\.card)
            if s.phase == .revealed, revealedReferenceCards.count == 3 {
                referenceCategory = (try? PrismetThreeCardPokerHandValue(cards: revealedReferenceCards)).map { presentationLabel($0.category) }
            }
            status = s.phase == .dealt ? "Three-card hands dealt; reveal the reference hand" : "Comparison resolved: \(comparison ?? "tie")"
            summaryRows = [.init(label: "Stage", value: s.phase == .dealt ? "Hands dealt" : "Comparison resolved"), .init(label: "Learner category", value: category ?? "Pending"), .init(label: "Reference category", value: referenceCategory ?? "Hidden")]
        case .holdem(let s):
            audit = .init(seed: s.seed, rulesVersion: s.rulesVersion, randomizerVersion: s.randomizerVersion, seeds: auditSeeds(seed: s.seed, action: "Deal", seedUsage: .newSeed))
            group("Hole cards", s.holeCards.map { .standard($0) }); group("Community", s.communityCards.map { .standard($0) }); category = s.bestCategory.map(presentationLabel); result = category
            let stage = holdemStage(s.phase)
            status = "Hold'em \(stage.lowercased())"
            summaryRows = [.init(label: "Stage", value: stage), .init(label: "Community cards", value: "\(s.communityCards.count)"), .init(label: "Best category", value: category ?? "Pending")]
        case .caribbean(let s):
            audit = .init(seed: s.seed, rulesVersion: s.rulesVersion, randomizerVersion: s.randomizerVersion, seeds: auditSeeds(seed: s.seed, action: "Deal", seedUsage: .newSeed))
            group("Learner", s.learnerCards.map { .standard($0) }); group("Reference", s.referenceCards.map { $0.card.map(PrismetCasinoStudyLabCard.standard) ?? .hidden }); comparison = s.comparison.map(presentationLabel); category = s.referenceQualification.map(presentationLabel)
            status = s.phase == .dealt ? "Learner hand dealt; reveal the reference hand" : "Qualification resolved: \(category ?? "unavailable")"
            summaryRows = [.init(label: "Stage", value: s.phase == .dealt ? "Reference hidden" : "Qualification resolved"), .init(label: "Reference qualification", value: category ?? "Pending"), .init(label: "Comparison", value: comparison ?? "Pending")]
        case .paiGow(let s, let draft):
            audit = .init(seed: s.seed, rulesVersion: s.rulesVersion, randomizerVersion: s.randomizerVersion, seeds: auditSeeds(seed: s.seed, action: "Deal", seedUsage: .newSeed)); selectedPaiGowCardIndices = draft.map { $0 + 1 }
            group("Seven-card deal", s.cards.map { card in
                switch card { case .joker: return .joker; case .standard(let value): return .standard(value) }
            })
            let analysisIsCurrent = paiGowAnalysisIsCurrent(state: s, draft: draft)
            category = analysisIsCurrent ? s.analysis.map { "Low \(presentationLabel($0.lowHand.category)), high \(presentationLabel($0.highHand.category))" } : nil
            status = paiGowStatus(state: s, draft: draft)
            let stage = analysisIsCurrent ? "Split analyzed" : s.phase == .dealt ? "Select low hand" : "Reanalysis pending"
            let analysisSummary = analysisIsCurrent ? category ?? "Unavailable" : s.phase == .dealt ? "Pending" : "Pending reanalysis"
            summaryRows = [.init(label: "Stage", value: stage), .init(label: "Selected positions", value: selectedPaiGowCardIndices.map(String.init).joined(separator: ", ").isEmpty ? "None" : selectedPaiGowCardIndices.map(String.init).joined(separator: ", ")), .init(label: "Analysis", value: analysisSummary)]
        case .omaha(let s):
            audit = .init(seed: s.seed, rulesVersion: s.rulesVersion, randomizerVersion: s.randomizerVersion, seeds: auditSeeds(seed: s.seed, action: "Deal", seedUsage: .newSeed)); group("Hole cards", s.holeCards.map { .standard($0) }); group("Board", s.visibleBoard.map { .standard($0) }); category = s.classification.map { presentationLabel($0.category) }
            let stage = omahaStage(s.phase)
            status = "Omaha \(stage.lowercased())"
            summaryRows = [.init(label: "Stage", value: stage), .init(label: "Board cards", value: "\(s.visibleBoard.count)"), .init(label: "Best category", value: category ?? "Pending")]
        case .baccarat(let s):
            audit = .init(seed: s.seed, rulesVersion: s.rulesVersion, randomizerVersion: s.randomizerVersion, seeds: auditSeeds(seed: s.seed, action: "Deal", seedUsage: .newSeed)); group("Player", s.playerCards.map { .standard($0.card) }); group("Banker", s.bankerCards.map { .standard($0.card) }); result = s.outcome.map(presentationLabel)
            let stage = baccaratStage(s.phase)
            status = s.phase == .complete ? "Resolved: \(result ?? "pending") — Player \(s.playerTotal), Banker \(s.bankerTotal)" : "\(stage): Player \(s.playerTotal), Banker \(s.bankerTotal)"
            summaryRows = [.init(label: "Stage", value: s.phase == .complete ? "Resolved" : stage), .init(label: "Player total", value: "\(s.playerTotal)"), .init(label: "Banker total", value: "\(s.bankerTotal)")] + (result.map { [.init(label: "Outcome", value: $0)] } ?? [])
        case .casinoWar(let s):
            audit = .init(seed: s.seed, rulesVersion: s.rulesVersion, randomizerVersion: s.randomizerVersion, seeds: s.auditHistory.enumerated().map { .init(sequence: $0.offset + 1, action: $0.element.action == .dealt ? "Deal" : "Reveal war", seed: $0.element.seed, seedUsage: $0.element.action == .dealt ? .newSeed : .reusedOriginalDealSeed) })
            group("Learner", [.standard(s.learnerCard)])
            group("Reference", [.standard(s.referenceCard)])
            if s.phase == .warReady || (s.phase == .complete && s.auditHistory.count > 1) {
                group("Learner war", s.learnerWarCards.map { $0.card.map(PrismetCasinoStudyLabCard.standard) ?? .hidden })
                group("Reference war", s.referenceWarCards.map { $0.card.map(PrismetCasinoStudyLabCard.standard) ?? .hidden })
            }
            result = s.outcome.map(presentationLabel)
            let isTiePath = s.learnerCard.rank == s.referenceCard.rank
            status = s.phase == .warReady ? "Tie dealt; reveal the war cards" : isTiePath ? "War resolved: \(result ?? "pending")" : "Comparison resolved: \(result ?? "pending")"
            summaryRows = [.init(label: "Stage", value: s.phase == .warReady ? "War ready" : isTiePath ? "War resolved" : "Comparison resolved"), .init(label: "Outcome", value: result ?? (isTiePath ? "Tie; reveal required" : "Pending"))]
        case .craps(let s):
            audit = .init(seed: s.history.last?.seed, rulesVersion: s.audit.rulesVersion, randomizerVersion: s.audit.randomizerVersion, seeds: s.history.enumerated().map { .init(sequence: $0.offset + 1, action: "Roll", seed: $0.element.seed, seedUsage: .newSeed) }); if let last = s.history.last { dice = .init(values: [last.dice.first, last.dice.second], total: last.total, pattern: s.observation) }; result = s.resolution.map(presentationLabel)
            status = crapsStatus(s)
            summaryRows = [.init(label: "Stage", value: s.phase == .point ? "Point \(s.point ?? 0)" : s.phase == .complete ? "Resolved" : "Come-out"), .init(label: "Rolls", value: "\(s.history.count)"), .init(label: "Observation", value: result ?? "Awaiting roll")]
        case .sicBo(let s):
            audit = .init(seed: s.seed, rulesVersion: s.rulesVersion, randomizerVersion: s.randomizerVersion, seeds: s.history.enumerated().map { .init(sequence: $0.offset + 1, action: "Roll", seed: $0.element.seed, seedUsage: .newSeed) }); if let total = s.total { dice = .init(values: s.dice, total: total, pattern: s.pattern.map(presentationLabel))}; result = s.pattern.map(presentationLabel)
            status = "Sic Bo resolved: total \(s.total ?? 0), \(result ?? "pattern pending")"
            summaryRows = [.init(label: "Stage", value: "Resolved"), .init(label: "Total", value: s.total.map(String.init) ?? "Pending"), .init(label: "Pattern", value: result ?? "Pending")]
        case .roulette(let s):
            audit = .init(seed: s.phase == .spun ? s.seed : nil, rulesVersion: s.rulesVersion, randomizerVersion: s.randomizerVersion, seeds: auditSeeds(seed: s.seed, action: "Spin", seedUsage: .newSeed)); if let pocket = s.pocket, let color = s.color { wheel = .init(pocket: pocket, color: color.rawValue); result = "Pocket \(pocket)" }
            status = "Roulette resolved: \(result ?? "pocket pending")"
            summaryRows = [.init(label: "Stage", value: "Resolved"), .init(label: "Pocket", value: wheel.map { "\($0.pocket)" } ?? "Pending"), .init(label: "Color", value: wheel?.color ?? "Pending")]
        }
        let primary = primaryAction
        return .init(phase: phase, title: descriptor.title, status: status, primaryAction: primary, primaryControlTitle: primary?.title ?? "", primaryControlEnabled: primary?.enabled ?? false, primaryControlRequiresSeed: primary?.requiresSeed ?? false, secondaryNewRoundTitle: phase == .unstarted ? nil : "New Round", cards: cards, dice: dice, wheel: wheel, ledger: ledger(for: gameID), summaryRows: summaryRows, audit: audit, result: result, comparison: comparison, category: category, referenceCategory: referenceCategory, selectedPaiGowCardIndices: selectedPaiGowCardIndices)
    }

    private func auditSeeds(seed: UInt64?, action: String, seedUsage: PrismetCasinoStudyLabAuditSeedUsage = .newSeed) -> [PrismetCasinoStudyLabAuditSeed] {
        seed.map { [.init(sequence: 1, action: action, seed: $0, seedUsage: seedUsage)] } ?? []
    }

    private func openingActionTitle(for gameID: PrismetPracticeCasinoGameID) -> String {
        switch gameID {
        case .crapsPointLab, .sicBoOutcomeLab: return "roll"
        case .europeanRouletteLab: return "spin"
        default: return "deal"
        }
    }

    private func holdemStage(_ phase: PrismetHoldemHandLabPhase) -> String {
        switch phase {
        case .ready: return "Ready"
        case .holeCards: return "Hole cards dealt"
        case .flop: return "Flop revealed"
        case .turn: return "Turn revealed"
        case .river: return "River revealed"
        case .complete: return "Hand classified"
        }
    }

    private func omahaStage(_ phase: PrismetOmahaHandLabPhase) -> String {
        switch phase {
        case .holeCards: return "Hole cards dealt"
        case .flop: return "Flop revealed"
        case .turn: return "Turn revealed"
        case .river: return "River revealed"
        case .complete: return "Hand classified"
        }
    }

    private func baccaratStage(_ phase: PrismetMiniBaccaratPhase) -> String {
        switch phase {
        case .ready: return "Ready"
        case .initialDeal: return "Initial deal"
        case .playerTableau: return "Player tableau"
        case .bankerTableau: return "Banker tableau"
        case .complete: return "Resolved"
        }
    }

    private func paiGowAnalysisIsCurrent(state: PrismetPaiGowSplitLabState, draft: [Int]) -> Bool {
        state.phase == .splitSelected && state.lowCardIndices == draft
    }

    private func paiGowStatus(state: PrismetPaiGowSplitLabState, draft: [Int]) -> String {
        if paiGowAnalysisIsCurrent(state: state, draft: draft) {
            return "Split analyzed: \(state.analysis.map { "Low \(presentationLabel($0.lowHand.category)), high \(presentationLabel($0.highHand.category))" } ?? "unavailable")"
        }
        if state.phase == .splitSelected {
            guard draft.count == 2 else { return "Split changed; select two low-hand cards to reanalyze" }
            guard isLegalPaiGowDraft(draft, in: state) else { return "Split changed; selected pair fouls the split; choose another pair before reanalyzing" }
            return "Split changed; selected positions \(draft.map { String($0 + 1) }.joined(separator: ", ")) are ready to reanalyze"
        }
        guard draft.count == 2 else { return "Select two low-hand cards" }
        guard isLegalPaiGowDraft(draft, in: state) else { return "Selected pair fouls the split; choose another pair" }
        return "Selected positions \(draft.map { String($0 + 1) }.joined(separator: ", ")) are ready to analyze"
    }

    private func crapsStatus(_ state: PrismetCrapsPointLabState) -> String {
        switch state.phase {
        case .ready: return "Ready for the come-out roll"
        case .point:
            switch state.resolution {
            case .some(.pointEstablished(let point)): return "Point \(point) established; roll again"
            case .some(.pointContinues): return "Point \(state.point ?? 0) continues; roll again"
            default: return "Point \(state.point ?? 0); roll again"
            }
        case .complete: return "Craps resolved: \(state.resolution.map(presentationLabel) ?? "observation complete")"
        }
    }

    private func ledger(for id: PrismetPracticeCasinoGameID) -> [PrismetCasinoStudyLabLedgerRow] {
        switch id {
        case .threeCardPokerLab:
            return PrismetThreeCardPokerCategory.allCases.compactMap { category in
                guard let count = PrismetThreeCardPokerLab.exactCategoryCounts[category] else { return nil }
                return .init(label: presentationLabel(category), value: .probability(numerator: count, denominator: PrismetThreeCardPokerLab.exactTotalSingleHandCount))
            }
        case .texasHoldemLab:
            return PrismetHoldemHandLabEngine.exactCategoryCounts.map { .init(label: presentationLabel($0.category), value: .probability(numerator: $0.count, denominator: PrismetHoldemHandLabEngine.exactTotalHandCount)) }
        case .caribbeanStudQualificationLab: return [.init(label: "Labeled five-card deals", value: .count(PrismetCaribbeanStudLab.exactLabeledDealCount))]
        case .paiGowSplitLab: return [.init(label: "Seven-card deals", value: .formula("C(53, 7) = \(PrismetPaiGowSplitLab.totalUnorderedDealCount); C(7, 2) = \(PrismetPaiGowSplitLab.possibleLowAllocationCount)"))]
        case .omahaHandLab: return [.init(label: "Legal Omaha candidates", value: .formula("C(4, 2) × C(5, 3) = \(PrismetOmahaHandLab.legalCandidateCount)"))]
        case .miniBaccaratPractice: return PrismetMiniBaccaratLabEngine.exactOutcomeCounts.map { .init(label: presentationLabel($0.outcome), value: .probability(numerator: $0.count, denominator: PrismetMiniBaccaratLabEngine.exactOutcomeDenominator)) }
        case .casinoWarPractice: return [.init(label: "Learner higher", value: .probability(numerator: 10_376, denominator: PrismetCasinoWarLab.exactOutcomeSampleCount)), .init(label: "Reference higher", value: .probability(numerator: 10_376, denominator: PrismetCasinoWarLab.exactOutcomeSampleCount)), .init(label: "Tie", value: .probability(numerator: 73, denominator: PrismetCasinoWarLab.exactOutcomeSampleCount))]
        case .crapsPointLab:
            return PrismetCrapsPointLabEngine.comeOutDisclosures.map { .init(label: $0.observation, value: .probability(numerator: $0.favorableCount, denominator: $0.totalCount)) } + PrismetCrapsPointLabEngine.pointResolutionDisclosures.map { .init(label: "Point \($0.point) before seven", value: .probability(numerator: $0.pointCount, denominator: $0.pointCount + $0.sevenCount)) }
        case .sicBoOutcomeLab:
            return PrismetSicBoOutcomeLab.exactTotalCounts.enumerated().map { .init(label: "Total \($0.offset + 3)", value: .probability(numerator: $0.element, denominator: 216)) } + PrismetSicBoPattern.allCases.compactMap { pattern in
                guard let count = PrismetSicBoOutcomeLab.exactPatternCounts[pattern] else { return nil }
                return .init(label: presentationLabel(pattern), value: .probability(numerator: count, denominator: 216))
            }
        case .europeanRouletteLab: return [.init(label: "Red", value: .probability(numerator: 18, denominator: 37)), .init(label: "Black", value: .probability(numerator: 18, denominator: 37)), .init(label: "Zero", value: .probability(numerator: 1, denominator: 37))]
        default: return []
        }
    }
}

private func cardLabel(_ card: PrismetCasinoStudyLabCard) -> String {
    switch card { case .hidden: return "Face-down card"; case .joker: return "Joker"; case .standard(let c): return c.accessibilityLabel(isFaceUp: true) }
}

private func presentationLabel(_ category: PrismetThreeCardPokerCategory) -> String {
    switch category {
    case .highCard: return "High card"
    case .onePair: return "One pair"
    case .flush: return "Flush"
    case .straight: return "Straight"
    case .threeOfAKind: return "Three of a kind"
    case .straightFlush: return "Straight flush"
    }
}

private func presentationLabel(_ category: PrismetPokerCategory) -> String {
    switch category {
    case .highCard: return "High card"
    case .onePair: return "One pair"
    case .twoPair: return "Two pair"
    case .threeOfAKind: return "Three of a kind"
    case .straight: return "Straight"
    case .flush: return "Flush"
    case .fullHouse: return "Full house"
    case .fourOfAKind: return "Four of a kind"
    case .straightFlush: return "Straight flush"
    case .royalFlush: return "Royal flush"
    }
}

private func presentationLabel(_ comparison: PrismetPokerComparison) -> String {
    switch comparison { case .learnerHigher: return "Learner higher"; case .referenceHigher: return "Reference higher"; case .neutral: return "Tie" }
}

private func presentationLabel(_ qualification: PrismetCaribbeanStudQualification) -> String {
    switch qualification { case .pairOrBetter: return "Pair or better"; case .aceKingHigh: return "Ace-king high"; case .doesNotQualify: return "Does not qualify" }
}

private func presentationLabel(_ category: PrismetPaiGowLowHandCategory) -> String {
    switch category { case .highCard: return "High card"; case .pair: return "Pair" }
}

private func presentationLabel(_ category: PrismetPaiGowHandCategory) -> String {
    switch category {
    case .highCard: return "High card"; case .onePair: return "One pair"; case .twoPair: return "Two pair"; case .threeOfAKind: return "Three of a kind"; case .straight: return "Straight"; case .flush: return "Flush"; case .fullHouse: return "Full house"; case .fourOfAKind: return "Four of a kind"; case .straightFlush: return "Straight flush"; case .royalFlush: return "Royal flush"; case .fiveAces: return "Five aces"
    }
}

private func presentationLabel(_ outcome: PrismetMiniBaccaratOutcome) -> String {
    switch outcome { case .player: return "Player"; case .banker: return "Banker"; case .tie: return "Tie" }
}

private func presentationLabel(_ outcome: PrismetCasinoWarOutcome) -> String {
    switch outcome { case .learnerHigher: return "Learner higher"; case .referenceHigher: return "Reference higher"; case .neutral: return "Tie" }
}

private func presentationLabel(_ resolution: PrismetCrapsPointLabResolution) -> String {
    switch resolution {
    case .natural: return "Natural"
    case .craps: return "Craps"
    case .pointEstablished(let point): return "Point \(point) established"
    case .pointContinues: return "Point continues"
    case .pointObserved(let point): return "Point \(point) observed"
    case .sevenObserved: return "Seven observed"
    }
}

private func presentationLabel(_ pattern: PrismetSicBoPattern) -> String {
    switch pattern { case .allDistinct: return "All distinct"; case .onePair: return "One pair"; case .triple: return "Triple" }
}
