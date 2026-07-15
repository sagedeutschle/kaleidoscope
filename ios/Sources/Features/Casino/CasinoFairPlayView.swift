import PrismetShared
import SwiftUI

struct PracticeBlackjackAuditSummary: Equatable {
    let seed: UInt64
    let rulesVersion: Int
    let randomizerVersion: Int
    let commandCount: Int
    let revealedCards: [String]
    let verification: String
}

struct CasinoFairPlayView: View {
    let auditSummary: PracticeBlackjackAuditSummary?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(CasinoFairPlayCopy.disclosure)
                        .font(.headline)
                        .foregroundStyle(CasinoTheme.feltTop)

                    fairPlaySection(
                        title: CasinoFairPlayCopy.rulesTitle,
                        body: "One freshly shuffled 52-card deck. Hit or Stand only. A two-card natural 21 beats a later 21, and equal totals tie."
                    )
                    fairPlaySection(
                        title: "Dealer policy",
                        body: CasinoFairPlayCopy.dealerPolicy
                    )
                    fairPlaySection(
                        title: "Hit bust probability",
                        body: PrismetPracticeCasinoCatalog[.blackjack].fairness
                    )
                    fairPlaySection(
                        title: "Shuffle",
                        body: "SplitMix64 v1 drives an unbiased Fisher–Yates shuffle. Results are never adjusted from previous hands or player choices."
                    )

                    Divider()

                    if let auditSummary {
                        auditSection(auditSummary)
                    } else {
                        Text(CasinoFairPlayCopy.pendingAudit)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Rules & Fairness")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func fairPlaySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func auditSection(_ summary: PracticeBlackjackAuditSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Replay & Fairness")
                .font(.title3.bold())
            LabeledContent("Seed", value: String(summary.seed))
            LabeledContent("Rules version", value: String(summary.rulesVersion))
            LabeledContent("Randomizer version", value: String(summary.randomizerVersion))
            LabeledContent("Player commands", value: String(summary.commandCount))
            LabeledContent("Verification", value: summary.verification)
            if !summary.revealedCards.isEmpty {
                Text("Revealed draw order")
                    .font(.headline)
                    .padding(.top, 4)
                Text(summary.revealedCards.joined(separator: ", "))
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
