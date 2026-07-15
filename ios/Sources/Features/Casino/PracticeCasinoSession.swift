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

    private let seedSource: () -> UInt64

    init(seedSource: @escaping () -> UInt64 = { UInt64.random(in: .min ... .max) }) {
        self.seedSource = seedSource
    }

    var descriptor: PrismetPracticeCasinoGameDescriptor { PrismetPracticeCasinoCatalog[selectedGameID] }

    func select(_ gameID: PrismetPracticeCasinoGameID) {
        guard gameID != selectedGameID else { return }
        selectedGameID = gameID
        clearTable()
    }

    func toggleChoice(_ id: String) {
        guard roundResult == nil, pokerState == nil,
              descriptor.choices.contains(where: { $0.id == id }) else { return }
        if selectedGameID == .higherLower {
            guard higherLowerPreview != nil else { return }
        }
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
        guard let result = try? PrismetFairChanceEngine.play(
            .init(gameID: selectedGameID, choiceIDs: selectedChoiceIDs.sorted()), seed: seedSource()
        ) else { return }
        roundResult = result
        completedRoundCount += 1
    }

    func showHigherLowerCard() {
        guard selectedGameID == .higherLower, roundResult == nil, higherLowerPreview == nil else { return }
        higherLowerPreview = try? PrismetFairChanceEngine.previewHigherLower(seed: seedSource())
        selectedChoiceIDs = []
    }

    func revealHigherLower() {
        guard selectedGameID == .higherLower, roundResult == nil,
              let preview = higherLowerPreview, selectedChoiceIDs.count == 1,
              let choice = selectedChoiceIDs.first.flatMap(PrismetHigherLowerChoice.init(rawValue:)) else { return }
        guard let result = try? PrismetFairChanceEngine.resolveHigherLower(preview, choice: choice) else { return }
        roundResult = result
        higherLowerPreview = nil
        completedRoundCount += 1
    }

    func dealPoker() {
        guard selectedGameID == .fiveCardDraw, pokerState == nil, roundResult == nil else { return }
        pokerState = try? PrismetFiveCardPokerEngine.deal(seed: seedSource())
    }

    func togglePokerHold(at index: Int) {
        guard let pokerState, pokerState.phase == .choosingHolds else { return }
        guard let updated = try? PrismetFiveCardPokerEngine.togglingHold(at: index, in: pokerState) else { return }
        self.pokerState = updated
    }

    func drawPoker() {
        guard let pokerState, pokerState.phase == .choosingHolds,
              let completed = try? PrismetFiveCardPokerEngine.drawing(pokerState) else { return }
        self.pokerState = completed
        completedRoundCount += 1
    }

    func newRound() { clearTable() }

    func resetSession() {
        selectedGameID = .blackjack
        completedRoundCount = 0
        clearTable()
    }

    private var hasValidSelection: Bool {
        switch descriptor.selectionRule {
        case .none: return selectedChoiceIDs.isEmpty
        case .exactly(let count): return selectedChoiceIDs.count == count
        }
    }

    private func clearTable() {
        selectedChoiceIDs = []
        roundResult = nil
        higherLowerPreview = nil
        pokerState = nil
    }
}
