import Foundation

public enum PrismetGameMode: String, CaseIterable, Codable, Hashable, Sendable {
    case soloBot
    case localTwoPlayer
    case onlineFriend
}

public enum PrismetGameLaunchSurface: String, CaseIterable, Codable, Hashable, Sendable {
    case home
    case parlor
}

public struct PrismetGameLaunchContext: Codable, Hashable, Sendable {
    public let featureID: PrismetFeatureID
    public let mode: PrismetGameMode
    public let surface: PrismetGameLaunchSurface
    public let platform: PrismetPlatform

    private enum CodingKeys: String, CodingKey {
        case featureID
        case mode
        case surface
        case platform
    }

    private init(
        featureID: PrismetFeatureID,
        mode: PrismetGameMode,
        surface: PrismetGameLaunchSurface,
        platform: PrismetPlatform
    ) {
        self.featureID = featureID
        self.mode = mode
        self.surface = surface
        self.platform = platform
    }

    public static func validated(
        featureID: PrismetFeatureID,
        mode: PrismetGameMode,
        surface: PrismetGameLaunchSurface,
        platform: PrismetPlatform
    ) throws -> PrismetGameLaunchContext {
        guard PrismetFeatureCatalog.feature(for: featureID) != nil else {
            throw PrismetGameLaunchValidationError.unknownFeature(featureID)
        }
        guard PrismetGameModeCatalog
            .playableModes(for: featureID, platform: platform)
            .contains(mode) else {
            throw PrismetGameLaunchValidationError.unavailableMode(
                featureID: featureID,
                mode: mode,
                platform: platform
            )
        }
        if surface == .parlor {
            let parlorIsAvailable = PrismetFeatureCatalog
                .feature(for: featureID)?
                .support(for: platform)?
                .status(for: .parlorTable)?
                .isAvailable == true
            guard parlorIsAvailable else {
                throw PrismetGameLaunchValidationError.unavailableSurface(
                    featureID: featureID,
                    surface: surface,
                    platform: platform
                )
            }
        }

        return PrismetGameLaunchContext(
            featureID: featureID,
            mode: mode,
            surface: surface,
            platform: platform
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = try Self.validated(
            featureID: container.decode(PrismetFeatureID.self, forKey: .featureID),
            mode: container.decode(PrismetGameMode.self, forKey: .mode),
            surface: container.decode(PrismetGameLaunchSurface.self, forKey: .surface),
            platform: container.decode(PrismetPlatform.self, forKey: .platform)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(featureID, forKey: .featureID)
        try container.encode(mode, forKey: .mode)
        try container.encode(surface, forKey: .surface)
        try container.encode(platform, forKey: .platform)
    }
}

public enum PrismetGameLaunchValidationError: Error, Equatable {
    case unknownFeature(PrismetFeatureID)
    case unavailableMode(
        featureID: PrismetFeatureID,
        mode: PrismetGameMode,
        platform: PrismetPlatform
    )
    case unavailableSurface(
        featureID: PrismetFeatureID,
        surface: PrismetGameLaunchSurface,
        platform: PrismetPlatform
    )
}

public enum PrismetGameModeCatalog {
    public static func playableModes(
        for featureID: PrismetFeatureID,
        platform: PrismetPlatform
    ) -> [PrismetGameMode] {
        guard let capabilities = PrismetFeatureCatalog
            .feature(for: featureID)?
            .support(for: platform)?
            .capabilities else {
            return []
        }

        let ordered: [(PrismetFeatureCapability, PrismetGameMode)] = [
            (.soloPlay, .soloBot),
            (.localTwoPlayer, .localTwoPlayer),
            (.onlineFriend, .onlineFriend)
        ]
        return ordered.compactMap { capability, mode in
            capabilities.contains(capability) ? mode : nil
        }
    }
}
