import XCTest
import AppKit
@testable import Kaleidoscope

/// The 2D swatch and the 3D material must read identical colors so a red brick
/// looks the same in both canvases. Both now derive from `rgb`, so pin it down.
final class LegoBrickColorAppearanceTests: XCTestCase {

    func testRedComponentsMatchClassicRed() {
        let rgb = LegoBrickColor.classicRed.rgb
        XCTAssertEqual(rgb.red, 0.76, accuracy: 0.0001)
        XCTAssertEqual(rgb.green, 0.05, accuracy: 0.0001)
        XCTAssertEqual(rgb.blue, 0.08, accuracy: 0.0001)
    }

    func testWhiteIsFullyWhite() {
        let rgb = LegoBrickColor.white.rgb
        XCTAssertEqual(rgb.red, 1.0, accuracy: 0.0001)
        XCTAssertEqual(rgb.green, 1.0, accuracy: 0.0001)
        XCTAssertEqual(rgb.blue, 1.0, accuracy: 0.0001)
    }

    func testNSColorTracksRGBComponents() {
        let ns = LegoBrickColor.brightBlue.nsColor.usingColorSpace(.sRGB)
        let rgb = LegoBrickColor.brightBlue.rgb
        XCTAssertEqual(Double(ns?.redComponent ?? -1), rgb.red, accuracy: 0.0001)
        XCTAssertEqual(Double(ns?.greenComponent ?? -1), rgb.green, accuracy: 0.0001)
        XCTAssertEqual(Double(ns?.blueComponent ?? -1), rgb.blue, accuracy: 0.0001)
    }

    func testEveryColorHasDistinctComponents() {
        // Guards against copy-paste mistakes giving two colors the same RGB.
        let all = LegoBrickColor.allCases.map { color -> String in
            let c = color.rgb
            return "\(c.red),\(c.green),\(c.blue)"
        }
        XCTAssertEqual(Set(all).count, LegoBrickColor.allCases.count)
    }
}
