import XCTest
@testable import Kaleidoscope

final class OracleResourceTests: XCTestCase {
    func testBundledDecreesLoadFromAppBundle() {
        let chronicle = DecreeChronicle.loadBundled()

        XCTAssertFalse(chronicle.decrees.isEmpty)
        XCTAssertEqual(chronicle.record.total, chronicle.decrees.count)
        XCTAssertTrue(chronicle.decrees.allSatisfy { !$0.title.isEmpty && !$0.regal.isEmpty })
    }
}
