import XCTest
@testable import Kaleidoscope

final class SolitaireGameTests: XCTestCase {

    // MARK: helpers
    private func card(_ r: Rank, _ s: Suit) -> Card { Card(rank: r, suit: s) }
    private func up(_ r: Rank, _ s: Suit) -> SolitairePileCard { SolitairePileCard(card: card(r, s), isFaceUp: true) }
    private func down(_ r: Rank, _ s: Suit) -> SolitairePileCard { SolitairePileCard(card: card(r, s), isFaceUp: false) }
    private func emptyFoundations() -> [Suit: [Card]] {
        var f: [Suit: [Card]] = [:]; Suit.allCases.forEach { f[$0] = [] }; return f
    }
    private func emptyTableau() -> [[SolitairePileCard]] {
        Array(repeating: [], count: SolitaireGame.pileCount)
    }
    private func game(waste: [Card] = [],
                      foundations: [Suit: [Card]]? = nil,
                      tableau: [[SolitairePileCard]]? = nil,
                      stock: [Card] = [],
                      drawCount: Int = 1) -> SolitaireGame {
        SolitaireGame(stock: stock,
                      waste: waste,
                      foundations: foundations ?? emptyFoundations(),
                      tableau: tableau ?? emptyTableau(),
                      drawCount: drawCount)
    }

    // MARK: deal
    func testNewGameDealStructure() {
        let g = SolitaireGame.newGame(seed: 99)
        XCTAssertEqual(g.tableau.count, 7)
        for (i, pile) in g.tableau.enumerated() {
            XCTAssertEqual(pile.count, i + 1)
            XCTAssertTrue(pile.last!.isFaceUp)
            XCTAssertTrue(pile.dropLast().allSatisfy { !$0.isFaceUp })
        }
        XCTAssertEqual(g.stock.count, 24)   // 52 - 28
        XCTAssertTrue(g.waste.isEmpty)
        XCTAssertFalse(g.isWon)
    }

    func testNewGameSeededDeterministic() {
        XCTAssertEqual(SolitaireGame.newGame(seed: 7), SolitaireGame.newGame(seed: 7))
        XCTAssertNotEqual(SolitaireGame.newGame(seed: 7), SolitaireGame.newGame(seed: 8))
    }

    // MARK: stock / waste
    func testDrawOneMovesTopToWaste() {
        var g = SolitaireGame.newGame(seed: 1, drawCount: 1)
        let stockTop = g.stock.last
        XCTAssertTrue(g.drawFromStock())
        XCTAssertEqual(g.waste.last, stockTop)
        XCTAssertEqual(g.stock.count, 23)
    }

    func testDrawThreeMovesThree() {
        var g = SolitaireGame.newGame(seed: 1, drawCount: 3)
        XCTAssertTrue(g.drawFromStock())
        XCTAssertEqual(g.waste.count, 3)
        XCTAssertEqual(g.stock.count, 21)
    }

    func testEmptyStockRecyclesWaste() {
        var g = game(waste: [card(.two, .clubs), card(.five, .hearts)], stock: [])
        XCTAssertTrue(g.drawFromStock())
        XCTAssertEqual(g.waste.count, 0)
        XCTAssertEqual(g.stock.count, 2)
        // turned over: former waste-top (5♥) is now at the bottom of the stock
        XCTAssertEqual(g.stock.last, card(.two, .clubs))
    }

    func testRecycleNoopWhenBothEmpty() {
        var g = game(waste: [], stock: [])
        XCTAssertFalse(g.drawFromStock())
    }

    // MARK: foundation rules
    func testFoundationAcceptsAceThenAscendingSameSuit() {
        var f = emptyFoundations(); f[.spades] = [card(.ace, .spades)]
        let g = game(foundations: f)
        XCTAssertTrue(g.canMoveToFoundation(card(.two, .spades)))
        XCTAssertFalse(g.canMoveToFoundation(card(.three, .spades)))
        XCTAssertFalse(g.canMoveToFoundation(card(.two, .hearts)))   // hearts empty → needs ace
    }

    func testAceGoesOnEmptyFoundation() {
        let g = game()
        XCTAssertTrue(g.canMoveToFoundation(card(.ace, .diamonds)))
        XCTAssertFalse(g.canMoveToFoundation(card(.two, .diamonds)))
    }

    func testMoveWasteToFoundation() {
        var g = game(waste: [card(.ace, .spades)])
        XCTAssertTrue(g.moveWasteToFoundation())
        XCTAssertEqual(g.foundationTop(.spades), card(.ace, .spades))
        XCTAssertTrue(g.waste.isEmpty)
    }

    // MARK: tableau rules
    func testTableauPlacement() {
        var t = emptyTableau()
        t[0] = [up(.seven, .clubs)]   // black 7 on top
        let g = game(tableau: t)
        XCTAssertTrue(g.canPlaceOnTableau(card(.six, .hearts), pile: 0))   // red 6 on black 7
        XCTAssertFalse(g.canPlaceOnTableau(card(.six, .spades), pile: 0))  // same colour
        XCTAssertFalse(g.canPlaceOnTableau(card(.five, .hearts), pile: 0)) // wrong rank
        XCTAssertTrue(g.canPlaceOnTableau(card(.king, .hearts), pile: 1))  // King on empty pile
        XCTAssertFalse(g.canPlaceOnTableau(card(.queen, .hearts), pile: 1))// non-King on empty
    }

    func testMoveRunOntoTableau() {
        var t = emptyTableau()
        t[0] = [up(.seven, .hearts), up(.six, .spades)]   // valid run 7♥ 6♠
        t[1] = [up(.eight, .spades)]                       // 8♠ to receive 7♥
        var g = game(tableau: t)
        XCTAssertTrue(g.moveTableau(from: 0, cardIndex: 0, to: 1))
        XCTAssertEqual(g.tableau[1].map { $0.card },
                       [card(.eight, .spades), card(.seven, .hearts), card(.six, .spades)])
        XCTAssertTrue(g.tableau[0].isEmpty)
    }

    func testMovingTopCardFlipsTheNewlyExposedCard() {
        var t = emptyTableau()
        t[0] = [down(.two, .clubs), up(.king, .spades)]
        t[1] = []
        var g = game(tableau: t)
        XCTAssertTrue(g.moveTableau(from: 0, cardIndex: 1, to: 1))   // King → empty pile
        XCTAssertEqual(g.tableau[0].count, 1)
        XCTAssertTrue(g.tableau[0][0].isFaceUp)                       // 2♣ auto-flipped
    }

    func testRejectsMovingAFaceDownCard() {
        var t = emptyTableau()
        t[0] = [down(.king, .spades)]
        var g = game(tableau: t)
        XCTAssertFalse(g.moveTableau(from: 0, cardIndex: 0, to: 1))
    }

    // MARK: win
    func testIsWonWhenAllFoundationsFull() {
        var f = emptyFoundations()
        for suit in Suit.allCases {
            f[suit] = Rank.allCases.map { card($0, suit) }
        }
        let g = game(foundations: f)
        XCTAssertTrue(g.isWon)
    }
}
