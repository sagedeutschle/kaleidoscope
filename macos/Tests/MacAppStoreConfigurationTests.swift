import Foundation
import XCTest

final class MacAppStoreConfigurationTests: XCTestCase {
    private let expectedTeamID = "ZW9HBTRLRT"
    private let expectedBundleID = "com.spocksclub.kaleidoscope"

    private var macOSRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var repositoryRoot: URL {
        macOSRoot.deletingLastPathComponent()
    }

    func testMacProjectUsesTheSameProductIdentityAsIOS() throws {
        let macProject = try yaml(at: macOSRoot.appendingPathComponent("project.yml"))
        let iosProject = try yaml(at: repositoryRoot.appendingPathComponent("ios/project.yml"))

        XCTAssertEqual(yamlValue("DEVELOPMENT_TEAM", in: macProject, target: "Prismet"), expectedTeamID)
        XCTAssertEqual(yamlValue("PRODUCT_BUNDLE_IDENTIFIER", in: macProject, target: "Prismet"), expectedBundleID)
        XCTAssertEqual(yamlValue("bundleIdPrefix", in: macProject), "com.spocksclub")
        XCTAssertEqual(yamlValue("DEVELOPMENT_TEAM", in: iosProject), expectedTeamID)
        XCTAssertEqual(yamlValue("PRODUCT_BUNDLE_IDENTIFIER", in: iosProject), expectedBundleID)
        XCTAssertEqual(yamlValue("PRODUCT_BUNDLE_IDENTIFIER", in: macProject, target: "PrismetTests"), "\(expectedBundleID).macos-tests")
    }

    func testMacProjectUsesAutomaticSigningAndHardenedRuntime() throws {
        let project = try yaml(at: macOSRoot.appendingPathComponent("project.yml"))

        XCTAssertEqual(yamlValue("CODE_SIGN_STYLE", in: project, target: "Prismet"), "Automatic")
        XCTAssertEqual(yamlValue("ENABLE_HARDENED_RUNTIME", in: project, target: "Prismet"), "YES")
        XCTAssertEqual(yamlValue("CODE_SIGN_IDENTITY", in: project, target: "Prismet"), "Apple Development")
    }

    func testMacProjectDeclaresExemptOnlyEncryptionForAppStoreExport() throws {
        let project = try yaml(at: macOSRoot.appendingPathComponent("project.yml"))
        let declaration = try XCTUnwrap(
            yamlValue("INFOPLIST_KEY_ITSAppUsesNonExemptEncryption", in: project, target: "Prismet")
        )

        XCTAssertTrue(
            ["NO", "FALSE", "0"].contains(declaration.uppercased()),
            "Prismet must declare only exempt encryption for App Store export compliance"
        )
    }

    func testMacAppStoreEntitlementsPermitOnlyRequiredCapabilities() throws {
        let entitlements = try plist(at: macOSRoot.appendingPathComponent("Prismet.entitlements"))

        let expectedEntitlements: [String: Bool] = [
            "com.apple.security.app-sandbox": true,
            "com.apple.security.network.client": true,
            "com.apple.developer.game-center": true,
            "com.apple.security.files.user-selected.read-write": true
        ]
        XCTAssertEqual(entitlements as? [String: Bool], expectedEntitlements)

        let prohibitedKeys = [
            "com.apple.security.network.server",
            "com.apple.security.files.downloads.read-only",
            "com.apple.security.files.downloads.read-write",
            "com.apple.security.files.user-selected.read-only",
            "com.apple.security.files.home-relative-path.read-only",
            "com.apple.security.files.home-relative-path.read-write",
            "com.apple.security.files.absolute-path.read-only",
            "com.apple.security.files.absolute-path.read-write",
            "com.apple.security.temporary-exception.apple-events",
            "com.apple.security.temporary-exception.files.absolute-path.read-only",
            "com.apple.security.temporary-exception.files.absolute-path.read-write"
        ]
        for key in prohibitedKeys {
            XCTAssertNil(entitlements[key], "Unexpected sandbox exception: \(key)")
        }
        for key in entitlements.keys {
            XCTAssertFalse(
                key.hasPrefix("com.apple.security.temporary-exception."),
                "Temporary entitlement is not App Store safe: \(key)"
            )
            XCTAssertFalse(
                key.contains(".home-relative-path.") || key.contains(".absolute-path."),
                "Path entitlement is not App Store safe: \(key)"
            )
        }
    }

    func testUserSelectedFileImportsUseScopedAccessWithoutBookmarks() throws {
        try assertImmediateScopedImport(
            in: "Sources/App/ContentView.swift",
            handler: "handleChessImport"
        )
        try assertImmediateScopedImport(
            in: "Sources/Views/WordPuzzleView.swift",
            handler: "handleImport"
        )
    }

    func testAppStoreConnectExportUsesCloudManagedUploadSigning() throws {
        let exportOptions = try plist(at: macOSRoot.appendingPathComponent("ExportOptions-AppStoreConnect.plist"))

        XCTAssertEqual(exportOptions["method"] as? String, "app-store-connect")
        XCTAssertEqual(exportOptions["destination"] as? String, "upload")
        XCTAssertEqual(exportOptions["signingStyle"] as? String, "automatic")
        XCTAssertEqual(exportOptions["teamID"] as? String, expectedTeamID)
        XCTAssertEqual(exportOptions["manageAppVersionAndBuildNumber"] as? Bool, false)
        XCTAssertEqual(exportOptions["uploadSymbols"] as? Bool, true)
    }

    func testMacVersionAndBuildInputsStayInSyncWithIOS() throws {
        let macProject = try yaml(at: macOSRoot.appendingPathComponent("project.yml"))
        let iosProject = try yaml(at: repositoryRoot.appendingPathComponent("ios/project.yml"))

        let macMarketingVersion = try XCTUnwrap(yamlValue("MARKETING_VERSION", in: macProject))
        let iosMarketingVersion = try XCTUnwrap(yamlValue("MARKETING_VERSION", in: iosProject))
        let macBuildNumber = try XCTUnwrap(yamlValue("CURRENT_PROJECT_VERSION", in: macProject))
        let iosBuildNumber = try XCTUnwrap(yamlValue("CURRENT_PROJECT_VERSION", in: iosProject))

        XCTAssertFalse(macMarketingVersion.isEmpty)
        XCTAssertEqual(macMarketingVersion, iosMarketingVersion)
        XCTAssertEqual(macBuildNumber, iosBuildNumber)
        XCTAssertGreaterThan(try XCTUnwrap(Int(macBuildNumber)), 0)
    }

    func testReleaseConfigurationAndDecreeSourceExcludePrivateNetworkExceptions() throws {
        let project = try yaml(at: macOSRoot.appendingPathComponent("project.yml"))
        let decreeStore = try String(
            contentsOf: macOSRoot.appendingPathComponent("Sources/Model/DecreeStore.swift"),
            encoding: .utf8
        )

        for prohibitedValue in [
            "http://",
            "archbox.lan",
            "100.108.54.108",
            "NSExceptionDomains",
            "NSAllowsArbitraryLoads",
            "NSLocalNetworkUsageDescription"
        ] {
            XCTAssertFalse(
                project.contains(prohibitedValue),
                "Release project configuration must not contain \(prohibitedValue)"
            )
            XCTAssertFalse(
                decreeStore.contains(prohibitedValue),
                "Release decree source must not contain \(prohibitedValue)"
            )
        }
        XCTAssertTrue(
            decreeStore.contains("https://gist.githubusercontent.com/"),
            "Release decree source must retain a public HTTPS chronicle endpoint"
        )
    }

    private func yaml(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func yamlValue(_ key: String, in yaml: String, target: String? = nil) -> String? {
        let lines = yaml.components(separatedBy: .newlines)
        var isInTarget = target == nil
        var targetIndentation: Int?

        for line in lines {
            let indentation = line.prefix { $0 == " " }.count
            if let target, line.trimmingCharacters(in: .whitespaces) == "\(target):" {
                isInTarget = true
                targetIndentation = indentation
                continue
            }
            if let targetIndentation, indentation <= targetIndentation, !line.trimmingCharacters(in: .whitespaces).isEmpty {
                isInTarget = false
            }
            guard isInTarget else { continue }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            return trimmed
                .dropFirst(key.count + 1)
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return nil
    }

    private func plist(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let value = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(value as? [String: Any])
    }

    private func assertImmediateScopedImport(in relativePath: String, handler: String,
                                             file: StaticString = #filePath, line: UInt = #line) throws {
        let source = try String(
            contentsOf: macOSRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
        let handlerRange = try XCTUnwrap(
            source.range(of: "private func \(handler)("),
            "Missing import handler \(handler)", file: file, line: line
        )
        let sourceAfterHandler = source[handlerRange.lowerBound...]
        let handlerSource: String
        if let nextHandler = sourceAfterHandler.dropFirst().range(of: "\n    private func ") {
            handlerSource = String(sourceAfterHandler[..<nextHandler.lowerBound])
        } else {
            handlerSource = String(sourceAfterHandler)
        }

        let accessExpression = try NSRegularExpression(
            pattern: #"let\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*url\.startAccessingSecurityScopedResource\(\)"#
        )
        let accessMatch = try XCTUnwrap(
            accessExpression.firstMatch(
                in: handlerSource,
                range: NSRange(handlerSource.startIndex..., in: handlerSource)
            ),
            "\(handler) must begin scoped access for the selected URL", file: file, line: line
        )
        let accessFlag = String(handlerSource[Range(accessMatch.range(at: 1), in: handlerSource)!])
        let deferredStopExpression = try NSRegularExpression(
            pattern: #"defer\s*\{\s*if\s+\#(accessFlag)\s*\{\s*url\.stopAccessingSecurityScopedResource\(\)\s*\}\s*\}"#
        )
        XCTAssertNotNil(
            deferredStopExpression.firstMatch(
                in: handlerSource,
                range: NSRange(handlerSource.startIndex..., in: handlerSource)
            ),
            "\(handler) must defer stopping scoped access only when it started", file: file, line: line
        )
        XCTAssertFalse(
            handlerSource.localizedCaseInsensitiveContains("bookmark"),
            "\(handler) must consume the selected URL immediately without retaining bookmarks", file: file, line: line
        )
    }
}
