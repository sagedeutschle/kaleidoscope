import XCTest
@testable import Kaleidoscope

final class ShotHarnessTests: XCTestCase {
    func testScreenshotHarnessLaunchSkipsAuthRestoreWhenShotIsRequested() {
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["KALEIDO_SHOT": "chess3d"]))
        XCTAssertFalse(RootLaunchPolicy.shouldRestoreAuth(environment: ["KALEIDO_SHOT": "  "]))
    }

    func testNormalLaunchRestoresAuthSession() {
        XCTAssertTrue(RootLaunchPolicy.shouldRestoreAuth(environment: [:]))
        XCTAssertTrue(RootLaunchPolicy.shouldRestoreAuth(environment: ["KALEIDO_SHOT": ""]))
    }
}
