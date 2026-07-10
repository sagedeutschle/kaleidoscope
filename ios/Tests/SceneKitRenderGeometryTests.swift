import SceneKit
import XCTest
@testable import Prismet

final class SceneKitRenderGeometryTests: XCTestCase {
    func testChessTileCenterMatchesDesktopBoardCoordinates() {
        let a1 = ChessSceneGeometry.tileCenter(file: 0, rank: 0, y: 0.10)
        XCTAssertEqual(a1.x, -3.5, accuracy: 0.0001)
        XCTAssertEqual(a1.y, 0.10, accuracy: 0.0001)
        XCTAssertEqual(a1.z, 3.5, accuracy: 0.0001)

        let h8 = ChessSceneGeometry.tileCenter(file: 7, rank: 7, y: 0.18)
        XCTAssertEqual(h8.x, 3.5, accuracy: 0.0001)
        XCTAssertEqual(h8.y, 0.18, accuracy: 0.0001)
        XCTAssertEqual(h8.z, -3.5, accuracy: 0.0001)
    }

    func testChessSquareNamesResolveHitTestTargets() {
        XCTAssertEqual(ChessSceneGeometry.squareName(12), "sq_12")
        XCTAssertEqual(ChessSceneGeometry.squareIndex(named: "sq_63"), 63)
        XCTAssertNil(ChessSceneGeometry.squareIndex(named: "sq_64"))
        XCTAssertNil(ChessSceneGeometry.squareIndex(named: "tile_12"))
    }

    func testRubiksCubieTransformMatchesDesktopSceneKitMapping() {
        let cubie = RubiksCube.Cubie(
            home: CubeVec(1, 0, -1),
            position: CubeVec(-1, 1, 0),
            orientation: CubeMat.rotation(axis: 1, quarters: 1)
        )

        let transform = RubiksSceneGeometry.transform(for: cubie)

        XCTAssertEqual(transform.columns.0.x, Float(cubie.orientation.c0.x), accuracy: 0.0001)
        XCTAssertEqual(transform.columns.0.y, Float(cubie.orientation.c0.y), accuracy: 0.0001)
        XCTAssertEqual(transform.columns.0.z, Float(cubie.orientation.c0.z), accuracy: 0.0001)
        XCTAssertEqual(transform.columns.3.x, -RubiksSceneGeometry.spacing, accuracy: 0.0001)
        XCTAssertEqual(transform.columns.3.y, RubiksSceneGeometry.spacing, accuracy: 0.0001)
        XCTAssertEqual(transform.columns.3.z, 0, accuracy: 0.0001)
    }
}
