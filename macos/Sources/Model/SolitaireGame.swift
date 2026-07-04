import Foundation

/// Klondike Solitaire — pure deterministic model (no AppKit, iOS-portable).
/// 7 tableau piles, 4 suit foundations, a stock + waste with recycling.
/// Draw-1 or draw-3. Every action returns whether it changed the board.

struct SolitairePileCard: Codable, Hashable {
    var card: Card
    var isFaceUp: Bool
}

struct SolitaireGame: Codable, Hashable {
    static let pileCount = 7

    private(set) var stock: [Card]          // face-down; top = last
    private(set) var waste: [Card]          // face-up;  top = last
    private(set) var foundations: [Suit: [Card]]   // built up A…K per suit
    private(set) var tableau: [[SolitairePileCard]]
    let drawCount: Int                      // 1 or 3
    private(set) var moves: Int

    init(stock: [Card],
         waste: [Card],
         foundations: [Suit: [Card]],
         tableau: [[SolitairePileCard]],
         drawCount: Int,
         moves: Int = 0) {
        self.stock = stock
        self.waste = waste
        self.foundations = foundations
        self.tableau = tableau
        self.drawCount = max(1, drawCount)
        self.moves = moves
    }

    /// Deal a fresh seeded game: pile `i` gets `i+1` cards, only the top face-up;
    /// the remaining 24 cards become the stock.
    static func newGame(seed: UInt64, drawCount: Int = 1) -> SolitaireGame {
        var deck = Deck(shuffledWithSeed: seed)
        var tableau: [[SolitairePileCard]] = []
        for pile in 0..<pileCount {
            var column: [SolitairePileCard] = []
            for row in 0...pile {
                if let card = deck.draw() {
                    column.append(SolitairePileCard(card: card, isFaceUp: row == pile))
                }
            }
            tableau.append(column)
        }
        var foundations: [Suit: [Card]] = [:]
        for suit in Suit.allCases { foundations[suit] = [] }
        return SolitaireGame(stock: deck.cards,
                             waste: [],
                             foundations: foundations,
                             tableau: tableau,
                             drawCount: drawCount,
                             moves: 0)
    }

    // MARK: - Queries

    var isWon: Bool {
        Suit.allCases.allSatisfy { (foundations[$0]?.count ?? 0) == Rank.allCases.count }
    }

    var wasteTop: Card? { waste.last }

    func foundationTop(_ suit: Suit) -> Card? { foundations[suit]?.last }

    func canMoveToFoundation(_ card: Card) -> Bool {
        if let top = foundations[card.suit]?.last {
            return card.rank.rawValue == top.rank.rawValue + 1
        }
        return card.rank == .ace
    }

    /// Can `card` be the new bottom of a move onto tableau pile `index`?
    func canPlaceOnTableau(_ card: Card, pile index: Int) -> Bool {
        guard tableau.indices.contains(index) else { return false }
        if let top = tableau[index].last {
            guard top.isFaceUp else { return false }
            return card.isRed != top.card.isRed && card.rank.rawValue == top.card.rank.rawValue - 1
        }
        return card.rank == .king   // only a King starts an empty pile
    }

    // MARK: - Actions (each returns whether the board changed)

    @discardableResult
    mutating func drawFromStock() -> Bool {
        if stock.isEmpty {
            guard !waste.isEmpty else { return false }
            stock = waste.reversed()   // turn the waste pile face-down again
            waste = []
            moves += 1
            return true
        }
        for _ in 0..<drawCount {
            guard let card = stock.popLast() else { break }
            waste.append(card)
        }
        moves += 1
        return true
    }

    @discardableResult
    mutating func moveWasteToFoundation() -> Bool {
        guard let card = waste.last, canMoveToFoundation(card) else { return false }
        waste.removeLast()
        foundations[card.suit, default: []].append(card)
        moves += 1
        return true
    }

    @discardableResult
    mutating func moveWasteToTableau(pile index: Int) -> Bool {
        guard let card = waste.last, canPlaceOnTableau(card, pile: index) else { return false }
        waste.removeLast()
        tableau[index].append(SolitairePileCard(card: card, isFaceUp: true))
        moves += 1
        return true
    }

    @discardableResult
    mutating func moveTableauToFoundation(pile index: Int) -> Bool {
        guard tableau.indices.contains(index),
              let top = tableau[index].last, top.isFaceUp,
              canMoveToFoundation(top.card) else { return false }
        tableau[index].removeLast()
        foundations[top.card.suit, default: []].append(top.card)
        flipExposed(pile: index)
        moves += 1
        return true
    }

    /// Move the face-up run starting at `cardIndex` of pile `from` onto pile `to`.
    @discardableResult
    mutating func moveTableau(from: Int, cardIndex: Int, to: Int) -> Bool {
        guard tableau.indices.contains(from), tableau.indices.contains(to), from != to else { return false }
        let pile = tableau[from]
        guard pile.indices.contains(cardIndex), pile[cardIndex].isFaceUp else { return false }
        let run = Array(pile[cardIndex...])
        guard isValidRun(run), let moving = run.first,
              canPlaceOnTableau(moving.card, pile: to) else { return false }
        tableau[to].append(contentsOf: run)
        tableau[from].removeSubrange(cardIndex...)
        flipExposed(pile: from)
        moves += 1
        return true
    }

    /// Greedily send every available card to the foundations (the "auto-finish"
    /// move). Returns whether anything moved.
    @discardableResult
    mutating func autoCollectToFoundations() -> Bool {
        var changed = false
        var progressed = true
        while progressed {
            progressed = false
            if moveWasteToFoundation() { progressed = true; changed = true }
            for index in tableau.indices where moveTableauToFoundation(pile: index) {
                progressed = true; changed = true
            }
        }
        return changed
    }

    // MARK: - Helpers

    private func isValidRun(_ run: [SolitairePileCard]) -> Bool {
        guard run.allSatisfy({ $0.isFaceUp }) else { return false }
        guard run.count > 1 else { return true }
        for index in 1..<run.count {
            let prev = run[index - 1].card, cur = run[index].card
            guard cur.isRed != prev.isRed, cur.rank.rawValue == prev.rank.rawValue - 1 else { return false }
        }
        return true
    }

    private mutating func flipExposed(pile index: Int) {
        guard tableau.indices.contains(index),
              let last = tableau[index].indices.last,
              !tableau[index][last].isFaceUp else { return }
        tableau[index][last].isFaceUp = true
    }
}
