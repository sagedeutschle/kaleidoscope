import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — Rubik's persistence snapshots.

// MARK: - Integer 3D vector / rotation matrix

/// A 3D vector with integer components. Cube coordinates live in {-1, 0, 1}^3.
struct CubeVec: Codable, Equatable, Hashable {
    var x: Int
    var y: Int
    var z: Int

    init(_ x: Int, _ y: Int, _ z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    func dot(_ other: CubeVec) -> Int { x * other.x + y * other.y + z * other.z }
}

/// A 3x3 integer rotation matrix, stored as the images of the three basis
/// vectors (column-major). Used to track each cubie's orientation exactly,
/// so face turns are derived from geometry rather than hand-written permutation
/// tables — the design least prone to transcription error.
struct CubeMat: Codable, Equatable, Hashable {
    var c0: CubeVec  // image of (1,0,0)
    var c1: CubeVec  // image of (0,1,0)
    var c2: CubeVec  // image of (0,0,1)

    static let identity = CubeMat(c0: CubeVec(1, 0, 0),
                                  c1: CubeVec(0, 1, 0),
                                  c2: CubeVec(0, 0, 1))

    func apply(_ v: CubeVec) -> CubeVec {
        CubeVec(c0.x * v.x + c1.x * v.y + c2.x * v.z,
                c0.y * v.x + c1.y * v.y + c2.y * v.z,
                c0.z * v.x + c1.z * v.y + c2.z * v.z)
    }

    /// Matrix product `self * other` (apply `other` first, then `self`).
    func times(_ other: CubeMat) -> CubeMat {
        CubeMat(c0: apply(other.c0), c1: apply(other.c1), c2: apply(other.c2))
    }

    /// For an orthonormal integer rotation matrix the inverse equals the transpose.
    var inverse: CubeMat {
        CubeMat(c0: CubeVec(c0.x, c1.x, c2.x),
                c1: CubeVec(c0.y, c1.y, c2.y),
                c2: CubeVec(c0.z, c1.z, c2.z))
    }

    /// Right-hand 90° rotation about the +x, +y, or +z axis.
    static func quarterTurn(axis: Int) -> CubeMat {
        switch axis {
        case 0: // about +x: y -> z, z -> -y
            return CubeMat(c0: CubeVec(1, 0, 0), c1: CubeVec(0, 0, 1), c2: CubeVec(0, -1, 0))
        case 1: // about +y: z -> x, x -> -z
            return CubeMat(c0: CubeVec(0, 0, -1), c1: CubeVec(0, 1, 0), c2: CubeVec(1, 0, 0))
        default: // about +z: x -> y, y -> -x
            return CubeMat(c0: CubeVec(0, 1, 0), c1: CubeVec(-1, 0, 0), c2: CubeVec(0, 0, 1))
        }
    }

    static func rotation(axis: Int, quarters: Int) -> CubeMat {
        var m = CubeMat.identity
        let q = CubeMat.quarterTurn(axis: axis)
        for _ in 0..<(((quarters % 4) + 4) % 4) { m = q.times(m) }
        return m
    }
}

// MARK: - Faces and moves

/// The six cube faces, each defined by the axis it spins about and the layer
/// (coordinate value along that axis) it affects.
enum CubeFace: String, CaseIterable, Codable, Hashable {
    case U, D, L, R, F, B

    /// Axis index: 0 = x, 1 = y, 2 = z.
    var axis: Int {
        switch self {
        case .R, .L: return 0
        case .U, .D: return 1
        case .F, .B: return 2
        }
    }

    /// Which layer along `axis` this face turns: +1 or -1.
    var layer: Int {
        switch self {
        case .R, .U, .F: return 1
        case .L, .D, .B: return -1
        }
    }
}

/// A face turn: one of the six faces, quarter / double / prime.
enum RubiksMove: String, CaseIterable, Codable, Hashable, Identifiable {
    case U, D, L, R, F, B
    case Uprime = "U'", Dprime = "D'", Lprime = "L'", Rprime = "R'", Fprime = "F'", Bprime = "B'"
    case U2, D2, L2, R2, F2, B2

    var id: String { rawValue }

    var face: CubeFace {
        switch self {
        case .U, .Uprime, .U2: return .U
        case .D, .Dprime, .D2: return .D
        case .L, .Lprime, .L2: return .L
        case .R, .Rprime, .R2: return .R
        case .F, .Fprime, .F2: return .F
        case .B, .Bprime, .B2: return .B
        }
    }

    /// Number of right-hand quarter turns about the face's axis: 1, 2, or 3.
    var quarters: Int {
        switch self {
        case .U, .D, .L, .R, .F, .B: return 1
        case .U2, .D2, .L2, .R2, .F2, .B2: return 2
        case .Uprime, .Dprime, .Lprime, .Rprime, .Fprime, .Bprime: return 3
        }
    }

    var inverse: RubiksMove {
        RubiksMove.move(face: face, quarters: 4 - quarters)
    }

    /// The base (clockwise quarter) move for a face — used for scrambling/labels.
    static let baseMoves: [RubiksMove] = [.U, .D, .L, .R, .F, .B]

    static func move(face: CubeFace, quarters: Int) -> RubiksMove {
        let q = ((quarters % 4) + 4) % 4
        switch (face, q) {
        case (_, 0): return base(face)                 // no-op normalizes to the base move
        case (let f, 1): return base(f)
        case (.U, 2): return .U2
        case (.D, 2): return .D2
        case (.L, 2): return .L2
        case (.R, 2): return .R2
        case (.F, 2): return .F2
        case (.B, 2): return .B2
        case (.U, _): return .Uprime
        case (.D, _): return .Dprime
        case (.L, _): return .Lprime
        case (.R, _): return .Rprime
        case (.F, _): return .Fprime
        case (.B, _): return .Bprime
        }
    }

    private static func base(_ face: CubeFace) -> RubiksMove {
        switch face {
        case .U: return .U
        case .D: return .D
        case .L: return .L
        case .R: return .R
        case .F: return .F
        case .B: return .B
        }
    }
}

/// The three middle slices (no outer face): M (x‑axis), E (y‑axis), S (z‑axis) —
/// each rotates the layer whose coordinate on that axis is 0.
enum CubeSlice: String, CaseIterable, Codable, Hashable, Identifiable {
    case m, e, s
    var id: String { rawValue }
    var axis: Int { switch self { case .m: return 0; case .e: return 1; case .s: return 2 } }
    var label: String { rawValue.uppercased() }
}

// MARK: - The cube

/// A 3×3×3 Rubik's Cube modelled as 26 visible cubies, each carrying its solved
/// "home" position (which fixes its sticker colours) plus its current position
/// and orientation. A face turn rotates every cubie in the affected layer by the
/// same integer rotation, applied to both position and orientation. Because the
/// permutation is derived from geometry, the move engine is correct by
/// construction; the unit tests pin the algebraic identities (e.g. the sexy
/// move's order-6 relation) that would expose any error.
struct RubiksCube: Codable, Equatable, Hashable {
    /// One small cube. `home` never changes and defines the sticker colours; a
    /// sticker exists on each axis where `home` has a ±1 component.
    struct Cubie: Codable, Equatable, Hashable {
        let home: CubeVec
        var position: CubeVec
        var orientation: CubeMat
    }

    private(set) var cubies: [Cubie]

    /// The six face directions as unit vectors, paired with a stable colour index.
    static let faceDirections: [CubeVec] = [
        CubeVec(1, 0, 0), CubeVec(-1, 0, 0),
        CubeVec(0, 1, 0), CubeVec(0, -1, 0),
        CubeVec(0, 0, 1), CubeVec(0, 0, -1)
    ]

    init() {
        var built: [Cubie] = []
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 where !(x == 0 && y == 0 && z == 0) {
                    let home = CubeVec(x, y, z)
                    built.append(Cubie(home: home, position: home, orientation: .identity))
                }
            }
        }
        cubies = built
    }

    mutating func apply(_ move: RubiksMove) {
        let axis = move.face.axis
        let layer = move.face.layer
        let rot = CubeMat.rotation(axis: axis, quarters: move.quarters)
        for index in cubies.indices where component(cubies[index].position, axis: axis) == layer {
            cubies[index].position = rot.apply(cubies[index].position)
            cubies[index].orientation = rot.times(cubies[index].orientation)
        }
    }

    /// Turn a middle slice (M = x, E = y, S = z): the layer whose coordinate on that axis is 0.
    mutating func turn(slice: CubeSlice, quarters: Int) {
        let rot = CubeMat.rotation(axis: slice.axis, quarters: quarters)
        for index in cubies.indices where component(cubies[index].position, axis: slice.axis) == 0 {
            cubies[index].position = rot.apply(cubies[index].position)
            cubies[index].orientation = rot.times(cubies[index].orientation)
        }
    }

    func applying(_ moves: [RubiksMove]) -> RubiksCube {
        var copy = self
        for move in moves { copy.apply(move) }
        return copy
    }

    /// A cube is solved when each of the six faces shows a single colour. This
    /// tolerates invisible centre spins, exactly like a physical cube.
    var isSolved: Bool {
        for direction in Self.faceDirections {
            var colours = Set<Int>()
            for cubie in cubies where cubie.position.dot(direction) == 1 {
                colours.insert(Self.colourIndex(of: cubie.orientation.inverse.apply(direction)))
            }
            if colours.count != 1 { return false }
        }
        return true
    }

    /// Apply `moveCount` random quarter turns and return the sequence applied.
    /// Deterministic for a given seed; guaranteed to leave the cube unsolved.
    @discardableResult
    mutating func scramble(seed: UInt64, moveCount: Int = 25) -> [RubiksMove] {
        var rng = SeededGenerator(seed: seed)
        var moves: [RubiksMove] = []
        for _ in 0..<max(1, moveCount) {
            let face = CubeFace.allCases[rng.nextInt(upperBound: CubeFace.allCases.count)]
            let quarters = rng.nextInt(upperBound: 3) + 1   // 1, 2, or 3
            let move = RubiksMove.move(face: face, quarters: quarters)
            moves.append(move)
            apply(move)
        }
        if isSolved {
            moves.append(.R)
            apply(.R)
        }
        return moves
    }

    /// The colour index (0–5) currently shown on a given world face by a cubie,
    /// or `nil` if the cubie has no sticker there. Used by the renderer.
    func colourIndex(at cubie: Cubie, worldDirection: CubeVec) -> Int? {
        let bodyDirection = cubie.orientation.inverse.apply(worldDirection)
        guard component(cubie.home, axis: axisOfUnit(bodyDirection)) == signOfUnit(bodyDirection) else {
            return nil
        }
        return Self.colourIndex(of: bodyDirection)
    }

    // MARK: - Helpers

    private func component(_ v: CubeVec, axis: Int) -> Int {
        switch axis {
        case 0: return v.x
        case 1: return v.y
        default: return v.z
        }
    }

    private func axisOfUnit(_ v: CubeVec) -> Int {
        if v.x != 0 { return 0 }
        if v.y != 0 { return 1 }
        return 2
    }

    private func signOfUnit(_ v: CubeVec) -> Int {
        v.x + v.y + v.z   // exactly one component is ±1 for a unit direction
    }

    static func colourIndex(of unit: CubeVec) -> Int {
        if unit.x == 1 { return 0 }
        if unit.x == -1 { return 1 }
        if unit.y == 1 { return 2 }
        if unit.y == -1 { return 3 }
        if unit.z == 1 { return 4 }
        return 5
    }
}
