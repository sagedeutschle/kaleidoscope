import SwiftUI

// PRISM: CLAIM Claude 2026-07-13 — Catan 3D overhaul (research branch). Win confetti overlay.
//
// A lightweight, self-contained celebratory confetti burst shown when someone wins. Pure SwiftUI
// (no dependencies on the SceneKit board), so it works over either board style. Honors reduce
// motion by simply not being shown by the caller.

struct CatanConfettiView: View {
    var colors: [Color]
    private let pieces: [Piece]

    init(colors: [Color], count: Int = 90) {
        self.colors = colors.isEmpty ? [.red, .orange, .yellow, .green, .blue] : colors
        self.pieces = (0..<count).map { _ in Piece.random() }
    }

    struct Piece {
        var x: CGFloat          // 0...1 horizontal start
        var delay: Double
        var duration: Double
        var size: CGFloat
        var spin: Double
        var colorIndex: Int
        var wobble: CGFloat

        static func random() -> Piece {
            Piece(x: .random(in: 0...1),
                  delay: .random(in: 0...0.6),
                  duration: .random(in: 1.6...2.8),
                  size: .random(in: 6...12),
                  spin: .random(in: -3...3),
                  colorIndex: Int.random(in: 0...4),
                  wobble: .random(in: -40...40))
        }
    }

    @State private var launched = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces.indices, id: \.self) { i in
                    let p = pieces[i]
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(colors[p.colorIndex % colors.count])
                        .frame(width: p.size, height: p.size * 1.6)
                        .rotationEffect(.radians(launched ? p.spin * .pi : 0))
                        .position(x: p.x * geo.size.width + (launched ? p.wobble : 0),
                                  y: launched ? geo.size.height + 40 : -40)
                        .opacity(launched ? 0.0 : 1.0)
                        .animation(.easeIn(duration: p.duration).delay(p.delay), value: launched)
                }
            }
            .onAppear { launched = true }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
