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

/// The app's first macOS settings surface: Prismet web tools and the live
/// App Store listing used for easy family/friend sharing.
struct PrismetSettingsPane: View {
    static let appStoreURL = URL(string: "https://apps.apple.com/us/app/kaleidescope/id6785993194")!

    var body: some View {
        Form {
            Section("Prismet") {
                Link("prismet.xyz — Steam Rewind & Debt Clock",
                     destination: URL(string: "https://prismet.xyz")!)
                Text("The web home for the Prismet tools.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ShareLink(item: Self.appStoreURL) {
                    Label("Share App Store link", systemImage: "square.and.arrow.up")
                }
                Text("Send Prismet to friends and family.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
    }
}
