import Foundation

/// Shared 52-card playing-card primitives, reused by every card facet
/// (Solitaire, Hearts, …). Pure value types, deterministic shuffling via the
/// app-wide `SeededGenerator`, fully unit-tested — no AppKit, so it ports to iOS.

enum Suit: String, CaseIterable, Codable, Hashable, Identifiable {
    case spades, hearts, diamonds, clubs

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .spades:   return "♠"
        case .hearts:   return "♥"
        case .diamonds: return "♦"
        case .clubs:    return "♣"
        }
    }

    /// Hearts and diamonds are the red suits (matters for Solitaire alternation).
    var isRed: Bool { self == .hearts || self == .diamonds }
}

enum Rank: Int, CaseIterable, Codable, Hashable, Comparable, Identifiable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .ace:   return "A"
        case .jack:  return "J"
        case .queen: return "Q"
        case .king:  return "K"
        default:     return String(rawValue)
        }
    }

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Card: Codable, Hashable, Identifiable {
    let rank: Rank
    let suit: Suit

    var id: String { "\(suit.rawValue)-\(rank.rawValue)" }
    var isRed: Bool { suit.isRed }
    /// Compact face label, e.g. "Q♠", "10♥".
    var label: String { "\(rank.shortLabel)\(suit.symbol)" }
}

extension Card {
    /// A fresh, ordered 52-card deck: spades A…K, then hearts, diamonds, clubs.
    static var standardDeck: [Card] {
        Suit.allCases.flatMap { suit in
            Rank.allCases.map { Card(rank: $0, suit: suit) }
        }
    }
}

/// A draw pile. Cards are drawn from the *top* (the end of the array).
struct Deck: Codable, Hashable {
    private(set) var cards: [Card]

    init(cards: [Card] = Card.standardDeck) {
        self.cards = cards
    }

    /// A full 52-card deck deterministically shuffled for a given seed, so a deal
    /// is reproducible in tests and across save/restore.
    init(shuffledWithSeed seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        var deck = Card.standardDeck
        // Fisher–Yates with the shared seeded generator (same approach as 2048).
        for index in stride(from: deck.count - 1, through: 1, by: -1) {
            let swap = rng.nextInt(upperBound: index + 1)
            deck.swapAt(index, swap)
        }
        self.cards = deck
    }

    var count: Int { cards.count }
    var isEmpty: Bool { cards.isEmpty }

    /// Draw a single card from the top, or nil if the deck is empty.
    mutating func draw() -> Card? { cards.popLast() }

    /// Draw up to `n` cards from the top (fewer if the deck runs out).
    mutating func draw(_ n: Int) -> [Card] {
        var drawn: [Card] = []
        for _ in 0..<max(0, n) {
            guard let card = draw() else { break }
            drawn.append(card)
        }
        return drawn
    }
}
