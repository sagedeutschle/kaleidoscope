import XCTest
@testable import Prismet

@MainActor
final class DecreeStoreTests: XCTestCase {
    func testRefreshTriesDecreeEndpointsUntilOneReturnsAChronicle() async throws {
        let stale = DecreeChronicle(generated: "bundled", record: DecreeRecord(), decrees: [], divided: [])
        let failingURL = URL(string: "http://archbox.lan:8787/decrees.json")!
        let liveURL = URL(string: "http://100.108.54.108:8787/decrees.json")!
        var requestedURLs: [URL] = []

        let store = DecreeStore(chronicle: stale, urls: [failingURL, liveURL]) { url in
            requestedURLs.append(url)
            if url == liveURL {
                return try Self.encodedChronicle(generated: "live")
            }
            throw URLError(.cannotFindHost)
        }

        await store.refresh()

        XCTAssertEqual(requestedURLs, [failingURL, liveURL])
        XCTAssertEqual(store.chronicle.generated, "live")
        XCTAssertEqual(store.lastRefreshURL, liveURL)
        XCTAssertFalse(store.isRefreshing)
        XCTAssertEqual(store.statusMessage, "Chronicle refreshed from 100.108.54.108.")
    }

    func testRefreshKeepsBundledSnapshotWhenEveryEndpointFails() async {
        let stale = DecreeChronicle(generated: "bundled", record: DecreeRecord(), decrees: [], divided: [])
        let store = DecreeStore(chronicle: stale, urls: [
            URL(string: "http://100.108.54.108:8787/decrees.json")!,
            URL(string: "http://archbox.lan:8787/decrees.json")!
        ]) { _ in
            throw URLError(.timedOut)
        }

        await store.refresh()

        XCTAssertEqual(store.chronicle.generated, "bundled")
        XCTAssertNil(store.lastRefreshURL)
        XCTAssertFalse(store.isRefreshing)
        XCTAssertEqual(store.statusMessage, "Couldn't reach the King's court — showing last snapshot.")
    }

    func testConfiguredURLsPreferOverrideThenTailnetAndLanFallbacks() {
        let defaults = UserDefaults(suiteName: "DecreeStoreTests.\(UUID().uuidString)")!
        defaults.set("http://oracle.example.test/decrees.json", forKey: DecreeStore.endpointOverrideDefaultsKey)

        let urls = DecreeStore.configuredURLs(environment: [:], defaults: defaults)

        XCTAssertEqual(urls.first, URL(string: "http://oracle.example.test/decrees.json"))
        XCTAssertTrue(urls.contains(URL(string: "http://100.108.54.108:8787/decrees.json")!))
        XCTAssertTrue(urls.contains(URL(string: "http://archbox.lan:8787/decrees.json")!))
    }

    private static func encodedChronicle(generated: String) throws -> Data {
        var record = DecreeRecord()
        record.total = 1
        record.standing = 1
        let chronicle = DecreeChronicle(
            generated: generated,
            record: record,
            decrees: [
                Decree(id: 1,
                       title: "Moon decree",
                       regal: "The moon shall keep its post.",
                       claim: "The moon exists.",
                       status: "standing",
                       confidence: 0.9,
                       resolves: "2099-01-01",
                       domain: "oracle",
                       verdict: nil,
                       correction: nil,
                       criteria: nil,
                       source: nil)
            ],
            divided: []
        )
        return try JSONEncoder().encode(chronicle)
    }
}
