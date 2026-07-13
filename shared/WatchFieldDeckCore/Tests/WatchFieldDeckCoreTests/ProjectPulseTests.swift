import XCTest
@testable import WatchFieldDeckCore

final class ProjectPulseTests: XCTestCase {
    func testJuly13CatalogCoversEveryActiveProjectFamily() {
        XCTAssertEqual(
            Set(FieldDeckCatalog.july13.projects.map(\.id)),
            Set(ProjectID.allCases)
        )
        XCTAssertEqual(
            FieldDeckCatalog.july13.schemaVersion,
            FieldDeckSnapshot.currentSchemaVersion
        )
    }

    func testContextRoundTripPreservesSnapshot() throws {
        let context = try FieldDeckCodec.context(for: .july13)
        XCTAssertEqual(try FieldDeckCodec.snapshot(from: context), .july13)
    }

    func testRefreshRequestUsesStableCrossDeviceKey() {
        XCTAssertEqual(FieldDeckCodec.refreshRequestKey, "prismet.fieldDeck.refresh")
    }

    func testOnlyNewerMatchingSchemaSnapshotIsAccepted() {
        let current = FieldDeckCatalog.july13
        let newer = current.replacingGeneratedAt(current.generatedAt.addingTimeInterval(60))
        let older = current.replacingGeneratedAt(current.generatedAt.addingTimeInterval(-60))

        XCTAssertTrue(FieldDeckCodec.shouldAccept(newer, replacing: current))
        XCTAssertFalse(FieldDeckCodec.shouldAccept(older, replacing: current))
        XCTAssertFalse(
            FieldDeckCodec.shouldAccept(
                newer.replacingSchemaVersion(current.schemaVersion + 1),
                replacing: current
            )
        )
    }
}
