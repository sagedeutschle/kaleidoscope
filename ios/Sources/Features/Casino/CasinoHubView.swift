import SwiftUI

public struct CasinoHubView: View {
    @StateObject private var session: PracticeBlackjackSession
    @Environment(\.scenePhase) private var scenePhase

    public init(previewSeed: UInt64? = nil) {
        _session = StateObject(
            wrappedValue: PracticeBlackjackSession(previewSeed: previewSeed)
        )
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [CasinoTheme.feltBottom, Color(uiColor: .systemBackground)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                hubHeader
                PracticeBlackjackView(session: session)
            }
        }
        .task {
            await session.restoreOrDeal()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            Task { await session.persist() }
        }
    }

    private var hubHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Casino")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(CasinoTheme.headerPrimary)
                    Text("Calm practice tables with open rules")
                        .font(.subheadline)
                        .foregroundStyle(CasinoTheme.headerSecondary)
                }
                Spacer(minLength: 12)
                Image(systemName: "suit.spade.fill")
                    .font(.title2)
                    .foregroundStyle(CasinoTheme.accent)
                    .accessibilityHidden(true)
            }

            Text(CasinoFairPlayCopy.disclosure)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CasinoTheme.headerPrimary)

            HStack(spacing: 8) {
                Label("Practice Blackjack", systemImage: "rectangle.stack.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CasinoTheme.accent)
                Text("Five-Card Poker — Coming next")
                    .font(.caption)
                    .foregroundStyle(CasinoTheme.headerSecondary)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}
