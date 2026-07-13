public struct HarvestDice: Codable, Equatable, Sendable {
    public let first: Int
    public let second: Int

    public init(first: Int, second: Int) {
        self.first = first
        self.second = second
    }

    public var total: Int { first + second }
}

public enum HarvestEvent: Codable, Equatable, Sendable {
    case productive(total: Int, gained: Int)
    case robber(lost: Int)
    case barren(total: Int)
}

public struct CatanHarvest: Codable, Equatable, Sendable {
    public static let winningHarvest = 25

    public private(set) var banked: Int
    public private(set) var unbanked: Int
    public private(set) var lastDice: HarvestDice?
    public private(set) var lastEvent: HarvestEvent?
    private var random: SeededRandom

    public init(seed: UInt64) {
        banked = 0
        unbanked = 0
        lastDice = nil
        lastEvent = nil
        random = SeededRandom(seed: seed)
    }

    public var didWin: Bool {
        banked >= Self.winningHarvest
    }

    @discardableResult
    public mutating func roll() -> HarvestEvent {
        let dice = HarvestDice(
            first: random.nextInt(upperBound: 6) + 1,
            second: random.nextInt(upperBound: 6) + 1
        )
        lastDice = dice
        return apply(total: dice.total)
    }

    @discardableResult
    public mutating func apply(total: Int) -> HarvestEvent {
        let event: HarvestEvent

        if total == 7 {
            let lost = (unbanked + 1) / 2
            unbanked -= lost
            event = .robber(lost: lost)
        } else {
            let gained = Self.pips(for: total)
            if gained > 0 {
                unbanked += gained
                event = .productive(total: total, gained: gained)
            } else {
                event = .barren(total: total)
            }
        }

        lastEvent = event
        return event
    }

    @discardableResult
    public mutating func bank() -> Int {
        let amount = unbanked
        banked += amount
        unbanked = 0
        return amount
    }

    public static func pips(for total: Int) -> Int {
        switch total {
        case 2, 12: 1
        case 3, 11: 2
        case 4, 10: 3
        case 5, 9: 4
        case 6, 8: 5
        default: 0
        }
    }
}
