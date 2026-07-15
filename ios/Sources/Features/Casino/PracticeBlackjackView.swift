import PrismetShared
import SwiftUI

struct PracticeBlackjackView: View {
    @ObservedObject var session: PracticeBlackjackSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        GeometryReader { proxy in
            let layout = CasinoMobileLayoutPolicy.layout(
                isCompactWidth: horizontalSizeClass == .compact,
                usableWidth: proxy.size.width
            )

            switch layout {
            case .compact:
                compactLayout
            case .regular(let sidebarWidth):
                regularLayout(sidebarWidth: sidebarWidth)
            }
        }
        .sheet(item: $session.presentedSheet) { sheet in
            switch sheet {
            case .rulesAndFairness, .replayAndFairness:
                CasinoFairPlayView(auditSummary: session.auditSummary)
            case .corruptSave:
                CasinoCorruptSaveView(session: session)
            }
        }
    }

    private var compactLayout: some View {
        ScrollView {
            tableContent
                .padding(.horizontal, CasinoTheme.compactSpacing)
                .padding(.bottom, 118)
        }
        .safeAreaInset(edge: .bottom) {
            actionRail
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(CasinoTheme.panel)
                .overlay(alignment: .top) { Divider() }
        }
    }

    private func regularLayout(sidebarWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: CasinoTheme.regularSpacing) {
            ScrollView {
                tableContent
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(spacing: 16) {
                    rulesSummary
                    actionRail
                }
            }
            .frame(width: sidebarWidth)
        }
        .padding(.horizontal, CasinoTheme.regularSpacing)
        .padding(.bottom, CasinoTheme.regularSpacing)
    }

    private var tableContent: some View {
        VStack(spacing: 18) {
            tableStatus

            VStack(spacing: 22) {
                handSection(
                    title: "Dealer",
                    subtitle: dealerSubtitle,
                    cards: session.table.dealerCards
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel(dealerSummaryAccessibilityLabel)

                Divider()
                    .overlay(Color.white.opacity(0.24))

                handSection(
                    title: "Your hand",
                    subtitle: playerSubtitle,
                    cards: session.table.playerCards.map { .faceUp($0) }
                )
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [CasinoTheme.feltTop, CasinoTheme.feltBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(colorSchemeContrast == .increased ? 0.58 : 0.24),
                                lineWidth: colorSchemeContrast == .increased ? 2 : 1
                            )
                    )
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.20),
                value: session.table.playerCards.count
            )

            if let odds = session.table.hitOdds {
                hitOddsView(odds)
            }

        }
        .padding(.top, 4)
    }

    private var tableStatus: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                if differentiateWithoutColor {
                    Image(systemName: statusSymbol)
                        .accessibilityHidden(true)
                }
                Text(statusTitle)
                    .multilineTextAlignment(.center)
            }
            .font(.system(.title2, design: .serif, weight: .bold))
            Text(statusDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func handSection(
        title: String,
        subtitle: String,
        cards: [PrismetBlackjackDisplayedCard]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text(subtitle)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.78))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                        CasinoPlayingCardView(displayedCard: card)
                    }
                }
            }
        }
    }

    private func hitOddsView(_ odds: PrismetBlackjackHitOdds) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("If you Hit")
                    .font(.headline)
                Spacer(minLength: 8)
                Text(odds.probability, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(CasinoTheme.accent)
            }
            Text("\(odds.bustingCardCount) of \(odds.unseenCardCount) unseen cards would put this hand over 21.")
                .font(.body)
            Text(odds.assumption)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .casinoPanel()
        .accessibilityElement(children: .combine)
    }

    private var rulesSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(CasinoFairPlayCopy.rulesTitle, systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundStyle(CasinoTheme.accent)
            Text(CasinoFairPlayCopy.dealerPolicy)
                .font(.body)
            Text(session.auditSummary == nil ? CasinoFairPlayCopy.pendingAudit : "Replay & Fairness is ready for this completed hand.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .casinoPanel()
    }

    private var actionRail: some View {
        VStack(spacing: 10) {
            switch CasinoMobileActionPolicy.actions(canStartNewHand: session.canStartNewHand) {
            case .decisions:
                HStack(spacing: 10) {
                    Button("Hit") { session.hit() }
                        .buttonStyle(CasinoActionButtonStyle(prominent: true))
                        .disabled(!session.canHit)
                    Button("Stand") { session.stand() }
                        .buttonStyle(CasinoActionButtonStyle())
                        .disabled(!session.canStand)
                }

                if session.table.canEndHand {
                    Button("End Hand", role: .destructive) { session.endHand() }
                        .buttonStyle(CasinoActionButtonStyle())
                }
            case .newHand:
                Button("New Hand") { session.newHand() }
                    .buttonStyle(CasinoActionButtonStyle(prominent: true))
            }

            Button(session.auditSummary == nil ? "Rules & Fairness" : "Replay & Fairness") {
                session.presentedSheet = session.auditSummary == nil
                    ? .rulesAndFairness
                    : .replayAndFairness
            }
            .buttonStyle(CasinoActionButtonStyle())
        }
    }

    private var hiddenCardCount: Int {
        session.table.dealerCards.reduce(into: 0) { count, displayedCard in
            if case .faceDown = displayedCard { count += 1 }
        }
    }

    private var dealerSummaryAccessibilityLabel: String {
        let hiddenDescription = hiddenCardCount == 1
            ? "1 hidden card"
            : "\(hiddenCardCount) hidden cards"
        if let finalValue = session.table.dealerFinalValue {
            return "Dealer total \(finalValue.total), no hidden cards"
        }
        return "Dealer visible total \(session.table.dealerVisibleValue.total), \(hiddenDescription)"
    }

    private var dealerSubtitle: String {
        if let value = session.table.dealerFinalValue {
            return "Total \(value.total)"
        }
        return "Visible \(session.table.dealerVisibleValue.total) · \(hiddenCardCount) hidden"
    }

    private var playerSubtitle: String {
        let value = session.table.playerValue
        if value.isBust { return "Total \(value.total) · over 21" }
        return "\(value.isSoft ? "Soft " : "Total ")\(value.total)"
    }

    private var statusTitle: String {
        guard let resolution = session.table.resolution else {
            return session.loadState == .loading ? "Restoring table…" : "Your decision"
        }
        switch resolution.outcome {
        case .playerWins: return "Hand complete"
        case .dealerWins: return "Hand complete"
        case .tie: return "Equal totals"
        case .abandoned: return "Hand ended"
        }
    }

    private var statusSymbol: String {
        switch session.table.phase {
        case .playerTurn, .dealerTurn: return "hand.tap.fill"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "stop.circle.fill"
        }
    }

    private var statusDetail: String {
        guard let resolution = session.table.resolution else {
            return "Choose Hit, Stand, or End Hand."
        }
        switch resolution.reason {
        case .playerNatural: return "Your two-card 21 is higher."
        case .dealerNatural: return "Dealer has a two-card 21."
        case .playerBust: return "Your total went over 21."
        case .dealerBust: return "Dealer total went over 21."
        case .playerHigherTotal: return "Your total is higher."
        case .dealerHigherTotal: return "Dealer total is higher."
        case .equalTotals: return "Both hands have the same total."
        case .endedByPlayer: return "No result was recorded."
        }
    }
}

private struct CasinoCorruptSaveView: View {
    @ObservedObject var session: PracticeBlackjackSession

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(CasinoTheme.accent)
                    .accessibilityHidden(true)
                Text("This saved hand could not be opened.")
                    .font(.title2.bold())
                Text("You can keep a diagnostic copy before starting a fresh practice hand. Nothing will be replaced until you choose Start Fresh.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Button("Preserve Diagnostic Copy") {
                    Task { await session.preserveDiagnosticCopy() }
                }
                .buttonStyle(CasinoActionButtonStyle())
                Button("Start Fresh") {
                    Task { await session.startFresh() }
                }
                .buttonStyle(CasinoActionButtonStyle(prominent: true))
            }
            .padding(24)
            .navigationTitle("Saved Hand")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
