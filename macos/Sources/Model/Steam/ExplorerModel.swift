import SwiftUI

@MainActor
final class ExplorerModel: ObservableObject {
    @Published var query: String = ""
    @Published var snapshot: SteamProfileSnapshot?
    @Published var isLoading: Bool = false
    @Published var errorText: String?
    @Published var selectedLensID: String = LensCatalog.all[0].id

    @Published var hasKey: Bool = SteamCredentials.hasKey()
    @Published var keyDraft: String = ""
    @Published var showingSettings: Bool = false
    /// True when the currently shown snapshot is the built-in demo library, not a real lookup.
    @Published var isDemo: Bool = false
    /// True when a real lookup returned a private / hidden library.
    @Published var isPrivate: Bool = false

    var selectedLens: Lens { LensCatalog.lens(id: selectedLensID) }

    private var liveProvider: SteamDataProvider? {
        SteamCredentials.apiKey().map { LiveSteamDataProvider(apiKey: $0) }
    }

    func loadInitial() async {
        guard snapshot == nil && !isLoading else { return }
        // Verification hook: launch with STEAMREWIND_TEST_QUERY set to auto-load a real profile.
        if let testQuery = ProcessInfo.processInfo.environment["STEAMREWIND_TEST_QUERY"],
           !testQuery.isEmpty, SteamCredentials.hasKey() {
            query = testQuery
            await load()
            return
        }
        // First run is never empty: show the demo library so the app looks alive.
        await loadDemo()
    }

    func loadDemo() async {
        isLoading = true; errorText = nil; isPrivate = false
        snapshot = try? await FixtureSteamDataProvider().snapshot(forQuery: "demo")
        isDemo = true
        isLoading = false
    }

    func load() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorText = SteamDataError.empty.userMessage
            return
        }
        guard let provider = liveProvider else {
            // No key yet — can't do a real lookup.
            errorText = nil
            showingSettings = true
            return
        }
        isLoading = true; errorText = nil; isPrivate = false; isDemo = false
        do {
            let snap = try await provider.snapshot(forQuery: trimmed)
            snapshot = snap
            isPrivate = snap.ownedGames.isEmpty
        } catch let error as SteamDataError {
            errorText = error.userMessage
        } catch {
            errorText = "Something went wrong. Try again in a moment."
        }
        isLoading = false
    }

    func saveKey() {
        let trimmed = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? SteamCredentials.saveAPIKey(trimmed)
        hasKey = SteamCredentials.hasKey()
        keyDraft = ""
        showingSettings = false
        if hasKey && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task { await load() }
        }
    }
}
