import XCTest

final class WatchProjectConfigurationTests: XCTestCase {
    func testProjectEmbedsFieldDeckWatchAppAndWidget() throws {
        let yaml = try String(contentsOf: projectRoot.appendingPathComponent("project.yml"))

        for required in [
            "WatchFieldDeckCore:",
            "path: ../shared/WatchFieldDeckCore",
            "- target: Prismet Watch App",
            "Prismet Watch App:",
            "Prismet Field Deck Widget:",
            "platform: watchOS",
            "deploymentTarget: \"11.0\"",
            "com.spocksclub.kaleidoscope.watchkitapp",
            "com.spocksclub.kaleidoscope.watchkitapp.fielddeck-widget",
        ] {
            XCTAssertTrue(yaml.contains(required), "Missing Watch project contract: \(required)")
        }
    }

    func testWatchAppUsesModernSingleTargetMetadata() throws {
        let yaml = try String(contentsOf: projectRoot.appendingPathComponent("project.yml"))

        XCTAssertTrue(yaml.contains("WKApplication: true"))
        XCTAssertFalse(
            yaml.contains("WKWatchKitApp: true"),
            "WKWatchKitApp marks the bundle as a legacy wrapper that requires a WatchKit extension"
        )
    }

    func testWatchTargetHasMinimalAppEntryAndAssets() {
        let requiredPaths = [
            "WatchFieldDeck/App/PrismetFieldDeckApp.swift",
            "WatchFieldDeck/App/FieldDeckRootView.swift",
            "WatchFieldDeck/Resources/Assets.xcassets/Contents.json",
            "WatchFieldDeck/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
        ]

        for relativePath in requiredPaths {
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: projectRoot.appendingPathComponent(relativePath).path
                ),
                "Missing Watch source or resource: \(relativePath)"
            )
        }
    }

    func testWatchInterfaceExposesAccessibleFieldControls() throws {
        let source = try watchSource([
            "Views/Pocket2048View.swift",
            "Views/PocketLightsOutView.swift",
            "Views/CatanHarvestView.swift",
            "Views/ProjectPulseDetailView.swift",
            "Views/PhoneLinkView.swift",
        ])

        for required in [
            "Move up",
            "Move down",
            "Move left",
            "Move right",
            "ForEach(0..<25",
            "Row \\(row + 1), column \\(column + 1)",
            "Roll dice",
            "Bank harvest",
            ".formatted(date: .abbreviated, time: .shortened)",
            "Request Update",
        ] {
            XCTAssertTrue(source.contains(required), "Missing Watch UI contract: \(required)")
        }
    }

    private func watchSource(_ relativePaths: [String]) throws -> String {
        try relativePaths
            .map { projectRoot.appendingPathComponent("WatchFieldDeck/\($0)") }
            .map { try String(contentsOf: $0) }
            .joined(separator: "\n")
    }

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
