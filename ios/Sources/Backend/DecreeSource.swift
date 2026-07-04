import Foundation

/// The Oracle's live chronicle source.
///
/// The Wizard King's council runs only on the source laptop and republishes
/// `decrees.json` to a public endpoint once a day, so every install — including
/// phones off the home network — reads the exact same decrees. On any failure the
/// caller keeps whatever it already has (its bundled/cached snapshot); this never
/// throws and never blocks play.
enum DecreeSource {
    /// Public chronicle, republished daily from the source laptop's council run.
    /// Single writer (the laptop, via `gh`/GitHub API), public read for everyone.
    static let publicURL = URL(string: "https://gist.githubusercontent.com/sagedeutschle/30f361c71a78dc0df3ab5904565d4ac0/raw/decrees.json")!

    /// Fetch + decode the latest chronicle, or `nil` on any failure (offline, bad
    /// payload, non-2xx). The Oracle always has the bundled snapshot to fall back on.
    static func fetchLatest() async -> DecreeChronicle? {
        guard await AppSecurity.allowClientAction(.remoteContentFetch, scope: publicURL.absoluteString) else {
            return nil
        }
        var request = URLRequest(url: publicURL)
        request.timeoutInterval = 6
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let chronicle = try? JSONDecoder().decode(DecreeChronicle.self, from: data)
        else { return nil }
        return chronicle
    }
}
