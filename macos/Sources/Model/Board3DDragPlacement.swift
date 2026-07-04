import Foundation

/// How the dragged 3D piece follows the cursor before it is dropped.
enum Board3DDragPlacement: String, CaseIterable, Identifiable {
    case loose = "Loose"
    case snappy = "Snappy"

    var id: String { rawValue }

    var help: String {
        switch self {
        case .loose:
            return "Free-follow drag movement"
        case .snappy:
            return "Snap dragged pieces to square centers"
        }
    }
}
