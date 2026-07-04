import SwiftUI

struct GamePlayRoute: Hashable {
    var gameID: CanonicalGameID
    var mode: GamePlayMode
}

struct GameLaunchView: View {
    let card: GameCard
    let gameID: CanonicalGameID
    let accountID: UUID?

    private var options: [GameModeOption] {
        GameModeCatalog.options(for: gameID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GameHeader(
                title: card.title,
                systemImage: card.icon,
                accent: card.accent,
                subtitle: "Choose a play mode"
            )

            VStack(spacing: 10) {
                ForEach(options) { option in
                    if option.isPlayable {
                        NavigationLink(value: GamePlayRoute(gameID: gameID, mode: option.mode)) {
                            modeRow(option)
                        }
                        .buttonStyle(.plain)
                    } else {
                        modeRow(option)
                            .opacity(0.58)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .facetBackground(card.accent)
        .navigationTitle(card.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modeRow(_ option: GameModeOption) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(card.accent.opacity(option.isPlayable ? 0.18 : 0.10))
                Image(systemName: option.mode.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(option.isPlayable ? card.accent : Kaleido.ink3)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(option.mode.title)
                    .font(Kaleido.rounded(18, .bold))
                    .foregroundStyle(Kaleido.ink)
                Text(option.mode.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Kaleido.ink2)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if option.isPlayable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(card.accent)
            } else {
                Text("NEXT")
                    .font(.caption2.weight(.heavy))
                    .tracking(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Kaleido.panelHi))
                    .foregroundStyle(Kaleido.ink2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Kaleido.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(option.isPlayable ? card.accent.opacity(0.35) : Kaleido.outline, lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        GameLaunchView(card: GameCard.all[9], gameID: .chess, accountID: nil)
    }
}
