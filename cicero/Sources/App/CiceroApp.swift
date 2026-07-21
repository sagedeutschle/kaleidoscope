import SwiftUI

/// Cicero — a pocket "vibe coding" studio.
///
/// One app, four surfaces: a code **editor** over a sandboxed on-device project,
/// an **agent** chat wired to the Claude API that can read and edit those files,
/// a small **arcade** of mini-games, and **settings** (API key, model, remote hosts).
///
/// See `cicero/README.md` for the architecture and the roadmap to true remote
/// execution on Sage's dev machines.
@main
struct CiceroApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // Cicero commits to a single dark "editor" look; the whole UI is
                // designed around CiceroTheme's dark palette.
                .preferredColorScheme(.dark)
        }
    }
}
