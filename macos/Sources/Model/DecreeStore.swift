import Foundation

/// Live-refreshing source of the Wizard King's Decree chronicle. Starts from the
/// bundled `decrees.json` snapshot and can pull a fresh copy from archbox's court
/// historian endpoint. On any failure it keeps the existing data and reports a
/// friendly status — the bundled snapshot is always a safe fallback.
@MainActor
final class DecreeStore: ObservableObject {
    typealias Fetcher = (URL) async throws -> Data

    nonisolated static let endpointOverrideDefaultsKey = "oracle.decreesURL"
    nonisolated static let endpointOverrideEnvironmentKey = "KALEIDOSCOPE_ORACLE_DECREES_URL"

    /// Live Oracle chronicle endpoints, tried in order. The public gist is the
    /// source of truth — published daily from the source laptop's council run, so
    /// EVERY install (including phones off the home network) sees the same decrees.
    /// The tailnet/LAN entries stay as fast local fallbacks when developing at home.
    nonisolated static let defaultDecreesURLs = [
        URL(string: "https://gist.githubusercontent.com/sagedeutschle/30f361c71a78dc0df3ab5904565d4ac0/raw/decrees.json")!,
        URL(string: "http://100.108.54.108:8787/decrees.json")!,
        URL(string: "http://archbox.lan:8787/decrees.json")!,
        URL(string: "http://archbox.lan:8790/decrees.json")!
    ]

    @Published var chronicle: DecreeChronicle
    @Published var isRefreshing = false
    @Published var statusMessage: String?
    @Published private(set) var lastRefreshURL: URL?

    private let urls: [URL]
    private let fetcher: Fetcher
    private var hasAttemptedAutomaticRefresh = false

    init(chronicle: DecreeChronicle = DecreeChronicle.loadBundled(),
         urls: [URL] = DecreeStore.configuredURLs(),
         fetcher: @escaping Fetcher = DecreeStore.defaultFetch) {
        self.chronicle = chronicle
        self.urls = urls
        self.fetcher = fetcher
    }

    nonisolated static func configuredURLs(environment: [String: String] = ProcessInfo.processInfo.environment,
                                           defaults: UserDefaults = .standard) -> [URL] {
        let overrides = [
            environment[endpointOverrideEnvironmentKey],
            defaults.string(forKey: endpointOverrideDefaultsKey)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .compactMap(URL.init(string:))

        var urls = overrides
        for defaultURL in defaultDecreesURLs where !urls.contains(defaultURL) {
            urls.append(defaultURL)
        }
        return urls
    }

    /// The Oracle view calls this on appearance. It only attempts a live pull once
    /// per view lifetime so slow or offline network paths do not keep interrupting
    /// play while the bundled chronicle remains readable.
    func refreshIfNeeded() async {
        guard !hasAttemptedAutomaticRefresh else { return }
        hasAttemptedAutomaticRefresh = true
        await refresh()
    }

    /// Fetch the latest chronicle from the first reachable Court Historian endpoint
    /// and swap it in on success. On total failure the published `chronicle` is left
    /// untouched and `statusMessage` explains that the last snapshot is being shown.
    func refresh() async {
        isRefreshing = true
        statusMessage = nil
        defer { isRefreshing = false }

        for url in urls {
            do {
                let data = try await fetcher(url)
                let fresh = try JSONDecoder().decode(DecreeChronicle.self, from: data)
                chronicle = fresh
                lastRefreshURL = url
                statusMessage = "Chronicle refreshed from \(url.host ?? "the King's court")."
                return
            } catch {
                continue
            }
        }

        lastRefreshURL = nil
        statusMessage = "Couldn't reach the King's court — showing last snapshot."
    }

    private static func defaultFetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw DecreeStoreError.unexpectedStatus(http.statusCode)
        }
        return data
    }
}

private enum DecreeStoreError: LocalizedError {
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Court Historian returned HTTP \(status)."
        }
    }
}
