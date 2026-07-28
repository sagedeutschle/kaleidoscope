import XCTest
@testable import Prismet

final class MookiesPhoneMotionTests: XCTestCase {
    func testReduceMotionRemovesContinuousAndSpatialMovement() {
        let profile = MookiesPhoneMotionPolicy.profile(reduceMotion: true)

        XCTAssertFalse(profile.allowsContinuousDecoration)
        XCTAssertEqual(profile.transitionDuration, 0)
        XCTAssertEqual(profile.hostRestingScale, 1)

        let entrance = MookiesPhoneMotionPolicy.transform(
            for: .entrance,
            reduceMotion: true
        )
        XCTAssertEqual(entrance, MookiesPhoneMotionTransform(
            opacity: 1,
            scale: 1,
            yOffset: 0,
            duration: 0
        ))
    }

    func testStandardMotionUsesBriefSubtleTransformOnly() {
        let profile = MookiesPhoneMotionPolicy.profile(reduceMotion: false)

        XCTAssertTrue(profile.allowsContinuousDecoration)
        XCTAssertEqual(profile.transitionDuration, 0.28, accuracy: 0.001)
        XCTAssertEqual(profile.hostRestingScale, 1.018, accuracy: 0.001)

        let entrance = MookiesPhoneMotionPolicy.transform(
            for: .entrance,
            reduceMotion: false
        )
        XCTAssertEqual(entrance.opacity, 0)
        XCTAssertEqual(entrance.scale, 0.97, accuracy: 0.001)
        XCTAssertEqual(entrance.yOffset, 12)
        XCTAssertEqual(entrance.duration, 0.28, accuracy: 0.001)
    }

    func testCelebrationIsCosmeticAndSettlesAtTheIdentityTransform() {
        let celebration = MookiesPhoneMotionPolicy.transform(
            for: .celebration,
            reduceMotion: false
        )
        let settled = MookiesPhoneMotionPolicy.transform(
            for: .settled,
            reduceMotion: false
        )

        XCTAssertEqual(celebration.scale, 1.035, accuracy: 0.001)
        XCTAssertEqual(celebration.yOffset, -3)
        XCTAssertEqual(settled, MookiesPhoneMotionTransform(
            opacity: 1,
            scale: 1,
            yOffset: 0,
            duration: 0.28
        ))
    }
}
