import XCTest
import SceneKit
@testable import Prismet

/// Pure layout math for the Brick Bench 3D scene. These coordinates are shared
/// by the renderer and by click hit-testing, so a wrong mapping shows up as a
/// brick (or placement ghost) landing on the wrong stud — exactly the kind of
/// off-by-half bug worth pinning down with tests before drawing anything.
final class LegoSceneGeometryTests: XCTestCase {

    // MARK: footprintCenter

    func testSingleStudBrickCentersOnItsGridCell() {
        // 1x1 brick at the corner sits half a stud in from the board edge.
        let c = LegoSceneGeometry.footprintCenter(origin: LegoGridPoint(x: 0, y: 0), size: .oneByOne)
        XCTAssertEqual(c.x, -5.5, accuracy: 0.0001)
        XCTAssertEqual(c.z, -5.5, accuracy: 0.0001)
    }

    func testWideBrickCentersOnItsFootprint() {
        // 2x4 brick (2 wide, 4 deep) placed at (4,4).
        let c = LegoSceneGeometry.footprintCenter(origin: LegoGridPoint(x: 4, y: 4), size: .twoByFour)
        XCTAssertEqual(c.x, -1.0, accuracy: 0.0001) // 4 + 2/2 - 6
        XCTAssertEqual(c.z,  0.0, accuracy: 0.0001) // 4 + 4/2 - 6
    }

    func testFootprintCenterWithExplicitDimsMatchesRotatedFootprint() {
        // A 2x4 brick turned 90° has a 4-wide, 2-deep footprint at (4,4).
        let c = LegoSceneGeometry.footprintCenter(origin: LegoGridPoint(x: 4, y: 4), wide: 4, deep: 2)
        XCTAssertEqual(c.x, 0.0, accuracy: 0.0001) // 4 + 4/2 - 6
        XCTAssertEqual(c.z, -1.0, accuracy: 0.0001) // 4 + 2/2 - 6
    }

    // MARK: centerY / stacking

    func testBrickLayerZeroRestsOnBaseplate() {
        let y = LegoSceneGeometry.centerY(layer: 0, kind: .brick)
        XCTAssertEqual(y, LegoSceneGeometry.brickHeight / 2, accuracy: 0.0001)
    }

    func testEachLayerLiftsByOneBrickHeight() {
        let y0 = LegoSceneGeometry.centerY(layer: 0, kind: .brick)
        let y1 = LegoSceneGeometry.centerY(layer: 1, kind: .brick)
        XCTAssertEqual(y1 - y0, LegoSceneGeometry.brickHeight, accuracy: 0.0001)
    }

    func testPlateIsShorterThanBrick() {
        XCTAssertLessThan(LegoSceneGeometry.height(of: .plate), LegoSceneGeometry.height(of: .brick))
    }

    // MARK: gridPoint (inverse mapping for click hit-testing)

    func testGridPointRoundTripsFromFootprintCenter() {
        for origin in [LegoGridPoint(x: 0, y: 0), LegoGridPoint(x: 5, y: 7), LegoGridPoint(x: 11, y: 11)] {
            let c = LegoSceneGeometry.footprintCenter(origin: origin, size: .oneByOne)
            let back = LegoSceneGeometry.gridPoint(worldX: c.x, worldZ: c.z)
            XCTAssertEqual(back, origin)
        }
    }

    func testGridPointClampsOutOfBoundsHits() {
        // A hit beyond the +X/+Z board edge clamps to the last valid cell.
        let p = LegoSceneGeometry.gridPoint(worldX: 99, worldZ: -99)
        XCTAssertEqual(p, LegoGridPoint(x: 11, y: 0))
    }

    // MARK: clampedOrigin

    func testClampedOriginKeepsWideBrickInsideBoard() {
        let clamped = LegoSceneGeometry.clampedOrigin(LegoGridPoint(x: 11, y: 11), for: .twoByFour)
        XCTAssertEqual(clamped, LegoGridPoint(x: 10, y: 8)) // 12-2 wide, 12-4 deep
    }

    func testClampedOriginRejectsNegativeCoordinates() {
        let clamped = LegoSceneGeometry.clampedOrigin(LegoGridPoint(x: -3, y: 5), for: .oneByOne)
        XCTAssertEqual(clamped, LegoGridPoint(x: 0, y: 5))
    }
}
