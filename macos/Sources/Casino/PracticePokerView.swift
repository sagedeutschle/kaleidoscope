import Foundation
import PrismetShared
import SwiftUI

struct PracticePokerView: View {
    @ObservedObject var session: PracticeCasinoSession
    let descriptor: PrismetPracticeCasinoGameDescriptor
    let onLeave: () -> Void

    @FocusState private var dealFocused: Bool
    @AccessibilityFocusState private var accessibilityFocusState: Bool
    @State private var showingResetConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(descriptor.title)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                    Text("Deal five cards, hold any cards, then draw once.")
                        .foregroundStyle(.white.opacity(0.72))
                    Label("Practice only. No money or transferable value.", systemImage: "checkmark.shield")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(CasinoTheme.brassSoft)
                }
                if let state = session.pokerState {
                    cardRow(state)
                    Text(state.phase == .complete ? "Complete · \(state.category?.displayName ?? "Hand classified")" : "Choose cards to hold")
                        .font(.title3.bold())
                    if state.phase == .complete {
                        Text("Seed \(state.seed) · randomizer v\(state.randomizerVersion)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else {
                    HStack(spacing: 16) {
                        CasinoProbabilityRosette(style: .watermark, diameter: 92)
                            .background(CasinoTheme.studyEmerald, in: Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text("The table waits for an explicit deal.")
                                .font(.title3.weight(.semibold))
                            Text("Five tactile cards arrive together. Choose any holds, then draw once.")
                                .foregroundStyle(.white.opacity(0.76))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .casinoPanel()
                }
                actionRail
                PokerProbabilityLedger()
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: session.pokerState)
        .onExitCommand(perform: onLeave)
    }

    private func cardRow(_ state: PrismetFiveCardPokerState) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Array(state.cards.enumerated()), id: \.offset) { index, card in
                    Button { session.togglePokerHold(at: index) } label: {
                        VStack(spacing: 5) {
                            CasinoPlayingCardView(card: .faceUp(card))
                            if state.heldIndices.contains(index) {
                                Label("Selected", systemImage: differentiateWithoutColor ? "checkmark" : "hand.raised.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(CasinoTheme.brassSoft)
                            } else {
                                Text("Hold")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                        .padding(4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(state.heldIndices.contains(index) ? CasinoTheme.brass : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(state.phase == .complete)
                    .accessibilityLabel("Card \(index + 1), \(card.accessibilityLabel(isFaceUp: true))\(state.heldIndices.contains(index) ? ", Selected" : "")")
                }
            }
        }
        .casinoPanel()
    }

    private var actionRail: some View {
        HStack(spacing: 10) {
            if session.pokerState == nil {
                Button("Deal Hand", systemImage: "rectangle.stack") { session.dealPoker() }
                    .buttonStyle(.borderedProminent)
                    .tint(CasinoTheme.brass)
                    .foregroundStyle(CasinoTheme.ink)
                    .keyboardShortcut(.defaultAction)
                    .focused($dealFocused)
                    .accessibilityFocused($accessibilityFocusState)
                    .casinoFocusRing(dealFocused || accessibilityFocusState)
            } else if session.pokerState?.phase == .choosingHolds {
                Button("Draw Once", systemImage: "arrow.down.right") { session.drawPoker() }
                    .buttonStyle(.borderedProminent)
                    .tint(CasinoTheme.brass)
                    .foregroundStyle(CasinoTheme.ink)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityFocused($accessibilityFocusState)
                    .casinoFocusRing(accessibilityFocusState)
            } else {
                Button("New Round", systemImage: "arrow.counterclockwise") { session.newRound() }
                    .buttonStyle(.borderedProminent)
                    .tint(CasinoTheme.brass)
                    .foregroundStyle(CasinoTheme.ink)
                    .keyboardShortcut(.defaultAction)
                    .focused($dealFocused)
                    .accessibilityFocused($accessibilityFocusState)
                    .casinoFocusRing(dealFocused || accessibilityFocusState)
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
}

private struct PokerProbabilityLedger: View {
    private static let total = 2_598_960
    private static let totalText = "2,598,960"
    private static let rows = [
        PokerProbabilityRow("High card", 1_302_540, "1,302,540"),
        PokerProbabilityRow("One pair", 1_098_240, "1,098,240"),
        PokerProbabilityRow("Two pair", 123_552, "123,552"),
        PokerProbabilityRow("Three of a kind", 54_912, "54,912"),
        PokerProbabilityRow("Straight", 10_200, "10,200"),
        PokerProbabilityRow("Flush", 5_108, "5,108"),
        PokerProbabilityRow("Full house", 3_744, "3,744"),
        PokerProbabilityRow("Four of a kind", 624, "624"),
        PokerProbabilityRow("Non-royal straight flush", 36, "36"),
        PokerProbabilityRow("Royal flush", 4, "4"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Exact opening-hand ledger", systemImage: "tablecells")
                .font(.headline)
            Text("Every opening hand is one of \(Self.totalText) equally likely five-card combinations.")
                .font(.callout)
                .foregroundStyle(CasinoTheme.mutedInk)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Category").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Exact count / all hands").frame(width: 230, alignment: .trailing)
                    Text("Share").frame(width: 90, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(CasinoTheme.mutedInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().overlay(CasinoTheme.ink.opacity(0.18))

                ForEach(Self.rows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.title)
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(row.countText) / \(Self.totalText)")
                            .monospacedDigit()
                            .frame(width: 230, alignment: .trailing)
                        Text(row.percentText)
                            .monospacedDigit()
                            .frame(width: 90, alignment: .trailing)
                    }
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)

                    if row.id != Self.rows.last?.id {
                        Divider().overlay(CasinoTheme.ink.opacity(0.12))
                    }
                }
            }
            .background(CasinoTheme.mutedIvory.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(CasinoTheme.ink.opacity(0.16), lineWidth: 1)
            }
        }
        .padding(16)
        .foregroundStyle(CasinoTheme.ink)
        .background(CasinoTheme.warmIvory, in: RoundedRectangle(cornerRadius: CasinoTheme.cornerRadius))
        .accessibilityElement(children: .contain)
    }
}

private struct PokerProbabilityRow: Identifiable {
    let title: String
    let count: Int
    let countText: String

    var id: String { title }
    var percentText: String {
        String(format: "%.4f%%", (Double(count) / Double(2_598_960)) * 100)
    }

    init(_ title: String, _ count: Int, _ countText: String) {
        self.title = title
        self.count = count
        self.countText = countText
    }
}

private extension PrismetPokerCategory {
    var displayName: String {
        switch self {
        case .highCard: "High card"
        case .onePair: "One pair"
        case .twoPair: "Two pair"
        case .threeOfAKind: "Three of a kind"
        case .straight: "Straight"
        case .flush: "Flush"
        case .fullHouse: "Full house"
        case .fourOfAKind: "Four of a kind"
        case .straightFlush: "Straight flush"
        case .royalFlush: "Royal flush"
        }
    }
}
