import XCTest
import SwiftUI
@testable import Kaleidoscope

/// Guards the font system: every option must be pickable (non-empty label),
/// map to a distinct `Font.Design`, and the default must stay the professional serif.
final class AppFontTests: XCTestCase {
    func testEveryCaseHasNonEmptyDisplayName() {
        for font in AppFont.allCases {
            XCTAssertFalse(
                font.displayName.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(font.rawValue) has an empty display name."
            )
        }
    }

    func testEveryCaseHasNonEmptyBlurb() {
        for font in AppFont.allCases {
            XCTAssertFalse(
                font.blurb.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(font.rawValue) has an empty blurb."
            )
        }
    }

    func testEveryCaseMapsToADistinctDesign() {
        let designs = AppFont.allCases.map(\.design)
        XCTAssertEqual(
            designs.count, Set(designs).count,
            "Two AppFont cases share the same Font.Design mapping."
        )
    }

    func testDisplayNamesAreDistinct() {
        let names = AppFont.allCases.map(\.displayName)
        XCTAssertEqual(names.count, Set(names).count, "Two AppFont cases share a display name.")
    }

    func testDefaultIsProfessionalSerif() {
        XCTAssertEqual(AppFont.default, .serif)
        XCTAssertEqual(AppFont.default.design, .serif)
    }

    func testStorageKeyIsTheAgreedContract() {
        XCTAssertEqual(AppFont.storageKey, "app.fontChoice")
    }

    func testStoredInitRoundTripsEveryRawValue() {
        for font in AppFont.allCases {
            XCTAssertEqual(AppFont(stored: font.rawValue), font)
        }
    }

    func testStoredInitFallsBackToDefaultForBadInput() {
        XCTAssertEqual(AppFont(stored: nil), .default)
        XCTAssertEqual(AppFont(stored: ""), .default)
        XCTAssertEqual(AppFont(stored: "comic-sans"), .default)
    }
}
