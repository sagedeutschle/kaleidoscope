import SwiftUI

enum CasinoMacPresentation: Equatable {
    case stacked
    case split
}

enum CasinoMacLayoutPolicy {
    static let splitBreakpoint: CGFloat = 860

    static func presentation(for width: CGFloat) -> CasinoMacPresentation {
        width < splitBreakpoint ? .stacked : .split
    }

    static func sidebarWidth(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<1_000:
            return 230
        case ..<1_280:
            return 260
        default:
            return 280
        }
    }
}

struct CasinoMacCommandAvailability: Equatable {
    let hit: Bool
    let stand: Bool
    let newHand: Bool
    let replay: Bool
    let leave: Bool

    init(
        canHit: Bool,
        canStand: Bool,
        canStartNewHand: Bool,
        hasReplay: Bool
    ) {
        hit = canHit
        stand = canStand
        newHand = canStartNewHand
        replay = hasReplay
        leave = true
    }
}

enum CasinoMacKeyboardHints {
    static let hit = "Return or H"
    static let stand = "S"
    static let newHand = "Command-N"
    static let replay = "Command-R"
    static let leave = "Escape"
}

enum CasinoTheme {
    static let feltTop = Color(red: 0.055, green: 0.235, blue: 0.19)
    static let feltBottom = Color(red: 0.025, green: 0.105, blue: 0.095)
    static let warmIvory = Color(red: 0.985, green: 0.965, blue: 0.91)
    static let brass = Color(red: 0.86, green: 0.66, blue: 0.26)
    static let brassSoft = Color(red: 0.96, green: 0.83, blue: 0.49)
    static let ink = Color(red: 0.11, green: 0.12, blue: 0.12)
    static let mutedInk = Color(red: 0.32, green: 0.34, blue: 0.34)
    static let danger = Color(red: 0.71, green: 0.18, blue: 0.2)
    static let panel = Color.white.opacity(0.09)
    static let panelBorder = Color.white.opacity(0.18)
    static let cornerRadius: CGFloat = 16

    static var feltBackground: LinearGradient {
        LinearGradient(
            colors: [feltTop, feltBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct CasinoPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(CasinoTheme.panel, in: RoundedRectangle(cornerRadius: CasinoTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: CasinoTheme.cornerRadius)
                    .stroke(CasinoTheme.panelBorder, lineWidth: 1)
            }
    }
}

extension View {
    func casinoPanel() -> some View {
        modifier(CasinoPanelModifier())
    }

    func casinoFocusRing(_ isFocused: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? CasinoTheme.brassSoft : .clear, lineWidth: 3)
                .padding(-3)
        }
    }
}
