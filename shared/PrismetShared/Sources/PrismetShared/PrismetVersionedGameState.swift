import Foundation

public struct PrismetVersionedGameState: Codable, Hashable, Sendable {
    public let gameID: String
    public let rulesVersion: Int
    public let payloadVersion: Int
    public let randomizerVersion: Int
    public let stateHash: PrismetStateHash
    public let payload: Data
    public let modifiedAt: Date

    public var hashAlgorithm: PrismetStateHashAlgorithm {
        stateHash.algorithm
    }

    public init(
        gameID: String,
        rulesVersion: Int,
        payloadVersion: Int,
        randomizerVersion: Int = 1,
        stateHash: PrismetStateHash,
        payload: Data,
        modifiedAt: Date = Date()
    ) throws {
        let normalizedGameID = gameID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedGameID.isEmpty else {
            throw PrismetVersionedGameStateError.invalidGameID
        }
        guard rulesVersion > 0 else {
            throw PrismetVersionedGameStateError.invalidRulesVersion(rulesVersion)
        }
        guard payloadVersion > 0 else {
            throw PrismetVersionedGameStateError.invalidPayloadVersion(payloadVersion)
        }
        guard randomizerVersion > 0 else {
            throw PrismetVersionedGameStateError.invalidRandomizerVersion(randomizerVersion)
        }
        guard stateHash.algorithm == .fnv1a64V1 else {
            throw PrismetVersionedGameStateError.unsupportedHashAlgorithm(
                stateHash.algorithm
            )
        }

        let expectedHash = PrismetStateHash.fnv1a64(payload)
        guard stateHash == expectedHash else {
            throw PrismetVersionedGameStateError.payloadHashMismatch(
                expected: expectedHash,
                actual: stateHash
            )
        }

        self.gameID = normalizedGameID
        self.rulesVersion = rulesVersion
        self.payloadVersion = payloadVersion
        self.randomizerVersion = randomizerVersion
        self.stateHash = stateHash
        self.payload = payload
        self.modifiedAt = modifiedAt
    }

    public init(
        gameID: String,
        rulesVersion: Int,
        payloadVersion: Int,
        randomizerVersion: Int = 1,
        hashAlgorithm: PrismetStateHashAlgorithm = .fnv1a64V1,
        payload: Data,
        modifiedAt: Date = Date()
    ) throws {
        guard hashAlgorithm == .fnv1a64V1 else {
            throw PrismetVersionedGameStateError.unsupportedHashAlgorithm(
                hashAlgorithm
            )
        }
        try self.init(
            gameID: gameID,
            rulesVersion: rulesVersion,
            payloadVersion: payloadVersion,
            randomizerVersion: randomizerVersion,
            stateHash: .fnv1a64(payload),
            payload: payload,
            modifiedAt: modifiedAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case gameID
        case rulesVersion
        case payloadVersion
        case randomizerVersion
        case stateHash
        case payload
        case modifiedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            gameID: container.decode(String.self, forKey: .gameID),
            rulesVersion: container.decode(Int.self, forKey: .rulesVersion),
            payloadVersion: container.decode(Int.self, forKey: .payloadVersion),
            randomizerVersion: container.decode(Int.self, forKey: .randomizerVersion),
            stateHash: container.decode(PrismetStateHash.self, forKey: .stateHash),
            payload: container.decode(Data.self, forKey: .payload),
            modifiedAt: container.decode(Date.self, forKey: .modifiedAt)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gameID, forKey: .gameID)
        try container.encode(rulesVersion, forKey: .rulesVersion)
        try container.encode(payloadVersion, forKey: .payloadVersion)
        try container.encode(randomizerVersion, forKey: .randomizerVersion)
        try container.encode(stateHash, forKey: .stateHash)
        try container.encode(payload, forKey: .payload)
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }
}

public struct PrismetSupportedGameVersion: Hashable, Sendable {
    public let gameID: String
    public let rulesVersion: Int
    public let payloadVersion: Int
    public let randomizerVersion: Int
    public let hashAlgorithm: PrismetStateHashAlgorithm

    public init(
        gameID: String,
        rulesVersion: Int,
        payloadVersion: Int,
        randomizerVersion: Int = 1,
        hashAlgorithm: PrismetStateHashAlgorithm = .fnv1a64V1
    ) {
        self.gameID = gameID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rulesVersion = rulesVersion
        self.payloadVersion = payloadVersion
        self.randomizerVersion = randomizerVersion
        self.hashAlgorithm = hashAlgorithm
    }
}

public struct PrismetVersionSupport: Hashable, Sendable {
    public let versions: Set<PrismetSupportedGameVersion>
    public let gameIDs: Set<String>
    public let rulesVersions: Set<Int>
    public let payloadVersions: Set<Int>
    public let randomizerVersions: Set<Int>
    public let hashAlgorithms: Set<PrismetStateHashAlgorithm>

    public init(versions: Set<PrismetSupportedGameVersion>) {
        self.versions = versions
        self.gameIDs = Set(versions.map(\.gameID))
        self.rulesVersions = Set(versions.map(\.rulesVersion))
        self.payloadVersions = Set(versions.map(\.payloadVersion))
        self.randomizerVersions = Set(versions.map(\.randomizerVersion))
        self.hashAlgorithms = Set(versions.map(\.hashAlgorithm))
    }

}

public enum PrismetVersionedGameStateError: Error, Equatable {
    case invalidGameID
    case invalidRulesVersion(Int)
    case invalidPayloadVersion(Int)
    case invalidRandomizerVersion(Int)
    case payloadHashMismatch(expected: PrismetStateHash, actual: PrismetStateHash)
    case unsupportedGameID(String)
    case unsupportedRulesVersion(Int)
    case unsupportedPayloadVersion(Int)
    case unsupportedRandomizerVersion(Int)
    case unsupportedHashAlgorithm(PrismetStateHashAlgorithm)
}

public enum PrismetVersionedGameStateCodec {
    public static func encode(_ state: PrismetVersionedGameState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(state)
    }

    public static func decodeSupported(
        _ data: Data,
        support: PrismetVersionSupport
    ) throws -> PrismetVersionedGameState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let state = try decoder.decode(PrismetVersionedGameState.self, from: data)

        guard support.gameIDs.contains(state.gameID) else {
            throw PrismetVersionedGameStateError.unsupportedGameID(state.gameID)
        }

        let gameVersions = support.versions.filter { $0.gameID == state.gameID }
        let rulesVersions = gameVersions.filter { $0.rulesVersion == state.rulesVersion }
        guard !rulesVersions.isEmpty else {
            throw PrismetVersionedGameStateError.unsupportedRulesVersion(state.rulesVersion)
        }
        let payloadVersions = rulesVersions.filter { $0.payloadVersion == state.payloadVersion }
        guard !payloadVersions.isEmpty else {
            throw PrismetVersionedGameStateError.unsupportedPayloadVersion(state.payloadVersion)
        }
        let randomizerVersions = payloadVersions.filter {
            $0.randomizerVersion == state.randomizerVersion
        }
        guard !randomizerVersions.isEmpty else {
            throw PrismetVersionedGameStateError.unsupportedRandomizerVersion(state.randomizerVersion)
        }
        guard randomizerVersions.contains(where: {
            $0.hashAlgorithm == state.stateHash.algorithm
        }) else {
            throw PrismetVersionedGameStateError.unsupportedHashAlgorithm(state.stateHash.algorithm)
        }
        return state
    }
}
