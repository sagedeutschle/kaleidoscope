import Foundation

public struct PrismetSaveEnvelope: Codable, Hashable, Sendable {
    public static let currentEnvelopeVersion = 1

    public let envelopeVersion: Int
    public let payloadSchemaVersion: Int
    public let featureID: PrismetFeatureID
    public let scope: PrismetStorageScope
    public let slotID: String
    public let score: Int?
    public let modifiedAt: Date
    public let deviceMutationID: UUID
    public let sourcePlatform: PrismetPlatform
    public let payload: Data

    public init(
        envelopeVersion: Int = currentEnvelopeVersion,
        payloadSchemaVersion: Int,
        featureID: PrismetFeatureID,
        scope: PrismetStorageScope,
        slotID: String,
        score: Int?,
        modifiedAt: Date,
        deviceMutationID: UUID,
        sourcePlatform: PrismetPlatform,
        payload: Data
    ) throws {
        guard envelopeVersion > 0 else {
            throw PrismetSaveEnvelopeValidationError.invalidEnvelopeVersion(envelopeVersion)
        }
        guard payloadSchemaVersion > 0 else {
            throw PrismetSaveEnvelopeValidationError.invalidPayloadSchemaVersion(payloadSchemaVersion)
        }
        let normalizedSlotID = slotID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSlotID.isEmpty else {
            throw PrismetSaveEnvelopeValidationError.emptySlotID
        }
        self.envelopeVersion = envelopeVersion
        self.payloadSchemaVersion = payloadSchemaVersion
        self.featureID = featureID
        self.scope = scope
        self.slotID = normalizedSlotID
        self.score = score
        self.modifiedAt = modifiedAt
        self.deviceMutationID = deviceMutationID
        self.sourcePlatform = sourcePlatform
        self.payload = payload
    }

    public var isSupportedEnvelopeVersion: Bool {
        envelopeVersion == Self.currentEnvelopeVersion
    }

    public static func wrappingLegacyPayload(
        _ payload: Data,
        payloadSchemaVersion: Int,
        featureID: PrismetFeatureID,
        scope: PrismetStorageScope,
        slotID: String,
        score: Int?,
        modifiedAt: Date,
        deviceMutationID: UUID,
        sourcePlatform: PrismetPlatform
    ) throws -> PrismetSaveEnvelope {
        try PrismetSaveEnvelope(
            payloadSchemaVersion: payloadSchemaVersion,
            featureID: featureID,
            scope: scope,
            slotID: slotID,
            score: score,
            modifiedAt: modifiedAt,
            deviceMutationID: deviceMutationID,
            sourcePlatform: sourcePlatform,
            payload: payload
        )
    }

    private enum CodingKeys: String, CodingKey {
        case envelopeVersion
        case payloadSchemaVersion
        case featureID
        case scope
        case slotID
        case score
        case modifiedAt
        case deviceMutationID
        case sourcePlatform
        case payload
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(envelopeVersion, forKey: .envelopeVersion)
        try container.encode(payloadSchemaVersion, forKey: .payloadSchemaVersion)
        try container.encode(featureID, forKey: .featureID)
        try container.encode(scope, forKey: .scope)
        try container.encode(slotID, forKey: .slotID)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(deviceMutationID, forKey: .deviceMutationID)
        try container.encode(sourcePlatform, forKey: .sourcePlatform)
        try container.encode(payload, forKey: .payload)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            envelopeVersion: container.decode(Int.self, forKey: .envelopeVersion),
            payloadSchemaVersion: container.decode(Int.self, forKey: .payloadSchemaVersion),
            featureID: container.decode(PrismetFeatureID.self, forKey: .featureID),
            scope: container.decode(PrismetStorageScope.self, forKey: .scope),
            slotID: container.decode(String.self, forKey: .slotID),
            score: container.decodeIfPresent(Int.self, forKey: .score),
            modifiedAt: container.decode(Date.self, forKey: .modifiedAt),
            deviceMutationID: container.decode(UUID.self, forKey: .deviceMutationID),
            sourcePlatform: container.decode(PrismetPlatform.self, forKey: .sourcePlatform),
            payload: container.decode(Data.self, forKey: .payload)
        )
    }
}

public enum PrismetSaveEnvelopeValidationError: Error, Equatable {
    case invalidEnvelopeVersion(Int)
    case invalidPayloadSchemaVersion(Int)
    case emptySlotID
}

public enum PrismetSaveEnvelopeCodec {
    public static func encode(_ envelope: PrismetSaveEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(envelope)
    }

    public static func decode(_ data: Data) throws -> PrismetSaveEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(PrismetSaveEnvelope.self, from: data)
    }
}
