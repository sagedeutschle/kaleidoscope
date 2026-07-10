import XCTest
@testable import Prismet

/// Draw detection: insufficient material, the fifty-move rule, and (via the
/// repetition helper) threefold repetition.
final class DrawRuleTests: XCTestCase {

    // MARK: - Insufficient material

    func testKingVsKingIsInsufficient() {
        let pos = Position(fen: "8/8/4k3/8/8/4K3/8/8 w - - 0 1")!
        XCTAssertTrue(MoveGenerator.isInsufficientMaterial(in: pos))
        XCTAssertEqual(MoveGenerator.status(of: pos), .draw)
    }

    func testKingBishopVsKingIsInsufficient() {
        let pos = Position(fen: "8/8/4k3/8/8/4KB2/8/8 w - - 0 1")!
        XCTAssertTrue(MoveGenerator.isInsufficientMaterial(in: pos))
    }

    func testKingKnightVsKingIsInsufficient() {
        let pos = Position(fen: "8/8/4k3/8/8/4KN2/8/8 w - - 0 1")!
        XCTAssertTrue(MoveGenerator.isInsufficientMaterial(in: pos))
    }

    func testSameColorBishopsAreInsufficient() {
        // White Bc1 (dark) and Black Bf8 (dark) — both on dark squares.
        let pos = Position(fen: "5b2/8/4k3/8/8/4K3/8/2B5 w - - 0 1")!
        XCTAssertTrue(MoveGenerator.isInsufficientMaterial(in: pos))
    }

    func testOppositeColorBishopsAreNotInsufficient() {
        // White Bc1 (dark) and Black Bc8 (light) — opposite colors.
        let pos = Position(fen: "2b5/8/4k3/8/8/4K3/8/2B5 w - - 0 1")!
        XCTAssertFalse(MoveGenerator.isInsufficientMaterial(in: pos))
    }

    func testRookIsSufficientMaterial() {
        let pos = Position(fen: "8/8/4k3/8/8/4K3/8/R7 w - - 0 1")!
        XCTAssertFalse(MoveGenerator.isInsufficientMaterial(in: pos))
    }

    func testPawnIsSufficientMaterial() {
        let pos = Position(fen: "8/8/4k3/8/8/4K3/4P3/8 w - - 0 1")!
        XCTAssertFalse(MoveGenerator.isInsufficientMaterial(in: pos))
    }

    // MARK: - Fifty-move rule (halfmove clock)

    func testFenParsesHalfmoveClock() {
        let pos = Position(fen: "4k3/8/8/8/8/8/8/4K2R w - - 7 1")
        XCTAssertEqual(pos?.halfmoveClock, 7)
    }

    func testHalfmoveClockDefaultsToZeroWhenFieldOmitted() {
        let pos = Position(fen: "4k3/8/8/8/8/8/8/4K2R w - -")
        XCTAssertEqual(pos?.halfmoveClock, 0)
    }

    func testHalfmoveClockIncrementsOnQuietMove() {
        // Ng1–f3 is a quiet, non-pawn, non-capturing move.
        let move = Move(from: Square(file: 6, rank: 0), to: Square(file: 5, rank: 2))
        let next = MoveGenerator.makeMove(move, in: .initial)
        XCTAssertEqual(next.halfmoveClock, 1)
    }

    func testHalfmoveClockResetsOnPawnMove() {
        let move = Move(from: Square(file: 4, rank: 1), to: Square(file: 4, rank: 3), isDoublePawnPush: true)
        let next = MoveGenerator.makeMove(move, in: .initial)
        XCTAssertEqual(next.halfmoveClock, 0)
    }

    func testHalfmoveClockResetsOnCapture() {
        // White Rd1 captures black Nd3; clock was 5.
        let pos = Position(fen: "4k3/8/8/8/8/3n4/8/3RK3 w - - 5 1")!
        let move = Move(from: Square(file: 3, rank: 0), to: Square(file: 3, rank: 2))
        let next = MoveGenerator.makeMove(move, in: pos)
        XCTAssertEqual(next.halfmoveClock, 0)
    }

    func testFiftyMoveRuleIsDrawAtHundredHalfmoves() {
        // K+R vs K (sufficient material) — only the clock forces the draw.
        let drawPos = Position(fen: "4k3/8/4K3/8/8/8/8/6R1 w - - 100 1")!
        XCTAssertEqual(MoveGenerator.status(of: drawPos), .draw)
    }

    func testNotYetFiftyMoveRuleAtNinetyNine() {
        let pos = Position(fen: "4k3/8/4K3/8/8/8/8/6R1 w - - 99 1")!
        XCTAssertNotEqual(MoveGenerator.status(of: pos), .draw)
    }
}
