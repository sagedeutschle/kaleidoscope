import XCTest
@testable import Kaleidoscope

final class AdConfigTests: XCTestCase {
    func testUsesRealBannerIDWhenFormatIsValid() {
        let id = AdConfig.resolvedBannerUnitID("ca-app-pub-1234567890123456/9876543210")

        XCTAssertEqual(id, "ca-app-pub-1234567890123456/9876543210")
    }

    func testFallsBackToTestBannerIDForMissingOrMalformedConfig() {
        XCTAssertEqual(AdConfig.resolvedBannerUnitID(nil), AdConfig.testBannerUnitID)
        XCTAssertEqual(AdConfig.resolvedBannerUnitID(""), AdConfig.testBannerUnitID)
        XCTAssertEqual(AdConfig.resolvedBannerUnitID("ca-app-pub-1234567890123456~9876543210"), AdConfig.testBannerUnitID)
    }

    func testLiveReadinessRequiresRealAppAndBannerIDs() {
        let ready = AdConfig.liveReadiness(
            appID: "ca-app-pub-1234567890123456~9876543210",
            bannerUnitID: "ca-app-pub-1234567890123456/0123456789"
        )

        XCTAssertTrue(ready.isReady)
        XCTAssertEqual(ready.blockers, [])
    }

    func testLiveReadinessReportsCurrentTestConfigurationBlockers() {
        let readiness = AdConfig.liveReadiness(
            appID: AdConfig.testAppID,
            bannerUnitID: ""
        )

        XCTAssertFalse(readiness.isReady)
        XCTAssertEqual(readiness.blockers, [
            "AdMob app id is still Google's sample/test id",
            "AdMob banner unit id is missing"
        ])
    }

    func testTesterCodeHashesIgnorePlaintextAndMalformedValues() {
        let validHash = String(repeating: "a", count: 64)
        let resolved = AdConfig.resolvedTesterCodeHashes([
            " family-code ",
            validHash.uppercased(),
            "1234"
        ])

        XCTAssertEqual(resolved, [validHash])
    }

    func testTesterCodeHashesCanComeFromCommaOrNewlineString() {
        let first = String(repeating: "1", count: 64)
        let second = String(repeating: "b", count: 64)

        XCTAssertEqual(
            AdConfig.resolvedTesterCodeHashes("\(first),\n\(second)"),
            [first, second]
        )
    }

    func testRemoveAdsProductIDHasStableDefault() {
        XCTAssertEqual(AdConfig.defaultRemoveAdsProductID, "com.spocksclub.kaleidoscope.removeads")
    }

    func testBannerIsHiddenUntilLiveAdMobIDsAreConfigured() {
        let testReadiness = AdConfig.liveReadiness(
            appID: AdConfig.testAppID,
            bannerUnitID: ""
        )
        let liveReadiness = AdConfig.liveReadiness(
            appID: "ca-app-pub-1234567890123456~9876543210",
            bannerUnitID: "ca-app-pub-1234567890123456/0123456789"
        )

        XCTAssertFalse(AdConfig.shouldDisplayBanner(adsRemoved: false, liveReadiness: testReadiness))
        XCTAssertFalse(AdConfig.shouldDisplayBanner(adsRemoved: true, liveReadiness: liveReadiness))
        XCTAssertTrue(AdConfig.shouldDisplayBanner(adsRemoved: false, liveReadiness: liveReadiness))
    }
}
