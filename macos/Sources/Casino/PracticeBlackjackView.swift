import PrismetShared
import SwiftUI

struct PracticeBlackjackView: View {
    private enum FocusedControl: Hashable {
        case hit
        case stand
        case endHand
        case newHand
        case replay
        case fairPlay
        case leave
    }

    @ObservedObject var session: PracticeBlackjackSession
    let onLeave: () -> Void

    @FocusState private var focusedControl: FocusedControl?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    init(
        session: PracticeBlackjackSession,
        onLeave: @escaping () -> Void = {}
    ) {
        self.session = session
        self.onLeave = onLeave
    }

    var body: some View {
        ZStack {
            CasinoTheme.feltBackground
                .ignoresSafeArea()

            tableContent

            if session.loadState == .loading {
                loadingOverlay
            }

            if case let .recoveryRequired(reason) = session.loadState {
                recoveryOverlay(reason)
            }
        }
        .foregroundStyle(.white)
        .onAppear(perform: moveFocusToAvailableAction)
        .onChange(of: session.table) { _, _ in
            moveFocusToAvailableAction()
        }
        .onChange(of: session.loadState) { _, _ in
            moveFocusToAvailableAction()
        }
        .onKeyPress(.return) {
            guard session.commandAvailability.hit else { return .ignored }
            session.hit()
            return .handled
        }
        .onExitCommand {
            onLeave()
        }
        .sheet(item: $session.presentedSheet) { sheet in
            CasinoFairPlayView(
                mode: sheet == .replay ? .replay : .fairPlay,
                hitOdds: session.table.hitOdds,
                audit: session.auditPresentation
            )
        }
    }

    private var tableContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tableHeader
                dealerHand
                playerHand

                if let resolution = session.table.resolution {
                    resultPanel(resolution)
                } else if let odds = session.table.hitOdds {
                    oddsPanel(odds)
                }

                if let errorMessage = session.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(CasinoTheme.brassSoft)
                        .accessibilityLabel(errorMessage)
                }

                actionRail
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.22),
            value: session.table.playerCards.count
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.22),
            value: session.table.dealerCards.count
        )
    }

    private var tableHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Practice Blackjack")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                    Text("One honest hand at a time")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button {
                    session.presentedSheet = .fairPlay
                } label: {
                    Label("Rules & Fairness", systemImage: "checkmark.shield")
                }
                .buttonStyle(.bordered)
                .focused($focusedControl, equals: .fairPlay)
                .casinoFocusRing(focusedControl == .fairPlay)
                .accessibilityLabel("Open Rules and Fairness")
            }

            Label(CasinoFairPlayCopy.firstHandDisclosure, systemImage: "leaf")
                .font(.callout.weight(.semibold))
                .foregroundStyle(CasinoTheme.brassSoft)
                .accessibilityLabel(CasinoFairPlayCopy.firstHandDisclosure)
        }
    }

    private var dealerHand: some View {
        handPanel(
            title: "Dealer",
            summary: dealerSummary,
            cards: session.table.dealerCards
        )
    }

    private var playerHand: some View {
        handPanel(
            title: "Your hand",
            summary: handValueSummary(session.table.playerValue),
            cards: session.table.playerCards.map(PrismetBlackjackDisplayedCard.faceUp)
        )
    }

    private func handPanel(
        title: String,
        summary: String,
        cards: [PrismetBlackjackDisplayedCard]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.bold())
                Spacer()
                Text(summary)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(CasinoTheme.brassSoft)
                    .accessibilityLabel("\(title), \(summary)")
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                        CasinoPlayingCardView(card: card)
                    }
                }
                .padding(.vertical, 5)
            }
            .scrollIndicators(.hidden)
        }
        .casinoPanel()
    }

    private func oddsPanel(_ odds: PrismetBlackjackHitOdds) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(CasinoTheme.brassSoft)
            VStack(alignment: .leading, spacing: 4) {
                Text("Bust on Hit")
                    .font(.headline)
                Text(odds.probability, format: .percent.precision(.fractionLength(1)))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("\(odds.bustingCardCount) of \(odds.unseenCardCount) unseen cards")
                    .font(.caption)
                Text(odds.assumption)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .casinoPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Hit bust probability \(odds.probability.formatted(.percent.precision(.fractionLength(1)))). \(odds.assumption)"
        )
    }

    private func resultPanel(_ resolution: PrismetBlackjackResolution) -> some View {
        HStack(spacing: 14) {
            if differentiateWithoutColor {
                Image(systemName: resultSymbol(resolution.outcome))
                    .font(.title2)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(resultTitle(resolution.outcome))
                    .font(.title2.bold())
                Text(resultDetail(resolution.reason))
                    .foregroundStyle(.white.opacity(0.78))
                Text("The result stays here until you choose New Hand.")
                    .font(.caption)
                    .foregroundStyle(CasinoTheme.brassSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .casinoPanel()
        .accessibilityElement(children: .combine)
    }

    private var actionRail: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { actionButtons }
            VStack(alignment: .leading, spacing: 10) { actionButtons }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var actionButtons: some View {
        let availability = session.commandAvailability

        if !session.canStartNewHand {
            Button {
                session.hit()
            } label: {
                Label("Hit", systemImage: "plus.rectangle.on.rectangle")
                    .frame(minWidth: 88)
            }
            .buttonStyle(.borderedProminent)
            .tint(CasinoTheme.brass)
            .foregroundStyle(CasinoTheme.ink)
            .keyboardShortcut("h", modifiers: [])
            .disabled(!availability.hit)
            .focused($focusedControl, equals: .hit)
            .casinoFocusRing(focusedControl == .hit)
            .accessibilityLabel("Hit. \(CasinoMacKeyboardHints.hit)")

            Button {
                session.stand()
            } label: {
                Label("Stand", systemImage: "hand.raised")
                    .frame(minWidth: 88)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("s", modifiers: [])
            .disabled(!availability.stand)
            .focused($focusedControl, equals: .stand)
            .casinoFocusRing(focusedControl == .stand)
            .accessibilityLabel("Stand. \(CasinoMacKeyboardHints.stand)")

            Button {
                session.endHand()
            } label: {
                Label("End Hand", systemImage: "xmark.circle")
                    .frame(minWidth: 96)
            }
            .buttonStyle(.bordered)
            .disabled(!session.canEndHand)
            .focused($focusedControl, equals: .endHand)
            .casinoFocusRing(focusedControl == .endHand)
            .accessibilityLabel("End the current hand")
        }

        if session.canStartNewHand {
            Button {
                session.newHand()
            } label: {
                Label("New Hand", systemImage: "plus.square")
                    .frame(minWidth: 104)
            }
            .buttonStyle(.borderedProminent)
            .tint(CasinoTheme.brass)
            .foregroundStyle(CasinoTheme.ink)
            .keyboardShortcut("n", modifiers: .command)
            .disabled(!availability.newHand)
            .focused($focusedControl, equals: .newHand)
            .casinoFocusRing(focusedControl == .newHand)
            .accessibilityLabel("New Hand. \(CasinoMacKeyboardHints.newHand)")

            Button {
                session.showReplay()
            } label: {
                Label("Replay", systemImage: "arrow.counterclockwise")
                    .frame(minWidth: 88)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("r", modifiers: .command)
            .disabled(!availability.replay)
            .focused($focusedControl, equals: .replay)
            .casinoFocusRing(focusedControl == .replay)
            .accessibilityLabel("Replay. \(CasinoMacKeyboardHints.replay)")
        }

        Spacer(minLength: 4)

        Button {
            onLeave()
        } label: {
            Label("Leave", systemImage: "door.left.hand.open")
        }
        .buttonStyle(.bordered)
        .focused($focusedControl, equals: .leave)
        .casinoFocusRing(focusedControl == .leave)
        .accessibilityLabel("Leave. \(CasinoMacKeyboardHints.leave)")
    }

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Restoring the table…")
                .font(.headline)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private func recoveryOverlay(_ reason: PracticeBlackjackSession.RecoveryReason) -> some View {
        VStack(spacing: 14) {
            Image(systemName: reason == .corrupt ? "doc.badge.gearshape" : "arrow.up.doc")
                .font(.system(size: 34))
                .foregroundStyle(CasinoTheme.brassSoft)
            Text("Saved hand needs attention")
                .font(.title3.bold())
            Text(session.errorMessage ?? "Start Fresh keeps a diagnostic copy first.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)
            Button("Start Fresh") {
                Task { await session.startFresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(CasinoTheme.brass)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }

    private var dealerSummary: String {
        if let finalValue = session.table.dealerFinalValue {
            return handValueSummary(finalValue)
        }
        let hiddenCount = session.table.dealerCards.reduce(into: 0) { count, card in
            if case .faceDown = card { count += 1 }
        }
        let hiddenText = hiddenCount == 1 ? "1 hidden card" : "\(hiddenCount) hidden cards"
        return "Visible \(session.table.dealerVisibleValue.total), \(hiddenText)"
    }

    private func handValueSummary(_ value: PrismetBlackjackHandValue) -> String {
        if value.isBust { return "Bust · \(value.total)" }
        if value.isNatural { return "Natural 21" }
        if value.isSoft { return "Soft \(value.total)" }
        return "Total \(value.total)"
    }

    private func resultTitle(_ outcome: PrismetBlackjackOutcome) -> String {
        switch outcome {
        case .playerWins: return "Player hand is higher"
        case .dealerWins: return "Dealer hand is higher"
        case .tie: return "Equal totals"
        case .abandoned: return "Hand ended"
        }
    }

    private func resultDetail(_ reason: PrismetBlackjackResolutionReason) -> String {
        switch reason {
        case .playerNatural: return "The player has a natural 21."
        case .dealerNatural: return "The dealer has a natural 21."
        case .playerBust: return "The player total is over 21."
        case .dealerBust: return "The dealer total is over 21."
        case .playerHigherTotal: return "The player total is closer to 21."
        case .dealerHigherTotal: return "The dealer total is closer to 21."
        case .equalTotals: return "Both hands have the same total."
        case .endedByPlayer: return "The player ended this hand."
        }
    }

    private func resultSymbol(_ outcome: PrismetBlackjackOutcome) -> String {
        switch outcome {
        case .playerWins: return "person.crop.circle.badge.checkmark"
        case .dealerWins: return "rectangle.portrait.on.rectangle.portrait"
        case .tie: return "equal.circle"
        case .abandoned: return "xmark.circle"
        }
    }

    private func moveFocusToAvailableAction() {
        if session.canHit {
            focusedControl = .hit
        } else if session.canStartNewHand {
            focusedControl = .newHand
        } else {
            focusedControl = .fairPlay
        }
    }
}
