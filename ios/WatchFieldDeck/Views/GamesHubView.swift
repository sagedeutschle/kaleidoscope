import SwiftUI

struct GamesHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                gameLink(
                    title: "Pocket 2048",
                    subtitle: "Slide · merge · survive",
                    symbol: "square.grid.3x3.square",
                    color: WatchTheme.gold
                ) { Pocket2048View() }

                gameLink(
                    title: "Lights Out",
                    subtitle: "Clear the 5 × 5 signal",
                    symbol: "lightbulb.max.fill",
                    color: WatchTheme.cyan
                ) { PocketLightsOutView() }

                gameLink(
                    title: "Catan Harvest",
                    subtitle: "Roll · risk · bank 25",
                    symbol: "dice.fill",
                    color: WatchTheme.mint
                ) { CatanHarvestView() }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .fieldDeckBackground()
        .navigationTitle("Pocket Games")
    }

    private func gameLink<Destination: View>(
        title: String,
        subtitle: String,
        symbol: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            FieldDeckCard {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color.opacity(0.15))
                        Image(systemName: symbol)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(color)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(WatchTheme.muted)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
