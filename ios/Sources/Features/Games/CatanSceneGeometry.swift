import SceneKit

// PRISM: CLAIM Claude 2026-07-13 — Catan 3D overhaul (research branch). Scene geometry math.
//
// Pure geometry for the 3D board — the SceneKit analogue of the model's CatanBoard. It maps the
// board's normalized 2D layout (pointy-top hexes, size 1, from CatanBoard) into SceneKit world
// space, and owns node naming so hit-testing can turn a tapped node back into a board index.
//
// Mapping: board (x, y) -> world (x*scale, height, -y*scale). The board lies on the XZ plane; the
// camera looks down at it. Because pieces are placed at board-derived world positions AND hex
// tiles are built from the SAME board corners, everything lines up exactly — settlements sit on
// shared corners, roads along real edges, tokens at true centers.

enum CatanSceneGeometry {
    static let scale: CGFloat = 1.0
    static let hexThickness: CGFloat = 0.36
    static let hexInset: CGFloat = 0.94        // slight grout gap between neighboring tiles
    static let topY: CGFloat = hexThickness     // world Y of the tile top surface

    /// World position of a board point, at height `y` (default the ground plane).
    static func world(_ p: CatanPoint, y: CGFloat = 0) -> SCNVector3 {
        SCNVector3(Float(p.x * scale), Float(y), Float(-p.y * scale))
    }

    static func worldXZ(_ p: CatanPoint) -> (x: CGFloat, z: CGFloat) {
        (p.x * scale, -p.y * scale)
    }

    /// A hex's six corners in the SCNShape LOCAL 2D frame (relative to the hex center), inset for
    /// a grout gap. Pair with a node at `world(center)` rotated -90° about X so it extrudes upward;
    /// then local (cx, cy) lands at world (center.x*scale + cx, top, -(center.y*scale) - cy).
    static func hexLocalPolygon(_ board: CatanBoard, _ hex: Int) -> [CGPoint] {
        let c = board.hexCenters[hex]
        return board.hexVertexIndices[hex].map { vi in
            let v = board.vertices[vi]
            return CGPoint(x: (v.x - c.x) * scale * hexInset, y: (v.y - c.y) * scale * hexInset)
        }
    }

    /// Midpoint of an edge in world space (where a road sits) and its rotation about Y so a
    /// box-road points from one endpoint to the other.
    static func edgeMidpointAndAngle(_ board: CatanBoard, _ edge: Int, y: CGFloat) -> (mid: SCNVector3, angleY: Float, length: CGFloat) {
        let (ai, bi) = board.endpoints(of: edge)
        let a = board.vertices[ai], b = board.vertices[bi]
        let s = Double(scale)
        let ax = a.x * s, az = -a.y * s
        let bx = b.x * s, bz = -b.y * s
        let mx = (ax + bx) / 2, mz = (az + bz) / 2
        let dx = bx - ax, dz = bz - az
        let len = (dx * dx + dz * dz).squareRoot()
        // angle in the XZ plane; rotate a +X-aligned box to align with the edge direction.
        let angle = atan2(dz, dx)
        return (SCNVector3(Float(mx), Float(y), Float(mz)), Float(-angle), CGFloat(len))
    }

    /// Radius of the whole island in world units (for framing the camera to fit any board).
    static func boardWorldRadius(_ board: CatanBoard) -> CGFloat {
        var maxR = 0.0
        for v in board.vertices {
            let r = (v.x * v.x + v.y * v.y).squareRoot()
            if r > maxR { maxR = r }
        }
        return CGFloat(maxR) * scale
    }

    // MARK: Node naming (hit-testing turns names back into board indices)

    static func hexName(_ i: Int) -> String { "hex_\(i)" }
    static func vertexName(_ i: Int) -> String { "vtx_\(i)" }
    static func edgeName(_ i: Int) -> String { "edge_\(i)" }

    private static func index(_ name: String?, _ prefix: String) -> Int? {
        guard let name, name.hasPrefix(prefix), let i = Int(name.dropFirst(prefix.count)) else { return nil }
        return i
    }
    static func hexIndex(_ name: String?) -> Int? { index(name, "hex_") }
    static func vertexIndex(_ name: String?) -> Int? { index(name, "vtx_") }
    static func edgeIndex(_ name: String?) -> Int? { index(name, "edge_") }
}
