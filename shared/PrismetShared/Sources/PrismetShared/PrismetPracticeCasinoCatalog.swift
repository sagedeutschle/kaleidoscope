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
    case threeCardPokerLab = "three-card-poker-lab"
    case texasHoldemLab = "texas-holdem-lab"
    case caribbeanStudQualificationLab = "caribbean-stud-qualification-lab"
    case paiGowSplitLab = "pai-gow-split-lab"
    case omahaHandLab = "omaha-hand-lab"
    case miniBaccaratPractice = "mini-baccarat-practice"
    case casinoWarPractice = "casino-war-practice"
    case crapsPointLab = "craps-point-lab"
    case sicBoOutcomeLab = "sic-bo-outcome-lab"
    case europeanRouletteLab = "european-roulette-lab"
}

public enum PrismetPracticeGameKind: String, Codable, Hashable, Sendable {
    case blackjack, poker, fairChance, studyLab
}

public enum PrismetPracticeCasinoRenderer: String, Codable, Hashable, Sendable {
    case cards
    case dice
    case wheel
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
    public let renderer: PrismetPracticeCasinoRenderer
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
        renderer: PrismetPracticeCasinoRenderer = .cards,
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
        self.renderer = renderer
        self.selectionRule = selectionRule
        self.choices = choices
        self.rulesVersion = rulesVersion
        self.rules = rules
        self.fairness = fairness
        self.actionTitle = actionTitle
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, symbol, kind, renderer, selectionRule, choices
        case rulesVersion, rules, fairness, actionTitle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(PrismetPracticeCasinoGameID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decode(String.self, forKey: .subtitle)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.kind = try container.decode(PrismetPracticeGameKind.self, forKey: .kind)
        self.renderer = try container.decodeIfPresent(PrismetPracticeCasinoRenderer.self, forKey: .renderer) ?? .cards
        self.selectionRule = try container.decode(PrismetPracticeSelectionRule.self, forKey: .selectionRule)
        self.choices = try container.decode([PrismetPracticeChoice].self, forKey: .choices)
        self.rulesVersion = try container.decode(Int.self, forKey: .rulesVersion)
        self.rules = try container.decode(String.self, forKey: .rules)
        self.fairness = try container.decode(String.self, forKey: .fairness)
        self.actionTitle = try container.decode(String.self, forKey: .actionTitle)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(kind, forKey: .kind)
        try container.encode(renderer, forKey: .renderer)
        try container.encode(selectionRule, forKey: .selectionRule)
        try container.encode(choices, forKey: .choices)
        try container.encode(rulesVersion, forKey: .rulesVersion)
        try container.encode(rules, forKey: .rules)
        try container.encode(fairness, forKey: .fairness)
        try container.encode(actionTitle, forKey: .actionTitle)
    }
}

public enum PrismetPracticeCasinoCatalog {
    public static let all: [PrismetPracticeCasinoGameDescriptor] = [
        game(.blackjack, "Practice Blackjack", "A calm hand with visible-information odds.", "rectangle.on.rectangle", .blackjack, .none, [], "Hit, Stand, or End Hand; begin another hand only when you choose.", "Hit bust odds are a dynamic exact visible-information count: unseen cards that would put this hand over 21 / all unseen cards. Only your cards and the dealer’s face-up card are treated as visible; the hole card and draw pile remain unseen. Dealer stands on every 17, including soft 17 (S17). Blackjack is not a 50/50 game.", "Deal Hand"),
        game(.fiveCardDraw, "Five-Card Draw", "Hold cards, then draw once.", "suit.club.fill", .poker, .none, [], "Deal five cards, choose holds, and draw once.", "Each opening hand is one of 2,598,960 equally likely combinations. High card: 1,302,540; One pair: 1,098,240; Two pair: 123,552; Three of a kind: 54,912; Straight: 10,200; Flush: 5,108; Full house: 3,744; Four of a kind: 624. The standard straight-flush family total is 40: 36 non-royal straight flushes plus 4 royal flushes. Engine display categories remain mutually exclusive: Straight flush (non-royal): 36; Royal flush: 4; no hand is double-counted.", "Deal Hand"),
        game(.redBlack, "Red or Black", "Choose a color and reveal one card.", "suit.heart.fill", .fairChance, .exactly(1), colorChoices, "Choose a color, then reveal one card.", "Red: 26/52. Black: 26/52.", "Reveal Card"),
        game(.higherLower, "Higher or Lower", "Compare the next card to the shown card.", "arrow.up.arrow.down", .fairChance, .exactly(1), higherLowerChoices, "Reveal a card, choose higher or lower, then reveal the next card.", "Conditional on shown rank: Higher = (14-rank)*4/51. Lower = (rank-2)*4/51. Equal = 3/51 and neutral.", "Reveal Next Card"),
        game(.highCard, "High Card", "One card for each side.", "rectangle.split.2x1", .fairChance, .none, [], "Deal one card to each side and compare ranks.", "Higher: 8/17. Lower: 8/17. Equal rank: 1/17.", "Deal Cards"),
        game(.coinCall, "Coin Call", "Choose a side, then reveal once.", "circle.lefthalf.filled", .fairChance, .exactly(1), coinChoices, "Choose heads or tails, then reveal the coin.", "Heads: 1/2. Tails: 1/2.", "Reveal Result"),
        game(.diceDuel, "Dice Duel", "One fair die for each side.", "die.face.5", .fairChance, .none, [], "Roll one fair die for each side.", "Higher: 15/36. Lower: 15/36. Tie: 6/36.", "Roll Dice"),
        game(.overUnderSeven, "Over or Under Seven", "Choose above or below, then roll two dice.", "die.face.6", .fairChance, .exactly(1), overUnderChoices, "Choose below seven or above seven, then roll two dice.", "Below: 15/36. Above: 15/36. Seven: 6/36 and neutral.", "Roll Dice"),
        game(.oddEven, "Odd or Even", "Choose parity, then roll two dice.", "circle.grid.3x3.fill", .fairChance, .exactly(1), parityChoices, "Choose odd or even, then roll two dice.", "Odd: 18/36. Even: 18/36.", "Roll Dice"),
        game(.fairWheel, "Fair Wheel", "Choose a color from twelve equal segments.", "circle.dotted", .fairChance, .exactly(1), wheelChoices, "Choose ivory or emerald, then reveal one of 12 equal segments.", "Six segments per color: 6/12. Each numbered segment: 1/12. No zero segment.", "Reveal Segment"),
        game(.numberDraw, "Number Draw", "Choose three values, then draw three.", "number.square", .fairChance, .exactly(3), numberChoices, "Choose exactly three values from 1 through 12, then draw three without replacement.", "Matches: zero 84/220, one 108/220, two 27/220, three 1/220.", "Draw Numbers"),
        game(.threeCardPokerLab, "Three-Card Poker Hand Lab", "Deal and compare two three-card hands.", "suit.club.fill", .studyLab, .none, [], "Deal two three-card hands and compare their categories.", "Three-card combinations: 22,100 total. High card: 16,440; pair: 3,744; flush: 1,096; straight: 720; three of a kind: 52; straight flush: 48. Categories are mutually exclusive and sum to 22,100.", "Deal Hands", .cards),
        game(.texasHoldemLab, "Texas Hold'em Hand Lab", "Reveal streets and classify the best five of seven.", "suit.spade.fill", .studyLab, .none, [], "Reveal hole cards and community streets, then classify the best five of seven.", "Seven-card combinations: 133,784,560 total. High card: 23,294,460; one pair: 58,627,800; two pair: 31,433,400; three of a kind: 6,461,620; straight: 6,180,020; flush: 4,047,644; full house: 3,473,184; four of a kind: 224,848; straight flush: 37,260; royal flush: 4,324. These mutually exclusive categories sum to 133,784,560.", "Reveal Next Street", .cards),
        game(.caribbeanStudQualificationLab, "Caribbean Stud Qualification Lab", "Compare five-card hands with a fixed reference hand.", "suit.diamond.fill", .studyLab, .none, [], "Deal two five-card hands and compare the learner hand with the reference hand.", "Five-card hand categories use 2,598,960 equally likely combinations; qualification follows a fixed reference-hand comparison.", "Deal Hands", .cards),
        game(.paiGowSplitLab, "Pai Gow Split Lab", "Set a two-card low and five-card high hand.", "rectangle.split.2x1", .studyLab, .none, [], "Deal seven cards, then choose one two-card low hand and one five-card high hand.", "A seven-card deal from the 53-card deck has C(53,7)=154143080 unordered combinations. Each deal has 21 two-card/five-card splits.", "Reveal Deal", .cards),
        game(.omahaHandLab, "Omaha Hand Lab", "Use exactly two hole cards and three board cards.", "rectangle.on.rectangle", .studyLab, .none, [], "Reveal four hole cards and a five-card board, then classify the best legal hand.", "A four-hole-card deal and five-card board are evaluated with exactly two hole cards and three board cards. Exactly 60 legal two-plus-three combinations are checked.", "Reveal Board", .cards),
        game(.miniBaccaratPractice, "Mini-Baccarat Outcome Lab", "Advance through fixed Punto Banco tableau rules.", "suit.heart.fill", .studyLab, .none, [], "Reveal the fixed tableau one explicit phase at a time.", "Across 4998398275503360 eight-deck deals: banker 2292252566437888; player 2230518282592256; tie 475627426473216. The stated draw rules classify each outcome.", "Reveal Next Card", .cards),
        game(.casinoWarPractice, "Casino War Practice", "Compare one card, then resolve one initial tie.", "arrow.left.arrow.right", .studyLab, .none, [], "Reveal one card for each side and resolve an initial tie once.", "Learner higher: 10376/20825. Reference higher: 10376/20825. Neutral: 73/20825. The three outcomes are not 50/50.", "Reveal Cards", .cards),
        game(.crapsPointLab, "Craps Point Lab", "Observe come-out and point resolution.", "die.face.5", .studyLab, .none, [], "Roll two dice and classify the come-out or point phase.", "Across 36 ordered two-dice outcomes, come-out natural: 8/36, craps: 4/36, point: 24/36. Point resolution uses point counts 3, 4, 5, 5, 4, 3 for 4, 5, 6, 8, 9, 10; seven has 6/36.", "Roll Dice", .dice),
        game(.sicBoOutcomeLab, "Sic Bo Outcome Lab", "Roll three dice and inspect totals and patterns.", "die.face.6", .studyLab, .none, [], "Roll three dice and classify the total and pattern.", "Three dice have 216 ordered outcomes. Totals 3 through 18 occur 1, 3, 6, 10, 15, 21, 25, 27, 27, 25, 21, 15, 10, 6, 3, 1 times; all same: 6/216, exactly one pair: 90/216, all distinct: 120/216.", "Roll Dice", .dice),
        game(.europeanRouletteLab, "European Roulette Lab", "Spin a single-zero 37-pocket wheel.", "circle.dotted", .studyLab, .none, [], "Spin the wheel and inspect its numbered pocket.", "A single-zero wheel has 37 pockets: red 18/37, black 18/37, zero 1/37. Red and black are not 50/50 because zero is neither.", "Spin Wheel", .wheel),
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
        _ actionTitle: String,
        _ renderer: PrismetPracticeCasinoRenderer = .cards
    ) -> PrismetPracticeCasinoGameDescriptor {
        PrismetPracticeCasinoGameDescriptor(
            id: id, title: title, subtitle: subtitle, symbol: symbol, kind: kind, renderer: renderer,
            selectionRule: selectionRule, choices: choices, rulesVersion: 1,
            rules: rules, fairness: fairness, actionTitle: actionTitle
        )
    }
}
