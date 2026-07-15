import SwiftUI

@main
struct PracticeCasinoMacApp: App {
    var body: some Scene {
        WindowGroup {
            CasinoHubView(previewSeed: 1)
                .frame(minWidth: 760, minHeight: 600)
        }
        .defaultSize(width: 1180, height: 760)
    }
}
