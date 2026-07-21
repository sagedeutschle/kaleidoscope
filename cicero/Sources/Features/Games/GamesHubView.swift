import SwiftUI

/// The Arcade tab: a small shelf of self-contained mini-games for a break
/// between builds. Add new games by dropping a view + a link here.
struct GamesHubView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                CiceroTheme.bg.ignoresSafeArea()
                List {
                    Section {
                        link(title: "Tic-Tac-Toe",
                             subtitle: "Beat the unbeatable minimax bot",
                             icon: "circle.grid.3x3.fill") { TicTacToeView() }
                        link(title: "Lights Out",
                             subtitle: "Clear the 5×5 grid",
                             icon: "lightbulb.fill") { LightsOutView() }
                    } header: {
                        Text("Mini-games").foregroundStyle(CiceroTheme.ink2)
                    } footer: {
                        Text("More on the way — these are the warm-up.")
                            .foregroundStyle(CiceroTheme.faint)
                    }
                    .listRowBackground(CiceroTheme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Arcade")
        }
    }

    private func link<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(CiceroTheme.accent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(CiceroTheme.ui(16, weight: .semibold))
                        .foregroundStyle(CiceroTheme.ink)
                    Text(subtitle)
                        .font(CiceroTheme.ui(12))
                        .foregroundStyle(CiceroTheme.ink2)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
