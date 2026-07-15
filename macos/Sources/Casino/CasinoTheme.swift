import Foundation
import SwiftUI

enum CasinoMacPresentation: Equatable {
    case stacked
    case split
}

enum CasinoMacLayoutPolicy {
    static let splitBreakpoint: CGFloat = 860
    static let tableCanvasMinimumHeight: CGFloat = 560

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

enum CasinoProbabilityRosetteStyle: Equatable {
    case watermark
    case wheel
}

private struct CasinoRosetteSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct CasinoProbabilityRosette: View {
    static let segmentCount = 12

    let style: CasinoProbabilityRosetteStyle
    var highlightedSegment: Int? = nil
    var diameter: CGFloat = 208

    var body: some View {
        ZStack {
            ForEach(0..<Self.segmentCount, id: \.self) { index in
                let segment = CasinoRosetteSegment(
                    startAngle: .degrees(Double(index * 30) - 90),
                    endAngle: .degrees(Double((index + 1) * 30) - 90)
                )
                segment
                    .fill(segmentFill(index))
                    .overlay {
                        segment.stroke(
                            highlightedSegment == index + 1 ? CasinoTheme.brass : segmentBorder,
                            lineWidth: highlightedSegment == index + 1 ? 3 : 1
                        )
                    }
            }

            if style == .wheel {
                GeometryReader { proxy in
                    ForEach(0..<Self.segmentCount, id: \.self) { index in
                        let angle = (Double(index) * 30 - 75) * Double.pi / 180
                        Text("\(index + 1)")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundStyle(index < 6 ? CasinoTheme.ink : CasinoTheme.warmIvory)
                            .position(
                                x: proxy.size.width / 2 + cos(angle) * proxy.size.width * 0.35,
                                y: proxy.size.height / 2 + sin(angle) * proxy.size.height * 0.35
                            )
                    }
                }
                Circle()
                    .fill(CasinoTheme.brass)
                    .frame(width: 17, height: 17)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var segmentBorder: Color {
        style == .wheel ? CasinoTheme.brass.opacity(0.72) : CasinoTheme.warmIvory.opacity(0.16)
    }

    private func segmentFill(_ index: Int) -> Color {
        switch style {
        case .watermark:
            return index.isMultiple(of: 2)
                ? CasinoTheme.warmIvory.opacity(0.08)
                : CasinoTheme.brass.opacity(0.08)
        case .wheel:
            return index < 6 ? CasinoTheme.warmIvory : CasinoTheme.studyEmerald
        }
    }

    private var accessibilityLabel: String {
        if let highlightedSegment {
            return "Twelve equal segments. Segment \(highlightedSegment) revealed."
        }
        return style == .wheel
            ? "Fair Wheel with twelve equal numbered segments"
            : "Twelve-part equal-probability rosette"
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
    static let primaryAction = "Return"
    static let resetSession = "Command-R"
    static let leaveGame = "Escape"
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
    static let minimumTarget: CGFloat = 44
    static let studyEmerald = Color(red: 0.043, green: 0.239, blue: 0.204)
    static let mutedIvory = Color(red: 0.91, green: 0.894, blue: 0.847)
    static let darkBrass = Color(red: 0.541, green: 0.353, blue: 0)

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
