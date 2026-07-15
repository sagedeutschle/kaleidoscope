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
    @Published private(set) var completedRoundCount = 0
    @Published private(set) var errorMessage: String?

    private let seedSource: () -> UInt64

    init(seedSource: @escaping () -> UInt64 = {
        var generator = SystemRandomNumberGenerator()
        return generator.next()
    }) {
        self.seedSource = seedSource
    }

    func select(_ gameID: PrismetPracticeCasinoGameID) {
        guard gameID != selectedGameID else { return }
        selectedGameID = gameID
        selectedChoiceIDs.removeAll()
        roundResult = nil
        higherLowerPreview = nil
        pokerState = nil
        errorMessage = nil
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
        let descriptor = PrismetPracticeCasinoCatalog[selectedGameID]
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
        roundResult = nil
        pokerState = nil
        higherLowerPreview = nil
        selectedChoiceIDs.removeAll()
        errorMessage = nil
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
            errorMessage = "Reset Session clears only compact and Poker visit state. Existing Blackjack audit save is preserved. Confirm to continue."
            return false
        }
        selectedGameID = .blackjack
        selectedChoiceIDs.removeAll()
        roundResult = nil
        pokerState = nil
        higherLowerPreview = nil
        completedRoundCount = 0
        errorMessage = nil
        return true
    }
}
