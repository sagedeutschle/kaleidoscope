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

struct FieldDeckWidget: Widget {
    let kind = "PrismetFieldDeck"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FieldDeckWidgetProvider()) { entry in
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: "circle.hexagongrid.fill")
                Text("Field Deck")
                    .font(.caption2.bold())
                Text("\(entry.snapshot.projects.count) lanes")
                    .font(.caption2)
            }
            .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Field Deck Pulse")
        .description("Your active project pulse at a glance.")
        .supportedFamilies([.accessoryRectangular])
    }
}
