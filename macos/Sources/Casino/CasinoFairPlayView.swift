import PrismetShared
import SwiftUI

enum CasinoFairPlayCopy {
    static let firstHandDisclosure =
        "Practice only. No money, purchases, wagering, prizes, or rewards."

    static let auditPrivacy =
        "The seed, hidden card, and draw order stay concealed during play. The completed-hand record reveals them for verification."
}

struct CasinoAuditPresentation: Equatable {
    let seed: String
    let rulesVersion: String
    let randomizerVersion: String
    let commands: [String]
    let revealedDrawOrder: [String]
    let stateHashes: [String]
    let replayOutcome: String
    let resolution: String
}

struct CasinoFairPlayView: View {
    enum Mode {
        case fairPlay
        case replay
    }

    let mode: Mode
    let hitOdds: PrismetBlackjackHitOdds?
    let audit: CasinoAuditPresentation?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                practiceDisclosure
                rules
                visibleOdds
                auditSection
            }
            .padding(24)
        }
        .frame(minWidth: 500, idealWidth: 620, minHeight: 460, idealHeight: 650)
        .background(CasinoTheme.feltBackground)
        .foregroundStyle(.white)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode == .replay ? "Completed Hand Record" : "Rules & Fairness")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Practice Blackjack · rules version \(PrismetBlackjackRulesV1.rulesVersion)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var practiceDisclosure: some View {
        Label(CasinoFairPlayCopy.firstHandDisclosure, systemImage: "checkmark.shield")
            .font(.headline)
            .foregroundStyle(CasinoTheme.brassSoft)
            .casinoPanel()
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Table rules")
                .font(.title3.bold())
            ruleLine("Cards two through ten use their number. Face cards count as ten.")
            ruleLine("Aces count as eleven unless counting one prevents a bust.")
            ruleLine("The dealer stands on every 17, including soft 17.")
            ruleLine("Hit draws one card. Stand completes the dealer hand.")
            ruleLine("New Hand is always a separate action after the result remains on screen.")
        }
        .casinoPanel()
    }

    @ViewBuilder
    private var visibleOdds: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Visible-information Hit odds")
                .font(.title3.bold())
            Text(PrismetPracticeCasinoCatalog[.blackjack].fairness)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.78))
            if let hitOdds {
                Text(hitOdds.probability, format: .percent.precision(.fractionLength(1)))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(CasinoTheme.brassSoft)
                    .accessibilityLabel(
                        "Hit bust probability \(hitOdds.probability.formatted(.percent.precision(.fractionLength(1))))"
                    )
                Text("\(hitOdds.bustingCardCount) of \(hitOdds.unseenCardCount) unseen cards would bust this hand.")
                Text(hitOdds.assumption)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                Text("Hit odds appear when Hit is available.")
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .casinoPanel()
    }

    @ViewBuilder
    private var auditSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verification record")
                .font(.title3.bold())
            Text(CasinoFairPlayCopy.auditPrivacy)
                .foregroundStyle(.white.opacity(0.78))

            if let audit {
                auditRow("Seed", value: audit.seed)
                auditRow("Rules version", value: audit.rulesVersion)
                auditRow("Randomizer version", value: audit.randomizerVersion)
                auditRow("Replay outcome", value: audit.replayOutcome)
                auditRow("Blackjack result", value: audit.resolution)

                DisclosureGroup("Commands (\(audit.commands.count))") {
                    auditList(audit.commands, emptyText: "No player commands")
                }
                DisclosureGroup("Revealed draw order (\(audit.revealedDrawOrder.count))") {
                    auditList(audit.revealedDrawOrder, emptyText: "No revealed cards")
                }
                DisclosureGroup("State hashes (\(audit.stateHashes.count))") {
                    auditList(audit.stateHashes, emptyText: "No state hashes")
                }
            } else {
                Label("Available after the current hand ends", systemImage: "lock")
                    .foregroundStyle(CasinoTheme.brassSoft)
            }
        }
        .casinoPanel()
    }

    private func ruleLine(_ text: String) -> some View {
        Label(text, systemImage: "diamond.fill")
            .labelStyle(.titleAndIcon)
    }

    private func auditRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .fontDesign(.monospaced)
                .textSelection(.enabled)
        }
    }

    private func auditList(_ values: [String], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if values.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Text("\(index + 1). \(value)")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.top, 8)
    }
}
