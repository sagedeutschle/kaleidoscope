import SwiftUI

enum LocalLeaderboardPresentation {
    static let loadingMessage = "Loading local scores…"
    static let failureMessage = "Scores could not be loaded."
    static let retryTitle = "Retry"
    static let emptyTitle = "No scores yet"
    static let emptyGuidance = "Finish a ranked game to create your first local score."
    static let loadingAccessibilityLabel = "Loading local scores"
    static let retryAccessibilityLabel = "Retry loading local scores"
}

struct ResultSlipView: View {
    let result: GameResult
    let accent: Color
    var onPlayAgain: () -> Void
    var onLeaderboard: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().fill(accent.opacity(0.16))
                    Circle().strokeBorder(
                        AngularGradient(gradient: Gradient(colors: irisColors(accent)), center: .center),
                        lineWidth: 2.5
                    )
                    Image(systemName: result.outcome == .won ? "crown.fill" : "flag.checkered")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(accent)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(PrismetDesign.title(30))
                        .foregroundStyle(PrismetDesign.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(PrismetDesign.ink2)
                }

                Spacer(minLength: 12)
            }

            HStack(spacing: 14) {
                resultMetric(label: "Score", value: scoreText)
                if let detail = detailText {
                    resultMetric(label: "Detail", value: detail)
                }
            }

            HStack(spacing: 12) {
                Button(action: onPlayAgain) {
                    Label("Play Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(AccentButtonStyle(accent: accent))

                Button(action: onLeaderboard) {
                    Label("Scores", systemImage: "trophy")
                }
                .buttonStyle(GlassButtonStyle())

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(GlassButtonStyle())
                .help("Close")
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(PrismetDesign.ground)
    }

    private var title: String {
        switch result.outcome {
        case .won: return "Victory"
        case .lost: return "Run Complete"
        case .solved: return "Solved"
        case .completed: return "Complete"
        case .abandoned: return "Stopped"
        }
    }

    private var subtitle: String {
        LeaderboardCatalog.mode(for: result.facetID, mode: result.mode)?.title ?? result.facetID
    }

    private var scoreText: String {
        result.score.map { "\($0)" } ?? "--"
    }

    private var detailText: String? {
        if let durationSeconds = result.durationSeconds {
            return "\(durationSeconds)s"
        }
        if let moveCount = result.moveCount {
            return "\(moveCount)"
        }
        if let maxTile = result.metadata["maxTile"] {
            return "Max \(maxTile)"
        }
        if let length = result.metadata["length"] {
            return "Length \(length)"
        }
        return nil
    }

    private func resultMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(PrismetDesign.ink3)
            Text(value)
                .font(PrismetDesign.rounded(28))
                .monospacedDigit()
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PrismetDesign.panel)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(PrismetDesign.outline, lineWidth: 1))
        )
    }
}

struct LocalLeaderboardPanel: View {
    let service: any LeaderboardService
    let facetID: String
    let mode: String
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PrismetDesign.title(28))
                        .foregroundStyle(PrismetDesign.ink)
                    Text("Local Scores")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PrismetDesign.ink2)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(GlassButtonStyle())
                .help("Close")
            }

            content

            if !isLoading, errorText == nil {
                HStack {
                    Spacer()
                    Button {
                        Task { await loadEntries() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(GlassButtonStyle())
                }
            }
        }
        .padding(24)
        .frame(width: 460)
        .frame(minHeight: 360)
        .background(PrismetDesign.ground)
        .task {
            await loadEntries()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(LocalLeaderboardPresentation.loadingMessage)
                .accessibilityLabel(LocalLeaderboardPresentation.loadingAccessibilityLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorText {
            HStack(spacing: 12) {
                Text(errorText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PrismetDesign.ink2)

                Button {
                    Task { await loadEntries() }
                } label: {
                    Label(LocalLeaderboardPresentation.retryTitle, systemImage: "arrow.clockwise")
                }
                .buttonStyle(GlassButtonStyle())
                .accessibilityLabel(LocalLeaderboardPresentation.retryAccessibilityLabel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if entries.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "trophy")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.65))
                Text(LocalLeaderboardPresentation.emptyTitle)
                    .font(PrismetDesign.rounded(18))
                    .foregroundStyle(PrismetDesign.ink)
                Text(LocalLeaderboardPresentation.emptyGuidance)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PrismetDesign.ink2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                ForEach(entries) { entry in
                    LeaderboardRow(entry: entry, accent: accent)
                }
            }
        }
    }

    private var title: String {
        LeaderboardCatalog.mode(for: facetID, mode: mode)?.title ?? facetID
    }

    private func loadEntries() async {
        isLoading = true
        errorText = nil
        do {
            entries = try await service.entries(facetID: facetID, mode: mode, scope: .local, limit: 10)
        } catch {
            entries = []
            errorText = LocalLeaderboardPresentation.failureMessage
        }
        isLoading = false
    }
}

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(PrismetDesign.rounded(18))
                .monospacedDigit()
                .foregroundStyle(accent)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .foregroundStyle(PrismetDesign.ink)
                if let detail = entry.detail {
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PrismetDesign.ink3)
                }
            }

            Spacer()

            Text("\(entry.score)")
                .font(PrismetDesign.rounded(22))
                .monospacedDigit()
                .foregroundStyle(PrismetDesign.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PrismetDesign.panel)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(PrismetDesign.outline, lineWidth: 1))
        )
    }
}
