import CoreGraphics

/// Pure layout math for the Brick Bench 3D scene.
///
/// The renderer and click hit-testing both go through these functions so a
/// placed brick, its placement ghost, and the stud the cursor lands on always
/// agree. One stud is 1.0 world unit; the 12×12 board straddles the origin.
enum LegoSceneGeometry {
    static let gridSize = 12
    static let brickHeight: CGFloat = 0.96
    static let plateHeight: CGFloat = 0.32   // a plate is ~1/3 of a brick
    static let baseTopY: CGFloat = 0.0        // top surface of the baseplate

    /// Half the board, so grid cell 0 sits at world −half and the board centers
    /// on the origin (matches the chess board's centered layout).
    private static var half: CGFloat { CGFloat(gridSize) / 2 }

    /// World X/Z center of a `size` footprint placed at grid `origin`.
    /// Grid +x → world +X (right), grid +y → world +Z (toward the camera).
    static func footprintCenter(origin: LegoGridPoint, size: LegoBrickSize) -> (x: CGFloat, z: CGFloat) {
        footprintCenter(origin: origin, wide: size.studsWide, deep: size.studsDeep)
    }

    /// World X/Z center for an explicit footprint (used by rotated bricks whose
    /// effective width/depth differ from the catalog size).
    static func footprintCenter(origin: LegoGridPoint, wide: Int, deep: Int) -> (x: CGFloat, z: CGFloat) {
        let x = CGFloat(origin.x) + CGFloat(wide) / 2 - half
        let z = CGFloat(origin.y) + CGFloat(deep) / 2 - half
        return (x, z)
    }

    /// Visual height of one element kind.
    static func height(of kind: LegoElementKind) -> CGFloat {
        kind == .brick ? brickHeight : plateHeight
    }

    /// Y of a brick/plate center when stacked on `layer`. Each layer is one
    /// brick-height tall, so plates rest on the floor of their layer.
    static func centerY(layer: Int, kind: LegoElementKind) -> CGFloat {
        baseTopY + CGFloat(layer) * brickHeight + height(of: kind) / 2
    }

    /// Map a world X/Z (e.g. a hit test on the baseplate) back to the stud cell
    /// under it, clamped into the board.
    static func gridPoint(worldX: CGFloat, worldZ: CGFloat) -> LegoGridPoint {
        let gx = Int((worldX + half).rounded(.down))
        let gy = Int((worldZ + half).rounded(.down))
        return LegoGridPoint(x: min(max(gx, 0), gridSize - 1),
                             y: min(max(gy, 0), gridSize - 1))
    }

    /// Keep a `size` footprint fully on the board from `origin`'s top-left stud.
    static func clampedOrigin(_ origin: LegoGridPoint, for size: LegoBrickSize) -> LegoGridPoint {
        LegoGridPoint(
            x: min(max(origin.x, 0), gridSize - size.studsWide),
            y: min(max(origin.y, 0), gridSize - size.studsDeep)
        )
    }
}
