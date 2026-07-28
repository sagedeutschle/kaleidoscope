import PrismetShared
import SwiftUI

struct PracticeChanceGameView: View {
    @ObservedObject var session: PracticeCasinoSession
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if session.descriptor.id == .fairWheel {
                fairWheelDiagram
            }
            if let result = session.roundResult {
                resultSurface(result)
            } else if let preview = session.higherLowerPreview {
                previewSurface(preview)
                choiceSurface
            } else if session.descriptor.id == .higherLower {
                Text("Show one card first. Its rank sets the conditional odds before you choose.")
            } else {
                choiceSurface
            }
            actionRow
        }
        .casinoPanel()
    }

    private var fairWheelDiagram: some View {
        VStack(spacing: 8) {
            CasinoProbabilityRosette(style: .wheel, highlightedSegment: revealedWheelSegment, diameter: 196)
            Text("12 equal segments · 6 ivory · 6 emerald · no zero")
                .font(.footnote.monospacedDigit().weight(.semibold))
                .foregroundStyle(CasinoTheme.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var revealedWheelSegment: Int? {
        guard session.roundResult?.gameID == .fairWheel,
              let primary = session.roundResult?.tokens.first?.primary
        else { return nil }
        return Int(primary)
    }

    private var choiceSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.descriptor.rules).font(.body)
            if !session.descriptor.choices.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                    ForEach(session.descriptor.choices) { choice in
                        let selected = session.selectedChoiceIDs.contains(choice.id)
                        Button { session.toggleChoice(choice.id) } label: {
                            Label(selected ? "\(choice.title) Selected" : choice.title, systemImage: selected && differentiateWithoutColor ? "checkmark.circle.fill" : choice.symbol)
                        }
                        .buttonStyle(CasinoActionButtonStyle(prominent: selected))
                        .accessibilityValue(selected ? "Selected" : "Not selected")
                    }
                }
            }
        }
    }

    private func previewSurface(_ preview: PrismetHigherLowerPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Shown card: \(preview.shownCard.primary)", systemImage: preview.shownCard.symbol)
                .font(.title3.bold())
            Text("Choose a relation, then reveal the next card. The conditional odds use the 51 unseen cards.")
            probabilityLines(preview.probabilities)
        }
    }

    private func resultSurface(_ result: PrismetPracticeRoundResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.title).font(.title3.bold())
            Text(result.detail)
            choiceSummary
            ForEach(result.tokens) { token in
                HStack {
                    Label("\(token.primary)\(token.secondary.map { " — \($0)" } ?? "")", systemImage: token.symbol)
                    if token.isSelected {
                        Label("Matched", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityElement(children: .combine)
            }
            probabilityLines(result.probabilities)
            Text("Seed \(result.seed) · randomizer v\(result.randomizerVersion)").font(.footnote.monospacedDigit())
        }
    }

    @ViewBuilder private var choiceSummary: some View {
        let choices = session.descriptor.choices.filter { session.selectedChoiceIDs.contains($0.id) }
        if !choices.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(choices.count == 1 ? "Your choice" : "Your choices")
                    .font(.headline)
                ForEach(choices) { choice in
                    Label(choice.title, systemImage: "checkmark.circle.fill")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func probabilityLines(_ lines: [PrismetPracticeProbabilityLine]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines, id: \.label) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(line.label)
                        .font(.footnote.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("\(line.fraction.numerator)/\(line.fraction.denominator) · \(line.fraction.percentText)")
                        .font(.footnote.monospacedDigit().weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                Divider().overlay(CasinoTheme.ink.opacity(0.14))
            }
        }
        .background(CasinoTheme.mutedIvory.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder private var actionRow: some View {
        if session.roundResult != nil {
            Button("New Round") { session.newRound() }.buttonStyle(CasinoActionButtonStyle(prominent: true))
        } else if session.descriptor.id == .higherLower {
            if session.higherLowerPreview == nil {
                Button("Show Card") { session.showHigherLowerCard() }.buttonStyle(CasinoActionButtonStyle(prominent: true))
            } else {
                Button("Reveal Next Card") { session.revealHigherLower() }
                    .buttonStyle(CasinoActionButtonStyle(prominent: true))
                    .disabled(session.selectedChoiceIDs.count != 1)
            }
        } else {
            Button(session.descriptor.actionTitle) { session.playRound() }
                .buttonStyle(CasinoActionButtonStyle(prominent: true))
                .disabled(!selectionIsReady)
        }
    }

    private var selectionIsReady: Bool {
        switch session.descriptor.selectionRule { case .none: return true; case .exactly(let count): return session.selectedChoiceIDs.count == count }
    }
}
