import Foundation

/// The hot-swappable 2D / 3D canvas style shared by Chess and Brick Bench.
enum BoardStyle: String, CaseIterable, Identifiable, Codable {
    case flat = "2D"
    case iso = "3D"

    var id: String { rawValue }
    var icon: String { self == .flat ? "square.grid.3x3.fill" : "cube.fill" }
    var label: String { self == .flat ? "Flat 2D" : "Isometric 3D" }
}
