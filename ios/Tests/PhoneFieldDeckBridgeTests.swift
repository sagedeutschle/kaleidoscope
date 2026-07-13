import XCTest
import WatchFieldDeckCore
@testable import Prismet

final class PhoneFieldDeckBridgeTests: XCTestCase {
    func testApplicationContextRoundTripsThroughPortableCodec() throws {
        let snapshot = FieldDeckSnapshot.july13.replacingGeneratedAt(
            Date(timeIntervalSince1970: 1_752_436_800)
        )

        let context = try PhoneFieldDeckBridge.applicationContext(for: snapshot)

        XCTAssertEqual(try FieldDeckCodec.snapshot(from: context), snapshot)
    }

    func testRefreshRequestKeyMatchesPortableContract() {
        XCTAssertEqual(
            PhoneFieldDeckBridge.refreshRequestKey,
            FieldDeckCodec.refreshRequestKey
        )
    }
}
