import PrismetShared
import SwiftUI

/// Snapshot-only presentation for all ten deterministic Study Labs.
struct PracticeStudyLabView: View {
    @ObservedObject var session: PracticeCasinoSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        if let snapshot = session.studyLabSnapshot {
            studyContent(snapshot)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: snapshot)
        } else {
            ContentUnavailableView("Study Lab unavailable", systemImage: "exclamationmark.triangle", description: Text("Choose a Study Lab table to begin a practice-only visit."))
        }
    }

    @ViewBuilder private func studyContent(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        if horizontalSizeClass == .regular {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    mainContent(snapshot).frame(minWidth: 360, maxWidth: .infinity, alignment: .leading)
                    auditPanel(snapshot).frame(width: 300, alignment: .topLeading)
                }
                compactStudyContent(snapshot)
            }
        } else {
            compactStudyContent(snapshot)
        }
    }

    private func compactStudyContent(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            mainContent(snapshot)
            auditPanel(snapshot)
        }
    }

    private func mainContent(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            statusPanel(snapshot)
            summaryPanel(snapshot)
            ForEach(Array(snapshot.cards.enumerated()), id: \.offset) { _, group in cardGroup(group, selectedPositions: snapshot.selectedPaiGowCardIndices) }
            if let dice = snapshot.dice { dicePanel(dice) }
            if let wheel = snapshot.wheel { wheelPanel(wheel) }
            ledgerPanel(snapshot.ledger)
            controls(snapshot)
        }
    }

    private func statusPanel(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(snapshot.title, systemImage: "book.closed.fill").font(.title3.bold()).foregroundStyle(CasinoTheme.ink)
            Text(snapshot.status).font(.body).foregroundStyle(.secondary)
            Text("Stage: \(phaseLabel(snapshot.phase))").font(.footnote.monospacedDigit()).foregroundStyle(CasinoTheme.ink.opacity(0.75))
            if let result = snapshot.result { Text(result).font(.subheadline.weight(.semibold)).foregroundStyle(CasinoTheme.ink) }
        }
        .casinoPanel().accessibilityElement(children: .combine)
    }

    private func phaseLabel(_ phase: PrismetCasinoStudyLabAdapter.Phase) -> String {
        switch phase {
        case .unstarted: "Not started"
        case .ready: "Ready"
        case .dealt: "Cards dealt"
        case .revealReady: "Ready to reveal"
        case .flop: "Flop"
        case .turn: "Turn"
        case .river: "River"
        case .tableau: "Tableau"
        case .initialDeal: "Initial deal"
        case .playerTableau: "Player tableau"
        case .bankerTableau: "Banker tableau"
        case .point: "Point established"
        case .warReady: "War ready"
        case .complete: "Complete"
        }
    }

    private func summaryPanel(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Study summary").font(.headline)
            ForEach(Array(snapshot.summaryRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline) { Text(row.label).foregroundStyle(.secondary); Spacer(minLength: 12); Text(row.value).multilineTextAlignment(.trailing).font(.body.weight(.semibold)).monospacedDigit() }
                    .accessibilityElement(children: .combine).accessibilityLabel("\(row.label): \(row.value)")
            }
        }.casinoPanel()
    }

    private func cardGroup(_ group: PrismetCasinoStudyLabCardGroup, selectedPositions: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.title).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58, maximum: 82), spacing: 9)], spacing: 9) {
                ForEach(Array(group.cards.enumerated()), id: \.offset) { index, card in
                    let position = index + 1
                    let selectable = session.selectedGameID == .paiGowSplitLab && group.title == "Seven-card deal"
                    if selectable {
                        let isSelected = selectedPositions.contains(position)
                        let hasReachedSelectionLimit = selectedPositions.count >= 2
                        Button { session.toggleStudyLabPaiGowCard(at: index) } label: {
                            StudyLabCardView(card: card, selected: isSelected, selectedPosition: position, differentiateWithoutColor: differentiateWithoutColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(hasReachedSelectionLimit && !isSelected)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityHint(isSelected
                            ? "Double tap to deselect this card from the low hand."
                            : hasReachedSelectionLimit
                                ? "Two-card selection limit reached. Deselect another selected card before selecting this card."
                                : "Card position \(position). Double tap to select it for the two-card low hand.")
                    } else {
                        StudyLabCardView(card: card, selected: false, selectedPosition: position, differentiateWithoutColor: differentiateWithoutColor)
                    }
                }
            }
        }.casinoPanel()
    }

    private func dicePanel(_ dice: PrismetCasinoStudyLabDiceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dice").font(.headline)
            HStack(spacing: 10) { ForEach(Array(dice.values.enumerated()), id: \.offset) { _, value in die(value) } }
            Text("Total \(dice.total)\(dice.pattern.map { " · \($0)" } ?? "")").font(.body.monospacedDigit()).accessibilityLabel("Dice total \(dice.total). \(dice.pattern ?? "")")
        }.casinoPanel()
    }

    private func die(_ value: Int) -> some View {
        Text("\(value)").font(.title2.bold().monospacedDigit()).foregroundStyle(CasinoTheme.ink).frame(width: 52, height: 52)
            .background(CasinoTheme.cardFace, in: RoundedRectangle(cornerRadius: 12, style: .continuous)).overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(CasinoTheme.accent, lineWidth: 1) }
            .accessibilityLabel("Die showing \(value)")
    }

    private func wheelPanel(_ wheel: PrismetCasinoStudyLabWheelSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("European roulette wheel").font(.headline)
            HStack { Text("Pocket \(wheel.pocket)").font(.title3.bold().monospacedDigit()); Spacer(); Label(wheel.color, systemImage: "circle.fill").foregroundStyle(wheel.color.lowercased() == "red" ? CasinoTheme.redSuit : wheel.color.lowercased() == "black" ? CasinoTheme.blackSuit : wheel.color.lowercased() == "green" ? CasinoTheme.feltTop : CasinoTheme.accent) }
                .accessibilityElement(children: .combine).accessibilityLabel("Roulette pocket \(wheel.pocket), \(wheel.color)")
        }.casinoPanel()
    }

    private func ledgerPanel(_ rows: [PrismetCasinoStudyLabLedgerRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exact counts & probabilities").font(.headline)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.label).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(row.displayText).font(.footnote.monospacedDigit()).multilineTextAlignment(.trailing)
                }.accessibilityElement(children: .combine).accessibilityLabel("\(row.label): \(row.displayText)")
            }
        }.casinoPanel()
    }

    private func auditPanel(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ordered audit").font(.headline)
                Text("Rules version: \(snapshot.audit.rulesVersion.map(String.init) ?? "Not started")").font(.footnote.monospacedDigit())
                Text("Randomizer version: \(snapshot.audit.randomizerVersion.map(String.init) ?? "Not started")").font(.footnote.monospacedDigit())
                if snapshot.audit.seeds.isEmpty { Text("No random seed has been consumed.").font(.footnote).foregroundStyle(.secondary) }
                ForEach(snapshot.audit.seeds, id: \.sequence) { seed in
                    Text("\(seed.sequence). \(seed.action): \(seed.seed) · \(seed.seedUsage.displayText)")
                        .font(.footnote.monospacedDigit())
                        .accessibilityLabel("Audit \(seed.sequence), \(seed.action), seed \(seed.seed). \(seed.seedUsage.displayText)")
                }
                Text("Practice only. No money, purchases, wagering, prizes, rewards, or transferable value.").font(.footnote.weight(.semibold)).foregroundStyle(CasinoTheme.ink)
            }.casinoPanel()
        }
    }

    private func controls(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(spacing: 10) {
            if let primaryAction = snapshot.primaryAction {
                Button { session.performStudyLabPrimaryAction() } label: { Label(primaryAction.title, systemImage: "play.circle.fill").frame(maxWidth: .infinity, minHeight: CasinoTheme.minimumTarget) }
                    .buttonStyle(CasinoActionButtonStyle(prominent: true)).disabled(!snapshot.primaryControlEnabled)
                    .accessibilityHint(primaryActionHint(primaryAction, snapshot: snapshot))
            }
            if let title = snapshot.secondaryNewRoundTitle { Button(title) { session.newRound() }.buttonStyle(CasinoActionButtonStyle()).frame(minHeight: CasinoTheme.minimumTarget).accessibilityHint("Starts an unplayed Study Lab round without consuming a seed.") }
        }
    }

    private func primaryActionHint(_ action: PrismetCasinoStudyLabPrimaryAction, snapshot: PrismetCasinoStudyLabSnapshot) -> String {
        if action.action == .reveal, snapshot.phase == .warReady {
            return "Reuses the original deal seed and consumes no new random draw."
        }
        return action.requiresSeed
            ? "Uses one fresh random seed only after this enabled action is chosen."
            : "Continues this deterministic study without consuming a seed."
    }
}

private struct StudyLabCardView: View {
    let card: PrismetCasinoStudyLabCard
    let selected: Bool
    let selectedPosition: Int
    let differentiateWithoutColor: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(face).overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(selected ? CasinoTheme.accent : Color.black.opacity(0.18), lineWidth: selected ? 3 : 1) }
            cardContent.padding(5)
            if selected { Image(systemName: differentiateWithoutColor ? "checkmark.circle.fill" : "checkmark.circle.fill").foregroundStyle(CasinoTheme.accent).padding(3).accessibilityHidden(true) }
        }
        .aspectRatio(0.68, contentMode: .fit).frame(maxWidth: 82).accessibilityElement(children: .ignore).accessibilityLabel(label)
    }

    private var face: Color { if case .hidden = card { return CasinoTheme.cardBack }; return CasinoTheme.cardFace }
    @ViewBuilder private var cardContent: some View {
        switch card {
        case .hidden: Image(systemName: "sparkles.rectangle.stack.fill").font(.title3).foregroundStyle(.white)
        case .joker: VStack(spacing: 3) { Text("JOKER").font(.caption2.bold()); Image(systemName: "theatermasks.fill") }.foregroundStyle(CasinoTheme.redSuit)
        case .standard(let value): VStack(spacing: 2) { Text(rank(value.rank)).font(.headline.bold()); Text(suit(value.suit)).font(.title2) }.foregroundStyle(color(value.suit))
        }
    }
    private var label: String { let base: String; switch card { case .hidden: base = "Face-down card"; case .joker: base = "Joker"; case .standard(let value): base = value.accessibilityLabel(isFaceUp: true) }; return selected ? "\(base), selected as low hand position \(selectedPosition)" : base }
    private func rank(_ rank: PrismetCardRank) -> String { switch rank { case .jack: "J"; case .queen: "Q"; case .king: "K"; case .ace: "A"; default: String(rank.rawValue) } }
    private func suit(_ suit: PrismetCardSuit) -> String { switch suit { case .clubs: "♣"; case .diamonds: "♦"; case .hearts: "♥"; case .spades: "♠" } }
    private func color(_ suit: PrismetCardSuit) -> Color { switch suit { case .diamonds, .hearts: CasinoTheme.redSuit; case .clubs, .spades: CasinoTheme.blackSuit } }
}
