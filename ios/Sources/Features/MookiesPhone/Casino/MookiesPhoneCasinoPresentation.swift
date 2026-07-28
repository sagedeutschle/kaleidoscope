import Foundation

/// Compact-width measurements for the decorative Casino shell.
///
/// The real table remains owned by the existing Casino destination. This value
/// only controls the surrounding theatre so it cannot alter a round or result.
public struct MookiesPhoneCasinoLayout: Equatable, Sendable {
    public let horizontalPadding: CGFloat
    public let hostDiameter: CGFloat
    public let stageCornerRadius: CGFloat
    public let minimumPlayHeight: CGFloat
    public let usesCondensedHostCopy: Bool

    public init(
        horizontalPadding: CGFloat,
        hostDiameter: CGFloat,
        stageCornerRadius: CGFloat,
        minimumPlayHeight: CGFloat,
        usesCondensedHostCopy: Bool
    ) {
        self.horizontalPadding = horizontalPadding
        self.hostDiameter = hostDiameter
        self.stageCornerRadius = stageCornerRadius
        self.minimumPlayHeight = minimumPlayHeight
        self.usesCondensedHostCopy = usesCondensedHostCopy
    }
}

/// Stable public contract for the commander-owned Casino integration seam.
public enum MookiesPhoneCasinoPresentation {
    public static let destinationName = "Reynard’s Casino"
    public static let hostAssetName = "ReynardCasinoHost"
    public static let minimumPlayWidth: CGFloat = 296
    public static let integrationSeam = "Place MookiesPhoneCasinoHostCard above the existing compact table and wrap its real table content in MookiesPhoneCasinoTableStage. Both views are presentation-only."

    public static func layout(usableWidth: CGFloat) -> MookiesPhoneCasinoLayout {
        if usableWidth < 390 {
            return MookiesPhoneCasinoLayout(
                horizontalPadding: 12,
                hostDiameter: 104,
                stageCornerRadius: 24,
                minimumPlayHeight: 300,
                usesCondensedHostCopy: true
            )
        }

        return MookiesPhoneCasinoLayout(
            horizontalPadding: 16,
            hostDiameter: 132,
            stageCornerRadius: 30,
            minimumPlayHeight: 360,
            usesCondensedHostCopy: false
        )
    }
}

/// Cosmetic host moods. Callers select a mood explicitly; this type never
/// observes odds, cards, randomization, session progress, or results.
public enum MookiesPhoneCasinoHostMood: String, CaseIterable, Equatable, Sendable {
    case welcome
    case tableReady
    case applause

    public var message: String {
        switch self {
        case .welcome:
            return "Welcome, friend. Pick a table and I’ll deal the theatre — never the odds."
        case .tableReady:
            return "Your practice table is ready. The next move is yours."
        case .applause:
            return "A flourish for the table! I’ll leave the result to fair play."
        }
    }

    public var accessibilityLabel: String {
        "Reynard, fox host of Reynard’s Casino. \(message)"
    }
}
