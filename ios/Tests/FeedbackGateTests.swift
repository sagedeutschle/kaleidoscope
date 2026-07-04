import XCTest
@testable import Kaleidoscope

final class FeedbackGateTests: XCTestCase {
    func testBothEnabledPlaysBoth() {
        let decision = FeedbackDecision(soundEnabled: true, hapticsEnabled: true)
        XCTAssertTrue(decision.playSound)
        XCTAssertTrue(decision.playHaptic)
    }

    func testSoundDisabledSuppressesOnlySound() {
        let decision = FeedbackDecision(soundEnabled: false, hapticsEnabled: true)
        XCTAssertFalse(decision.playSound)
        XCTAssertTrue(decision.playHaptic)
    }

    func testHapticsDisabledSuppressesOnlyHaptic() {
        let decision = FeedbackDecision(soundEnabled: true, hapticsEnabled: false)
        XCTAssertTrue(decision.playSound)
        XCTAssertFalse(decision.playHaptic)
    }

    func testBothDisabledPlaysNothing() {
        let decision = FeedbackDecision(soundEnabled: false, hapticsEnabled: false)
        XCTAssertFalse(decision.playSound)
        XCTAssertFalse(decision.playHaptic)
    }
}
