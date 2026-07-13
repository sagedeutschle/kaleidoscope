import SwiftUI
import WidgetKit
import WatchFieldDeckCore

struct FieldDeckWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: FieldDeckSnapshot
}

struct FieldDeckWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FieldDeckWidgetEntry {
        FieldDeckWidgetEntry(date: .now, snapshot: .july13)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (FieldDeckWidgetEntry) -> Void
    ) {
        completion(FieldDeckWidgetEntry(date: .now, snapshot: .july13))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<FieldDeckWidgetEntry>) -> Void
    ) {
        let entry = FieldDeckWidgetEntry(date: .now, snapshot: .july13)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(86_400))))
    }
}

private struct FieldDeckComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FieldDeckWidgetEntry

    private var activeCount: Int {
        entry.snapshot.projects.filter { $0.state == .active }.count
    }

    private var topProject: ProjectPulse {
        entry.snapshot.projects.first(where: { $0.state == .active })
            ?? entry.snapshot.projects[0]
    }

    @ViewBuilder
    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryInline:
            inline
        default:
            rectangular
        }
    }

    private var rectangular: some View {
        HStack(spacing: 5) {
            VStack(spacing: 0) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.headline)
                Text("\(entry.snapshot.projects.count)")
                    .font(.system(.caption2, design: .rounded, weight: .black))
            }
            .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 0) {
                Text(topProject.title)
                    .font(.caption2.bold())
                    .lineLimit(1)
                Text(topProject.headline)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(activeCount) active · \(entry.snapshot.projects.count) lanes")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
            }
        }
        .widgetURL(URL(string: "fielddeck://today")!)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .trim(from: 0, to: CGFloat(activeCount) / CGFloat(entry.snapshot.projects.count))
                .stroke(.yellow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.caption2)
                Text("\(entry.snapshot.projects.count)")
                    .font(.system(.headline, design: .rounded, weight: .black))
            }
        }
        .widgetURL(URL(string: "fielddeck://today")!)
    }

    private var inline: some View {
        Label(
            "Field Deck · \(entry.snapshot.projects.count) lanes",
            systemImage: "circle.hexagongrid.fill"
        )
        .widgetURL(URL(string: "fielddeck://today")!)
    }
}

struct FieldDeckWidget: Widget {
    let kind = "PrismetFieldDeck"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FieldDeckWidgetProvider()) { entry in
            FieldDeckComplicationView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Field Deck Pulse")
        .description("Your active project pulse at a glance.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}
