import Foundation

public enum PrismetFairChanceEngineError: Error, Equatable, Sendable {
    case invalidFraction
    case unsupportedGame(PrismetPracticeCasinoGameID)
    case invalidChoiceCount(expected: Int, actual: Int)
    case invalidChoice(String)
    case duplicateChoice(String)
    case invalidHigherLowerPreview
}

public struct PrismetProbabilityFraction: Codable, Hashable, Sendable {
    public let numerator: Int
    public let denominator: Int

    public init(_ numerator: Int, _ denominator: Int) throws {
        guard numerator >= 0, denominator > 0 else { throw PrismetFairChanceEngineError.invalidFraction }
        if numerator == 0 {
            self.numerator = 0
            self.denominator = 1
        } else {
            let divisor = Self.greatestCommonDivisor(numerator, denominator)
            self.numerator = numerator / divisor
            self.denominator = denominator / divisor
        }
    }

    public var percentText: String {
        let value = (Double(numerator) / Double(denominator)) * 100
        return value.rounded() == value ? String(format: "%.0f%%", value) : String(format: "%.2f%%", value)
    }

    private enum CodingKeys: String, CodingKey {
        case numerator
        case denominator
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let numerator = try container.decode(Int.self, forKey: .numerator)
        let denominator = try container.decode(Int.self, forKey: .denominator)
        try self.init(numerator, denominator)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(numerator, forKey: .numerator)
        try container.encode(denominator, forKey: .denominator)
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = abs(lhs)
        var b = abs(rhs)
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }
}

public struct PrismetPracticeRoundRequest: Codable, Hashable, Sendable {
    public let gameID: PrismetPracticeCasinoGameID
    public let choiceIDs: [String]

    public init(gameID: PrismetPracticeCasinoGameID, choiceIDs: [String]) {
        self.gameID = gameID
        self.choiceIDs = choiceIDs
    }
}

public struct PrismetPracticeRevealToken: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let primary: String
    public let secondary: String?
    public let symbol: String
    public let isSelected: Bool

    public init(id: String, primary: String, secondary: String?, symbol: String, isSelected: Bool) {
        self.id = id
        self.primary = primary
        self.secondary = secondary
        self.symbol = symbol
        self.isSelected = isSelected
    }
}

public struct PrismetPracticeProbabilityLine: Codable, Hashable, Sendable {
    public let label: String
    public let fraction: PrismetProbabilityFraction

    public init(label: String, fraction: PrismetProbabilityFraction) {
        self.label = label
        self.fraction = fraction
    }
}

public struct PrismetPracticeRoundResult: Codable, Hashable, Sendable {
    public let gameID: PrismetPracticeCasinoGameID
    public let seed: UInt64
    public let randomizerVersion: Int
    public let title: String
    public let detail: String
    public let tokens: [PrismetPracticeRevealToken]
    public let probabilities: [PrismetPracticeProbabilityLine]

    public init(gameID: PrismetPracticeCasinoGameID, seed: UInt64, randomizerVersion: Int, title: String, detail: String, tokens: [PrismetPracticeRevealToken], probabilities: [PrismetPracticeProbabilityLine]) {
        self.gameID = gameID
        self.seed = seed
        self.randomizerVersion = randomizerVersion
        self.title = title
        self.detail = detail
        self.tokens = tokens
        self.probabilities = probabilities
    }
}

public enum PrismetHigherLowerChoice: String, Codable, CaseIterable, Hashable, Sendable {
    case higher
    case lower

    fileprivate var probabilityLabel: String { rawValue.capitalized }
}

/// The explicit, one-card stage of a Higher/Lower round. The next card is not
/// exposed until the player supplies a typed choice.
public struct PrismetHigherLowerPreview: Codable, Hashable, Sendable {
    public let seed: UInt64
    public let randomizerVersion: Int
    public let shownCard: PrismetPracticeRevealToken
    public let probabilities: [PrismetPracticeProbabilityLine]

    public init(seed: UInt64, randomizerVersion: Int, shownCard: PrismetPracticeRevealToken, probabilities: [PrismetPracticeProbabilityLine]) {
        self.seed = seed
        self.randomizerVersion = randomizerVersion
        self.shownCard = shownCard
        self.probabilities = probabilities
    }
}

public enum PrismetFairChanceEngine {
    public static func play(_ request: PrismetPracticeRoundRequest, seed: UInt64) throws -> PrismetPracticeRoundResult {
        try validate(request)
        var random = PrismetDeterministicRandom(seed: seed)
        switch request.gameID {
        case .redBlack: return try redBlack(request, seed: seed, random: &random)
        case .higherLower: return try higherLower(request, seed: seed, random: &random)
        case .highCard: return try highCard(seed: seed, random: &random)
        case .coinCall: return try coinCall(request, seed: seed, random: &random)
        case .diceDuel: return try diceDuel(seed: seed, random: &random)
        case .overUnderSeven: return try overUnderSeven(request, seed: seed, random: &random)
        case .oddEven: return try oddEven(request, seed: seed, random: &random)
        case .fairWheel: return try fairWheel(request, seed: seed, random: &random)
        case .numberDraw: return try numberDraw(request, seed: seed, random: &random)
        case .blackjack, .fiveCardDraw: throw PrismetFairChanceEngineError.unsupportedGame(request.gameID)
        }
    }

    public static func previewHigherLower(seed: UInt64) throws -> PrismetHigherLowerPreview {
        let shown = try higherLowerCards(seed: seed)[0]
        let rank = shown.rank.rawValue
        return PrismetHigherLowerPreview(
            seed: seed,
            randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
            shownCard: cardToken(shown, selected: false),
            probabilities: [
                line("Higher", (14 - rank) * 4, 51),
                line("Lower", (rank - 2) * 4, 51),
                line("Equal rank", 3, 51),
            ]
        )
    }

    public static func resolveHigherLower(
        _ preview: PrismetHigherLowerPreview,
        choice: PrismetHigherLowerChoice
    ) throws -> PrismetPracticeRoundResult {
        let cards = try higherLowerCards(seed: preview.seed)
        let shown = cards[0]
        let next = cards[1]
        guard preview.randomizerVersion == PrismetDeterministicRandom.algorithmVersion,
              preview.shownCard == cardToken(shown, selected: false),
              preview.probabilities == higherLowerProbabilities(for: shown) else {
            throw PrismetFairChanceEngineError.invalidHigherLowerPreview
        }

        let relation = next.rank.rawValue == shown.rank.rawValue ? "Equal rank" : (next.rank.rawValue > shown.rank.rawValue ? "Higher" : "Lower")
        return result(
            .higherLower,
            preview.seed,
            relation == choice.probabilityLabel ? "Selected relation revealed" : "\(relation) revealed",
            "The equal-rank outcome is neutral.",
            [cardToken(shown, selected: false), cardToken(next, selected: relation == choice.probabilityLabel)],
            higherLowerProbabilities(for: shown)
        )
    }

    private static func validate(_ request: PrismetPracticeRoundRequest) throws {
        guard request.gameID != .blackjack, request.gameID != .fiveCardDraw else {
            throw PrismetFairChanceEngineError.unsupportedGame(request.gameID)
        }
        let descriptor = PrismetPracticeCasinoCatalog[request.gameID]
        let expected: Int
        switch descriptor.selectionRule {
        case .none: expected = 0
        case .exactly(let count): expected = count
        }
        guard request.choiceIDs.count == expected else {
            throw PrismetFairChanceEngineError.invalidChoiceCount(expected: expected, actual: request.choiceIDs.count)
        }
        var seen = Set<String>()
        for choice in request.choiceIDs {
            guard seen.insert(choice).inserted else { throw PrismetFairChanceEngineError.duplicateChoice(choice) }
            guard descriptor.choices.contains(where: { $0.id == choice }) else { throw PrismetFairChanceEngineError.invalidChoice(choice) }
        }
    }

    private static func redBlack(_ request: PrismetPracticeRoundRequest, seed: UInt64, random: inout PrismetDeterministicRandom) throws -> PrismetPracticeRoundResult {
        let card = try drawCards(1, random: &random)[0]
        let isRed = card.suit == .diamonds || card.suit == .hearts
        return result(.redBlack, seed, isRed == (request.choiceIDs[0] == "red") ? "Selected color revealed" : "Other color revealed", "One card was drawn from a shuffled standard deck.", [cardToken(card, selected: (isRed ? "red" : "black") == request.choiceIDs[0])], [line("Red", 1, 2), line("Black", 1, 2)])
    }

    private static func higherLower(_ request: PrismetPracticeRoundRequest, seed: UInt64, random: inout PrismetDeterministicRandom) throws -> PrismetPracticeRoundResult {
        _ = random
        let choice = try higherLowerChoice(request.choiceIDs[0])
        return try resolveHigherLower(previewHigherLower(seed: seed), choice: choice)
    }

    private static func highCard(seed: UInt64, random: inout PrismetDeterministicRandom) throws -> PrismetPracticeRoundResult {
        let cards = try drawCards(2, random: &random)
        let relation = cards[0].rank.rawValue == cards[1].rank.rawValue ? "Equal rank" : (cards[0].rank.rawValue > cards[1].rank.rawValue ? "First card higher" : "Second card higher")
        return result(.highCard, seed, relation, "One card was dealt to each side.", [cardToken(cards[0], selected: cards[0].rank.rawValue > cards[1].rank.rawValue), cardToken(cards[1], selected: cards[1].rank.rawValue > cards[0].rank.rawValue)], [line("Higher", 8, 17), line("Lower", 8, 17), line("Equal rank", 1, 17)])
    }

    private static func coinCall(_ request: PrismetPracticeRoundRequest, seed: UInt64, random: inout PrismetDeterministicRandom) throws -> PrismetPracticeRoundResult {
        let side = try random.nextInt(upperBound: 2) == 0 ? "heads" : "tails"
        return result(.coinCall, seed, side == request.choiceIDs[0] ? "Selected side revealed" : "Other side revealed", "The coin has two equally likely sides.", [token(side, side.capitalized, nil, "circle.lefthalf.filled", side == request.choiceIDs[0])], [line("Heads", 1, 2), line("Tails", 1, 2)])
    }

    private static func diceDuel(seed: UInt64, random: inout PrismetDeterministicRandom) throws -> PrismetPracticeRoundResult {
        let first = try die(&random)
        let second = try die(&random)
        let title = first == second ? "Tie" : (first > second ? "First die higher" : "Second die higher")
        return result(.diceDuel, seed, title, "Two fair dice were rolled.", [token("first-die", String(first), nil, "die.face.\(first)", first > second), token("second-die", String(second), nil, "die.face.\(second)", second > first)], [line("Higher", 5, 12), line("Lower", 5, 12), line("Tie", 1, 6)])
    }

    private static func overUnderSeven(_ request: PrismetPracticeRoundRequest, seed: UInt64, random: inout PrismetDeterministicRandom) throws -> PrismetPracticeRoundResult {
        let first = try die(&random)
        let second = try die(&random)
        let sum = first + second
        let outcome = sum == 7 ? "Seven" : (sum < 7 ? "Below seven" : "Above seven")
        return result(.overUnderSeven, seed, outcome == request.choiceIDs[0].replacingOccurrences(of: "below", with: "Below seven").replacingOccurrences(of: "above", with: "Above seven") ? "Selected range revealed" : "\(outcome) revealed", "Seven is neutral.", [token("die-one", String(first), nil, "die.face.\(first)", false), token("die-two", String(second), nil, "die.face.\(second)", false)], [line("Below seven", 5, 12), line("Above seven", 5, 12), line("Seven", 1, 6)])
    }

    private static func oddEven(_ request: PrismetPracticeRoundRequest, seed: UInt64, random: inout PrismetDeterministicRandom) throws -> PrismetPracticeRoundResult {
        let first = try die(&random)
        let second = try die(&random)
        let outcome = (first + second).isMultiple(of: 2) ? "even" : "odd"
        return result(.oddEven, seed, outcome == request.choiceIDs[0] ? "Selected parity revealed" : "Other parity revealed", "Two fair dice were rolled.", [token("die-one", String(first), nil, "die.face.\(first)", false), token("die-two", String(second), nil, "die.face.\(second)", false)], [line("Odd", 1, 2), line("Even", 1, 2)])
    }

    private static func fairWheel(_ request: PrismetPracticeRoundRequest, seed: UInt64, random: inout PrismetDeterministicRandom) throws -> PrismetPracticeRoundResult {
        let segment = try random.nextInt(upperBound: 12) + 1
        let color = segment <= 6 ? "ivory" : "emerald"
        return result(.fairWheel, seed, color == request.choiceIDs[0] ? "Selected color revealed" : "Other color revealed", "Segment \(segment) is one of 12 equal segments.", [token("wheel-segment-\(segment)", String(segment), color.capitalized, "circle.dotted", color == request.choiceIDs[0])], [line("Ivory", 1, 2), line("Emerald", 1, 2), line("Each segment", 1, 12)])
    }

    private static func numberDraw(_ request: PrismetPracticeRoundRequest, seed: UInt64, random: inout PrismetDeterministicRandom) throws -> PrismetPracticeRoundResult {
        var values = Array(1...12)
        try random.shuffle(&values)
        let drawn = Array(values.prefix(3))
        let selected = Set(request.choiceIDs.compactMap(Int.init))
        let matches = drawn.filter { selected.contains($0) }.count
        return result(.numberDraw, seed, "\(matches) match\(matches == 1 ? "" : "es")", "Three values were drawn without replacement.", drawn.map { token("number-\($0)", String($0), nil, "number.square", selected.contains($0)) }, [line("Zero matches", 21, 55), line("One match", 27, 55), line("Two matches", 27, 220), line("Three matches", 1, 220)])
    }

    private static func drawCards(_ count: Int, random: inout PrismetDeterministicRandom) throws -> [PrismetPlayingCard] {
        var deck = PrismetDeckFactory.standard52()
        try random.shuffle(&deck)
        return Array(deck.prefix(count))
    }

    private static func higherLowerCards(seed: UInt64) throws -> [PrismetPlayingCard] {
        var deck = PrismetDeckFactory.standard52()
        var random = PrismetDeterministicRandom(seed: seed)
        try random.shuffle(&deck)
        return Array(deck.prefix(2))
    }

    private static func higherLowerProbabilities(for card: PrismetPlayingCard) -> [PrismetPracticeProbabilityLine] {
        let rank = card.rank.rawValue
        return [line("Higher", (14 - rank) * 4, 51), line("Lower", (rank - 2) * 4, 51), line("Equal rank", 3, 51)]
    }

    private static func higherLowerChoice(_ rawValue: String) throws -> PrismetHigherLowerChoice {
        guard let choice = PrismetHigherLowerChoice(rawValue: rawValue) else {
            throw PrismetFairChanceEngineError.invalidChoice(rawValue)
        }
        return choice
    }

    private static func die(_ random: inout PrismetDeterministicRandom) throws -> Int { try random.nextInt(upperBound: 6) + 1 }
    private static func line(_ label: String, _ numerator: Int, _ denominator: Int) -> PrismetPracticeProbabilityLine { PrismetPracticeProbabilityLine(label: label, fraction: try! PrismetProbabilityFraction(numerator, denominator)) }
    private static func token(_ id: String, _ primary: String, _ secondary: String?, _ symbol: String, _ isSelected: Bool) -> PrismetPracticeRevealToken { PrismetPracticeRevealToken(id: id, primary: primary, secondary: secondary, symbol: symbol, isSelected: isSelected) }
    private static func cardToken(_ card: PrismetPlayingCard, selected: Bool) -> PrismetPracticeRevealToken { token(card.id, card.rank.displayName, card.suit.displayName, suitSymbol(for: card.suit), selected) }
    private static func suitSymbol(for suit: PrismetCardSuit) -> String {
        switch suit {
        case .clubs: return "suit.club.fill"
        case .diamonds: return "suit.diamond.fill"
        case .hearts: return "suit.heart.fill"
        case .spades: return "suit.spade.fill"
        }
    }
    private static func result(_ gameID: PrismetPracticeCasinoGameID, _ seed: UInt64, _ title: String, _ detail: String, _ tokens: [PrismetPracticeRevealToken], _ probabilities: [PrismetPracticeProbabilityLine]) -> PrismetPracticeRoundResult { PrismetPracticeRoundResult(gameID: gameID, seed: seed, randomizerVersion: PrismetDeterministicRandom.algorithmVersion, title: title, detail: detail, tokens: tokens, probabilities: probabilities) }
}
