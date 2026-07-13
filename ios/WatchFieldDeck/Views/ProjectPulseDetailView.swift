import SwiftUI
import WatchFieldDeckCore

struct ProjectPulseDetailView: View {
    let project: ProjectPulse
    let generatedAt: Date

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: project.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color(hex: project.accentHex))
                    Spacer()
                    PulsePill(state: project.state)
                }

                Text(project.title)
                    .font(.system(.title3, design: .rounded, weight: .black))
                Text(project.headline)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(hex: project.accentHex))

                FieldDeckCard {
                    Text("VERIFIED PULSE")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(WatchTheme.muted)
                    Text(project.detail)
                        .font(.caption)
                        .padding(.top, 2)
                }

                FieldDeckCard {
                    Label("NEXT MOVE", systemImage: "arrow.forward.circle.fill")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(WatchTheme.gold)
                    Text(project.nextAction)
                        .font(.caption)
                        .padding(.top, 2)
                }

                Text("Captured \(generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(WatchTheme.muted)
            }
            .padding(.horizontal, 7)
            .padding(.bottom, 12)
        }
        .fieldDeckBackground()
        .navigationTitle(project.title)
    }
}
