import SwiftUI

@main
struct KaleidoscopeApp: App {
    var body: some Scene {
        WindowGroup("Kaleidoscope") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 880)
    }
}
