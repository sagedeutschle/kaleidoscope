import Foundation
import PrismetShared
import SwiftUI

@MainActor
final class PracticeCasinoSession: ObservableObject {
    @Published var selectedGameID: PrismetPracticeCasinoGameID = .blackjack
    @Published var selectedChoiceIDs: Set<String> = []
    @Published private(set) var roundResult: PrismetPracticeRoundResult?
    @Published private(set) var higherLowerPreview: PrismetHigherLowerPreview?
    @Published private(set) var pokerState: PrismetFiveCardPokerState?
    /// Study Labs are visit-scoped value adapters. Their snapshot is the only UI contract.
    @Published private(set) var studyLabSnapshot: PrismetCasinoStudyLabSnapshot?
    @Published private(set) var completedRoundCount = 0
    @Published private(set) var errorMessage: String?

    private let seedSource: () -> UInt64
    private var studyLabAdapter: PrismetCasinoStudyLabAdapter?

    init(seedSource: @escaping () -> UInt64 = {
        var generator = SystemRandomNumberGenerator()
        return generator.next()
    }) {
        self.seedSource = seedSource
    }

    convenience init(previewSeed: UInt64?) {
        guard let previewSeed else {
            self.init()
            return
        }
        var nextPreviewSeed = previewSeed
        self.init(seedSource: {
            let seed = nextPreviewSeed
            nextPreviewSeed &+= 1
            return seed
        })
    }

    func select(_ gameID: PrismetPracticeCasinoGameID) {
        guard gameID != selectedGameID else { return }
        selectedGameID = gameID
        selectedChoiceIDs.removeAll()
        roundResult = nil
        higherLowerPreview = nil
        pokerState = nil
        studyLabAdapter = nil
        studyLabSnapshot = nil
        errorMessage = nil
        if PrismetCasinoStudyLabAdapter.supportedGameIDs.contains(gameID) {
            do {
                let adapter = try PrismetCasinoStudyLabAdapter(gameID: gameID)
                studyLabAdapter = adapter
                studyLabSnapshot = adapter.snapshot
            } catch {
                errorMessage = "This study table is unavailable."
            }
        }
    }

    func toggleChoice(_ choiceID: String) {
        guard selectedGameID != .blackjack, selectedGameID != .fiveCardDraw else { return }
        guard roundResult == nil else { return }
        guard PrismetPracticeCasinoCatalog[selectedGameID].choices.contains(where: { $0.id == choiceID }) else { return }
        if selectedGameID == .higherLower {
            guard higherLowerPreview != nil else { return }
        }
        let descriptor = PrismetPracticeCasinoCatalog[selectedGameID]
        let maximum: Int
        switch descriptor.selectionRule {
        case .none: maximum = 0
        case .exactly(let count): maximum = count
        }
        guard maximum > 0 else { return }
        if selectedChoiceIDs.contains(choiceID) {
            selectedChoiceIDs.remove(choiceID)
        } else if maximum == 1 {
            selectedChoiceIDs = [choiceID]
        } else if selectedChoiceIDs.count < maximum {
            selectedChoiceIDs.insert(choiceID)
        }
        errorMessage = nil
    }

    func showHigherLowerCard() {
        guard selectedGameID == .higherLower, higherLowerPreview == nil, roundResult == nil else { return }
        let seed = seedSource()
        do {
            higherLowerPreview = try PrismetFairChanceEngine.previewHigherLower(seed: seed)
            errorMessage = nil
        } catch {
            errorMessage = "This table could not show a card."
        }
    }

    func playRound() {
        guard selectedGameID != .blackjack, selectedGameID != .fiveCardDraw else { return }
        guard roundResult == nil else { return }
        let descriptor = PrismetPracticeCasinoCatalog[selectedGameID]
        guard descriptor.kind == .fairChance else { return }
        if selectedGameID == .higherLower {
            guard let preview = higherLowerPreview,
                  selectedChoiceIDs.count == 1,
                  let choice = selectedChoiceIDs.first.flatMap(PrismetHigherLowerChoice.init(rawValue:)) else {
                errorMessage = "Show the card, then choose Higher or Lower."
                return
            }
            do {
                roundResult = try PrismetFairChanceEngine.resolveHigherLower(preview, choice: choice)
                completedRoundCount += 1
                errorMessage = nil
            } catch {
                errorMessage = "That preview is no longer valid."
            }
            return
        }
        if case .exactly(let count) = descriptor.selectionRule, selectedChoiceIDs.count != count {
            errorMessage = "Choose the required options before revealing a result."
            return
        }
        do {
            roundResult = try PrismetFairChanceEngine.play(
                PrismetPracticeRoundRequest(
                    gameID: selectedGameID,
                    choiceIDs: selectedChoiceIDs.sorted()
                ),
                seed: seedSource()
            )
            completedRoundCount += 1
            errorMessage = nil
        } catch {
            errorMessage = "Choose the required options before revealing a result."
        }
    }

    func newRound() {
        if var adapter = studyLabAdapter {
            // A fresh Study Lab round deliberately consumes no random seed. The next explicit
            // primary action validates before asking the source for exactly one seed.
            do {
                try adapter.perform(.newRound)
                studyLabAdapter = adapter
                studyLabSnapshot = adapter.snapshot
                errorMessage = nil
            } catch {
                errorMessage = "This study table could not start a new round."
            }
            return
        }
        roundResult = nil
        pokerState = nil
        higherLowerPreview = nil
        selectedChoiceIDs.removeAll()
        errorMessage = nil
    }

    func performStudyLabPrimary() {
        guard var adapter = studyLabAdapter, let primary = adapter.snapshot.primaryAction,
              primary.enabled else {
            errorMessage = "Choose the required study step before continuing."
            return
        }

        // Validate the action with the published snapshot before consuming a seed.
        // Non-random reveal/classification actions are explicitly passed no seed.
        let priorPhase = adapter.snapshot.phase
        do {
            let seed = primary.requiresSeed ? seedSource() : nil
            try adapter.perform(primary.action, seed: seed)
            studyLabAdapter = adapter // structs require reassignment for published state.
            studyLabSnapshot = adapter.snapshot
            if priorPhase != .complete, adapter.snapshot.phase == .complete {
                completedRoundCount += 1
            }
            errorMessage = nil
        } catch {
            errorMessage = "That study action is not available right now."
        }
    }

    func togglePaiGowCard(at zeroBasedIndex: Int) {
        guard var adapter = studyLabAdapter else { return }
        do {
            try adapter.perform(.togglePaiGowCard(index: zeroBasedIndex))
            studyLabAdapter = adapter
            studyLabSnapshot = adapter.snapshot
            errorMessage = nil
        } catch {
            errorMessage = "Choose two valid Pai Gow low-hand cards."
        }
    }

    func changePaiGowSplit(toZeroBasedIndices indices: [Int]) {
        guard var adapter = studyLabAdapter else { return }
        do {
            try adapter.perform(.changePaiGowSplit(indices: indices))
            studyLabAdapter = adapter
            studyLabSnapshot = adapter.snapshot
            errorMessage = nil
        } catch {
            errorMessage = "That Pai Gow split is not legal."
        }
    }

    func dealPoker() {
        guard selectedGameID == .fiveCardDraw, pokerState == nil else { return }
        do {
            pokerState = try PrismetFiveCardPokerEngine.deal(seed: seedSource())
            roundResult = nil
            errorMessage = nil
        } catch {
            errorMessage = "This table could not deal a fresh hand."
        }
    }

    func togglePokerHold(at index: Int) {
        guard let pokerState else { return }
        do {
            self.pokerState = try PrismetFiveCardPokerEngine.togglingHold(at: index, in: pokerState)
        } catch {
            errorMessage = "That card cannot be held right now."
        }
    }

    func drawPoker() {
        guard let pokerState else { return }
        do {
            let completed = try PrismetFiveCardPokerEngine.drawing(pokerState)
            self.pokerState = completed
            completedRoundCount += 1
            errorMessage = nil
        } catch {
            errorMessage = "Draw is available once per hand."
        }
    }

    @discardableResult
    func resetSession(confirming: Bool = false) -> Bool {
        guard confirming else {
            errorMessage = "Reset Session clears only Fair Chance, Poker, and Study Lab visit state. Adults 18+ only; no money or transferable value. Existing Blackjack audit save is preserved. Confirm to continue."
            return false
        }
        selectedGameID = .blackjack
        selectedChoiceIDs.removeAll()
        roundResult = nil
        pokerState = nil
        studyLabAdapter = nil
        studyLabSnapshot = nil
        higherLowerPreview = nil
        completedRoundCount = 0
        errorMessage = nil
        return true
    }
}
