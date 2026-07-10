import XCTest
@testable import Prismet

final class BrickControlsTests: XCTestCase {

    func testDefaultBindingsLookUpByKeyCode() {
        let c = BrickControls.defaults
        XCTAssertEqual(c.action(for: 123), .moveLeft)   // ←
        XCTAssertEqual(c.action(for: 15), .rotateCW)    // R
        XCTAssertEqual(c.action(for: 12), .rotateCCW)   // Q
        XCTAssertEqual(c.action(for: 49), .raise)       // Space
    }

    func testDefaultCommandBindingsUseRequestedKeys() {
        let c = BrickControls.defaults
        XCTAssertEqual(c.action(for: 14), .placeBrick)  // E
        XCTAssertEqual(c.action(for: 53), .undo)        // Esc
        XCTAssertEqual(c.action(for: 48), .lower)       // Tab lowers a level
        XCTAssertEqual(c.action(for: 121), .redo)       // Page Down redoes
    }

    func testUnboundKeyCodeReturnsNil() {
        XCTAssertNil(BrickControls.defaults.action(for: 999))
    }

    func testEffectsMatchDefaultsWithoutToggles() {
        let c = BrickControls.defaults
        XCTAssertEqual(c.effect(of: .moveLeft), .move(dx: -1, dy: 0, dLayer: 0))
        XCTAssertEqual(c.effect(of: .moveForward), .move(dx: 0, dy: -1, dLayer: 0))
        XCTAssertEqual(c.effect(of: .raise), .move(dx: 0, dy: 0, dLayer: 1))
        XCTAssertEqual(c.effect(of: .rotateCW), .rotate(quarters: 1))
        XCTAssertEqual(c.effect(of: .rotateCCW), .rotate(quarters: -1))
        XCTAssertEqual(c.effect(of: .placeBrick), .placeBrick)
        XCTAssertEqual(c.effect(of: .undo), .undo)
        XCTAssertEqual(c.effect(of: .redo), .redo)
    }

    func testInvertForwardBackFlipsDepthMovement() {
        var c = BrickControls.defaults
        c.invertForwardBack = true
        XCTAssertEqual(c.effect(of: .moveForward), .move(dx: 0, dy: 1, dLayer: 0))
        XCTAssertEqual(c.effect(of: .moveBack), .move(dx: 0, dy: -1, dLayer: 0))
    }

    func testInvertVerticalFlipsRaiseLower() {
        var c = BrickControls.defaults
        c.invertVertical = true
        XCTAssertEqual(c.effect(of: .raise), .move(dx: 0, dy: 0, dLayer: -1))
        XCTAssertEqual(c.effect(of: .lower), .move(dx: 0, dy: 0, dLayer: 1))
    }

    func testBindReassignsAndClearsConflictingKey() {
        var c = BrickControls.defaults
        c.bind(.moveLeft, to: 13)            // remap Move left to W (keyCode 13)
        XCTAssertEqual(c.action(for: 13), .moveLeft)
        XCTAssertNil(c.action(for: 123))     // old ← binding is gone

        // Binding a key already used by another action steals it.
        c.bind(.moveRight, to: 13)
        XCTAssertEqual(c.action(for: 13), .moveRight)
        XCTAssertNotEqual(c.keyCodes[.moveLeft], 13)
    }

    func testKeyNameLabels() {
        XCTAssertEqual(BrickControls.keyName(forKeyCode: 123), "←")
        XCTAssertEqual(BrickControls.keyName(forKeyCode: 49), "Space")
        XCTAssertEqual(BrickControls.keyName(forKeyCode: 14), "E")
        XCTAssertEqual(BrickControls.keyName(forKeyCode: 15), "R")
        XCTAssertEqual(BrickControls.keyName(forKeyCode: 53), "Esc")
        XCTAssertEqual(BrickControls.keyName(forKeyCode: 48), "Tab")
    }
}
