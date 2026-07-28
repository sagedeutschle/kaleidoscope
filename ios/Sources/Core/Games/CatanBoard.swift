import Foundation

// PRISM: RELEASE Agent-Design/Claude 2026-07-12 — Catan (Settlers) board topology.
//
// The classic Catan board is a radius-2 hexagon of 19 land hexes. Everything the
// game needs — where settlements/cities can sit (vertices), where roads go (edges),
// and which hexes pay out to which corner — is derived here ONCE from geometry, then
// referenced by index. The topology is fixed for every game, so it is never encoded
// in a save; only the per-game layout (resources/number tokens) and play state are.
//
// Vertices and edges are discovered by computing each hex's six corners in a shared
// pixel space and de-duplicating shared corners by a rounded key. A correct build
// yields the well-known counts: 19 hexes, 54 vertices, 72 edges (see CatanGameTests).

/// A point in the board's normalized layout space (hex size = 1). Not the screen.
struct CatanPoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
}

/// Axial coordinates of a hex (q, r); the third cube coord is s = -q - r.
struct CatanHexCoord: Codable, Equatable, Hashable {
    var q: Int
    var r: Int
}

/// An undirected edge between two vertex indices, stored with a < b.
struct CatanEdge: Codable, Equatable, Hashable {
    var a: Int
    var b: Int
}

/// The five producing resources. The desert produces nothing and is represented by a
/// `nil` resource on its tile.
enum CatanResource: String, Codable, CaseIterable, Equatable, Hashable {
    case brick, lumber, wool, grain, ore

    var label: String {
        switch self {
        case .brick: return "Brick"
        case .lumber: return "Lumber"
        case .wool: return "Wool"
        case .grain: return "Grain"
        case .ore: return "Ore"
        }
    }

    /// SF Symbol used to represent the resource in the UI.
    var symbolName: String {
        switch self {
        case .brick: return "rectangle.fill"
        case .lumber: return "tree.fill"
        case .wool: return "cloud.fill"
        case .grain: return "leaf.fill"
        case .ore: return "mountain.2.fill"
        }
    }
}

/// Fixed board graph: hexes, vertices, edges and the incidence between them.
/// Build once via `CatanBoard.standard`.
struct CatanBoard {
    let hexes: [CatanHexCoord]
    let hexCenters: [CatanPoint]
    let vertices: [CatanPoint]
    let edges: [CatanEdge]

    /// The six vertex indices around each hex, in corner order.
    let hexVertexIndices: [[Int]]
    /// The hex indices each vertex touches (1...3).
    let vertexHexIndices: [[Int]]
    /// The vertex indices adjacent to each vertex (connected by an edge).
    let vertexAdjacency: [[Int]]
    /// The edge indices incident to each vertex.
    let vertexEdgeIndices: [[Int]]

    private let edgeLookup: [String: Int]

    static let standard = CatanBoard()

    /// Bounding box of the vertex layout, for mapping into a view.
    let minX: Double
    let minY: Double
    let maxX: Double
    let maxY: Double

    init() {
        // 1) The 19 hexes of a radius-2 hexagon, in a stable row-major order.
        var hexList: [CatanHexCoord] = []
        for r in -2...2 {
            for q in -2...2 {
                let s = -q - r
                if abs(q) <= 2 && abs(r) <= 2 && abs(s) <= 2 {
                    hexList.append(CatanHexCoord(q: q, r: r))
                }
            }
        }
        self.hexes = hexList

        // 2) Pointy-top pixel geometry (size = 1).
        let sqrt3 = 3.0.squareRoot()
        func center(_ h: CatanHexCoord) -> CatanPoint {
            let x = sqrt3 * (Double(h.q) + Double(h.r) / 2.0)
            let y = 1.5 * Double(h.r)
            return CatanPoint(x: x, y: y)
        }
        func corner(_ c: CatanPoint, _ i: Int) -> CatanPoint {
            let angle = Double.pi / 180.0 * (60.0 * Double(i) - 30.0)
            return CatanPoint(x: c.x + cos(angle), y: c.y + sin(angle))
        }
        func key(_ p: CatanPoint) -> String {
            let kx = Int((p.x * 1000.0).rounded())
            let ky = Int((p.y * 1000.0).rounded())
            return "\(kx):\(ky)"
        }

        let centers = hexList.map(center)
        self.hexCenters = centers

        // 3) Discover vertices by de-duplicating shared corners.
        var vertexList: [CatanPoint] = []
        var vertexKeyToIndex: [String: Int] = [:]
        var hexCorners: [[Int]] = []
        var vertexHexes: [[Int]] = []

        for (hi, c) in centers.enumerated() {
            var corners: [Int] = []
            for i in 0..<6 {
                let p = corner(c, i)
                let k = key(p)
                let vi: Int
                if let existing = vertexKeyToIndex[k] {
                    vi = existing
                } else {
                    vi = vertexList.count
                    vertexKeyToIndex[k] = vi
                    vertexList.append(p)
                    vertexHexes.append([])
                }
                corners.append(vi)
                if !vertexHexes[vi].contains(hi) { vertexHexes[vi].append(hi) }
            }
            hexCorners.append(corners)
        }

        self.vertices = vertexList
        self.hexVertexIndices = hexCorners
        self.vertexHexIndices = vertexHexes

        // 4) Discover edges from consecutive hex corners.
        var edgeList: [CatanEdge] = []
        var edgeKeyToIndex: [String: Int] = [:]
        for corners in hexCorners {
            for i in 0..<6 {
                let va = corners[i]
                let vb = corners[(i + 1) % 6]
                let lo = min(va, vb)
                let hi = max(va, vb)
                let k = "\(lo):\(hi)"
                if edgeKeyToIndex[k] == nil {
                    edgeKeyToIndex[k] = edgeList.count
                    edgeList.append(CatanEdge(a: lo, b: hi))
                }
            }
        }
        self.edges = edgeList
        self.edgeLookup = edgeKeyToIndex

        // 5) Vertex adjacency + incident edges.
        var adjacency: [[Int]] = Array(repeating: [], count: vertexList.count)
        var vertexEdges: [[Int]] = Array(repeating: [], count: vertexList.count)
        for (ei, e) in edgeList.enumerated() {
            adjacency[e.a].append(e.b)
            adjacency[e.b].append(e.a)
            vertexEdges[e.a].append(ei)
            vertexEdges[e.b].append(ei)
        }
        self.vertexAdjacency = adjacency
        self.vertexEdgeIndices = vertexEdges

        self.minX = vertexList.map(\.x).min() ?? -1
        self.minY = vertexList.map(\.y).min() ?? -1
        self.maxX = vertexList.map(\.x).max() ?? 1
        self.maxY = vertexList.map(\.y).max() ?? 1
    }

    /// Edge index for an unordered vertex pair, if such an edge exists.
    func edgeIndex(_ v1: Int, _ v2: Int) -> Int? {
        edgeLookup["\(min(v1, v2)):\(max(v1, v2))"]
    }

    /// The two endpoints of an edge.
    func endpoints(of edgeIndex: Int) -> (Int, Int) {
        let e = edges[edgeIndex]
        return (e.a, e.b)
    }
}
