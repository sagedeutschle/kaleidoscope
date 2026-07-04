import Foundation

enum CrazyEightPlayer: String, Codable, Equatable, Hashable {
    case host
    case guest

    var opponent: CrazyEightPlayer {
        self == .host ? .guest : .host
    }
}

struct CrazyEightGame: Codable, Equatable, Hashable {
    private(set) var hands: [CrazyEightPlayer: [Card]]
    private(set) var drawPile: [Card]
    private(set) var discardPile: [Card]
    private(set) var currentPlayer: CrazyEightPlayer
    private(set) var declaredSuit: Suit
    private(set) var winner: CrazyEightPlayer?

    init(
        hands: [CrazyEightPlayer: [Card]],
        drawPile: [Card],
        discardPile: [Card],
        currentPlayer: CrazyEightPlayer = .host,
        declaredSuit: Suit,
        winner: CrazyEightPlayer? = nil
    ) {
        self.hands = hands
        self.drawPile = drawPile
        self.discardPile = discardPile
        self.currentPlayer = currentPlayer
        self.declaredSuit = declaredSuit
        self.winner = winner
    }

    static func newGame(seed: UInt64) -> CrazyEightGame {
        var deck = Card.standardDeck
        var rng = SeededGenerator(seed: seed)
        for index in stride(from: deck.count - 1, through: 1, by: -1) {
            deck.swapAt(index, rng.nextInt(upperBound: index + 1))
        }

        let hostHand = Array(deck.prefix(7))
        let guestHand = Array(deck.dropFirst(7).prefix(7))
        let discard = deck[14]
        return CrazyEightGame(
            hands: [.host: hostHand, .guest: guestHand],
            drawPile: Array(deck.dropFirst(15)),
            discardPile: [discard],
            currentPlayer: .host,
            declaredSuit: discard.suit
        )
    }

    var discardTop: Card? { discardPile.last }
    var currentSuit: Suit { declaredSuit }
    var isGameOver: Bool { winner != nil }

    func hand(for player: CrazyEightPlayer) -> [Card] {
        hands[player, default: []]
    }

    func canPlay(_ card: Card) -> Bool {
        guard let top = discardTop else { return true }
        return card.rank == .eight || card.rank == top.rank || card.suit == declaredSuit
    }

    @discardableResult
    mutating func playCard(_ card: Card, declaredSuit nextSuit: Suit? = nil) -> Bool {
        guard winner == nil,
              var hand = hands[currentPlayer],
              let cardIndex = hand.firstIndex(of: card),
              canPlay(card)
        else { return false }

        hand.remove(at: cardIndex)
        hands[currentPlayer] = hand
        discardPile.append(card)
        declaredSuit = card.rank == .eight ? (nextSuit ?? card.suit) : card.suit

        if hand.isEmpty {
            winner = currentPlayer
        }
        currentPlayer = currentPlayer.opponent
        return true
    }

    @discardableResult
    mutating func drawCard() -> Bool {
        guard winner == nil else { return false }
        if drawPile.isEmpty {
            recycleDiscardIntoDrawPile()
        }
        guard let card = drawPile.popLast() else { return false }
        hands[currentPlayer, default: []].append(card)
        currentPlayer = currentPlayer.opponent
        return true
    }

    private mutating func recycleDiscardIntoDrawPile() {
        guard let top = discardPile.last, discardPile.count > 1 else { return }
        drawPile = discardPile.dropLast().reversed()
        discardPile = [top]
    }
}
