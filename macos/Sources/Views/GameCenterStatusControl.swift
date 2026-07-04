import SwiftUI

// PRISM: Agent-A 2026-06-29 — Game Center toolbar status/sign-in control. Surfaces
// GameCenterAuthenticationController state so sign-in is actually reachable from the UI
// (the controller previously had no call site anywhere in the app).

/// A compact toolbar control that reflects Game Center authentication state and
/// lets the player (re)start sign-in. Lives next to the Reading menu in the shell.
struct GameCenterStatusControl: View {
    @ObservedObject var controller: GameCenterAuthenticationController

    var body: some View {
        Menu {
            switch controller.state {
            case .authenticated(let displayName):
                Section("Game Center") {
                    Label("Signed in as \(displayName)", systemImage: "checkmark.seal.fill")
                }
            case .authenticating, .notStarted:
                Label("Connecting to Game Center…", systemImage: "hourglass")
            case .unauthenticated(let message):
                Section("Game Center") {
                    Text(message)
                }
                Button {
                    controller.startAuthentication()
                } label: {
                    Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                }
            }
        } label: {
            Label(labelText, systemImage: iconName)
        }
        .help(helpText)
    }

    private var labelText: String {
        switch controller.state {
        case .authenticated(let displayName): return displayName
        case .authenticating, .notStarted: return "Game Center"
        case .unauthenticated: return "Sign In"
        }
    }

    private var iconName: String {
        switch controller.state {
        case .authenticated: return "checkmark.seal.fill"
        case .authenticating, .notStarted: return "hourglass"
        case .unauthenticated: return "person.crop.circle.badge.exclamationmark"
        }
    }

    private var helpText: String {
        switch controller.state {
        case .authenticated(let displayName): return "Signed in to Game Center as \(displayName)"
        case .authenticating: return "Connecting to Game Center…"
        case .notStarted: return "Game Center"
        case .unauthenticated(let message): return message
        }
    }
}
