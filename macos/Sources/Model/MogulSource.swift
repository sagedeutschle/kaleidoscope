// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — "The Moguls" board source — macOS mirror.
// macOS adaptation: no AppSecurity gate here — the macOS app's net fetches
// (see `DecreeStore`) go straight to URLSession, so this mirror does the same.
import Foundation

/// The Moguls board's live source — same serve pattern as the decrees gist:
/// the council pipeline runs on the source laptop, republishes `moguls.json`
/// to a public gist, and every install reads the same board. On any failure
/// the caller keeps its bundled snapshot; this never throws and never blocks.
enum MogulSource {
    /// Public board, republished by the council pipeline. Single writer
    /// (the laptop, via the GitHub API), public read for everyone.
    static let publicURL = URL(string: "https://gist.githubusercontent.com/sagedeutschle/89deccae62f7fcd458d47fa464d82e0c/raw/moguls.json")!

    /// Fetch + decode the latest board, or `nil` on any failure (offline, bad
    /// payload, non-2xx, or an empty placeholder). The view always has the
    /// bundled snapshot to fall back on.
    static func fetchLatest() async -> MogulLedger? {
        var request = URLRequest(url: publicURL)
        request.timeoutInterval = 6
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let ledger = try? JSONDecoder().decode(MogulLedger.self, from: data),
              !ledger.moguls.isEmpty
        else { return nil }
        return ledger
    }

    /// The snapshot shipped in the app bundle — first-launch/offline fallback.
    static func loadBundled() -> MogulLedger? {
        guard let url = Bundle.main.url(forResource: "moguls", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(MogulLedger.self, from: data)
    }
}
