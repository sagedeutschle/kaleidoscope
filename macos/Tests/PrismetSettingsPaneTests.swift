import XCTest
@testable import Prismet

final class PrismetSettingsPaneTests: XCTestCase {
    func testAppStoreShareURLUsesLivePublicListing() {
        XCTAssertEqual(
            PrismetSettingsPane.appStoreURL.absoluteString,
            "https://apps.apple.com/us/app/kaleidescope/id6785993194"
        )
    }
}
