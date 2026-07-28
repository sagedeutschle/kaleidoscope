import Foundation

public struct PrismetCrapsPointLabDice: Codable, Equatable, Hashable, Sendable {
    public let first: Int
    public let second: Int

    public init(first: Int, second: Int) {
        self.first = first
        self.second = second
    }

    public var total: Int { first + second }
}

public enum PrismetCrapsPointLabComeOut: Equatable, Hashable, Sendable {
    case natural
    case craps
    case point(Int)
}

public enum PrismetCrapsPointLabPhase: String, Codable, Equatable, Hashable, Sendable {
    case ready
    case point
    case complete
}

public enum PrismetCrapsPointLabResolution: Codable, Equatable, Hashable, Sendable {
    case natural
    case craps
    case pointEstablished(Int)
    case pointContinues
    case pointObserved(Int)
    case sevenObserved
}

public struct PrismetCrapsPointLabDisclosure: Codable, Equatable, Hashable, Sendable {
    public let observation: String
    public let favorableCount: Int
    public let totalCount: Int

    public init(observation: String, favorableCount: Int, totalCount: Int) {
        self.observation = observation
        self.favorableCount = favorableCount
        self.totalCount = totalCount
    }
}

public struct PrismetCrapsPointLabPointResolutionDisclosure: Codable, Equatable, Hashable, Sendable {
    public let point: Int
    public let pointCount: Int
    public let sevenCount: Int

    public init(point: Int, pointCount: Int, sevenCount: Int) {
        self.point = point
        self.pointCount = pointCount
        self.sevenCount = sevenCount
    }
}

public struct PrismetCrapsPointLabAudit: Codable, Equatable, Hashable, Sendable {
    public let rulesVersion: Int
    public let randomizerVersion: Int

    public init(rulesVersion: Int, randomizerVersion: Int) {
        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
    }
}

public struct PrismetCrapsPointLabRoll: Codable, Equatable, Hashable, Sendable {
    public let seed: UInt64
    public let dice: PrismetCrapsPointLabDice

    public init(seed: UInt64, dice: PrismetCrapsPointLabDice) {
        self.seed = seed
        self.dice = dice
    }

    public var total: Int { dice.total }
}

public enum PrismetCrapsPointLabStateValidationError: Error, Equatable {
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case invalidCanonicalState
}

public struct PrismetCrapsPointLabState: Codable, Equatable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let audit: PrismetCrapsPointLabAudit
    public let phase: PrismetCrapsPointLabPhase
    public let point: Int?
    public let resolution: PrismetCrapsPointLabResolution?
    public let history: [PrismetCrapsPointLabRoll]

    public static let ready = PrismetCrapsPointLabState(
        audit: .init(
            rulesVersion: Self.rulesVersion,
            randomizerVersion: PrismetDeterministicRandom.algorithmVersion
        ),
        phase: .ready,
        point: nil,
        resolution: nil,
        history: []
    )

    public var observation: String {
        switch phase {
        case .ready:
            return "Observe an explicit seeded two-dice roll."
        case .point:
            return "Observe further explicit rolls against point \(point ?? 0)."
        case .complete:
            return "Observe the completed point sequence."
        }
    }

    fileprivate init(
        audit: PrismetCrapsPointLabAudit,
        phase: PrismetCrapsPointLabPhase,
        point: Int?,
        resolution: PrismetCrapsPointLabResolution?,
        history: [PrismetCrapsPointLabRoll]
    ) {
        self.audit = audit
        self.phase = phase
        self.point = point
        self.resolution = resolution
        self.history = history
    }

    private enum CodingKeys: String, CodingKey {
        case audit
        case phase
        case point
        case resolution
        case history
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let audit = try container.decode(PrismetCrapsPointLabAudit.self, forKey: .audit)
        let phase = try container.decode(PrismetCrapsPointLabPhase.self, forKey: .phase)
        let point = try container.decodeIfPresent(Int.self, forKey: .point)
        let resolution = try container.decodeIfPresent(PrismetCrapsPointLabResolution.self, forKey: .resolution)
        let history = try container.decode([PrismetCrapsPointLabRoll].self, forKey: .history)
        try Self.validate(audit: audit, phase: phase, point: point, resolution: resolution, history: history)
        self.init(audit: audit, phase: phase, point: point, resolution: resolution, history: history)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(audit, forKey: .audit)
        try container.encode(phase, forKey: .phase)
        try container.encodeIfPresent(point, forKey: .point)
        try container.encodeIfPresent(resolution, forKey: .resolution)
        try container.encode(history, forKey: .history)
    }

    private static func validate(
        audit: PrismetCrapsPointLabAudit,
        phase: PrismetCrapsPointLabPhase,
        point: Int?,
        resolution: PrismetCrapsPointLabResolution?,
        history: [PrismetCrapsPointLabRoll]
    ) throws {
        guard audit.rulesVersion == rulesVersion else {
            throw PrismetCrapsPointLabStateValidationError.unsupportedRulesVersion(audit.rulesVersion)
        }
        guard audit.randomizerVersion == PrismetDeterministicRandom.algorithmVersion else {
            throw PrismetCrapsPointLabStateValidationError.unsupportedRandomizerVersion(audit.randomizerVersion)
        }
        let expected = try PrismetCrapsPointLabEngine.replay(history: history)
        guard phase == expected.phase,
              point == expected.point,
              resolution == expected.resolution else {
            throw PrismetCrapsPointLabStateValidationError.invalidCanonicalState
        }
    }
}

public enum PrismetCrapsPointLabEngineError: Error, Equatable {
    case invalidPhase(PrismetCrapsPointLabPhase)
}

public enum PrismetCrapsPointLabEngine {
    public static let comeOutDisclosures: [PrismetCrapsPointLabDisclosure] = [
        .init(observation: "Natural", favorableCount: 8, totalCount: 36),
        .init(observation: "Craps", favorableCount: 4, totalCount: 36),
        .init(observation: "Point", favorableCount: 24, totalCount: 36),
    ]

    public static let pointResolutionDisclosures: [PrismetCrapsPointLabPointResolutionDisclosure] = [
        .init(point: 4, pointCount: 3, sevenCount: 6),
        .init(point: 5, pointCount: 4, sevenCount: 6),
        .init(point: 6, pointCount: 5, sevenCount: 6),
        .init(point: 8, pointCount: 5, sevenCount: 6),
        .init(point: 9, pointCount: 4, sevenCount: 6),
        .init(point: 10, pointCount: 3, sevenCount: 6),
    ]

    public static func classifyComeOut(_ dice: PrismetCrapsPointLabDice) -> PrismetCrapsPointLabComeOut {
        switch dice.total {
        case 7, 11: return .natural
        case 2, 3, 12: return .craps
        default: return .point(dice.total)
        }
    }

    public static func roll(
        seed: UInt64,
        in state: PrismetCrapsPointLabState
    ) throws -> PrismetCrapsPointLabState {
        guard state.phase != .complete else {
            throw PrismetCrapsPointLabEngineError.invalidPhase(.complete)
        }
        return try apply(seed: seed, to: state)
    }

    fileprivate static func replay(history: [PrismetCrapsPointLabRoll]) throws -> PrismetCrapsPointLabState {
        var state = PrismetCrapsPointLabState.ready
        for roll in history {
            guard state.phase != .complete, try dice(seed: roll.seed) == roll.dice else {
                throw PrismetCrapsPointLabStateValidationError.invalidCanonicalState
            }
            state = try apply(seed: roll.seed, to: state)
        }
        return state
    }

    private static func apply(
        seed: UInt64,
        to state: PrismetCrapsPointLabState
    ) throws -> PrismetCrapsPointLabState {
        let dice = try dice(seed: seed)
        let history = state.history + [.init(seed: seed, dice: dice)]
        switch state.phase {
        case .ready:
            switch classifyComeOut(dice) {
            case .natural:
                return makeState(phase: .complete, point: nil, resolution: .natural, history: history)
            case .craps:
                return makeState(phase: .complete, point: nil, resolution: .craps, history: history)
            case .point(let point):
                return makeState(phase: .point, point: point, resolution: .pointEstablished(point), history: history)
            }
        case .point:
            guard let point = state.point else {
                throw PrismetCrapsPointLabStateValidationError.invalidCanonicalState
            }
            if dice.total == point {
                return makeState(phase: .complete, point: point, resolution: .pointObserved(point), history: history)
            }
            if dice.total == 7 {
                return makeState(phase: .complete, point: point, resolution: .sevenObserved, history: history)
            }
            return makeState(phase: .point, point: point, resolution: .pointContinues, history: history)
        case .complete:
            throw PrismetCrapsPointLabEngineError.invalidPhase(.complete)
        }
    }

    private static func makeState(
        phase: PrismetCrapsPointLabPhase,
        point: Int?,
        resolution: PrismetCrapsPointLabResolution?,
        history: [PrismetCrapsPointLabRoll]
    ) -> PrismetCrapsPointLabState {
        PrismetCrapsPointLabState(
            audit: .init(
                rulesVersion: PrismetCrapsPointLabState.rulesVersion,
                randomizerVersion: PrismetDeterministicRandom.algorithmVersion
            ),
            phase: phase,
            point: point,
            resolution: resolution,
            history: history
        )
    }

    private static func dice(seed: UInt64) throws -> PrismetCrapsPointLabDice {
        var random = PrismetDeterministicRandom(seed: seed)
        let first = try random.nextInt(upperBound: 6)
        let second = try random.nextInt(upperBound: 6)
        return PrismetCrapsPointLabDice(first: first + 1, second: second + 1)
    }
}
