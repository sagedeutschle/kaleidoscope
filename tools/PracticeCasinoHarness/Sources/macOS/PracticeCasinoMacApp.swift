import SwiftUI

@main
struct PracticeCasinoMacApp: App {
    @StateObject private var session = PracticeBlackjackSession(previewSeed: 1)

    var body: some Scene {
        Window("Prismet Practice Casino", id: "practice-casino") {
            CasinoHubView(session: session)
                .frame(minWidth: 760, minHeight: 600)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Hand") {
                    session.newHand()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!session.canStartNewHand)
            }
        }
    }
}
