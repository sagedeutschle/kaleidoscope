import SwiftUI
import WatchFieldDeckCore

struct FieldDeckRootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    ForEach(FieldDeckCatalog.july13.projects) { project in
                        NavigationLink {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(project.title, systemImage: project.symbol)
                                    .font(.headline)
                                Text(project.detail)
                                    .font(.caption)
                                Text("Next: \(project.nextAction)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } label: {
                            Label(project.title, systemImage: project.symbol)
                        }
                    }
                }

                Section("Pocket Games") {
                    Text("2048 · Lights Out · Catan Harvest")
                }

                Section("Phone Link") {
                    Text("Offline snapshot ready")
                }
            }
            .navigationTitle("Field Deck")
        }
    }
}
