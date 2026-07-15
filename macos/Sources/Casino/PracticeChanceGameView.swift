import PrismetShared
import SwiftUI

struct PracticeChanceGameView: View {
    @ObservedObject var session: PracticeCasinoSession
    let descriptor: PrismetPracticeCasinoGameDescriptor
    let onLeave: () -> Void

    @FocusState private var actionFocused: Bool
    @AccessibilityFocusState private var accessibilityFocusState: Bool
    @State private var showingResetConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if descriptor.id == .fairWheel {
                    fairWheelDiagram
                }
                if let result = session.roundResult {
                    resultPanel(result)
                } else if descriptor.id == .higherLower {
                    higherLowerStage
                } else if !descriptor.choices.isEmpty {
                    choicePanel
                }
                if let errorMessage = session.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(CasinoTheme.brassSoft)
                }
                actionRail
                rulesInspector
            }
            .frame(
                maxWidth: 900,
                minHeight: CasinoMacLayoutPolicy.tableCanvasMinimumHeight,
                alignment: .center
            )
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .foregroundStyle(.white)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: session.roundResult)
        .onExitCommand(perform: onLeave)
    }

    private var fairWheelDiagram: some View {
        HStack(spacing: 22) {
            CasinoProbabilityRosette(style: .wheel, highlightedSegment: revealedWheelSegment, diameter: 228)
            VStack(alignment: .leading, spacing: 8) {
                Text("Twelve equal outcomes")
                    .font(.title3.bold())
                Text("Segments 1–6 are ivory. Segments 7–12 are emerald. Every segment is exactly 1/12, with no zero.")
                    .foregroundStyle(.white.opacity(0.78))
                Text("Ivory 6/12 · Emerald 6/12")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(CasinoTheme.brassSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .casinoPanel()
    }

    private var revealedWheelSegment: Int? {
        guard session.roundResult?.gameID == .fairWheel,
              let primary = session.roundResult?.tokens.first?.primary
        else { return nil }
        return Int(primary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(descriptor.title)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                    Text(descriptor.subtitle)
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Text("Phase: \(session.roundResult == nil ? "Ready" : "Complete")")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(CasinoTheme.brassSoft)
            }
            Label("Practice only. No money or transferable value.", systemImage: "checkmark.shield")
                .font(.callout.weight(.semibold))
                .foregroundStyle(CasinoTheme.brassSoft)
        }
    }

    private var choicePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose an option")
                .font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 10)], spacing: 10) {
                ForEach(descriptor.choices) { choice in
                    let selected = session.selectedChoiceIDs.contains(choice.id)
                    Button { session.toggleChoice(choice.id) } label: {
                        HStack {
                            Image(systemName: choice.symbol)
                            Text(choice.title)
                            Spacer(minLength: 2)
                            if selected { Image(systemName: "checkmark.circle.fill") }
                        }
                        .frame(minWidth: 110, minHeight: CasinoTheme.minimumTarget, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? CasinoTheme.brass : .white.opacity(0.65))
                    .background(selected ? CasinoTheme.brass.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("\(choice.title)\(selected ? ", Selected" : "")")
                }
            }
        }
        .casinoPanel()
    }

    private var higherLowerStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preview = session.higherLowerPreview {
                Label("Shown card: \(preview.shownCard.primary)", systemImage: preview.shownCard.symbol)
                    .font(.title3.bold())
                Text("Conditional odds from this card")
                    .font(.headline)
                ForEach(preview.probabilities, id: \.label) { line in
                    probabilityLine(line)
                }
                choicePanel
            } else {
                Text("Show one card first. Its rank sets the conditional odds.")
                Button("Show Card", systemImage: "rectangle.portrait.on.rectangle.portrait") {
                    session.showHigherLowerCard()
                }
                .buttonStyle(.borderedProminent)
                .tint(CasinoTheme.brass)
                .foregroundStyle(CasinoTheme.ink)
                .keyboardShortcut(.defaultAction)
                .focused($actionFocused)
                .accessibilityFocused($accessibilityFocusState)
                .casinoFocusRing(actionFocused || accessibilityFocusState)
            }
        }
        .casinoPanel()
    }

    private var actionRail: some View {
        HStack(spacing: 10) {
            if session.roundResult != nil {
                Button("New Round", systemImage: "arrow.counterclockwise") { session.newRound() }
                    .buttonStyle(.borderedProminent)
                    .tint(CasinoTheme.brass)
                    .foregroundStyle(CasinoTheme.ink)
                    .keyboardShortcut(.defaultAction)
                    .focused($actionFocused)
                    .accessibilityFocused($accessibilityFocusState)
                    .casinoFocusRing(actionFocused || accessibilityFocusState)
            } else if descriptor.id != .higherLower || session.higherLowerPreview != nil {
                Button { session.playRound() } label: {
                    Label(descriptor.id == .higherLower ? "Reveal Next" : descriptor.actionTitle, systemImage: "eye")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(CasinoTheme.brass)
                .foregroundStyle(CasinoTheme.ink)
                .keyboardShortcut(.defaultAction)
                .disabled(!selectionIsReady)
                .focused($actionFocused)
                .accessibilityFocused($accessibilityFocusState)
                .casinoFocusRing(actionFocused || accessibilityFocusState)
            }
            Button("Reset Session", systemImage: "trash") { showingResetConfirmation = true }
                .buttonStyle(.bordered)
                .keyboardShortcut("r", modifiers: .command)
            Spacer()
            Button("Leave Game", systemImage: "door.left.hand.open", action: onLeave)
                .buttonStyle(.bordered)
        }
        .confirmationDialog("Reset Session", isPresented: $showingResetConfirmation) {
            Button("Reset Session", role: .destructive) { _ = session.resetSession(confirming: true) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This clears compact and Poker visit state. Existing Blackjack audit save is preserved.")
        }
    }

    private var selectionIsReady: Bool {
        switch descriptor.selectionRule {
        case .none:
            return true
        case .exactly(let count):
            return session.selectedChoiceIDs.count == count
        }
    }

    private var rulesInspector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Rules & Fairness", systemImage: "checkmark.shield")
                .font(.headline)
            Text(descriptor.rules)
            Text(descriptor.fairness)
                .font(.callout)
                .foregroundStyle(CasinoTheme.brassSoft)
        }
        .casinoPanel()
    }

    private func probabilityLine(_ line: PrismetPracticeProbabilityLine) -> some View {
        HStack {
            Text(line.label)
            Spacer()
            Text("\(line.fraction.numerator)/\(line.fraction.denominator) · \(line.fraction.percentText)")
                .font(.system(.callout, design: .monospaced).weight(.semibold))
        }
    }

    private func resultPanel(_ result: PrismetPracticeRoundResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(result.title, systemImage: differentiateWithoutColor ? "checkmark.seal" : "sparkle")
                .font(.title3.bold())
            Text(result.detail)
            choiceSummary
            ForEach(result.tokens) { token in
                HStack {
                    Label("\(token.primary)\(token.secondary.map { " — \($0)" } ?? "")", systemImage: token.symbol)
                    if token.isSelected {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(token.isSelected ? CasinoTheme.brassSoft : .white)
                .accessibilityElement(children: .combine)
            }
            Divider()
            ForEach(result.probabilities, id: \.label) { line in
                HStack {
                    Text(line.label)
                    Spacer()
                    Text("\(line.fraction.numerator)/\(line.fraction.denominator) · \(line.fraction.percentText)")
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                }
            }
            Text("Seed \(result.seed) · randomizer v\(result.randomizerVersion)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .casinoPanel()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var choiceSummary: some View {
        let choices = descriptor.choices.filter { session.selectedChoiceIDs.contains($0.id) }
        if !choices.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(choices.count == 1 ? "Your choice" : "Your choices")
                    .font(.headline)
                ForEach(choices) { choice in
                    Label(choice.title, systemImage: "checkmark.circle.fill")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
