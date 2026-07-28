import Foundation

public enum PrismetStorageScopeKind: String, CaseIterable, Codable, Hashable, Sendable {
    case device
    case backendAccount
}

public struct PrismetStorageScope: Codable, Hashable, Sendable {
    public let kind: PrismetStorageScopeKind
    public let identifier: UUID

    public init(kind: PrismetStorageScopeKind, identifier: UUID) {
        self.kind = kind
        self.identifier = identifier
    }
}

public struct PrismetGameCenterIdentity: Codable, Hashable, Sendable {
    public let developerTeamID: String
    public let accountID: UUID

    public init(developerTeamID: String, accountID: UUID) {
        self.developerTeamID = developerTeamID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.accountID = accountID
    }
}

public struct PrismetPlayerIdentity: Codable, Hashable, Sendable {
    public let localGuestID: UUID
    public let backendAccountID: UUID?
    public let gameCenter: PrismetGameCenterIdentity?

    public init(
        localGuestID: UUID,
        backendAccountID: UUID?,
        gameCenter: PrismetGameCenterIdentity?
    ) {
        self.localGuestID = localGuestID
        self.backendAccountID = backendAccountID
        self.gameCenter = gameCenter
    }

    public var localStorageScope: PrismetStorageScope {
        PrismetStorageScope(kind: .device, identifier: localGuestID)
    }

    public var cloudStorageScope: PrismetStorageScope? {
        backendAccountID.map { PrismetStorageScope(kind: .backendAccount, identifier: $0) }
    }
}
