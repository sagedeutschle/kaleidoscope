import XCTest
@testable import Prismet

final class SettingsViewTests: XCTestCase {
    func testAppStoreShareURLUsesLivePublicListing() {
        XCTAssertEqual(
            SettingsView.appStoreURL.absoluteString,
            "https://apps.apple.com/us/app/kaleidescope/id6785993194"
        )
    }
}
