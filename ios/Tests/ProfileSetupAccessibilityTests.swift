import XCTest

final class ProfileSetupAccessibilityTests: XCTestCase {
    private var source: String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return (try? String(contentsOf: root.appendingPathComponent("Sources/Features/Profile/ProfileSetupView.swift"))) ?? ""
    }

    func testAvatarAndColorChoicesUseNativeAccessibleButtons() {
        XCTAssertFalse(source.contains(".onTapGesture"))
        XCTAssertGreaterThanOrEqual(source.components(separatedBy: "Button {").count, 3)
        XCTAssertTrue(source.contains(".accessibilityLabel"))
        XCTAssertTrue(source.contains(".accessibilityAddTraits(emoji == e ? .isSelected : [])"))
        XCTAssertTrue(source.contains(".accessibilityAddTraits(colorHex == c ? .isSelected : [])"))
        XCTAssertTrue(source.contains(#".accessibilityValue(emoji == e ? "Selected" : "Not selected")"#))
        XCTAssertTrue(source.contains(#".accessibilityValue(colorHex == c ? "Selected" : "Not selected")"#))
        XCTAssertTrue(source.contains(".frame(minWidth: 44, minHeight: 44)"))
    }

    func testColorChoicesHaveSpokenNames() {
        let expectedMappings = [
            #"case "B88A2E": return "Gold""#,
            #"case "B0494C": return "Ruby red""#,
            #"case "4C8C6B": return "Emerald green""#,
            #"case "3C76A8": return "Sapphire blue""#,
            #"case "75569E": return "Amethyst purple""#,
            #"case "C76B3A": return "Copper orange""#,
        ]

        for mapping in expectedMappings {
            XCTAssertTrue(source.contains(mapping), "Missing spoken color mapping: \(mapping)")
        }
        XCTAssertFalse(source.contains("accessibilityLabel(c)"))
    }
}
