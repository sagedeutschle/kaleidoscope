public enum PrismetPokerHandValueError: Error, Equatable {
    case invalidCardCount(expectedAtLeast: Int, actual: Int)
    case duplicateCards
}

public struct PrismetPokerHandValue: Codable, Comparable, Hashable, Sendable {
    public let category: PrismetPokerCategory
    public let tieBreakRanks: [Int]

    public init(cards: [PrismetPlayingCard]) throws {
        guard cards.count == 5 else {
            throw PrismetPokerHandValueError.invalidCardCount(expectedAtLeast: 5, actual: cards.count)
        }
        guard Set(cards).count == cards.count else {
            throw PrismetPokerHandValueError.duplicateCards
        }

        let ranks = cards.map { $0.rank.rawValue }
        let grouped = Dictionary(grouping: ranks, by: { $0 }).mapValues(\.count)
        let groups = grouped.map { (rank: $0.key, count: $0.value) }
        let sortedRanks = ranks.sorted(by: >)
        let straightHigh = Self.straightHighRank(ranks)
        let isFlush = Set(cards.map(\.suit)).count == 1

        if let straightHigh, isFlush {
            if straightHigh == PrismetCardRank.ace.rawValue,
               Set(ranks) == Set(10...14) {
                category = .royalFlush
                tieBreakRanks = [straightHigh]
            } else {
                category = .straightFlush
                tieBreakRanks = [straightHigh]
            }
        } else if let four = groups.first(where: { $0.count == 4 }) {
            category = .fourOfAKind
            tieBreakRanks = [four.rank] + groups.filter { $0.count == 1 }.map(\.rank).sorted(by: >)
        } else if let trips = groups.first(where: { $0.count == 3 }),
                  let pair = groups.first(where: { $0.count == 2 }) {
            category = .fullHouse
            tieBreakRanks = [trips.rank, pair.rank]
        } else if isFlush {
            category = .flush
            tieBreakRanks = sortedRanks
        } else if let straightHigh {
            category = .straight
            tieBreakRanks = [straightHigh]
        } else if let trips = groups.first(where: { $0.count == 3 }) {
            category = .threeOfAKind
            tieBreakRanks = [trips.rank] + groups.filter { $0.count == 1 }.map(\.rank).sorted(by: >)
        } else {
            let pairs = groups.filter { $0.count == 2 }.map(\.rank).sorted(by: >)
            if pairs.count == 2 {
                category = .twoPair
                tieBreakRanks = pairs + groups.filter { $0.count == 1 }.map(\.rank)
            } else if let pair = pairs.first {
                category = .onePair
                tieBreakRanks = [pair] + groups.filter { $0.count == 1 }.map(\.rank).sorted(by: >)
            } else {
                category = .highCard
                tieBreakRanks = sortedRanks
            }
        }
    }

    public static func bestFive(of cards: [PrismetPlayingCard]) throws -> Self {
        guard cards.count >= 5 else {
            throw PrismetPokerHandValueError.invalidCardCount(expectedAtLeast: 5, actual: cards.count)
        }
        guard Set(cards).count == cards.count else {
            throw PrismetPokerHandValueError.duplicateCards
        }

        var best: Self?
        for first in 0..<(cards.count - 4) {
            for second in (first + 1)..<(cards.count - 3) {
                for third in (second + 1)..<(cards.count - 2) {
                    for fourth in (third + 1)..<(cards.count - 1) {
                        for fifth in (fourth + 1)..<cards.count {
                            let value = try Self(cards: [cards[first], cards[second], cards[third], cards[fourth], cards[fifth]])
                            if let currentBest = best {
                                if currentBest < value { best = value }
                            } else {
                                best = value
                            }
                        }
                    }
                }
            }
        }
        guard let best else {
            throw PrismetPokerHandValueError.invalidCardCount(expectedAtLeast: 5, actual: cards.count)
        }
        return best
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.category != rhs.category { return lhs.category < rhs.category }
        for (left, right) in zip(lhs.tieBreakRanks, rhs.tieBreakRanks) where left != right {
            return left < right
        }
        return lhs.tieBreakRanks.count < rhs.tieBreakRanks.count
    }

    private static func straightHighRank(_ ranks: [Int]) -> Int? {
        let unique = Set(ranks)
        guard unique.count == 5 else { return nil }
        if unique == Set([2, 3, 4, 5, 14]) { return 5 }
        guard let low = unique.min(), let high = unique.max(), high - low == 4 else { return nil }
        return high
    }
}

public enum PrismetPokerComparison: String, Codable, Hashable, Sendable {
    case learnerHigher
    case referenceHigher
    case neutral

    public static func compare(learner: PrismetPokerHandValue, reference: PrismetPokerHandValue) -> Self {
        if learner > reference { return .learnerHigher }
        if learner < reference { return .referenceHigher }
        return .neutral
    }
}
