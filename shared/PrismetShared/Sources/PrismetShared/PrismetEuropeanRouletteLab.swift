import Foundation

public enum PrismetEuropeanRoulettePocketColor: String, Codable, CaseIterable, Hashable, Sendable {
    case green
    case red
    case black
}

public enum PrismetEuropeanRoulettePhase: String, Codable, Hashable, Sendable {
    case ready
    case spun
}

public enum PrismetEuropeanRouletteLabError: Error, Equatable, Hashable, Sendable {
    case invalidPhase(PrismetEuropeanRoulettePhase)
}

public enum PrismetEuropeanRouletteLabStateValidationError: Error, Equatable, Hashable, Sendable {
    case unsupportedRulesVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case invalidPhaseState
    case invalidPocketIndex
    case invalidPocket
    case invalidColor
    case invalidRandomizerDrawCount
}

public struct PrismetEuropeanRouletteLabState: Codable, Equatable, Hashable, Sendable {
    public static let rulesVersion = 1

    public let rulesVersion: Int
    public let randomizerVersion: Int
    public let seed: UInt64
    public let phase: PrismetEuropeanRoulettePhase
    public let pocketIndex: Int?
    public let pocket: Int?
    public let color: PrismetEuropeanRoulettePocketColor?
    public let randomizerDrawCount: UInt64

    public init(seed: UInt64) {
        self.rulesVersion = Self.rulesVersion
        self.randomizerVersion = PrismetDeterministicRandom.algorithmVersion
        self.seed = seed
        self.phase = .ready
        self.pocketIndex = nil
        self.pocket = nil
        self.color = nil
        self.randomizerDrawCount = 0
    }

    fileprivate init(seed: UInt64, pocketIndex: Int, pocket: Int, color: PrismetEuropeanRoulettePocketColor, randomizerDrawCount: UInt64) {
        self.rulesVersion = Self.rulesVersion
        self.randomizerVersion = PrismetDeterministicRandom.algorithmVersion
        self.seed = seed
        self.phase = .spun
        self.pocketIndex = pocketIndex
        self.pocket = pocket
        self.color = color
        self.randomizerDrawCount = randomizerDrawCount
    }

    private enum CodingKeys: String, CodingKey {
        case rulesVersion, randomizerVersion, seed, phase, pocketIndex, pocket, color, randomizerDrawCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rulesVersion = try container.decode(Int.self, forKey: .rulesVersion)
        let randomizerVersion = try container.decode(Int.self, forKey: .randomizerVersion)
        let seed = try container.decode(UInt64.self, forKey: .seed)
        let phase = try container.decode(PrismetEuropeanRoulettePhase.self, forKey: .phase)
        let pocketIndex = try container.decodeIfPresent(Int.self, forKey: .pocketIndex)
        let pocket = try container.decodeIfPresent(Int.self, forKey: .pocket)
        let color = try container.decodeIfPresent(PrismetEuropeanRoulettePocketColor.self, forKey: .color)
        let randomizerDrawCount = try container.decode(UInt64.self, forKey: .randomizerDrawCount)

        guard rulesVersion == Self.rulesVersion else {
            throw PrismetEuropeanRouletteLabStateValidationError.unsupportedRulesVersion(rulesVersion)
        }
        guard randomizerVersion == PrismetDeterministicRandom.algorithmVersion else {
            throw PrismetEuropeanRouletteLabStateValidationError.unsupportedRandomizerVersion(randomizerVersion)
        }
        guard phase == .ready || (phase == .spun && pocketIndex != nil && pocket != nil && color != nil) else {
            throw PrismetEuropeanRouletteLabStateValidationError.invalidPhaseState
        }
        guard phase == .ready || randomizerDrawCount > 0 else {
            throw PrismetEuropeanRouletteLabStateValidationError.invalidRandomizerDrawCount
        }
        if phase == .ready {
            guard pocketIndex == nil, pocket == nil, color == nil, randomizerDrawCount == 0 else {
                throw PrismetEuropeanRouletteLabStateValidationError.invalidPhaseState
            }
        } else if let pocketIndex, let pocket, let color {
            guard PrismetEuropeanRouletteLab.wheel.indices.contains(pocketIndex) else {
                throw PrismetEuropeanRouletteLabStateValidationError.invalidPocketIndex
            }
            guard PrismetEuropeanRouletteLab.wheel[pocketIndex] == pocket else {
                throw PrismetEuropeanRouletteLabStateValidationError.invalidPocket
            }
            guard PrismetEuropeanRouletteLab.color(of: pocket) == color else {
                throw PrismetEuropeanRouletteLabStateValidationError.invalidColor
            }
            let expected = try PrismetEuropeanRouletteLab.rolled(seed: seed)
            guard expected.index == pocketIndex, expected.pocket == pocket, expected.color == color, expected.drawCount == randomizerDrawCount else {
                throw PrismetEuropeanRouletteLabStateValidationError.invalidRandomizerDrawCount
            }
        }

        self.rulesVersion = rulesVersion
        self.randomizerVersion = randomizerVersion
        self.seed = seed
        self.phase = phase
        self.pocketIndex = pocketIndex
        self.pocket = pocket
        self.color = color
        self.randomizerDrawCount = randomizerDrawCount
    }
}

public enum PrismetEuropeanRouletteLab {
    public static let exactPocketCount = 37
    public static let exactZeroCount = 1
    public static let exactRedCount = 18
    public static let exactBlackCount = 18
    public static let redBlackDisclosure = "Red and black are not 50/50 because zero is neither."
    public static let wheel: [Int] = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]

    private static let redPockets: Set<Int> = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

    public static func ready(seed: UInt64) -> PrismetEuropeanRouletteLabState {
        PrismetEuropeanRouletteLabState(seed: seed)
    }

    public static func spin(seed: UInt64) throws -> PrismetEuropeanRouletteLabState {
        let result = try rolled(seed: seed)
        return PrismetEuropeanRouletteLabState(seed: seed, pocketIndex: result.index, pocket: result.pocket, color: result.color, randomizerDrawCount: result.drawCount)
    }

    public static func spin(in state: PrismetEuropeanRouletteLabState) throws -> PrismetEuropeanRouletteLabState {
        guard state.phase == .ready else { throw PrismetEuropeanRouletteLabError.invalidPhase(state.phase) }
        return try spin(seed: state.seed)
    }

    public static func color(of pocket: Int) -> PrismetEuropeanRoulettePocketColor? {
        if pocket == 0 { return .green }
        if redPockets.contains(pocket) { return .red }
        if (1...36).contains(pocket) { return .black }
        return nil
    }

    fileprivate static func rolled(seed: UInt64) throws -> (index: Int, pocket: Int, color: PrismetEuropeanRoulettePocketColor, drawCount: UInt64) {
        var random = PrismetDeterministicRandom(seed: seed)
        let index = try random.nextInt(upperBound: wheel.count)
        let pocket = wheel[index]
        guard let color = color(of: pocket) else {
            throw PrismetEuropeanRouletteLabStateValidationError.invalidColor
        }
        return (index, pocket, color, random.drawCount)
    }
}
