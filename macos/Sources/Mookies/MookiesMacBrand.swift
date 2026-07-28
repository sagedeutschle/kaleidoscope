import SwiftUI

enum MookiesMacPresentation: Equatable {
    case compact
    case standard
    case cinematic
}

enum MookiesMacLayoutPolicy {
    static let standardBreakpoint: CGFloat = 800
    static let cinematicBreakpoint: CGFloat = 1_180
    static let minimumTableHeight: CGFloat = 540

    static func presentation(for width: CGFloat) -> MookiesMacPresentation {
        switch width {
        case ..<standardBreakpoint:
            return .compact
        case ..<cinematicBreakpoint:
            return .standard
        default:
            return .cinematic
        }
    }

    static func mascotWidth(for width: CGFloat) -> CGFloat {
        switch presentation(for: width) {
        case .compact:
            return 132
        case .standard:
            return 172
        case .cinematic:
            return 218
        }
    }

    static func tableInset(for width: CGFloat) -> CGFloat {
        switch presentation(for: width) {
        case .compact:
            return 12
        case .standard:
            return 20
        case .cinematic:
            return 28
        }
    }
}

enum MookiesMacAsset {
    static let mookieHost = "MookieHost"
    static let reynardCasinoHost = "ReynardCasinoHost"
}

enum MookiesMacCopy {
    static let arcadeTitle = "Mookie's Arcade"
    static let casinoTitle = "Reynard's Casino"
    static let mookieHostLabel = "Mookie, the friendly arcade host"
    static let reynardHostLabel = "Reynard, the good-natured Casino host"
    static let mookieGreeting = "Nice one! I saved you a seat."
    static let reynardGreeting = "Welcome, friend. The theatre is yours."
    static let practiceDisclosure =
        "Practice play only. No money, purchases, wagering, prizes, rewards, or transferable value."
}

enum MookiesMacCharacter: Equatable {
    case mookie
    case reynard

    var assetName: String {
        switch self {
        case .mookie:
            return MookiesMacAsset.mookieHost
        case .reynard:
            return MookiesMacAsset.reynardCasinoHost
        }
    }

    var displayName: String {
        switch self {
        case .mookie:
            return "Mookie"
        case .reynard:
            return "Reynard"
        }
    }

    var role: String {
        switch self {
        case .mookie:
            return "Arcade host"
        case .reynard:
            return "Casino host"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .mookie:
            return MookiesMacCopy.mookieHostLabel
        case .reynard:
            return MookiesMacCopy.reynardHostLabel
        }
    }

    var accent: Color {
        switch self {
        case .mookie:
            return MookiesMacBrand.hatPurple
        case .reynard:
            return MookiesMacBrand.reynardOrange
        }
    }
}

enum MookiesMacBrand {
    static let nearBlack = Color(red: 0.043, green: 0.043, blue: 0.059)
    static let panel = Color(red: 0.078, green: 0.078, blue: 0.125)
    static let warmWhite = Color(red: 0.961, green: 0.953, blue: 0.925)
    static let hatPurple = Color(red: 0.486, green: 0.361, blue: 1.0)
    static let deepPurple = Color(red: 0.294, green: 0.180, blue: 0.514)
    static let reynardOrange = Color(red: 0.941, green: 0.412, blue: 0.165)
    static let bowTieRed = Color(red: 0.702, green: 0.071, blue: 0.169)
    static let feltEmerald = Color(red: 0.025, green: 0.255, blue: 0.190)
    static let feltShadow = Color(red: 0.008, green: 0.082, blue: 0.075)
    static let brass = Color(red: 0.929, green: 0.718, blue: 0.302)
    static let brassHighlight = Color(red: 1.0, green: 0.894, blue: 0.565)
    static let minimumTarget: CGFloat = 44
    static let stageCornerRadius: CGFloat = 26

    static var arcadeBackground: LinearGradient {
        LinearGradient(
            colors: [deepPurple.opacity(0.78), nearBlack, panel],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var feltBackground: LinearGradient {
        LinearGradient(
            colors: [feltEmerald, feltShadow],
            startPoint: .top,
            endPoint: .bottomTrailing
        )
    }

    static var brassRail: LinearGradient {
        LinearGradient(
            colors: [brassHighlight, brass, Color(red: 0.42, green: 0.25, blue: 0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
