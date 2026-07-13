import XCTest

final class FieldDeckWidgetSourceTests: XCTestCase {
    func testWidgetSupportsEveryWatchComplicationFamilyAndDeepLink() throws {
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent(
                "WatchFieldDeckWidget/FieldDeckWidget.swift"
            )
        )

        for required in [
            ".accessoryRectangular",
            ".accessoryCircular",
            ".accessoryInline",
            "activeCount",
            "topProject.title",
            "fielddeck://today",
            ".widgetURL",
        ] {
            XCTAssertTrue(source.contains(required), "Missing widget contract: \(required)")
        }
    }

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
