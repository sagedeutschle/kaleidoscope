import XCTest
@testable import Prismet

final class MobileGameControlTests: XCTestCase {
    func testBrickBenchDuplicateCreatesOffsetCopyWithFreshIdentity() throws {
        let originalID = UUID()
        var document = LegoBuildDocument(bricks: [
            LegoBrick(
                id: originalID,
                size: .twoByFour,
                color: .brightBlue,
                origin: LegoGridPoint(x: 14, y: 13),
                layer: 2,
                rotationQuarters: 1
            )
        ])

        let duplicateID = document.duplicate(id: originalID, gridSize: 16)

        XCTAssertNotNil(duplicateID)
        XCTAssertEqual(document.bricks.count, 2)
        XCTAssertNotEqual(duplicateID, originalID)

        let duplicate = try XCTUnwrap(document.bricks.first { $0.id == duplicateID })
        XCTAssertEqual(duplicate.size, .twoByFour)
        XCTAssertEqual(duplicate.color, .brightBlue)
        XCTAssertEqual(duplicate.layer, 2)
        XCTAssertEqual(duplicate.rotationQuarters, 1)
        XCTAssertEqual(duplicate.origin, LegoGridPoint(x: 12, y: 13))
    }

    func testRubiksMoveControlRowsGroupNormalAndInverseByFace() {
        let rows = RubiksMove.mobileControlRows

        XCTAssertEqual(rows.map(\.face), [.U, .D, .L, .R, .F, .B])
        XCTAssertEqual(rows.map(\.turn), [.U, .D, .L, .R, .F, .B])
        XCTAssertEqual(rows.map(\.inverse), [.Uprime, .Dprime, .Lprime, .Rprime, .Fprime, .Bprime])
        XCTAssertTrue(rows.allSatisfy { $0.inverse == $0.turn.inverse })
    }
}
