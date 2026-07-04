import SwiftUI
import AppKit

/// Canonical colors for the Brick Bench palette. The 2D swatch and the 3D
/// SceneKit material both derive from `rgb`, so a brick reads the same in
/// either canvas.
extension LegoBrickColor {
    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .classicRed: return (0.76, 0.05, 0.08)
        case .brightBlue: return (0.04, 0.28, 0.72)
        case .brightYellow: return (0.95, 0.78, 0.08)
        case .orange: return (0.92, 0.36, 0.08)
        case .tan: return (0.70, 0.56, 0.38)
        case .black: return (0.05, 0.05, 0.05)
        case .white: return (1.00, 1.00, 1.00)
        case .darkGreen: return (0.05, 0.38, 0.18)
        case .lightBluishGray: return (0.62, 0.66, 0.68)
        case .darkBluishGray: return (0.25, 0.27, 0.28)
        case .reddishBrown: return (0.35, 0.16, 0.08)
        }
    }

    var swatch: Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}
