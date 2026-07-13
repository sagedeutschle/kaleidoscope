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

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
