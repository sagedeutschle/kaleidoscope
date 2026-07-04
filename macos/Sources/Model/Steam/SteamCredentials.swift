import Foundation

// The Steam Web API key lives ONLY on the user's machine — never in the bundle, never in git.
// Read order: env var (dev) → local config file in Application Support. The user enters it once in the
// app's Settings and it is written here. PRISM: when this folds into Kaleidoscope, the key moves behind
// Codex's proxy and this file is dropped; the app then talks to the proxy with no key at all.
enum SteamCredentials {
    static let configURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("SteamRewind", isDirectory: true).appendingPathComponent("config.json")
    }()

    static func apiKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["STEAM_WEB_API_KEY"], !env.isEmpty {
            return env
        }
        guard
            let data = try? Data(contentsOf: configURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let key = object["steamWebApiKey"] as? String,
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func hasKey() -> Bool { apiKey() != nil }

    static func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: ["steamWebApiKey": trimmed], options: [.prettyPrinted])
        try data.write(to: configURL, options: [.atomic])
    }

    static func clear() {
        try? FileManager.default.removeItem(at: configURL)
    }
}
