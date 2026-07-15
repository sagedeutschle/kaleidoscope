public struct PrismetDeterministicRandom: RandomNumberGenerator, Codable, Hashable, Sendable {
    public static let algorithmVersion = 1
    public let seed: UInt64
    public private(set) var state: UInt64
    public private(set) var drawCount: UInt64

    public init(seed: UInt64) {
        self.seed = seed
        self.state = seed
        self.drawCount = 0
    }

    public mutating func next() -> UInt64 {
        drawCount &+= 1
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func next(upperBound: UInt64) throws -> UInt64 {
        guard upperBound > 0 else {
            throw PrismetDeterministicRandomError.invalidUpperBound
        }
        let threshold = (0 &- upperBound) % upperBound
        var value = next()
        while value < threshold {
            value = next()
        }
        return value % upperBound
    }

    public mutating func nextInt(upperBound: Int) throws -> Int {
        guard upperBound > 0 else {
            throw PrismetDeterministicRandomError.invalidUpperBound
        }
        return Int(try next(upperBound: UInt64(upperBound)))
    }

    public mutating func shuffle<Element>(_ values: inout [Element]) throws {
        guard values.count > 1 else { return }
        for index in stride(from: values.count - 1, through: 1, by: -1) {
            let swapIndex = try nextInt(upperBound: index + 1)
            values.swapAt(index, swapIndex)
        }
    }
}

public enum PrismetDeterministicRandomError: Error, Equatable {
    case invalidUpperBound
}
