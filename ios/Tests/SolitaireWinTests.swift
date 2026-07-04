import XCTest
@testable import Kaleidoscope

/// Tester bug #2 (celebration): the UI fires its "You Won!" overlay off the model's
/// completion signal. These cover the pure progress accounting added to
/// `SolitaireGame` (`foundationCardCount`, `completionProgress`) that drives it.
/// The cascade-drains-the-board behavior itself lives in SolitaireAutoFinishTests.
final class SolitaireWinTests: XCTestCase {

    private func emptyFoundations() -> [Suit: [Card]] {
        var f: [Suit: [Card]] = [:]
        for suit in Suit.allCases { f[suit] = [] }
        return f
    }

    /// Every card in a foundation ⇒ 52 home, progress 1.0, and `isWon`.
    private func fullFoundations() -> [Suit: [Card]] {
        var f: [Suit: [Card]] = [:]
        for suit in Suit.allCases {
            f[suit] = Rank.allCases.map { Card(rank: $0, suit: suit) }
        }
        return f
    }

    func testFreshDealHasZeroFoundationProgress() {
        let game = SolitaireGame.newGame(seed: 42, drawCount: 1)
        XCTAssertEqual(game.foundationCardCount, 0)
        XCTAssertEqual(game.completionProgress, 0, accuracy: 1e-9)
        XCTAssertFalse(game.isWon)
    }

    func testFoundationCardCountReflectsPartialProgress() {
        var foundations = emptyFoundations()
        // Spades A,2 + hearts A ⇒ 3 cards home.
        foundations[.spades] = [Card(rank: .ace, suit: .spades), Card(rank: .two, suit: .spades)]
        foundations[.hearts] = [Card(rank: .ace, suit: .hearts)]
        let game = SolitaireGame(stock: [], waste: [], foundations: foundations,
                                 tableau: [], drawCount: 1)
        XCTAssertEqual(game.foundationCardCount, 3)
        XCTAssertEqual(game.completionProgress, 3.0 / 52.0, accuracy: 1e-9)
        XCTAssertFalse(game.isWon)
    }

    /// The completion signal the celebration overlay keys off: full foundations means
    /// 52 home, progress exactly 1.0, and `isWon` true.
    func testFullFoundationsSignalsCompletion() {
        let game = SolitaireGame(stock: [], waste: [], foundations: fullFoundations(),
                                 tableau: [], drawCount: 1)
        XCTAssertEqual(game.foundationCardCount, 52)
        XCTAssertEqual(game.completionProgress, 1.0, accuracy: 1e-9)
        XCTAssertTrue(game.isWon)
    }

    /// Progress must climb monotonically to 1.0 as the auto-finish cascade drains an
    /// all-face-up board, and land exactly on completion — so a "just won" edge is
    /// observable to the UI without over/undershoot.
    func testProgressReachesExactlyOneWhenCascadeWins() {
        var tableau: [[SolitairePileCard]] = []
        for suit in Suit.allCases {
            tableau.append(Rank.allCases.reversed().map {
                SolitairePileCard(card: Card(rank: $0, suit: suit), isFaceUp: true)
            })
        }
        var game = SolitaireGame(stock: [], waste: [], foundations: emptyFoundations(),
                                 tableau: tableau, drawCount: 1)
        XCTAssertTrue(game.canAutoFinish)

        var last = game.completionProgress
        var steps = 0
        while game.autoStepToFoundation() && steps < 5000 {
            steps += 1
            XCTAssertGreaterThanOrEqual(game.completionProgress, last,
                                        "foundation progress must never regress")
            last = game.completionProgress
        }

        XCTAssertTrue(game.isWon)
        XCTAssertEqual(game.completionProgress, 1.0, accuracy: 1e-9)
        XCTAssertEqual(game.foundationCardCount, 52)
    }
}
