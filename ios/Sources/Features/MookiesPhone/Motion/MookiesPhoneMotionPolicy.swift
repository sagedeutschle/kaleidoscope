import Foundation

/// Resolved decorative-motion values for the compact Casino shell.
public struct MookiesPhoneMotionProfile: Equatable, Sendable {
    public let allowsContinuousDecoration: Bool
    public let transitionDuration: TimeInterval
    public let hostRestingScale: CGFloat

    public init(
        allowsContinuousDecoration: Bool,
        transitionDuration: TimeInterval,
        hostRestingScale: CGFloat
    ) {
        self.allowsContinuousDecoration = allowsContinuousDecoration
        self.transitionDuration = transitionDuration
        self.hostRestingScale = hostRestingScale
    }
}

public struct MookiesPhoneMotionTransform: Equatable, Sendable {
    public let opacity: Double
    public let scale: CGFloat
    public let yOffset: CGFloat
    public let duration: TimeInterval

    public init(
        opacity: Double,
        scale: CGFloat,
        yOffset: CGFloat,
        duration: TimeInterval
    ) {
        self.opacity = opacity
        self.scale = scale
        self.yOffset = yOffset
        self.duration = duration
    }
}

public enum MookiesPhoneCasinoMotionMoment: Equatable, Sendable {
    case entrance
    case celebration
    case settled
}

/// Centralizes Reduce Motion behavior so every decorative layer resolves to a
/// fully static identity transform when the accessibility preference is on.
public enum MookiesPhoneMotionPolicy {
    public static func profile(reduceMotion: Bool) -> MookiesPhoneMotionProfile {
        if reduceMotion {
            return MookiesPhoneMotionProfile(
                allowsContinuousDecoration: false,
                transitionDuration: 0,
                hostRestingScale: 1
            )
        }

        return MookiesPhoneMotionProfile(
            allowsContinuousDecoration: true,
            transitionDuration: 0.28,
            hostRestingScale: 1.018
        )
    }

    public static func transform(
        for moment: MookiesPhoneCasinoMotionMoment,
        reduceMotion: Bool
    ) -> MookiesPhoneMotionTransform {
        let resolvedProfile = profile(reduceMotion: reduceMotion)
        guard !reduceMotion else {
            return MookiesPhoneMotionTransform(
                opacity: 1,
                scale: 1,
                yOffset: 0,
                duration: 0
            )
        }

        switch moment {
        case .entrance:
            return MookiesPhoneMotionTransform(
                opacity: 0,
                scale: 0.97,
                yOffset: 12,
                duration: resolvedProfile.transitionDuration
            )
        case .celebration:
            return MookiesPhoneMotionTransform(
                opacity: 1,
                scale: 1.035,
                yOffset: -3,
                duration: resolvedProfile.transitionDuration
            )
        case .settled:
            return MookiesPhoneMotionTransform(
                opacity: 1,
                scale: 1,
                yOffset: 0,
                duration: resolvedProfile.transitionDuration
            )
        }
    }
}
