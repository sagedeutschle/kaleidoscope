public enum MookiesIPadCasinoLayout: Equatable, Sendable {
    case stacked
    case balanced
    case panoramic
}

public enum MookiesIPadCasinoLayoutPolicy {
    public static func layout(
        width: Double,
        height: Double,
        isRegularWidth: Bool,
        usesAccessibilityText: Bool
    ) -> MookiesIPadCasinoLayout {
        guard isRegularWidth, !usesAccessibilityText, width >= 760, height >= 600 else {
            return .stacked
        }
        guard width >= 1_100, height >= 700 else {
            return .balanced
        }
        return .panoramic
    }
}

public enum MookiesCasinoMotionMode: Equatable, Sendable {
    case ambient
    case staticOnly
}

public enum MookiesCasinoMotionPolicy {
    public static func mode(reduceMotion: Bool) -> MookiesCasinoMotionMode {
        reduceMotion ? .staticOnly : .ambient
    }
}
