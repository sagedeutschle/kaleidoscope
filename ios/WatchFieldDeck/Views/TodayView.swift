import SwiftUI
import WatchFieldDeckCore

struct TodayView: View {
    @EnvironmentObject private var store: FieldDeckStore

    private var activeCount: Int {
        store.snapshot.projects.filter { $0.state == .active }.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 9) {
                hero
                quickDeck

                HStack {
                    Text("PROJECT PULSE")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(WatchTheme.muted)
                    Spacer()
                    Text("\(store.snapshot.projects.count) LANES")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(WatchTheme.gold)
                }
                .padding(.horizontal, 3)

                ForEach(store.snapshot.projects) { project in
                    NavigationLink {
                        ProjectPulseDetailView(
                            project: project,
                            generatedAt: store.snapshot.generatedAt
                        )
                    } label: {
                        projectRow(project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .fieldDeckBackground()
        .navigationTitle("Field Deck")
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "27365E"), WatchTheme.navy],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 58, weight: .light))
                        .foregroundStyle(WatchTheme.gold.opacity(0.16))
                        .offset(x: 10, y: -7)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("FIELD STATUS")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(WatchTheme.gold)
                Text("\(activeCount) active · \(store.snapshot.projects.count) tracked")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text(store.linkStatus)
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.muted)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(height: 92)
        .accessibilityElement(children: .combine)
    }

    private var quickDeck: some View {
        HStack(spacing: 8) {
            NavigationLink {
                GamesHubView()
            } label: {
                quickTile(title: "Games", subtitle: "3 offline", symbol: "gamecontroller.fill")
            }
            .buttonStyle(.plain)

            NavigationLink {
                PhoneLinkView()
            } label: {
                quickTile(
                    title: "Link",
                    subtitle: store.isReachable ? "phone ready" : "saved mode",
                    symbol: store.isReachable ? "iphone.radiowaves.left.and.right" : "iphone.slash"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func quickTile(title: String, subtitle: String, symbol: String) -> some View {
        FieldDeckCard {
            Image(systemName: symbol)
                .foregroundStyle(WatchTheme.gold)
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(WatchTheme.muted)
                .lineLimit(1)
        }
    }

    private func projectRow(_ project: ProjectPulse) -> some View {
        FieldDeckCard {
            HStack(alignment: .top, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: project.accentHex).opacity(0.15))
                    Image(systemName: project.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: project.accentHex))
                }
                .frame(width: 35, height: 35)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(project.title)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Circle()
                            .fill(project.state.fieldColor)
                            .frame(width: 6, height: 6)
                    }
                    Text(project.headline)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WatchTheme.muted)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.title), \(project.state.fieldLabel), \(project.headline)")
    }
}
