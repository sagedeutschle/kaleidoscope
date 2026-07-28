public enum MookiesBrandIdentity {
    public static let appName = "Mookie's Arcade"
    public static let casinoName = "Reynard's Casino"
    public static let studioName = "Prismet"
}

public enum MookiesBrandCharacter: String, CaseIterable, Equatable, Hashable, Sendable {
    case mookie
    case reynard
}

public struct MookiesMascotPresentation: Equatable, Sendable {
    public let character: MookiesBrandCharacter
    public let assetName: String
    public let title: String
    public let message: String
    public let accessibilityLabel: String
    public let isDismissible: Bool
    public let overlaysPrimaryPlay: Bool
    public let affectsGameOutcome: Bool

    public init(
        character: MookiesBrandCharacter,
        assetName: String,
        title: String,
        message: String,
        accessibilityLabel: String,
        isDismissible: Bool,
        overlaysPrimaryPlay: Bool,
        affectsGameOutcome: Bool
    ) {
        self.character = character
        self.assetName = assetName
        self.title = title
        self.message = message
        self.accessibilityLabel = accessibilityLabel
        self.isDismissible = isDismissible
        self.overlaysPrimaryPlay = overlaysPrimaryPlay
        self.affectsGameOutcome = affectsGameOutcome
    }
}

public struct MookiesCasinoMascotPresencePlan: Equatable, Sendable {
    public let primary: MookiesMascotPresentation
    public let secondary: MookiesMascotPresentation

    public var presentations: [MookiesMascotPresentation] {
        [primary, secondary]
    }

    public static let casino = MookiesCasinoMascotPresencePlan(
        primary: MookiesMascotPresentation(
            character: .reynard,
            assetName: "ReynardCasinoHost",
            title: "Reynard",
            message: "Welcome to my practice tables — the odds stay honest, even when I wink.",
            accessibilityLabel: "Reynard, casino host. Welcome to my practice tables. The odds stay honest.",
            isDismissible: true,
            overlaysPrimaryPlay: false,
            affectsGameOutcome: false
        ),
        secondary: MookiesMascotPresentation(
            character: .mookie,
            assetName: "MookieHost",
            title: "Mookie",
            message: "I’m your arcade guide. I’ll watch from the rail while you play.",
            accessibilityLabel: "Mookie, your arcade guide. Watching from the rail while you play.",
            isDismissible: true,
            overlaysPrimaryPlay: false,
            affectsGameOutcome: false
        )
    )

    public init(primary: MookiesMascotPresentation, secondary: MookiesMascotPresentation) {
        self.primary = primary
        self.secondary = secondary
    }
}

public struct MookiesCasinoMascotVisibility: Equatable, Sendable {
    private var dismissedCharacters: Set<MookiesBrandCharacter>

    public init(dismissedCharacters: Set<MookiesBrandCharacter> = []) {
        self.dismissedCharacters = dismissedCharacters
    }

    public func isVisible(_ character: MookiesBrandCharacter) -> Bool {
        !dismissedCharacters.contains(character)
    }

    public func visiblePresentations(
        in plan: MookiesCasinoMascotPresencePlan
    ) -> [MookiesMascotPresentation] {
        plan.presentations.filter { isVisible($0.character) }
    }

    public mutating func dismiss(_ character: MookiesBrandCharacter) {
        dismissedCharacters.insert(character)
    }

    public mutating func restoreAll() {
        dismissedCharacters.removeAll()
    }
}
