import Combine
import PrismetShared

@MainActor
final class PracticeCasinoSession: ObservableObject {
    @Published private(set) var selectedGameID: PrismetPracticeCasinoGameID = .blackjack
    @Published private(set) var selectedChoiceIDs: Set<String> = []
    @Published private(set) var roundResult: PrismetPracticeRoundResult?
    @Published private(set) var higherLowerPreview: PrismetHigherLowerPreview?
    @Published private(set) var pokerState: PrismetFiveCardPokerState?
    @Published private(set) var completedRoundCount = 0
    @Published private(set) var studyLabAdapter: PrismetCasinoStudyLabAdapter?
    @Published private(set) var studyLabSnapshot: PrismetCasinoStudyLabSnapshot?

    private let seedSource: () -> UInt64

    init(seedSource: @escaping () -> UInt64 = { UInt64.random(in: .min ... .max) }) {
        self.seedSource = seedSource
    }

    /// Preview builds use a deterministic, stateful sequence while production keeps
    /// the normal fresh-randomness source.
    convenience init(previewSeed: UInt64?) {
        guard let previewSeed else {
            self.init()
            return
        }

        var nextPreviewSeed = previewSeed
        self.init(seedSource: {
            defer { nextPreviewSeed &+= 1 }
            return nextPreviewSeed
        })
    }

    var descriptor: PrismetPracticeCasinoGameDescriptor { PrismetPracticeCasinoCatalog[selectedGameID] }

    func select(_ gameID: PrismetPracticeCasinoGameID) {
        guard gameID != selectedGameID else { return }
        selectedGameID = gameID
        clearTable()
        if descriptor.kind == .studyLab, let adapter = try? PrismetCasinoStudyLabAdapter(gameID: gameID) {
            studyLabAdapter = adapter
            studyLabSnapshot = adapter.snapshot
        }
    }

    func toggleChoice(_ id: String) {
        guard roundResult == nil, pokerState == nil,
              descriptor.choices.contains(where: { $0.id == id }) else { return }
        if selectedGameID == .higherLower { guard higherLowerPreview != nil else { return } }
        let maximum: Int
        switch descriptor.selectionRule { case .none: maximum = 0; case .exactly(let count): maximum = count }
        guard maximum > 0 else { return }
        if selectedChoiceIDs.contains(id) { selectedChoiceIDs.remove(id) }
        else if maximum == 1 { selectedChoiceIDs = [id] }
        else if selectedChoiceIDs.count < maximum { selectedChoiceIDs.insert(id) }
    }

    func playRound() {
        guard descriptor.kind == .fairChance, selectedGameID != .higherLower,
              roundResult == nil, higherLowerPreview == nil, hasValidSelection else { return }
        guard let result = try? PrismetFairChanceEngine.play(.init(gameID: selectedGameID, choiceIDs: selectedChoiceIDs.sorted()), seed: seedSource()) else { return }
        roundResult = result
        completedRoundCount += 1
    }

    func showHigherLowerCard() {
        guard selectedGameID == .higherLower, roundResult == nil, higherLowerPreview == nil else { return }
        higherLowerPreview = try? PrismetFairChanceEngine.previewHigherLower(seed: seedSource())
        selectedChoiceIDs = []
    }

    func revealHigherLower() {
        guard selectedGameID == .higherLower, roundResult == nil, let preview = higherLowerPreview,
              selectedChoiceIDs.count == 1, let choice = selectedChoiceIDs.first.flatMap(PrismetHigherLowerChoice.init(rawValue:)),
              let result = try? PrismetFairChanceEngine.resolveHigherLower(preview, choice: choice) else { return }
        roundResult = result
        higherLowerPreview = nil
        completedRoundCount += 1
    }

    func dealPoker() {
        guard selectedGameID == .fiveCardDraw, pokerState == nil, roundResult == nil else { return }
        pokerState = try? PrismetFiveCardPokerEngine.deal(seed: seedSource())
    }

    func togglePokerHold(at index: Int) {
        guard let pokerState, pokerState.phase == .choosingHolds,
              let updated = try? PrismetFiveCardPokerEngine.togglingHold(at: index, in: pokerState) else { return }
        self.pokerState = updated
    }

    func drawPoker() {
        guard let pokerState, pokerState.phase == .choosingHolds,
              let completed = try? PrismetFiveCardPokerEngine.drawing(pokerState) else { return }
        self.pokerState = completed
        completedRoundCount += 1
    }

    /// Performs the snapshot-derived Study Lab control. A seed is requested only after
    /// the adapter has published an enabled seeded primary action.
    func performStudyLabPrimaryAction() {
        guard var adapter = studyLabAdapter, let primary = adapter.snapshot.primaryAction, primary.enabled else { return }
        let priorPhase = adapter.snapshot.phase
        let seed = primary.requiresSeed ? seedSource() : nil
        guard (try? adapter.perform(primary.action, seed: seed)) != nil else { return }
        publish(adapter)
        if priorPhase != .complete, adapter.snapshot.phase == .complete {
            completedRoundCount += 1
        }
    }

    /// Pai Gow action indices are stable zero-based card positions; the snapshot exposes one-based positions for display.
    func toggleStudyLabPaiGowCard(at index: Int) {
        guard var adapter = studyLabAdapter,
              (try? adapter.perform(.togglePaiGowCard(index: index))) != nil else { return }
        publish(adapter)
    }

    func changeStudyLabPaiGowSplit(to indices: [Int]) {
        guard var adapter = studyLabAdapter,
              (try? adapter.perform(.changePaiGowSplit(indices: indices))) != nil else { return }
        publish(adapter)
    }

    func newRound() {
        if var adapter = studyLabAdapter {
            guard (try? adapter.perform(.newRound)) != nil else { return }
            publish(adapter)
        } else {
            clearTable()
        }
    }

    func resetSession() {
        selectedGameID = .blackjack
        completedRoundCount = 0
        clearTable()
    }

    private var hasValidSelection: Bool {
        switch descriptor.selectionRule { case .none: return selectedChoiceIDs.isEmpty; case .exactly(let count): return selectedChoiceIDs.count == count }
    }

    private func publish(_ adapter: PrismetCasinoStudyLabAdapter) {
        studyLabAdapter = adapter
        studyLabSnapshot = adapter.snapshot
    }

    private func clearTable() {
        selectedChoiceIDs = []
        roundResult = nil
        higherLowerPreview = nil
        pokerState = nil
        studyLabAdapter = nil
        studyLabSnapshot = nil
    }
}
