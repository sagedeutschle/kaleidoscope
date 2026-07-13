import SwiftUI

struct PhoneLinkView: View {
    @EnvironmentObject private var store: FieldDeckStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(linkColor.opacity(0.13))
                    Circle()
                        .stroke(linkColor.opacity(0.35), lineWidth: 1)
                    Image(systemName: store.isReachable
                          ? "iphone.radiowaves.left.and.right"
                          : "iphone.slash")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(linkColor)
                }
                .frame(width: 82, height: 82)

                Text(store.isReachable ? "PHONE REACHABLE" : "SAVED MODE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(linkColor)

                FieldDeckCard {
                    Label("CURRENT PULSE", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(WatchTheme.gold)
                    Text(store.snapshot.generatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                    Text(store.linkStatus)
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.muted)
                        .padding(.top, 1)
                }

                Button {
                    store.requestRefresh()
                } label: {
                    Label("Request Update", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchTheme.gold)
                .accessibilityLabel("Request Update from iPhone")
                .accessibilityHint("Asks the paired iPhone for the latest project snapshot")

                Text("Games and the last verified pulse remain available without the phone.")
                    .font(.system(size: 9))
                    .foregroundStyle(WatchTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 7)
            .padding(.bottom, 12)
        }
        .fieldDeckBackground()
        .navigationTitle("Phone Link")
    }

    private var linkColor: Color {
        store.isReachable ? WatchTheme.mint : WatchTheme.gold
    }
}
