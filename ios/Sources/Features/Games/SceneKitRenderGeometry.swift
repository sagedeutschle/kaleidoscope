import SceneKit
import simd

enum ChessSceneGeometry {
    static func tileCenter(file: Int, rank: Int, y: Float) -> SCNVector3 {
        SCNVector3(Float(file) - 3.5, y, Float(7 - rank) - 3.5)
    }

    static func squareName(_ index: Int) -> String {
        "sq_\(index)"
    }

    static func squareIndex(named name: String) -> Int? {
        guard name.hasPrefix("sq_"),
              let index = Int(name.dropFirst(3)),
              (0..<64).contains(index) else {
            return nil
        }
        return index
    }
}

enum RubiksSceneGeometry {
    static let spacing: Float = 1.04

    static func key(_ home: CubeVec) -> String {
        "\(home.x),\(home.y),\(home.z)"
    }

    static func transform(for cubie: RubiksCube.Cubie) -> simd_float4x4 {
        let m = cubie.orientation
        let s = spacing
        return simd_float4x4(
            SIMD4<Float>(Float(m.c0.x), Float(m.c0.y), Float(m.c0.z), 0),
            SIMD4<Float>(Float(m.c1.x), Float(m.c1.y), Float(m.c1.z), 0),
            SIMD4<Float>(Float(m.c2.x), Float(m.c2.y), Float(m.c2.z), 0),
            SIMD4<Float>(
                Float(cubie.position.x) * s,
                Float(cubie.position.y) * s,
                Float(cubie.position.z) * s,
                1
            )
        )
    }
}
