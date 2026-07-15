import Foundation

public enum PrismetPracticeCasinoGameID: String, CaseIterable, Codable, Hashable, Sendable {
    case blackjack = "blackjack"
    case fiveCardDraw = "five-card-draw"
    case redBlack = "red-black"
    case higherLower = "higher-lower"
    case highCard = "high-card"
    case coinCall = "coin-call"
    case diceDuel = "dice-duel"
    case overUnderSeven = "over-under-seven"
    case oddEven = "odd-even"
    case fairWheel = "fair-wheel"
    case numberDraw = "number-draw"
}

public enum PrismetPracticeGameKind: String, Codable, Hashable, Sendable {
    case blackjack, poker, fairChance
}

public enum PrismetPracticeSelectionRule: Codable, Hashable, Sendable {
    case none
    case exactly(Int)
}

public struct PrismetPracticeChoice: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String

    public init(id: String, title: String, symbol: String) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }
}

public struct PrismetPracticeCasinoGameDescriptor: Identifiable, Codable, Hashable, Sendable {
    public let id: PrismetPracticeCasinoGameID
    public let title: String
    public let subtitle: String
    public let symbol: String
    public let kind: PrismetPracticeGameKind
    public let selectionRule: PrismetPracticeSelectionRule
    public let choices: [PrismetPracticeChoice]
    public let rulesVersion: Int
    public let rules: String
    public let fairness: String
    public let actionTitle: String

    public init(
        id: PrismetPracticeCasinoGameID,
        title: String,
        subtitle: String,
        symbol: String,
        kind: PrismetPracticeGameKind,
        selectionRule: PrismetPracticeSelectionRule,
        choices: [PrismetPracticeChoice],
        rulesVersion: Int,
        rules: String,
        fairness: String,
        actionTitle: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.kind = kind
        self.selectionRule = selectionRule
        self.choices = choices
        self.rulesVersion = rulesVersion
        self.rules = rules
        self.fairness = fairness
        self.actionTitle = actionTitle
    }
}

public enum PrismetPracticeCasinoCatalog {
    public static let all: [PrismetPracticeCasinoGameDescriptor] = [
        game(.blackjack, "Practice Blackjack", "A calm hand with visible-information odds.", "rectangle.on.rectangle", .blackjack, .none, [], "Hit, Stand, or End Hand; begin another hand only when you choose.", "Dealer stands on all 17s. Blackjack is not a 50/50 game.", "Deal Hand"),
        game(.fiveCardDraw, "Five-Card Draw", "Hold cards, then draw once.", "suit.club.fill", .poker, .none, [], "Deal five cards, choose holds, and draw once.", "Each opening hand is one of 2,598,960 equally likely combinations. High card: 1,302,540; One pair: 1,098,240; Two pair: 123,552; Three of a kind: 54,912; Straight: 10,200; Flush: 5,108; Full house: 3,744; Four of a kind: 624; Straight flush (non-royal): 36; Royal flush: 4. Counts are mutually exclusive.", "Deal Hand"),
        game(.redBlack, "Red or Black", "Choose a color and reveal one card.", "suit.heart.fill", .fairChance, .exactly(1), colorChoices, "Choose a color, then reveal one card.", "Red: 26/52. Black: 26/52.", "Reveal Card"),
        game(.higherLower, "Higher or Lower", "Compare the next card to the shown card.", "arrow.up.arrow.down", .fairChance, .exactly(1), higherLowerChoices, "Reveal a card, choose higher or lower, then reveal the next card.", "Conditional on shown rank: Higher = (14-rank)*4/51. Lower = (rank-2)*4/51. Equal = 3/51 and neutral.", "Reveal Next Card"),
        game(.highCard, "High Card", "One card for each side.", "rectangle.split.2x1", .fairChance, .none, [], "Deal one card to each side and compare ranks.", "Higher: 8/17. Lower: 8/17. Equal rank: 1/17.", "Deal Cards"),
        game(.coinCall, "Coin Call", "Choose a side, then reveal once.", "circle.lefthalf.filled", .fairChance, .exactly(1), coinChoices, "Choose heads or tails, then reveal the coin.", "Heads: 1/2. Tails: 1/2.", "Reveal Result"),
        game(.diceDuel, "Dice Duel", "One fair die for each side.", "die.face.5", .fairChance, .none, [], "Roll one fair die for each side.", "Higher: 15/36. Lower: 15/36. Tie: 6/36.", "Roll Dice"),
        game(.overUnderSeven, "Over or Under Seven", "Choose above or below, then roll two dice.", "die.face.6", .fairChance, .exactly(1), overUnderChoices, "Choose below seven or above seven, then roll two dice.", "Below: 15/36. Above: 15/36. Seven: 6/36 and neutral.", "Roll Dice"),
        game(.oddEven, "Odd or Even", "Choose parity, then roll two dice.", "circle.grid.3x3.fill", .fairChance, .exactly(1), parityChoices, "Choose odd or even, then roll two dice.", "Odd: 18/36. Even: 18/36.", "Roll Dice"),
        game(.fairWheel, "Fair Wheel", "Choose a color from twelve equal segments.", "circle.dotted", .fairChance, .exactly(1), wheelChoices, "Choose ivory or emerald, then reveal one of 12 equal segments.", "Six segments per color: 6/12. Each numbered segment: 1/12. No zero segment.", "Reveal Segment"),
        game(.numberDraw, "Number Draw", "Choose three values, then draw three.", "number.square", .fairChance, .exactly(3), numberChoices, "Choose exactly three values from 1 through 12, then draw three without replacement.", "Matches: zero 84/220, one 108/220, two 27/220, three 1/220.", "Draw Numbers"),
    ]

    public static subscript(_ id: PrismetPracticeCasinoGameID) -> PrismetPracticeCasinoGameDescriptor {
        guard let descriptor = all.first(where: { $0.id == id }) else {
            preconditionFailure("Catalog construction omitted required game ID: \(id.rawValue)")
        }
        return descriptor
    }

    private static let colorChoices = [
        PrismetPracticeChoice(id: "red", title: "Red", symbol: "suit.heart.fill"),
        PrismetPracticeChoice(id: "black", title: "Black", symbol: "suit.spade.fill"),
    ]
    private static let higherLowerChoices = [
        PrismetPracticeChoice(id: "higher", title: "Higher", symbol: "arrow.up"),
        PrismetPracticeChoice(id: "lower", title: "Lower", symbol: "arrow.down"),
    ]
    private static let coinChoices = [
        PrismetPracticeChoice(id: "heads", title: "Heads", symbol: "h.circle"),
        PrismetPracticeChoice(id: "tails", title: "Tails", symbol: "t.circle"),
    ]
    private static let overUnderChoices = [
        PrismetPracticeChoice(id: "below", title: "Below Seven", symbol: "arrow.down"),
        PrismetPracticeChoice(id: "above", title: "Above Seven", symbol: "arrow.up"),
    ]
    private static let wheelChoices = [
        PrismetPracticeChoice(id: "ivory", title: "Ivory", symbol: "circle.fill"),
        PrismetPracticeChoice(id: "emerald", title: "Emerald", symbol: "circle.fill"),
    ]
    private static let parityChoices = [
        PrismetPracticeChoice(id: "odd", title: "Odd", symbol: "1.circle"),
        PrismetPracticeChoice(id: "even", title: "Even", symbol: "2.circle"),
    ]
    private static let numberChoices = (1...12).map {
        PrismetPracticeChoice(id: String($0), title: String($0), symbol: "number.square")
    }

    private static func game(
        _ id: PrismetPracticeCasinoGameID,
        _ title: String,
        _ subtitle: String,
        _ symbol: String,
        _ kind: PrismetPracticeGameKind,
        _ selectionRule: PrismetPracticeSelectionRule,
        _ choices: [PrismetPracticeChoice],
        _ rules: String,
        _ fairness: String,
        _ actionTitle: String
    ) -> PrismetPracticeCasinoGameDescriptor {
        PrismetPracticeCasinoGameDescriptor(
            id: id, title: title, subtitle: subtitle, symbol: symbol, kind: kind,
            selectionRule: selectionRule, choices: choices, rulesVersion: 1,
            rules: rules, fairness: fairness, actionTitle: actionTitle
        )
    }
}
