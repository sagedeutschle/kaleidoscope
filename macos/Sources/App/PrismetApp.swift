// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — first Settings scene (prismet.xyz link)
import SwiftUI

@main
struct PrismetApp: App {
    var body: some Scene {
        WindowGroup("Prismet") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 880)

        Settings {
            PrismetSettingsPane()
        }
    }
}

/// The app's first macOS settings surface: a single pane linking out to the
/// prismet.xyz web tools (Steam Rewind explorer + Debt Clock).
private struct PrismetSettingsPane: View {
    var body: some View {
        Form {
            Section("Prismet") {
                Link("prismet.xyz — Steam Rewind & Debt Clock",
                     destination: URL(string: "https://prismet.xyz")!)
                Text("The web home for the Prismet tools.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
    }
}
