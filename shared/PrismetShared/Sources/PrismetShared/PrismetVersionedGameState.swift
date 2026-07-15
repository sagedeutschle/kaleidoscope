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
        let stateHash: PrismetStateHash
        switch hashAlgorithm {
        case .fnv1a64V1:
            stateHash = .fnv1a64(payload)
        }
        try self.init(
            gameID: gameID,
            rulesVersion: rulesVersion,
            payloadVersion: payloadVersion,
            randomizerVersion: randomizerVersion,
            stateHash: stateHash,
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

public struct PrismetVersionSupport: Hashable, Sendable {
    public let gameIDs: Set<String>
    public let rulesVersions: Set<Int>
    public let payloadVersions: Set<Int>
    public let randomizerVersions: Set<Int>
    public let hashAlgorithms: Set<PrismetStateHashAlgorithm>

    public init(
        gameIDs: Set<String>,
        rulesVersions: Set<Int>,
        payloadVersions: Set<Int>,
        randomizerVersions: Set<Int> = [1],
        hashAlgorithms: Set<PrismetStateHashAlgorithm> = [.fnv1a64V1]
    ) {
        self.gameIDs = gameIDs
        self.rulesVersions = rulesVersions
        self.payloadVersions = payloadVersions
        self.randomizerVersions = randomizerVersions
        self.hashAlgorithms = hashAlgorithms
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
        guard support.rulesVersions.contains(state.rulesVersion) else {
            throw PrismetVersionedGameStateError.unsupportedRulesVersion(state.rulesVersion)
        }
        guard support.payloadVersions.contains(state.payloadVersion) else {
            throw PrismetVersionedGameStateError.unsupportedPayloadVersion(state.payloadVersion)
        }
        guard support.randomizerVersions.contains(state.randomizerVersion) else {
            throw PrismetVersionedGameStateError.unsupportedRandomizerVersion(state.randomizerVersion)
        }
        guard support.hashAlgorithms.contains(state.stateHash.algorithm) else {
            throw PrismetVersionedGameStateError.unsupportedHashAlgorithm(state.stateHash.algorithm)
        }
        return state
    }
}
