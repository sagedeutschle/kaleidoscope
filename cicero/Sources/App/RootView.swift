import SwiftUI

/// Root tab shell. Owns the three long-lived stores and wires the agent to the
/// project so it can act on the same files the user is editing.
struct RootView: View {
    @StateObject private var settings: CiceroSettings
    @StateObject private var projects: ProjectStore
    @StateObject private var agent: AgentSession

    init() {
        // Build the trio once and share references. StateObject keeps the first
        // instance of each; because all three come from the same init call, the
        // retained `agent` references the retained `projects`/`settings`.
        let settings = CiceroSettings()
        let projects = ProjectStore()
        let agent = AgentSession(projects: projects, settings: settings)
        _settings = StateObject(wrappedValue: settings)
        _projects = StateObject(wrappedValue: projects)
        _agent = StateObject(wrappedValue: agent)
    }

    var body: some View {
        TabView {
            CodeScreen(projects: projects)
                .tabItem { Label("Code", systemImage: "curlybraces.square") }

            AgentChatView(agent: agent, projects: projects)
                .tabItem { Label("Agent", systemImage: "sparkles") }

            GamesHubView()
                .tabItem { Label("Arcade", systemImage: "gamecontroller") }

            SettingsView(settings: settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(CiceroTheme.accent)
        .task { projects.reloadIfNeeded() }
    }
}
