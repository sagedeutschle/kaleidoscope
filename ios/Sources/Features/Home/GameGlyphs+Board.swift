import SwiftUI

// MARK: - Board game glyphs (app-icon style)
//
// Self-contained, pure-SwiftUI vector glyphs for the Home cards. Each glyph is a
// `View` that draws a SQUARE icon filling its frame edge-to-edge; the caller sizes
// it (~28–64pt) and clips it to a rounded rectangle. Everything is normalized to the
// smaller side (via GeometryReader / a Canvas scaled to `size`) so it scales cleanly
// at any size. No image assets, no bundled files, no network.
//
// Authentic references baked into the palettes below (from research):
//  • GlyphChess       — Staunton KNIGHT (chess's most iconic silhouette), ivory-on-dark
//                       walnut over a subtle checkerboard corner.
//  • GlyphCheckers    — US-style red-and-black checkerboard with a stacked red disc and
//                       black disc; the red disc is crowned (a "king").
//  • GlyphReversi     — authentic Othello green felt board with a black disc and a white
//                       disc, the white one tilted to evoke a mid-flip capture.
//  • GlyphConnectFour — Hasbro's classic blue vertical grid of circular holes, with a
//                       red disc and a yellow disc seated in the columns.

// Shared corner-rounding ratio for the background tile, matching a cohesive app-icon look
// (kept identical to the Arcade glyph set so all Home tiles feel like one family).
private let boardGlyphTileCornerRatio: CGFloat = 0.225

// A filled rounded-square background tile used by every board glyph for consistency.
private struct BoardGlyphTile<Content: View>: View {
    let fill: BoardAnyShapeView
    let inset: CGFloat            // fraction of side reserved as internal padding (~0.12–0.15)
    @ViewBuilder let content: (CGFloat) -> Content   // receives the inner content side length

    init<S: ShapeStyle>(fill: S, inset: CGFloat = 0.13, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.fill = BoardAnyShapeView(fill)
        self.inset = inset
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let corner = side * boardGlyphTileCornerRatio
            let pad = side * inset
            let inner = side - pad * 2
            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(fill.style)
                content(inner)
                    .frame(width: inner, height: inner)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// Type-erased ShapeStyle wrapper so BoardGlyphTile can accept Color or Gradient uniformly.
private struct BoardAnyShapeView {
    let style: AnyShapeStyle
    init<S: ShapeStyle>(_ s: S) { style = AnyShapeStyle(s) }
}

// MARK: - Chess

/// The Staunton KNIGHT — chess's most recognizable silhouette — rendered in ivory over a
/// dark walnut tile, with a subtle two-square checkerboard tucked into the bottom-right
/// corner to unmistakably read as a chessboard.
struct GlyphChess: View {
    private let board  = Color(red: 0.180, green: 0.106, blue: 0.055)   // dark walnut
    private let boardHi = Color(red: 0.271, green: 0.169, blue: 0.098)  // lighter walnut sheen
    private let ivory  = Color(red: 0.960, green: 0.941, blue: 0.886)   // ivory piece
    private let ivoryShade = Color(red: 0.808, green: 0.780, blue: 0.706) // ivory shadow side
    private let square = Color(red: 0.949, green: 0.933, blue: 0.878)   // light checker square

    var body: some View {
        BoardGlyphTile(fill: LinearGradient(colors: [boardHi, board],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                       inset: 0.12) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)

                // Faint full-tile checkerboard so the surface clearly reads as a chessboard
                // (subtle light squares only — avoids the blocky corner artifact).
                let n = 8
                let cell = s / CGFloat(n)
                for r in 0..<n {
                    for c in 0..<n where (r + c) % 2 == 0 {
                        let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell,
                                          width: cell, height: cell)
                        ctx.fill(Path(rect), with: .color(square.opacity(0.10)))
                    }
                }

                // Knight silhouette, drawn as a closed path in a normalized 0..1 box then
                // scaled/centered. Classic left-facing Staunton knight profile.
                let scale = s * 0.78
                let dx = (s - scale) / 2
                let dy = (s - scale) / 2 - s * 0.01
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: dx + x * scale, y: dy + y * scale)
                }

                var knight = Path()
                knight.move(to: p(0.20, 0.94))                 // base, left
                knight.addLine(to: p(0.80, 0.94))              // base, right
                knight.addLine(to: p(0.80, 0.84))              // base collar top-right
                knight.addLine(to: p(0.66, 0.84))              // collar step
                knight.addCurve(to: p(0.72, 0.56),             // neck / chest, right side rising
                                control1: p(0.74, 0.80),
                                control2: p(0.78, 0.66))
                knight.addCurve(to: p(0.63, 0.30),             // up the back of the neck to poll
                                control1: p(0.68, 0.46),
                                control2: p(0.66, 0.37))
                knight.addLine(to: p(0.70, 0.20))              // ear (pointed)
                knight.addLine(to: p(0.58, 0.20))              // ear notch / forehead
                knight.addCurve(to: p(0.34, 0.16),             // over the brow to the muzzle top
                                control1: p(0.50, 0.14),
                                control2: p(0.42, 0.13))
                knight.addLine(to: p(0.16, 0.28))              // muzzle / nose (snout to the left)
                knight.addLine(to: p(0.14, 0.36))              // nostril tip
                knight.addLine(to: p(0.26, 0.40))              // under the jaw
                knight.addCurve(to: p(0.30, 0.58),             // throat / mane front
                                control1: p(0.30, 0.47),
                                control2: p(0.28, 0.52))
                knight.addCurve(to: p(0.28, 0.84),             // down the chest to the base collar
                                control1: p(0.33, 0.68),
                                control2: p(0.30, 0.77))
                knight.addLine(to: p(0.20, 0.84))
                knight.closeSubpath()

                // Soft drop shadow behind the piece for depth.
                ctx.translateBy(x: s * 0.012, y: s * 0.02)
                ctx.fill(knight, with: .color(Color.black.opacity(0.28)))
                ctx.translateBy(x: -s * 0.012, y: -s * 0.02)

                // The ivory piece body, with a subtle left-light gradient.
                ctx.fill(knight, with: .linearGradient(
                    Gradient(colors: [ivory, ivoryShade]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: s, y: s)))

                // Eye dot.
                let eye = CGRect(x: dx + 0.40 * scale, y: dy + 0.26 * scale,
                                 width: scale * 0.055, height: scale * 0.055)
                ctx.fill(Path(ellipseIn: eye), with: .color(board))
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Checkers

/// US-style checkers: a red-and-black checkerboard with a stacked pair of discs —
/// a black disc and, on top / beside it, a crowned red "king" disc.
struct GlyphCheckers: View {
    private let dark   = Color(red: 0.098, green: 0.086, blue: 0.078)   // near-black square
    private let redSq  = Color(red: 0.647, green: 0.129, blue: 0.129)   // deep red square
    private let redLo  = Color(red: 0.804, green: 0.157, blue: 0.157)   // red disc
    private let redHi  = Color(red: 0.933, green: 0.322, blue: 0.290)   // red disc highlight
    private let blkLo  = Color(red: 0.129, green: 0.118, blue: 0.114)   // black disc
    private let blkHi  = Color(red: 0.310, green: 0.290, blue: 0.286)   // black disc highlight
    private let crown  = Color(red: 0.984, green: 0.816, blue: 0.310)   // gold king crown

    var body: some View {
        BoardGlyphTile(fill: dark, inset: 0.11) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)

                // 4x4 red/black checkerboard filling the tile.
                let n = 4
                let cell = s / CGFloat(n)
                for r in 0..<n {
                    for c in 0..<n {
                        let isRed = (r + c) % 2 == 0
                        let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell,
                                          width: cell, height: cell)
                        ctx.fill(Path(rect), with: .color(isRed ? redSq : dark))
                    }
                }

                // A ridged disc: base circle + concentric inner ring for the classic checker look.
                func disc(center: CGPoint, radius: CGFloat, lo: Color, hi: Color) {
                    let ring = CGRect(x: center.x - radius, y: center.y - radius,
                                      width: radius * 2, height: radius * 2)
                    // Drop shadow.
                    let sh = ring.offsetBy(dx: s * 0.012, dy: s * 0.02)
                    ctx.fill(Path(ellipseIn: sh), with: .color(Color.black.opacity(0.30)))
                    // Body gradient (top-lit).
                    ctx.fill(Path(ellipseIn: ring), with: .radialGradient(
                        Gradient(colors: [hi, lo]),
                        center: CGPoint(x: center.x - radius * 0.28, y: center.y - radius * 0.32),
                        startRadius: 0, endRadius: radius * 1.4))
                    // Inner ridge ring.
                    let ir = radius * 0.62
                    let inner = CGRect(x: center.x - ir, y: center.y - ir, width: ir * 2, height: ir * 2)
                    ctx.stroke(Path(ellipseIn: inner), with: .color(Color.black.opacity(0.18)),
                               lineWidth: radius * 0.10)
                }

                let radius = s * 0.245
                // Black disc, lower and to the left (behind).
                let blkC = CGPoint(x: s * 0.40, y: s * 0.66)
                disc(center: blkC, radius: radius, lo: blkLo, hi: blkHi)
                // Red king disc, upper-right, overlapping (stacked on top).
                let redC = CGPoint(x: s * 0.62, y: s * 0.42)
                disc(center: redC, radius: radius, lo: redLo, hi: redHi)

                // A small gold crown on the red king disc.
                let cw = radius * 1.05
                let ch = radius * 0.62
                let cx = redC.x - cw / 2
                let cy = redC.y - ch * 0.42
                var cr = Path()
                cr.move(to: CGPoint(x: cx, y: cy + ch))              // bottom-left
                cr.addLine(to: CGPoint(x: cx, y: cy + ch * 0.25))    // up left side
                cr.addLine(to: CGPoint(x: cx + cw * 0.22, y: cy + ch * 0.62)) // valley 1
                cr.addLine(to: CGPoint(x: cx + cw * 0.5, y: cy))     // center peak
                cr.addLine(to: CGPoint(x: cx + cw * 0.78, y: cy + ch * 0.62)) // valley 2
                cr.addLine(to: CGPoint(x: cx + cw, y: cy + ch * 0.25)) // up right side
                cr.addLine(to: CGPoint(x: cx + cw, y: cy + ch))      // bottom-right
                cr.closeSubpath()
                ctx.fill(cr, with: .color(crown))
                ctx.stroke(cr, with: .color(Color.black.opacity(0.22)), lineWidth: s * 0.008)
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Reversi (Othello)

/// Authentic Othello: a green felt board with a subtle grid, holding a black disc and a
/// white disc. The white disc is drawn as a tilted ellipse to evoke a disc mid-flip.
struct GlyphReversi: View {
    private let feltLo = Color(red: 0.055, green: 0.408, blue: 0.212)   // Othello green
    private let feltHi = Color(red: 0.094, green: 0.478, blue: 0.259)   // lighter green
    private let grid   = Color(red: 0.020, green: 0.271, blue: 0.129)   // dark grid lines
    private let blkLo  = Color(red: 0.078, green: 0.086, blue: 0.098)   // black disc
    private let blkHi  = Color(red: 0.290, green: 0.306, blue: 0.325)   // black disc sheen
    private let whtLo  = Color(red: 0.878, green: 0.882, blue: 0.878)   // white disc shade
    private let whtHi  = Color(red: 1.000, green: 1.000, blue: 1.000)   // white disc highlight

    var body: some View {
        BoardGlyphTile(fill: LinearGradient(colors: [feltHi, feltLo],
                                            startPoint: .top, endPoint: .bottom),
                       inset: 0.11) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)

                // Subtle 4x4 grid lines across the felt.
                let n = 4
                let cell = s / CGFloat(n)
                var lines = Path()
                for i in 1..<n {
                    let v = CGFloat(i) * cell
                    lines.move(to: CGPoint(x: v, y: 0)); lines.addLine(to: CGPoint(x: v, y: s))
                    lines.move(to: CGPoint(x: 0, y: v)); lines.addLine(to: CGPoint(x: s, y: v))
                }
                ctx.stroke(lines, with: .color(grid.opacity(0.55)), lineWidth: s * 0.012)

                // Black disc, lower-left.
                let radius = s * 0.24
                let blkC = CGPoint(x: s * 0.36, y: s * 0.62)
                let bRing = CGRect(x: blkC.x - radius, y: blkC.y - radius,
                                   width: radius * 2, height: radius * 2)
                ctx.fill(Path(ellipseIn: bRing.offsetBy(dx: s * 0.012, dy: s * 0.02)),
                         with: .color(Color.black.opacity(0.32)))
                ctx.fill(Path(ellipseIn: bRing), with: .radialGradient(
                    Gradient(colors: [blkHi, blkLo]),
                    center: CGPoint(x: blkC.x - radius * 0.3, y: blkC.y - radius * 0.35),
                    startRadius: 0, endRadius: radius * 1.4))

                // White disc, upper-right, drawn as a tilted (foreshortened) ellipse to read
                // as a disc caught mid-flip.
                let wC = CGPoint(x: s * 0.64, y: s * 0.40)
                let wW = radius * 2
                let wH = radius * 1.42            // squashed vertically → tilt/flip look
                let wRing = CGRect(x: wC.x - wW / 2, y: wC.y - wH / 2, width: wW, height: wH)
                ctx.fill(Path(ellipseIn: wRing.offsetBy(dx: s * 0.012, dy: s * 0.02)),
                         with: .color(Color.black.opacity(0.28)))
                ctx.fill(Path(ellipseIn: wRing), with: .radialGradient(
                    Gradient(colors: [whtHi, whtLo]),
                    center: CGPoint(x: wC.x - wW * 0.16, y: wC.y - wH * 0.24),
                    startRadius: 0, endRadius: wW * 0.75))
                // Thin edge to give the tilted disc a sense of thickness (the flipping rim).
                ctx.stroke(Path(ellipseIn: wRing),
                           with: .color(Color.black.opacity(0.12)), lineWidth: s * 0.008)
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Connect Four

/// Hasbro's classic Connect Four: a bright-blue vertical grid of circular holes, with a
/// red disc and a yellow disc seated in the columns (the rest are empty sky-blue holes).
struct GlyphConnectFour: View {
    private let blueLo = Color(red: 0.118, green: 0.435, blue: 0.827)   // classic Connect-4 blue
    private let blueHi = Color(red: 0.220, green: 0.549, blue: 0.910)   // lighter blue sheen
    private let hole   = Color(red: 0.086, green: 0.278, blue: 0.545)   // empty hole (shadowed sky)
    private let redLo  = Color(red: 0.859, green: 0.169, blue: 0.180)   // red disc
    private let redHi  = Color(red: 0.965, green: 0.353, blue: 0.325)   // red highlight
    private let ylwLo  = Color(red: 0.976, green: 0.769, blue: 0.129)   // yellow disc
    private let ylwHi  = Color(red: 1.000, green: 0.886, blue: 0.380)   // yellow highlight

    // Which holes hold a disc: nil = empty, "r" = red, "y" = yellow. A 4x4 sample of the grid.
    private let cells: [[String?]] = [
        [nil, nil, nil, nil],
        [nil, nil, "y", nil],
        [nil, "r", "y", nil],
        ["r", "r", "y", "r"]
    ]

    var body: some View {
        BoardGlyphTile(fill: LinearGradient(colors: [blueHi, blueLo],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                       inset: 0.10) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)
                let n = 4
                let margin = s * 0.06
                let usable = s - margin * 2
                let cell = usable / CGFloat(n)
                let radius = cell * 0.38

                for r in 0..<n {
                    for c in 0..<n {
                        let cx = margin + (CGFloat(c) + 0.5) * cell
                        let cy = margin + (CGFloat(r) + 0.5) * cell
                        let rect = CGRect(x: cx - radius, y: cy - radius,
                                          width: radius * 2, height: radius * 2)
                        let token = cells[r][c]
                        if token == nil {
                            // Empty hole: dark recessed circle with a faint inner shadow.
                            ctx.fill(Path(ellipseIn: rect), with: .color(hole))
                            ctx.stroke(Path(ellipseIn: rect),
                                       with: .color(Color.black.opacity(0.18)),
                                       lineWidth: radius * 0.14)
                        } else {
                            let isRed = token == "r"
                            let hi = isRed ? redHi : ylwHi
                            let lo = isRed ? redLo : ylwLo
                            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                                Gradient(colors: [hi, lo]),
                                center: CGPoint(x: cx - radius * 0.3, y: cy - radius * 0.32),
                                startRadius: 0, endRadius: radius * 1.35))
                            ctx.stroke(Path(ellipseIn: rect),
                                       with: .color(Color.black.opacity(0.14)),
                                       lineWidth: radius * 0.08)
                        }
                    }
                }
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct GameGlyphsBoard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                GlyphChess().frame(width: 64, height: 64)
                GlyphCheckers().frame(width: 64, height: 64)
                GlyphReversi().frame(width: 64, height: 64)
                GlyphConnectFour().frame(width: 64, height: 64)
            }
            HStack(spacing: 12) {
                GlyphChess().frame(width: 32, height: 32)
                GlyphCheckers().frame(width: 32, height: 32)
                GlyphReversi().frame(width: 32, height: 32)
                GlyphConnectFour().frame(width: 32, height: 32)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
