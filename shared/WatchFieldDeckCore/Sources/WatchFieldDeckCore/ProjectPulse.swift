import Foundation

public enum ProjectID: String, Codable, CaseIterable, Sendable {
    case prismet
    case longNow
    case allhands
    case prismCode
    case protonOutlook
    case minecraftMesh
    case mediaNAS
    case macWorkflow
}

public enum PulseState: String, Codable, CaseIterable, Sendable {
    case shipped
    case ready
    case active
    case queued
    case guarded
}

public struct ProjectPulse: Codable, Equatable, Identifiable, Sendable {
    public let id: ProjectID
    public let title: String
    public let state: PulseState
    public let headline: String
    public let detail: String
    public let nextAction: String
    public let symbol: String
    public let accentHex: String

    public init(
        id: ProjectID,
        title: String,
        state: PulseState,
        headline: String,
        detail: String,
        nextAction: String,
        symbol: String,
        accentHex: String
    ) {
        self.id = id
        self.title = title
        self.state = state
        self.headline = headline
        self.detail = detail
        self.nextAction = nextAction
        self.symbol = symbol
        self.accentHex = accentHex
    }
}

public struct FieldDeckSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let generatedAt: Date
    public let projects: [ProjectPulse]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        generatedAt: Date,
        projects: [ProjectPulse]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.projects = projects
    }

    public func replacingGeneratedAt(_ date: Date) -> Self {
        Self(schemaVersion: schemaVersion, generatedAt: date, projects: projects)
    }

    public func replacingSchemaVersion(_ version: Int) -> Self {
        Self(schemaVersion: version, generatedAt: generatedAt, projects: projects)
    }
}

public enum FieldDeckCodec {
    public static let contextKey = "prismet.fieldDeck.snapshot"

    public static func context(for snapshot: FieldDeckSnapshot) throws -> [String: Any] {
        [contextKey: try JSONEncoder().encode(snapshot)]
    }

    public static func snapshot(from context: [String: Any]) throws -> FieldDeckSnapshot {
        guard let data = context[contextKey] as? Data else {
            throw FieldDeckCodecError.missingSnapshot
        }
        return try JSONDecoder().decode(FieldDeckSnapshot.self, from: data)
    }

    public static func shouldAccept(
        _ candidate: FieldDeckSnapshot,
        replacing current: FieldDeckSnapshot
    ) -> Bool {
        candidate.schemaVersion == FieldDeckSnapshot.currentSchemaVersion
            && candidate.generatedAt > current.generatedAt
    }
}

public enum FieldDeckCodecError: Error, Equatable {
    case missingSnapshot
}

public extension FieldDeckSnapshot {
    static var july13: Self { FieldDeckCatalog.july13 }
}
