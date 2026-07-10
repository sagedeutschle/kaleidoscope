import XCTest
@testable import Prismet

@MainActor
final class AdEntitlementStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "AdEntitlementStoreTests"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    func testDefaultStateDoesNotRemoveAds() {
        let store = makeStore(codeHashes: [])

        XCTAssertFalse(store.adsRemoved)
        XCTAssertNil(store.unlockSource)
    }

    func testRedeemedTesterCodeRemovesAdsAndPersists() {
        let hash = AdEntitlementStore.hashTesterCode("family-night-2026")
        let store = makeStore(codeHashes: [hash])

        XCTAssertTrue(store.redeemTesterCode("  Family-Night-2026  "))
        XCTAssertTrue(store.adsRemoved)
        XCTAssertEqual(store.unlockSource, .testerCode)

        let restored = makeStore(codeHashes: [hash])
        XCTAssertTrue(restored.adsRemoved)
        XCTAssertEqual(restored.unlockSource, .testerCode)
    }

    func testInvalidTesterCodeDoesNotUnlock() {
        let hash = AdEntitlementStore.hashTesterCode("real-code")
        let store = makeStore(codeHashes: [hash])

        XCTAssertFalse(store.redeemTesterCode("wrong-code"))
        XCTAssertFalse(store.adsRemoved)
        XCTAssertNil(store.unlockSource)
    }

    func testRawHashCannotBeRedeemedAsACode() {
        let hash = AdEntitlementStore.hashTesterCode("friends-only")
        let store = makeStore(codeHashes: [hash])

        XCTAssertFalse(store.redeemTesterCode(hash))
        XCTAssertFalse(store.adsRemoved)
    }

    func testStorePurchaseGrantRemovesAds() {
        let store = makeStore(codeHashes: [])

        store.grantStorePurchase(transactionID: "tx-123")

        XCTAssertTrue(store.adsRemoved)
        XCTAssertEqual(store.unlockSource, .storePurchase)

        let restored = makeStore(codeHashes: [])
        XCTAssertTrue(restored.adsRemoved)
        XCTAssertEqual(restored.unlockSource, .storePurchase)
    }

    func testRemoveAdsExplainsMissingStoreKitProductSetup() {
        XCTAssertTrue(RemoveAdsView.purchaseUnavailableMessage.contains("App Store Connect"))
        XCTAssertTrue(RemoveAdsView.purchaseUnavailableMessage.contains("com.spocksclub.kaleidoscope.removeads"))
    }

    func testLocalStoreKitConfigurationExistsForRemoveAdsProduct() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let storeKitURL = repoRoot.appendingPathComponent("Configuration/RemoveAds.storekit")
        let contents = try String(contentsOf: storeKitURL)

        XCTAssertTrue(contents.contains("com.spocksclub.kaleidoscope.removeads"))
        XCTAssertTrue(contents.contains("4.99"))
    }

    private func makeStore(codeHashes: [String]) -> AdEntitlementStore {
        AdEntitlementStore(
            userDefaults: defaults,
            testerCodeHashes: codeHashes,
            purchaseProductID: AdConfig.removeAdsProductID
        )
    }
}
