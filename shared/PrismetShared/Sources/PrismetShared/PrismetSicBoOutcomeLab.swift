import Foundation

/// The two lifecycle positions of a three-die observation.
public enum PrismetSicBoOutcomeLabPhase: String, Codable, Hashable, Sendable {
    case ready
    case complete
}

public enum PrismetSicBoPattern: String, Codable, CaseIterable, Hashable, Sendable {
    case allDistinct
    case onePair
    case triple

    public static func classify(_ dice: [Int]) throws -> Self {
        guard PrismetSicBoOutcomeLab.isValidDice(dice) else {
            throw PrismetSicBoOutcomeLabError.invalidDice(dice)
        }

        let distinctCount = Set(dice).count
        switch distinctCount {
        case 3: return .allDistinct
        case 2: return .onePair
        case 1: return .triple
        default: throw PrismetSicBoOutcomeLabError.invalidDice(dice)
        }
    }
}

public struct PrismetSicBoOutcome: Codable, Hashable, Sendable {
    public let dice: [Int]
    public let total: Int
    public let pattern: PrismetSicBoPattern

    public init(dice: [Int]) throws {
        guard PrismetSicBoOutcomeLab.isValidDice(dice) else {
            throw PrismetSicBoOutcomeLabError.invalidDice(dice)
        }
        self.dice = dice
        self.total = dice.reduce(0, +)
        self.pattern = try PrismetSicBoPattern.classify(dice)
    }

    private enum CodingKeys: String, CodingKey { case dice, total, pattern }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dice = try container.decode([Int].self, forKey: .dice)
        let total = try container.decode(Int.self, forKey: .total)
        let pattern = try container.decode(PrismetSicBoPattern.self, forKey: .pattern)
        let canonical = try Self(dice: dice)
        guard total == canonical.total else { throw PrismetSicBoOutcomeLabStateValidationError.totalMismatch }
        guard pattern == canonical.pattern else { throw PrismetSicBoOutcomeLabStateValidationError.patternMismatch }
        self = canonical
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dice, forKey: .dice)
        try container.encode(total, forKey: .total)
        try container.encode(pattern, forKey: .pattern)
    }
}

public enum PrismetSicBoAuditAction: String, Codable, Hashable, Sendable { case roll }

public struct PrismetSicBoAuditEntry: Codable, Hashable, Sendable {
    public let sequence: Int
    public let action: PrismetSicBoAuditAction
    public let seed: UInt64

    public init(sequence: Int, action: PrismetSicBoAuditAction, seed: UInt64) {
        self.sequence = sequence
        self.action = action
        self.seed = seed
    }
}

public enum PrismetSicBoOutcomeLabError: Error, Equatable, Sendable {
    case invalidPhase(PrismetSicBoOutcomeLabPhase)
    case invalidDice([Int])
}

public enum PrismetSicBoOutcomeLabStateValidationError: Error, Equatable, Sendable {
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case invalidReadyState
    case invalidCompleteState
    case diceMismatch
    case totalMismatch
    case patternMismatch
    case invalidHistory
}

/// A deckless, single-observation state. A completed state can always be
/// recomputed from its recorded seed and randomizer version.
public struct PrismetSicBoOutcomeLabState: Codable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let rulesVersion: Int
    public let randomizerVersion: Int
    public let phase: PrismetSicBoOutcomeLabPhase
    public let seed: UInt64?
    public let dice: [Int]
    public let total: Int?
    public let pattern: PrismetSicBoPattern?
    public let history: [PrismetSicBoAuditEntry]

    public static let ready = PrismetSicBoOutcomeLabState(
        rulesVersion: rulesVersion,
        randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
        phase: .ready,
        seed: nil,
        dice: [],
        total: nil,
        pattern: nil,
        history: []
    )

    private init(
        rulesVersion: Int,
        randomizerVersion: Int,
        phase: PrismetSicBoOutcomeLabPhase,
        seed: UInt64?,
        dice: [Int],
        total: Int?,
        pattern: PrismetSicBoPattern?,
        history: [PrismetSicBoAuditEntry]
    ) {
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.phase = phase
        self.seed = seed
        self.dice = dice
        self.total = total
        self.pattern = pattern
        self.history = history
    }

    private enum CodingKeys: String, CodingKey {
        case rulesVersion, randomizerVersion, phase, seed, dice, total, pattern, history
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rulesVersion = try container.decode(Int.self, forKey: .rulesVersion)
        let randomizerVersion = try container.decode(Int.self, forKey: .randomizerVersion)
        let phase = try container.decode(PrismetSicBoOutcomeLabPhase.self, forKey: .phase)
        let seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
        let dice = try container.decode([Int].self, forKey: .dice)
        let total = try container.decodeIfPresent(Int.self, forKey: .total)
        let pattern = try container.decodeIfPresent(PrismetSicBoPattern.self, forKey: .pattern)
        let history = try container.decode([PrismetSicBoAuditEntry].self, forKey: .history)

        try Self.validate(
            rulesVersion: rulesVersion,
            randomizerVersion: randomizerVersion,
            phase: phase,
            seed: seed,
            dice: dice,
            total: total,
            pattern: pattern,
            history: history
        )
        self.init(
            rulesVersion: rulesVersion,
            randomizerVersion: randomizerVersion,
            phase: phase,
            seed: seed,
            dice: dice,
            total: total,
            pattern: pattern,
            history: history
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rulesVersion, forKey: .rulesVersion)
        try container.encode(randomizerVersion, forKey: .randomizerVersion)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encode(dice, forKey: .dice)
        try container.encodeIfPresent(total, forKey: .total)
        try container.encodeIfPresent(pattern, forKey: .pattern)
        try container.encode(history, forKey: .history)
    }

    fileprivate static func completed(seed: UInt64, outcome: PrismetSicBoOutcome) -> Self {
        Self(
            rulesVersion: rulesVersion,
            randomizerVersion: PrismetDeterministicRandom.algorithmVersion,
            phase: .complete,
            seed: seed,
            dice: outcome.dice,
            total: outcome.total,
            pattern: outcome.pattern,
            history: [.init(sequence: 1, action: .roll, seed: seed)]
        )
    }

    private static func validate(
        rulesVersion: Int,
        randomizerVersion: Int,
        phase: PrismetSicBoOutcomeLabPhase,
        seed: UInt64?,
        dice: [Int],
        total: Int?,
        pattern: PrismetSicBoPattern?,
        history: [PrismetSicBoAuditEntry]
    ) throws {
        guard rulesVersion == Self.rulesVersion else {
            throw PrismetSicBoOutcomeLabStateValidationError.unsupportedRulesVersion(rulesVersion)
        }
        guard randomizerVersion == PrismetDeterministicRandom.algorithmVersion else {
            throw PrismetSicBoOutcomeLabStateValidationError.unsupportedRandomizerVersion(randomizerVersion)
        }

        if phase == .ready {
            guard seed == nil, dice.isEmpty, total == nil, pattern == nil, history.isEmpty else {
                throw PrismetSicBoOutcomeLabStateValidationError.invalidReadyState
            }
            return
        }

        guard let seed, let total, let pattern else {
            throw PrismetSicBoOutcomeLabStateValidationError.invalidCompleteState
        }
        let expectedDice = try PrismetSicBoOutcomeLab.dice(seed: seed)
        guard dice == expectedDice else { throw PrismetSicBoOutcomeLabStateValidationError.diceMismatch }
        let outcome = try PrismetSicBoOutcome(dice: dice)
        guard total == outcome.total else { throw PrismetSicBoOutcomeLabStateValidationError.totalMismatch }
        guard pattern == outcome.pattern else { throw PrismetSicBoOutcomeLabStateValidationError.patternMismatch }
        guard history == [.init(sequence: 1, action: .roll, seed: seed)] else {
            throw PrismetSicBoOutcomeLabStateValidationError.invalidHistory
        }
    }
}

public enum PrismetSicBoOutcomeLab {
    public static let exactTotalCounts = [1, 3, 6, 10, 15, 21, 25, 27, 27, 25, 21, 15, 10, 6, 3, 1]
    public static let exactPatternCounts: [PrismetSicBoPattern: Int] = [
        .allDistinct: 120,
        .onePair: 90,
        .triple: 6,
    ]

    /// Performs the laboratory's sole state-changing action.
    public static func roll(_ state: PrismetSicBoOutcomeLabState, seed: UInt64) throws -> PrismetSicBoOutcomeLabState {
        guard state.phase == .ready else { throw PrismetSicBoOutcomeLabError.invalidPhase(state.phase) }
        return .completed(seed: seed, outcome: try PrismetSicBoOutcome(dice: dice(seed: seed)))
    }

    fileprivate static func dice(seed: UInt64) throws -> [Int] {
        var random = PrismetDeterministicRandom(seed: seed)
        return try (0..<3).map { _ in try random.nextInt(upperBound: 6) + 1 }
    }

    fileprivate static func isValidDice(_ dice: [Int]) -> Bool {
        dice.count == 3 && dice.allSatisfy { (1...6).contains($0) }
    }
}
