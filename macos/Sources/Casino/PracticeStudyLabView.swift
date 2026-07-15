import PrismetShared
import SwiftUI

/// Native, visit-scoped presentation for every shared Casino Study Lab snapshot.
struct PracticeStudyLabView: View {
    @ObservedObject var session: PracticeCasinoSession
    let descriptor: PrismetPracticeCasinoGameDescriptor
    let onLeave: () -> Void

    @FocusState private var primaryFocused: Bool
    @AccessibilityFocusState private var primaryAccessibilityFocused: Bool
    @State private var showingResetConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ScrollView {
            if let snapshot = session.studyLabSnapshot {
                VStack(alignment: .leading, spacing: 18) {
                    header(snapshot)
                    errorBanner
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 18) { outcomePanel(snapshot); summaryPanel(snapshot) }
                        VStack(alignment: .leading, spacing: 18) { outcomePanel(snapshot); summaryPanel(snapshot) }
                    }
                    cardGroups(snapshot)
                    if let dice = snapshot.dice { dicePanel(dice) }
                    if let wheel = snapshot.wheel { wheelPanel(wheel) }
                    ledgerPanel(snapshot)
                    rulesPanel
                    auditPanel(snapshot.audit)
                    actionRail(snapshot)
                }
                .frame(maxWidth: 1_000, minHeight: CasinoMacLayoutPolicy.tableCanvasMinimumHeight, alignment: .topLeading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .center)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: snapshot)
            } else {
                VStack(spacing: 12) {
                    ContentUnavailableView("Study Lab unavailable", systemImage: "exclamationmark.triangle", description: Text("Choose a Study Lab table to begin."))
                    errorBanner
                }
                .padding(40)
            }
        }
        .foregroundStyle(.white)
        .onExitCommand(perform: onLeave)
    }

    @ViewBuilder private var errorBanner: some View {
        if let errorMessage = session.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(CasinoTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .casinoPanel()
                .accessibilityLabel("Study Lab error: \(errorMessage)")
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func header(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(descriptor.title).font(.system(size: 31, weight: .bold, design: .rounded))
                    Text(descriptor.subtitle).foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Text("Phase: \(snapshot.phase.rawValue)")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(CasinoTheme.brassSoft)
            }
            Label("Adults 18+ · practice visit only · no money, purchases, wagering, prizes, rewards, or transferable value", systemImage: "checkmark.shield")
                .font(.callout.weight(.semibold)).foregroundStyle(CasinoTheme.brassSoft)
        }
        .accessibilityElement(children: .combine)
    }

    private func outcomePanel(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(snapshot.status, systemImage: "checkmark.seal")
                .font(.title3.bold()).foregroundStyle(CasinoTheme.brassSoft)
            if let result = snapshot.result { Text(result).font(.headline) }
            if let comparison = snapshot.comparison { Text("Comparison: \(comparison)") }
            if let category = snapshot.category { Text("Category: \(category)") }
            if let reference = snapshot.referenceCategory { Text("Reference: \(reference)") }
        }
        .frame(maxWidth: .infinity, alignment: .leading).casinoPanel()
        .accessibilityElement(children: .combine)
    }

    private func summaryPanel(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ordered summary").font(.headline)
            ForEach(Array(snapshot.summaryRows.enumerated()), id: \.offset) { _, row in
                HStack { Text(row.label); Spacer(); Text(row.value).foregroundStyle(CasinoTheme.brassSoft) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).casinoPanel()
    }

    @ViewBuilder private func cardGroups(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        if !snapshot.cards.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Cards").font(.headline)
                ForEach(Array(snapshot.cards.enumerated()), id: \.offset) { groupIndex, group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title).font(.subheadline.weight(.semibold))
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(Array(group.cards.enumerated()), id: \.offset) { index, card in
                                    let paiGowPosition = group.title == "Seven-card deal" ? index + 1 : nil
                                    cardTile(card, label: group.accessibilityLabels[index], position: paiGowPosition, snapshot: snapshot)
                                }
                            }.padding(.vertical, 2)
                        }.scrollIndicators(.hidden)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("\(group.title) cards")
                }
            }.casinoPanel()
        }
    }

    @ViewBuilder private func cardTile(_ card: PrismetCasinoStudyLabCard, label: String, position: Int?, snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        let selectable = descriptor.id == .paiGowSplitLab && position != nil
        let selected = position.map { snapshot.selectedPaiGowCardIndices.contains($0) } ?? false
        let canTogglePaiGowCard = selectable && (selected || snapshot.selectedPaiGowCardIndices.count < 2)
        if selectable {
            Button {
                if let position { session.togglePaiGowCard(at: position - 1) }
            } label: {
                cardFace(card, selected: selected)
            }
            .buttonStyle(.plain).disabled(!canTogglePaiGowCard)
            .accessibilityLabel("\(label)\(position.map { ", position \($0)" } ?? "")\(selected ? ", selected for low hand" : "")")
            .accessibilityHint(paiGowSelectionHint(isSelectable: selectable, isSelected: selected, selectedCount: snapshot.selectedPaiGowCardIndices.count))
        } else {
            cardFace(card, selected: selected)
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    @ViewBuilder private func cardFace(_ card: PrismetCasinoStudyLabCard, selected: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10).fill(CasinoTheme.warmIvory)
            switch card {
            case .standard(let value):
                VStack(alignment: .leading) {
                    Text(rankMark(value.rank)).font(.system(size: 25, weight: .bold, design: .rounded))
                    Text(suitMark(value.suit)).font(.system(size: 23, weight: .bold))
                    Spacer(); Text(suitMark(value.suit)).font(.system(size: 34))
                }.padding(9).foregroundStyle(suitColor(value.suit))
            case .hidden:
                Image(systemName: "sparkles").font(.title).foregroundStyle(CasinoTheme.brassSoft)
            case .joker:
                VStack { Text("JOKER").font(.caption.bold()); Image(systemName: "theatermasks.fill") }.foregroundStyle(CasinoTheme.darkBrass)
            }
        }
        .frame(width: 78, height: 112)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(selected ? CasinoTheme.brassSoft : CasinoTheme.ink.opacity(0.16), lineWidth: selected ? 4 : 1) }
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: differentiateWithoutColor ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(CasinoTheme.ink)
                    .padding(6)
                    .accessibilityHidden(true)
            }
        }
    }

    private func paiGowSelectionHint(isSelectable: Bool, isSelected: Bool, selectedCount: Int) -> String {
        guard isSelectable else { return "" }
        if isSelected { return "Selected for the low hand. Activate to deselect it." }
        if selectedCount >= 2 { return "Two cards already selected. Activate a selected card to deselect it before selecting another." }
        return "Activate to select this card for the two-card low hand."
    }

    private func dicePanel(_ dice: PrismetCasinoStudyLabDiceSnapshot) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(dice.values.enumerated()), id: \.offset) { _, value in
                DieFace(value: value)
            }
            VStack(alignment: .leading) { Text("Total \(dice.total)").font(.title3.bold()); if let pattern = dice.pattern { Text(pattern) } }
        }.frame(maxWidth: .infinity, alignment: .leading).casinoPanel().accessibilityLabel("Dice: \(dice.values.map(String.init).joined(separator: ", ")). Total \(dice.total). \(dice.pattern ?? "")")
    }

    private func wheelPanel(_ wheel: PrismetCasinoStudyLabWheelSnapshot) -> some View {
        HStack(spacing: 18) {
            EuropeanRouletteWheel(wheel: wheel)
            VStack(alignment: .leading) {
                Text("Pocket \(wheel.pocket)").font(.title2.bold())
                Text("Color: \(wheel.color.capitalized)").foregroundStyle(CasinoTheme.brassSoft)
                Text("European single-zero wheel · 37 pockets")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }.casinoPanel().accessibilityLabel("European roulette: pocket \(wheel.pocket), \(wheel.color)")
    }

    private func ledgerPanel(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exact counts & probabilities").font(.headline)
            ForEach(Array(snapshot.ledger.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.label); Spacer()
                    Text(row.value.displayText)
                        .font(.system(.callout, design: .monospaced).weight(.semibold)).foregroundStyle(CasinoTheme.brassSoft)
                }
            }
        }.casinoPanel()
    }

    private var rulesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Rules & fairness", systemImage: "checkmark.shield").font(.headline)
            Text(descriptor.rules)
            Text(descriptor.fairness).foregroundStyle(CasinoTheme.brassSoft)
            Text("Practice only: no money, purchases, wagering, prizes, rewards, or transferable value.")
                .font(.callout.weight(.semibold))
        }.casinoPanel()
    }

    private func auditPanel(_ audit: PrismetCasinoStudyLabAudit) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Audit trail").font(.headline)
            Text("Rules v\(audit.rulesVersion.map(String.init) ?? "—") · randomizer v\(audit.randomizerVersion.map(String.init) ?? "—")")
                .font(.system(.caption, design: .monospaced))
            if audit.seeds.isEmpty { Text("No seed consumed until an explicit random action.").foregroundStyle(.white.opacity(0.72)) }
            ForEach(audit.seeds, id: \.sequence) { entry in
                Text("#\(entry.sequence) · \(entry.seedUsage.displayText) · \(entry.action) · seed \(entry.seed)")
                    .font(.system(.caption, design: .monospaced))
                    .accessibilityLabel("Audit \(entry.sequence): \(entry.seedUsage.displayText), \(entry.action), seed \(entry.seed)")
            }
        }.casinoPanel()
    }

    private func actionRail(_ snapshot: PrismetCasinoStudyLabSnapshot) -> some View {
        HStack(spacing: 10) {
            if let primary = snapshot.primaryAction, primary.enabled {
                Button(primary.title, action: session.performStudyLabPrimary)
                    .buttonStyle(.borderedProminent).tint(CasinoTheme.brass).foregroundStyle(CasinoTheme.ink)
                    .frame(minHeight: CasinoTheme.minimumTarget).keyboardShortcut(.defaultAction)
                    .focused($primaryFocused).accessibilityFocused($primaryAccessibilityFocused)
                    .casinoFocusRing(primaryFocused || primaryAccessibilityFocused)
                    .accessibilityHint("\(CasinoMacKeyboardHints.primaryAction). \(primary.requiresSeed ? "Uses one audit seed." : "Uses no seed.")")
                if snapshot.secondaryNewRoundTitle != nil {
                    Button("New Round", systemImage: "arrow.counterclockwise", action: session.newRound)
                        .buttonStyle(.bordered).frame(minHeight: CasinoTheme.minimumTarget)
                        .accessibilityHint("Starts a ready state without consuming a seed.")
                }
                Text("Return: \(primary.title) · Escape: leave").font(.caption).foregroundStyle(.white.opacity(0.72))
            } else if snapshot.secondaryNewRoundTitle != nil {
                if let primary = snapshot.primaryAction {
                    Button(primary.title, action: session.performStudyLabPrimary)
                        .buttonStyle(.bordered).frame(minHeight: CasinoTheme.minimumTarget)
                        .disabled(true)
                        .accessibilityHint("Complete the required study step before continuing.")
                }
                Button("New Round", systemImage: "arrow.counterclockwise", action: session.newRound)
                    .buttonStyle(.bordered).frame(minHeight: CasinoTheme.minimumTarget)
                    .keyboardShortcut(.defaultAction)
                    .focused($primaryFocused).accessibilityFocused($primaryAccessibilityFocused)
                    .casinoFocusRing(primaryFocused || primaryAccessibilityFocused)
                    .accessibilityHint("Starts a ready state without consuming a seed.")
                Text("Return: New Round · Escape: leave").font(.caption).foregroundStyle(.white.opacity(0.72))
            } else {
                if let primary = snapshot.primaryAction {
                    Button(primary.title, action: session.performStudyLabPrimary)
                        .buttonStyle(.bordered).frame(minHeight: CasinoTheme.minimumTarget)
                        .disabled(true)
                        .accessibilityHint("Complete the required study step before continuing.")
                }
                Text("Escape: leave").font(.caption).foregroundStyle(.white.opacity(0.72))
            }
            Button("Reset Session", systemImage: "trash") { showingResetConfirmation = true }
                .buttonStyle(.bordered)
                .keyboardShortcut("r", modifiers: .command)
            Spacer()
            Button("Leave Game", systemImage: "door.left.hand.open", action: onLeave).buttonStyle(.bordered).frame(minHeight: CasinoTheme.minimumTarget)
        }
        .confirmationDialog("Reset Session", isPresented: $showingResetConfirmation) {
            Button("Reset Session", role: .destructive) { _ = session.resetSession(confirming: true) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Adults 18+ only. This clears Chance, Poker, and Study Lab visit state; no money, purchases, wagering, prizes, rewards, or transferable value are involved. Existing Blackjack audit save is preserved.")
        }
    }

    private func rankMark(_ rank: PrismetCardRank) -> String { switch rank { case .ace: "A"; case .king: "K"; case .queen: "Q"; case .jack: "J"; default: String(rank.rawValue) } }
    private func suitMark(_ suit: PrismetCardSuit) -> String { switch suit { case .clubs: "♣"; case .diamonds: "♦"; case .hearts: "♥"; case .spades: "♠" } }
    private func suitColor(_ suit: PrismetCardSuit) -> Color { switch suit { case .diamonds, .hearts: CasinoTheme.danger; case .clubs, .spades: CasinoTheme.ink } }
}

private struct DieFace: View {
    let value: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(0..<9, id: \.self) { index in
                Circle()
                    .fill(CasinoTheme.ink)
                    .opacity(pipPositions(for: value).contains(index) ? 1 : 0)
                    .accessibilityHidden(true)
            }
        }
        .padding(8)
        .frame(width: 52, height: 52)
        .background(CasinoTheme.warmIvory, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(CasinoTheme.brass.opacity(0.55), lineWidth: 1) }
        .accessibilityLabel("Die showing \(value)")
    }

    private func pipPositions(for value: Int) -> Set<Int> {
        guard (1...6).contains(value) else { return [] }
        return switch value {
        case 1: [4]
        case 2: [0, 8]
        case 3: [0, 4, 8]
        case 4: [0, 2, 6, 8]
        case 5: [0, 2, 4, 6, 8]
        default: [0, 2, 3, 5, 6, 8]
        }
    }
}

private struct RoulettePocketSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct EuropeanRouletteWheel: View {
    static let pocketOrder: [Int] = [
        0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
        5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26
    ]

    let wheel: PrismetCasinoStudyLabWheelSnapshot

    var body: some View {
        ZStack {
            ForEach(Self.pocketOrder.indices, id: \.self) { index in
                let pocket = Self.pocketOrder[index]
                let segment = RoulettePocketSegment(startAngle: angle(for: index), endAngle: angle(for: index + 1))
                segment
                    .fill(pocketColor(pocket))
                    .overlay { segment.stroke(CasinoTheme.brass.opacity(0.62), lineWidth: pocket == wheel.pocket ? 3 : 0.7) }
            }
            Circle().fill(CasinoTheme.feltBottom).padding(35)
            VStack(spacing: 3) {
                Text("Pocket \(wheel.pocket)").font(.system(.caption, design: .rounded).weight(.bold))
                Text(wheel.color.capitalized).font(.system(size: 9, weight: .semibold, design: .rounded))
                Text("37 pockets").font(.system(size: 8, weight: .medium, design: .monospaced))
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(CasinoTheme.warmIvory)
            .accessibilityHidden(true)
        }
        .frame(width: 174, height: 174)
        .overlay { Circle().stroke(CasinoTheme.brass, lineWidth: 2) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("European roulette wheel with 37 pockets. Observed pocket \(wheel.pocket), \(wheel.color).")
        .accessibilityHint("The highlighted division is the observed result.")
        .onAppear { precondition(Self.pocketOrder.count == 37) }
    }

    private func angle(for index: Int) -> Angle {
        .degrees(Double(index) * (360 / Double(Self.pocketOrder.count)) - 90)
    }

    private func pocketColor(_ pocket: Int) -> Color {
        if pocket == 0 { return CasinoTheme.studyEmerald }
        return Self.redPockets.contains(pocket) ? CasinoTheme.danger : CasinoTheme.ink
    }

    private static let redPockets: Set<Int> = [
        1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36
    ]
}
