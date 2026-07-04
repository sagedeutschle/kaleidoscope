// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — SteamRewind fold-in (Lens)
import Foundation

// The Steam Web API key lives ONLY on the user's device — never in the bundle, never in git.
// iOS read order: env var STEAM_WEB_API_KEY (dev / simulator) → UserDefaults "steam.webApiKey"
// (the user enters it once in-app and it is written there). Same enum API surface as the macOS
// original (apiKey / hasKey / saveAPIKey / clear) so the engine compiles unchanged.
// PRISM: when Codex's proxy lands, the key moves behind the proxy and this file is dropped;
// the app then talks to the proxy with no key at all.
enum SteamCredentials {
    static let defaultsKey = "steam.webApiKey"

    static func apiKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["STEAM_WEB_API_KEY"], !env.isEmpty {
            return env
        }
        guard
            let stored = UserDefaults.standard.string(forKey: defaultsKey),
            !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return stored.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func hasKey() -> Bool { apiKey() != nil }

    static func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: defaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
