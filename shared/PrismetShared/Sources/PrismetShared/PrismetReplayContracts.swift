import Foundation

public struct PrismetStateHashAlgorithm: Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let fnv1a64V1 = PrismetStateHashAlgorithm(rawValue: "fnv1a64-v1")

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum PrismetReplayError: Error, Equatable {
    case invalidStateHash(String)
    case emptyPayloadKind
    case invalidRecordSequence(Int)
    case invalidActorSeat(Int)
    case emptyGameID
    case invalidRulesetVersion(Int)
    case invalidRandomizerVersion(Int)
    case nonContiguousSequence(record: String, expected: Int, actual: Int)
    case nonIncreasingSequence(record: String, previous: Int, actual: Int)
    case unsupportedHashAlgorithm(PrismetStateHashAlgorithm)
    case finalStateHashMismatch
}

public struct PrismetStateHash: Codable, Hashable, Sendable {
    public let algorithm: PrismetStateHashAlgorithm
    public let value: String

    public init(
        algorithm: PrismetStateHashAlgorithm = .fnv1a64V1,
        value: String
    ) throws {
        if algorithm == .fnv1a64V1 {
            guard value.count == 16,
                  value.unicodeScalars.allSatisfy({ scalar in
                      (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
                  }) else {
                throw PrismetReplayError.invalidStateHash(value)
            }
        }
        self.algorithm = algorithm
        self.value = value
    }

    public static func fnv1a64(_ data: Data) -> PrismetStateHash {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return try! PrismetStateHash(value: String(format: "%016llx", hash))
    }

    private enum CodingKeys: String, CodingKey {
        case algorithm
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            algorithm: container.decode(PrismetStateHashAlgorithm.self, forKey: .algorithm),
            value: container.decode(String.self, forKey: .value)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(algorithm, forKey: .algorithm)
        try container.encode(value, forKey: .value)
    }
}

public struct PrismetReplayPayload: Codable, Hashable, Sendable {
    public let kind: String
    public let data: Data

    public init(kind: String, data: Data) throws {
        let normalizedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKind.isEmpty else {
            throw PrismetReplayError.emptyPayloadKind
        }
        self.kind = normalizedKind
        self.data = data
    }

    public init<Value: Encodable>(kind: String, value: Value) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try self.init(kind: kind, data: encoder.encode(value))
    }

    public func decode<Value: Decodable>(as type: Value.Type) throws -> Value {
        try JSONDecoder().decode(type, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            kind: container.decode(String.self, forKey: .kind),
            data: container.decode(Data.self, forKey: .data)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(data, forKey: .data)
    }
}

public struct PrismetGameCommandRecord: Codable, Hashable, Sendable {
    public let sequence: Int
    public let actorSeat: Int?
    public let payload: PrismetReplayPayload

    public init(
        sequence: Int,
        actorSeat: Int?,
        payload: PrismetReplayPayload
    ) throws {
        guard sequence >= 0 else {
            throw PrismetReplayError.invalidRecordSequence(sequence)
        }
        if let actorSeat, actorSeat < 0 {
            throw PrismetReplayError.invalidActorSeat(actorSeat)
        }
        self.sequence = sequence
        self.actorSeat = actorSeat
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case sequence
        case actorSeat
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            sequence: container.decode(Int.self, forKey: .sequence),
            actorSeat: container.decodeIfPresent(Int.self, forKey: .actorSeat),
            payload: container.decode(PrismetReplayPayload.self, forKey: .payload)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sequence, forKey: .sequence)
        try container.encodeIfPresent(actorSeat, forKey: .actorSeat)
        try container.encode(payload, forKey: .payload)
    }
}

public struct PrismetGameEventRecord: Codable, Hashable, Sendable {
    public let sequence: Int
    public let payload: PrismetReplayPayload
    public let stateHash: PrismetStateHash

    public init(
        sequence: Int,
        payload: PrismetReplayPayload,
        stateHash: PrismetStateHash
    ) throws {
        guard sequence >= 0 else {
            throw PrismetReplayError.invalidRecordSequence(sequence)
        }
        self.sequence = sequence
        self.payload = payload
        self.stateHash = stateHash
    }

    private enum CodingKeys: String, CodingKey {
        case sequence
        case payload
        case stateHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            sequence: container.decode(Int.self, forKey: .sequence),
            payload: container.decode(PrismetReplayPayload.self, forKey: .payload),
            stateHash: container.decode(PrismetStateHash.self, forKey: .stateHash)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(payload, forKey: .payload)
        try container.encode(stateHash, forKey: .stateHash)
    }
}

public enum PrismetGameReplayOutcome: String, CaseIterable, Codable, Hashable, Sendable {
    case completed
    case abandoned
}

public struct PrismetGameReplay: Codable, Hashable, Sendable {
    public let gameID: String
    public let rulesetVersion: Int
    public let randomizerVersion: Int
    public let seed: UInt64
    public let commands: [PrismetGameCommandRecord]
    public let events: [PrismetGameEventRecord]
    public let finalOutcome: PrismetGameReplayOutcome
    public let finalStateHash: PrismetStateHash

    public var stateHashes: [PrismetStateHash] {
        events.map(\.stateHash)
    }

    public init(
        gameID: String,
        rulesetVersion: Int,
        randomizerVersion: Int,
        seed: UInt64,
        commands: [PrismetGameCommandRecord],
        events: [PrismetGameEventRecord],
        finalOutcome: PrismetGameReplayOutcome,
        finalStateHash: PrismetStateHash
    ) throws {
        let normalizedGameID = gameID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedGameID.isEmpty else {
            throw PrismetReplayError.emptyGameID
        }
        guard rulesetVersion > 0 else {
            throw PrismetReplayError.invalidRulesetVersion(rulesetVersion)
        }
        guard randomizerVersion > 0 else {
            throw PrismetReplayError.invalidRandomizerVersion(randomizerVersion)
        }
        if let unsupportedAlgorithm = (events.map(\.stateHash) + [finalStateHash])
            .map(\.algorithm)
            .first(where: { $0 != .fnv1a64V1 }) {
            throw PrismetReplayError.unsupportedHashAlgorithm(unsupportedAlgorithm)
        }
        try Self.validateSequences(commands.map(\.sequence), record: "command")
        try Self.validateSequences(events.map(\.sequence), record: "event")
        if let lastEvent = events.last, lastEvent.stateHash != finalStateHash {
            throw PrismetReplayError.finalStateHashMismatch
        }

        self.gameID = normalizedGameID
        self.rulesetVersion = rulesetVersion
        self.randomizerVersion = randomizerVersion
        self.seed = seed
        self.commands = commands
        self.events = events
        self.finalOutcome = finalOutcome
        self.finalStateHash = finalStateHash
    }

    private static func validateSequences(_ sequences: [Int], record: String) throws {
        guard var previous = sequences.first else { return }
        for actual in sequences.dropFirst() {
            guard actual > previous else {
                throw PrismetReplayError.nonIncreasingSequence(
                    record: record,
                    previous: previous,
                    actual: actual
                )
            }
            previous = actual
        }
    }

    private enum CodingKeys: String, CodingKey {
        case gameID
        case rulesetVersion
        case randomizerVersion
        case seed
        case commands
        case events
        case finalOutcome
        case finalStateHash
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            gameID: container.decode(String.self, forKey: .gameID),
            rulesetVersion: container.decode(Int.self, forKey: .rulesetVersion),
            randomizerVersion: container.decode(Int.self, forKey: .randomizerVersion),
            seed: container.decode(UInt64.self, forKey: .seed),
            commands: container.decode([PrismetGameCommandRecord].self, forKey: .commands),
            events: container.decode([PrismetGameEventRecord].self, forKey: .events),
            finalOutcome: container.decode(PrismetGameReplayOutcome.self, forKey: .finalOutcome),
            finalStateHash: container.decode(PrismetStateHash.self, forKey: .finalStateHash)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gameID, forKey: .gameID)
        try container.encode(rulesetVersion, forKey: .rulesetVersion)
        try container.encode(randomizerVersion, forKey: .randomizerVersion)
        try container.encode(seed, forKey: .seed)
        try container.encode(commands, forKey: .commands)
        try container.encode(events, forKey: .events)
        try container.encode(finalOutcome, forKey: .finalOutcome)
        try container.encode(finalStateHash, forKey: .finalStateHash)
    }
}

public enum PrismetGameReplayCodec {
    public static func encode(_ replay: PrismetGameReplay) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(replay)
    }

    public static func decode(_ data: Data) throws -> PrismetGameReplay {
        try JSONDecoder().decode(PrismetGameReplay.self, from: data)
    }
}

public enum PrismetReplayMismatch: Equatable, Sendable {
    case metadata(field: String)
    case command(index: Int)
    case commandCount(expected: Int, actual: Int)
    case event(index: Int)
    case eventCount(expected: Int, actual: Int)
    case finalOutcome
    case finalStateHash
}

public enum PrismetGameReplayVerifier {
    public static func firstMismatch(
        recorded: PrismetGameReplay,
        reproduced: PrismetGameReplay
    ) -> PrismetReplayMismatch? {
        if recorded.gameID != reproduced.gameID { return .metadata(field: "gameID") }
        if recorded.rulesetVersion != reproduced.rulesetVersion {
            return .metadata(field: "rulesetVersion")
        }
        if recorded.randomizerVersion != reproduced.randomizerVersion {
            return .metadata(field: "randomizerVersion")
        }
        if recorded.seed != reproduced.seed { return .metadata(field: "seed") }
        for index in 0..<min(recorded.commands.count, reproduced.commands.count)
        where recorded.commands[index] != reproduced.commands[index] {
            return .command(index: index)
        }
        if recorded.commands.count != reproduced.commands.count {
            return .commandCount(expected: recorded.commands.count, actual: reproduced.commands.count)
        }
        for index in 0..<min(recorded.events.count, reproduced.events.count)
        where recorded.events[index] != reproduced.events[index] {
            return .event(index: index)
        }
        if recorded.events.count != reproduced.events.count {
            return .eventCount(expected: recorded.events.count, actual: reproduced.events.count)
        }
        if recorded.finalOutcome != reproduced.finalOutcome { return .finalOutcome }
        if recorded.finalStateHash != reproduced.finalStateHash { return .finalStateHash }
        return nil
    }
}
