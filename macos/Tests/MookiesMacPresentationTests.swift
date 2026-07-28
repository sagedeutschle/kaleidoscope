import Foundation
import XCTest
@testable import Prismet

@MainActor
final class MookiesMacPresentationTests: XCTestCase {
    func testDesktopLayoutKeepsTheTheatreReadableAcrossWindowSizes() {
        XCTAssertEqual(MookiesMacLayoutPolicy.presentation(for: 799), .compact)
        XCTAssertEqual(MookiesMacLayoutPolicy.presentation(for: 800), .standard)
        XCTAssertEqual(MookiesMacLayoutPolicy.presentation(for: 1_179), .standard)
        XCTAssertEqual(MookiesMacLayoutPolicy.presentation(for: 1_180), .cinematic)

        XCTAssertEqual(MookiesMacLayoutPolicy.mascotWidth(for: 720), 132)
        XCTAssertEqual(MookiesMacLayoutPolicy.mascotWidth(for: 960), 172)
        XCTAssertEqual(MookiesMacLayoutPolicy.mascotWidth(for: 1_320), 218)
        XCTAssertGreaterThanOrEqual(MookiesMacLayoutPolicy.minimumTableHeight, 520)
    }

    func testBrandCopyNamesTheArcadeAndCasinoHostsExactly() {
        XCTAssertEqual(MookiesMacCopy.arcadeTitle, "Mookie's Arcade")
        XCTAssertEqual(MookiesMacCopy.casinoTitle, "Reynard's Casino")
        XCTAssertEqual(MookiesMacCopy.mookieHostLabel, "Mookie, the friendly arcade host")
        XCTAssertEqual(MookiesMacCopy.reynardHostLabel, "Reynard, the good-natured Casino host")
        XCTAssertTrue(MookiesMacCopy.practiceDisclosure.localizedCaseInsensitiveContains("no money"))
    }

    func testMascotAssetNamesRemainStableIntegrationContracts() {
        XCTAssertEqual(MookiesMacAsset.mookieHost, "MookieHost")
        XCTAssertEqual(MookiesMacAsset.reynardCasinoHost, "ReynardCasinoHost")
    }

    func testTheatreSourceIncludesMotionKeyboardAndVoiceOverHooks() throws {
        let source = try mookiesSource("MookiesCasinoTheatreView.swift")

        for required in [
            "@Environment(\\.accessibilityReduceMotion)",
            "@Environment(\\.accessibilityDifferentiateWithoutColor)",
            ".onExitCommand(perform: onLeave)",
            ".keyboardShortcut(.cancelAction)",
            ".accessibilityLabel",
            "MookiesMacLayoutPolicy.presentation",
            "MookiesCasinoFelt",
            "MookiesCasinoStageLights",
            "MookiesDecorativeChipStack",
            "MookiesDecorativeCardFan",
        ] {
            XCTAssertTrue(source.contains(required), "Desktop Casino theatre must retain \(required)")
        }
    }

    func testCompanionIsDismissibleAndNeverOwnsPrimaryGameActions() throws {
        let source = try mookiesSource("MookiesDesktopCompanionView.swift")

        for required in [
            "Button(\"Dismiss companion\"",
            ".keyboardShortcut(.cancelAction)",
            ".accessibilityLabel",
            "accessibilityReduceMotion",
            "MookiesMacMascotView",
        ] {
            XCTAssertTrue(source.contains(required), "Desktop companion must retain \(required)")
        }
        XCTAssertFalse(source.contains(".keyboardShortcut(.defaultAction)"))
    }

    func testMacMascotCatalogsContainOneAndTwoScaleTransparentPNGs() throws {
        try assertImageSet(
            named: "MookieHost",
            oneScaleFilename: "mookie-host@1x.png",
            twoScaleFilename: "mookie-host@2x.png"
        )
        try assertImageSet(
            named: "ReynardCasinoHost",
            oneScaleFilename: "reynard-casino-host@1x.png",
            twoScaleFilename: "reynard-casino-host@2x.png"
        )
    }

    private var macOSRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func mookiesSource(_ filename: String) throws -> String {
        try String(
            contentsOf: macOSRoot
                .appendingPathComponent("Sources/Mookies", isDirectory: true)
                .appendingPathComponent(filename),
            encoding: .utf8
        )
    }

    private func assertImageSet(
        named name: String,
        oneScaleFilename: String,
        twoScaleFilename: String
    ) throws {
        let root = macOSRoot
            .appendingPathComponent("Sources/Resources/Assets.xcassets", isDirectory: true)
            .appendingPathComponent("\(name).imageset", isDirectory: true)
        let contents = try String(contentsOf: root.appendingPathComponent("Contents.json"), encoding: .utf8)

        XCTAssertTrue(contents.contains(oneScaleFilename))
        XCTAssertTrue(contents.contains(twoScaleFilename))
        for filename in [oneScaleFilename, twoScaleFilename] {
            let data = try Data(contentsOf: root.appendingPathComponent(filename))
            XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        }
    }
}
