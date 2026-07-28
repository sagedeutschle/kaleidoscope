import XCTest

final class ProfileSetupAccessibilityTests: XCTestCase {
    private var source: String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return (try? String(contentsOf: root.appendingPathComponent("Sources/Features/Profile/ProfileSetupView.swift"))) ?? ""
    }

    private func occurrenceCount(of value: String) -> Int {
        source.components(separatedBy: value).count - 1
    }

    func testAvatarAndColorChoicesUseNativeAccessibleButtons() {
        XCTAssertFalse(source.contains(".onTapGesture"))
        XCTAssertEqual(occurrenceCount(of: "Button {"), 3)
        XCTAssertTrue(source.contains(".accessibilityLabel"))
        XCTAssertTrue(source.contains(".accessibilityAddTraits(emoji == e ? .isSelected : [])"))
        XCTAssertTrue(source.contains(".accessibilityAddTraits(colorHex == c ? .isSelected : [])"))
        XCTAssertTrue(source.contains(#".accessibilityValue(emoji == e ? "Selected" : "Not selected")"#))
        XCTAssertTrue(source.contains(#".accessibilityValue(colorHex == c ? "Selected" : "Not selected")"#))
        XCTAssertEqual(occurrenceCount(of: ".frame(minWidth: 44, minHeight: 44)"), 1)
        XCTAssertEqual(occurrenceCount(of: ".frame(width: 44, height: 44)"), 1)
    }

    func testColorChoicesWrapWithinCompactWidths() {
        XCTAssertTrue(source.contains(
            "GridItem(.adaptive(minimum: 44, maximum: 44), spacing: 10)"
        ))
        XCTAssertTrue(source.contains("LazyVGrid(columns: colorChoiceColumns, spacing: 10)"))
        XCTAssertFalse(source.contains("HStack(spacing: 12)"))
    }

    func testEmojiChoicesHaveNonDuplicativeSpokenNames() {
        XCTAssertTrue(source.contains(#".accessibilityLabel("\(emojiName(for: e)) avatar")"#))

        let expectedMappings = [
            #"case "🎴": return "Card""#,
            #"case "🦊": return "Fox""#,
            #"case "🐉": return "Dragon""#,
            #"case "🌙": return "Moon""#,
            #"case "⚡️": return "Lightning""#,
            #"case "🎲": return "Dice""#,
            #"case "🔮": return "Crystal ball""#,
            #"case "🦉": return "Owl""#,
            #"case "🌸": return "Blossom""#,
            #"case "🛡️": return "Shield""#,
            #"case "👾": return "Alien""#,
            #"case "🎯": return "Target""#,
        ]

        for mapping in expectedMappings {
            XCTAssertTrue(source.contains(mapping), "Missing spoken avatar mapping: \(mapping)")
        }
        XCTAssertFalse(source.contains(#"return "card avatar""#))
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
