import Foundation
import PrismetShared
import SwiftUI

struct PracticePokerView: View {
    @ObservedObject var session: PracticeCasinoSession
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let state = session.pokerState {
                hand(state)
            } else {
                preDealSurface
            }
            PokerProbabilityLedger()
            Button(actionTitle) { action() }
                .buttonStyle(CasinoActionButtonStyle(prominent: true))
        }
        .casinoPanel()
    }

    private var preDealSurface: some View {
        HStack(spacing: 14) {
            CasinoProbabilityRosette(style: .watermark, diameter: 72)
                .background(CasinoTheme.feltTop, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("The table is ready")
                    .font(.headline)
                Text("Deal five cards, choose any holds, then draw once.")
                    .font(.subheadline)
                    .foregroundStyle(CasinoTheme.mutedInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CasinoTheme.mutedIvory.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
    }

    private func hand(_ state: PrismetFiveCardPokerState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let category = state.category {
                Label("Final hand: \(category.title)", systemImage: "checkmark.seal")
                    .font(.title3.bold())
            } else {
                Text("Choose cards to hold")
                    .font(.headline)
                    .foregroundStyle(CasinoTheme.mutedInk)
            }

            HStack(alignment: .top, spacing: 5) {
                ForEach(Array(state.cards.enumerated()), id: \.offset) { index, card in
                    let held = state.heldIndices.contains(index)
                    Button { session.togglePokerHold(at: index) } label: {
                        CasinoPlayingCardView(displayedCard: .faceUp(card), maximumWidth: 72)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(held ? CasinoTheme.accent : .clear, lineWidth: 2)
                            }
                            .overlay(alignment: .bottom) {
                                if held {
                                    Label("Held", systemImage: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(CasinoTheme.ink)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(CasinoTheme.accent, in: Capsule())
                                        .offset(y: 6)
                                }
                            }
                            .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .disabled(state.phase != .choosingHolds)
                    .accessibilityLabel("Card \(index + 1), \(card.accessibilityLabel(isFaceUp: true))\(held ? ", Held" : "")")
                    .accessibilityValue(held ? "Held" : "Not held")
                    .overlay(alignment: .topTrailing) {
                        if held && differentiateWithoutColor {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CasinoTheme.ink, CasinoTheme.accent)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if state.phase == .complete {
                Text("Seed \(state.seed) · randomizer v\(state.randomizerVersion)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(CasinoTheme.mutedInk)
            }
        }
    }

    private var actionTitle: String { session.pokerState == nil ? "Deal Hand" : session.pokerState?.phase == .choosingHolds ? "Draw Cards" : "New Round" }
    private func action() { if session.pokerState == nil { session.dealPoker() } else if session.pokerState?.phase == .choosingHolds { session.drawPoker() } else { session.newRound() } }
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
                .font(.footnote)
                .foregroundStyle(CasinoTheme.mutedInk)

            VStack(spacing: 0) {
                ForEach(Self.rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(row.countText) / \(Self.totalText)")
                            Spacer(minLength: 8)
                            Text(row.percentText)
                        }
                        .font(.footnote.monospacedDigit().weight(.semibold))
                        .foregroundStyle(CasinoTheme.ink)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                    if row.id != Self.rows.last?.id {
                        Divider().overlay(CasinoTheme.ink.opacity(0.14))
                    }
                }
            }
            .background(CasinoTheme.mutedIvory.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(CasinoTheme.ink.opacity(0.16), lineWidth: 1)
            }
        }
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
    var title: String {
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
