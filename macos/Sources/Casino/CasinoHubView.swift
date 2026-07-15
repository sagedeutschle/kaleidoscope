import SwiftUI

struct CasinoHubView: View {
    @StateObject private var session: PracticeBlackjackSession
    @Environment(\.dismiss) private var dismiss

    private let suppliedLeaveAction: (() -> Void)?

    init(
        previewSeed: UInt64? = nil,
        onLeave: (() -> Void)? = nil
    ) {
        _session = StateObject(
            wrappedValue: PracticeBlackjackSession(previewSeed: previewSeed)
        )
        suppliedLeaveAction = onLeave
    }

    var body: some View {
        GeometryReader { proxy in
            switch CasinoMacLayoutPolicy.presentation(for: proxy.size.width) {
            case .split:
                HStack(spacing: 0) {
                    gameSidebar
                        .frame(width: CasinoMacLayoutPolicy.sidebarWidth(for: proxy.size.width))
                    Divider()
                    PracticeBlackjackView(session: session, onLeave: leave)
                }
            case .stacked:
                VStack(spacing: 0) {
                    compactGameStrip
                    Divider()
                    PracticeBlackjackView(session: session, onLeave: leave)
                }
            }
        }
        .background(CasinoTheme.feltBottom)
        .task {
            await session.restoreOrDeal()
        }
    }

    private var gameSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Casino", systemImage: "suit.spade.fill")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("Practice tables")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 6)

            CasinoGameChoice(
                title: "Practice Blackjack",
                detail: "Playable now",
                symbol: "suit.spade.fill",
                selected: true
            )

            CasinoGameChoice(
                title: "Five-Card Poker",
                detail: "Coming next",
                symbol: "rectangle.stack",
                selected: false
            )
            .accessibilityLabel("Five-Card Poker, Coming next")

            Spacer()

            Text("No-money play · transparent rules")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
    }

    private var compactGameStrip: some View {
        HStack(spacing: 10) {
            CasinoGameChoice(
                title: "Practice Blackjack",
                detail: "Playable now",
                symbol: "suit.spade.fill",
                selected: true
            )
            CasinoGameChoice(
                title: "Five-Card Poker",
                detail: "Coming next",
                symbol: "rectangle.stack",
                selected: false
            )
            .accessibilityLabel("Five-Card Poker, Coming next")
        }
        .padding(12)
        .background(.regularMaterial)
    }

    private func leave() {
        if let suppliedLeaveAction {
            suppliedLeaveAction()
        } else {
            dismiss()
        }
    }
}

private struct CasinoGameChoice: View {
    let title: String
    let detail: String
    let symbol: String
    let selected: Bool

    @State private var pointerInside = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 24)
                .foregroundStyle(selected ? CasinoTheme.ink : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(selected ? CasinoTheme.ink.opacity(0.7) : .secondary)
            }
            Spacer(minLength: 2)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            selected ? CasinoTheme.brassSoft : Color.primary.opacity(pointerInside ? 0.07 : 0.035),
            in: RoundedRectangle(cornerRadius: 11)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(selected ? CasinoTheme.brass : Color.primary.opacity(0.1), lineWidth: 1)
        }
        .scaleEffect(pointerInside && !reduceMotion ? 1.01 : 1)
        .onHover { pointerInside = $0 }
        .accessibilityElement(children: .combine)
    }
}
