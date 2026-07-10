import XCTest
@testable import Prismet

/// Tester bug #2: "once all cards are uncovered, it should auto-complete."
/// These verify the model support the UI cascade drives (`canAutoFinish`,
/// `autoStepToFoundation`, stock cycling) actually empties an all-face-up board.
final class SolitaireAutoFinishTests: XCTestCase {

    /// Runs the exact loop `SolitaireView.startAutoFinish` uses, headlessly.
    private func drive(_ game: inout SolitaireGame, maxSteps: Int = 5000) {
        var idleDraws = 0, steps = 0
        while !game.isWon && steps < maxSteps {
            steps += 1
            if game.autoStepToFoundation() { idleDraws = 0; continue }
            let cyclable = game.stockPlusWasteCount
            if cyclable == 0 { break }
            game.drawFromStock()
            idleDraws += 1
            if idleDraws > cyclable + 1 { break }
        }
    }

    private func emptyFoundations() -> [Suit: [Card]] {
        var f: [Suit: [Card]] = [:]
        for suit in Suit.allCases { f[suit] = [] }
        return f
    }

    /// Each suit fully in a tableau pile, Ace on top (last). Greedy top→foundation
    /// should drain the whole board to a win.
    func testAutoFinishEmptiesAllFaceUpTableau() {
        var tableau: [[SolitairePileCard]] = []
        for suit in Suit.allCases {
            // Rank.allCases is ace…king; reversed puts King at the bottom, Ace on top.
            tableau.append(Rank.allCases.reversed().map {
                SolitairePileCard(card: Card(rank: $0, suit: suit), isFaceUp: true)
            })
        }
        var game = SolitaireGame(stock: [], waste: [], foundations: emptyFoundations(),
                                 tableau: tableau, drawCount: 1)
        XCTAssertTrue(game.allTableauFaceUp)
        XCTAssertTrue(game.canAutoFinish)

        drive(&game)

        XCTAssertTrue(game.isWon, "auto-finish should empty an all-face-up board to the foundations")
        XCTAssertFalse(game.canAutoFinish)
    }

    /// Three suits in the tableau, the fourth entirely in the stock — the cascade must
    /// cycle the stock to finish. `canAutoFinish` is still true (no face-down tableau).
    func testAutoFinishDrawsThroughStock() {
        var tableau: [[SolitairePileCard]] = []
        for suit in [Suit.spades, .hearts, .diamonds] {
            tableau.append(Rank.allCases.reversed().map {
                SolitairePileCard(card: Card(rank: $0, suit: suit), isFaceUp: true)
            })
        }
        let clubs = Rank.allCases.map { Card(rank: $0, suit: .clubs) }   // ace…king in the stock
        var game = SolitaireGame(stock: clubs, waste: [], foundations: emptyFoundations(),
                                 tableau: tableau, drawCount: 1)
        XCTAssertTrue(game.canAutoFinish)

        drive(&game)

        XCTAssertTrue(game.isWon, "auto-finish should cycle the stock to place the remaining suit")
    }

    /// A fresh deal has face-down cards, so it must NOT auto-finish.
    func testFreshDealDoesNotAutoFinish() {
        let game = SolitaireGame.newGame(seed: 12345, drawCount: 1)
        XCTAssertFalse(game.allTableauFaceUp)
        XCTAssertFalse(game.canAutoFinish)
    }
}
