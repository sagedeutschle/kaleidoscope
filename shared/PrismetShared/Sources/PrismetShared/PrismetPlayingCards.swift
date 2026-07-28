import Foundation

public enum PrismetCardSuit: String, CaseIterable, Codable, Hashable, Sendable {
    case clubs, diamonds, hearts, spades

    public var displayName: String { rawValue }
}

public enum PrismetCardRank: Int, CaseIterable, Codable, Hashable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

    public var identifier: String {
        switch self {
        case .two: return "two"
        case .three: return "three"
        case .four: return "four"
        case .five: return "five"
        case .six: return "six"
        case .seven: return "seven"
        case .eight: return "eight"
        case .nine: return "nine"
        case .ten: return "ten"
        case .jack: return "jack"
        case .queen: return "queen"
        case .king: return "king"
        case .ace: return "ace"
        }
    }

    public var displayName: String { identifier.capitalized }
}

public struct PrismetPlayingCard: Identifiable, Codable, Hashable, Sendable {
    public let suit: PrismetCardSuit
    public let rank: PrismetCardRank

    public init(rank: PrismetCardRank, suit: PrismetCardSuit) {
        self.rank = rank
        self.suit = suit
    }

    public init(suit: PrismetCardSuit, rank: PrismetCardRank) {
        self.init(rank: rank, suit: suit)
    }

    public var id: String { "\(rank.identifier)-of-\(suit.rawValue)" }

    public func accessibilityLabel(isFaceUp: Bool) -> String {
        guard isFaceUp else { return "Face-down card" }
        return "\(rank.displayName) of \(suit.displayName)"
    }
}

public enum PrismetDeckFactory {
    public static func standard52() -> [PrismetPlayingCard] {
        PrismetCardSuit.allCases.flatMap { suit in
            PrismetCardRank.allCases.map { PrismetPlayingCard(rank: $0, suit: suit) }
        }
    }

    public static func euchre24() -> [PrismetPlayingCard] {
        PrismetCardSuit.allCases.flatMap { suit in
            PrismetCardRank.allCases.filter { $0.rawValue >= PrismetCardRank.nine.rawValue }
                .map { PrismetPlayingCard(rank: $0, suit: suit) }
        }
    }
}
