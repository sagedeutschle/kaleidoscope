import SwiftUI
import WatchFieldDeckCore

enum WatchTheme {
    static let navy = Color(hex: "08111F")
    static let panel = Color(hex: "132338")
    static let panelRaised = Color(hex: "1B314C")
    static let gold = Color(hex: "F4C95D")
    static let cyan = Color(hex: "4DD8E8")
    static let mint = Color(hex: "62E6A7")
    static let muted = Color(hex: "A9B7C8")
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: .whitespacesAndNewlines))
            .scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension PulseState {
    var fieldLabel: String {
        switch self {
        case .shipped: "Shipped"
        case .ready: "Ready"
        case .active: "Active"
        case .queued: "Queued"
        case .guarded: "Guarded"
        }
    }

    var fieldColor: Color {
        switch self {
        case .shipped: WatchTheme.mint
        case .ready: WatchTheme.cyan
        case .active: WatchTheme.gold
        case .queued: Color(hex: "A78BFA")
        case .guarded: Color(hex: "FB923C")
        }
    }
}

struct FieldDeckCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
        }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(WatchTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

struct PulsePill: View {
    let state: PulseState

    var body: some View {
        Text(state.fieldLabel.uppercased())
            .font(.system(size: 9, weight: .black, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(state.fieldColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(state.fieldColor.opacity(0.14), in: Capsule())
    }
}

extension View {
    func fieldDeckBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(WatchTheme.navy)
    }
}
