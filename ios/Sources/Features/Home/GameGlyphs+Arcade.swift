import SwiftUI

// MARK: - Arcade game glyphs (app-icon style)
//
// Self-contained, pure-SwiftUI vector glyphs for the Home cards. Each glyph is a
// `View` that draws a SQUARE icon filling its frame edge-to-edge; the caller sizes
// it (~28–64pt) and clips it to a rounded rectangle. Everything is normalized to the
// smaller side via GeometryReader so it scales cleanly at any size. No image assets,
// no bundled files, no network.
//
// Authentic references baked into the palettes below:
//  • Glyph2048    — real 2048 board (#bbada0) + "4" tile (#ede8c8) + dark ink (#776e65)
//  • GlyphSnake   — classic Snake: dark playfield, bright green segmented body, red apple
//  • GlyphSliding — the 15-puzzle: 4x4 grid of numbered tiles with one empty gap
//  • GlyphLightsOut — Tiger Electronics Lights Out: grid of cells, some lit warm amber

// Shared corner-rounding ratio for the background tile, matching a cohesive app-icon look.
private let glyphTileCornerRatio: CGFloat = 0.225

// A filled rounded-square background tile used by every glyph for consistency.
private struct GlyphTile<Content: View>: View {
    let fill: AnyShapeView
    let inset: CGFloat            // fraction of side reserved as internal padding (~0.12–0.15)
    @ViewBuilder let content: (CGFloat) -> Content   // receives the inner content side length

    init<S: ShapeStyle>(fill: S, inset: CGFloat = 0.13, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.fill = AnyShapeView(fill)
        self.inset = inset
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let corner = side * glyphTileCornerRatio
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

// Type-erased ShapeStyle wrapper so GlyphTile can accept Color or Gradient uniformly.
private struct AnyShapeView {
    let style: AnyShapeStyle
    init<S: ShapeStyle>(_ s: S) { style = AnyShapeStyle(s) }
}

// MARK: - 2048

/// The classic 2048 tile: warm board-brown background with a cream "4" tile and dark-brown numeral.
struct Glyph2048: View {
    // Authentic 2048 palette.
    private let board = Color(red: 0.733, green: 0.678, blue: 0.627)   // #bbada0
    private let tile  = Color(red: 0.929, green: 0.910, blue: 0.784)   // #ede8c8 (the "4" tile)
    private let ink   = Color(red: 0.467, green: 0.431, blue: 0.396)   // #776e65

    var body: some View {
        GlyphTile(fill: board, inset: 0.15) { inner in
            let corner = inner * 0.16
            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(tile)
                Text("4")
                    .font(.system(size: inner * 0.62, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Snake

/// Classic Snake: dark playfield, a bright-green segmented/rounded snake body, and a small red apple.
struct GlyphSnake: View {
    private let field = Color(red: 0.086, green: 0.145, blue: 0.086)   // deep green-black LCD field
    private let bodyLo = Color(red: 0.298, green: 0.780, blue: 0.286)  // bright green
    private let bodyHi = Color(red: 0.541, green: 0.902, blue: 0.376)  // lighter green highlight
    private let apple  = Color(red: 0.882, green: 0.196, blue: 0.220)  // red apple
    private let appleLeaf = Color(red: 0.302, green: 0.686, blue: 0.318)

    var body: some View {
        GlyphTile(fill: field, inset: 0.14) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)
                // Snake as a run of rounded square segments forming an L/step shape.
                let seg = s * 0.205
                let gap = s * 0.045
                let step = seg + gap
                // Segment grid positions (col,row) tracing a path from top-left down then right.
                let cells: [(CGFloat, CGFloat)] = [
                    (0, 0), (0, 1), (0, 2),
                    (1, 2), (2, 2), (3, 2)
                ]
                // Center the traced shape (4 wide, 3 tall) inside the inner box.
                let usedW = 4 * seg + 3 * gap
                let usedH = 3 * seg + 2 * gap
                let originX = (s - usedW) / 2
                let originY = (s - usedH) / 2
                for (i, cell) in cells.enumerated() {
                    let x = originX + cell.0 * step
                    let y = originY + cell.1 * step
                    let rect = CGRect(x: x, y: y, width: seg, height: seg)
                    let path = Path(roundedRect: rect, cornerRadius: seg * 0.34)
                    // Head (last segment) gets a lighter highlight; body alternates a subtle sheen.
                    let isHead = (i == cells.count - 1)
                    ctx.fill(path, with: .color(isHead ? bodyHi : bodyLo))
                    if !isHead {
                        // Inner sheen dot for a rounded, dimensional segment look.
                        let inset = seg * 0.24
                        let sheen = CGRect(x: x + inset, y: y + inset,
                                           width: seg - inset * 2, height: seg - inset * 2)
                        ctx.fill(Path(roundedRect: sheen, cornerRadius: (seg - inset * 2) * 0.34),
                                 with: .color(bodyHi.opacity(0.35)))
                    }
                }
                // Head eye (tiny dark dot).
                if let head = cells.last {
                    let hx = originX + head.0 * step
                    let hy = originY + head.1 * step
                    let eye = CGRect(x: hx + seg * 0.58, y: hy + seg * 0.24,
                                     width: seg * 0.18, height: seg * 0.18)
                    ctx.fill(Path(ellipseIn: eye), with: .color(field))
                }
                // Apple in the open upper-right quadrant.
                let ad = s * 0.19
                let ax = originX + 3 * step - seg * 0.1
                let ay = originY - seg * 0.15
                let appleRect = CGRect(x: max(ax, s - ad - s * 0.04), y: max(ay, s * 0.04),
                                       width: ad, height: ad)
                ctx.fill(Path(ellipseIn: appleRect), with: .color(apple))
                // Leaf on the apple.
                let leaf = CGRect(x: appleRect.midX + ad * 0.02, y: appleRect.minY - ad * 0.14,
                                  width: ad * 0.30, height: ad * 0.22)
                ctx.fill(Path(ellipseIn: leaf), with: .color(appleLeaf))
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Sliding (15-puzzle)

/// The 15-puzzle: a 4x4 grid of numbered tiles with one empty gap (bottom-right).
struct GlyphSliding: View {
    private let frame = Color(red: 0.176, green: 0.235, blue: 0.322)   // slate frame
    private let tile  = Color(red: 0.949, green: 0.933, blue: 0.882)   // warm cream tile
    private let ink   = Color(red: 0.176, green: 0.235, blue: 0.322)   // matching slate ink
    private let gap   = Color.black.opacity(0.18)

    var body: some View {
        GlyphTile(fill: frame, inset: 0.12) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)
                let cols = 4
                let spacing = s * 0.045
                let cell = (s - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                // Numbers 1..15 fill the grid; last cell (row 3, col 3) is the empty gap.
                var n = 1
                for row in 0..<cols {
                    for col in 0..<cols {
                        let x = CGFloat(col) * (cell + spacing)
                        let y = CGFloat(row) * (cell + spacing)
                        let rect = CGRect(x: x, y: y, width: cell, height: cell)
                        let path = Path(roundedRect: rect, cornerRadius: cell * 0.22)
                        let isGap = (row == cols - 1 && col == cols - 1)
                        if isGap {
                            ctx.fill(path, with: .color(gap))
                        } else {
                            ctx.fill(path, with: .color(tile))
                            let label = Text("\(n)")
                                .font(.system(size: cell * 0.56, weight: .bold, design: .rounded))
                                .foregroundColor(ink)
                            ctx.draw(ctx.resolve(label), at: CGPoint(x: rect.midX, y: rect.midY))
                            n += 1
                        }
                    }
                }
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Lights Out

/// Lights Out (Tiger Electronics): a 3x3 grid of rounded cells, some glowing warm amber, some dark.
struct GlyphLightsOut: View {
    private let panel  = Color(red: 0.098, green: 0.110, blue: 0.137)  // dark device panel
    private let offLo  = Color(red: 0.161, green: 0.176, blue: 0.216)  // unlit cell
    private let offHi  = Color(red: 0.216, green: 0.235, blue: 0.286)
    private let litLo  = Color(red: 0.965, green: 0.749, blue: 0.192)  // warm amber
    private let litHi  = Color(red: 1.000, green: 0.906, blue: 0.482)  // bright amber highlight

    // A fixed, pleasant "some on, some off" pattern (true = lit).
    private let lit: [Bool] = [
        true,  false, true,
        false, true,  false,
        true,  false, true
    ]

    var body: some View {
        GlyphTile(fill: panel, inset: 0.13) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)
                let cols = 3
                let spacing = s * 0.08
                let cell = (s - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                for row in 0..<cols {
                    for col in 0..<cols {
                        let idx = row * cols + col
                        let x = CGFloat(col) * (cell + spacing)
                        let y = CGFloat(row) * (cell + spacing)
                        let rect = CGRect(x: x, y: y, width: cell, height: cell)
                        let path = Path(roundedRect: rect, cornerRadius: cell * 0.30)
                        let isLit = lit[idx]
                        let grad = Gradient(colors: isLit ? [litHi, litLo] : [offHi, offLo])
                        ctx.fill(path, with: .linearGradient(
                            grad,
                            startPoint: CGPoint(x: rect.minX, y: rect.minY),
                            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                        if isLit {
                            // Soft inner glow highlight for the lit cells.
                            let g = cell * 0.22
                            let glow = CGRect(x: rect.minX + g, y: rect.minY + g,
                                              width: cell - g * 2, height: cell - g * 2)
                            ctx.fill(Path(roundedRect: glow, cornerRadius: (cell - g * 2) * 0.3),
                                     with: .color(litHi.opacity(0.55)))
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
struct GameGlyphsArcade_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                Glyph2048().frame(width: 64, height: 64)
                GlyphSnake().frame(width: 64, height: 64)
                GlyphSliding().frame(width: 64, height: 64)
                GlyphLightsOut().frame(width: 64, height: 64)
            }
            HStack(spacing: 12) {
                Glyph2048().frame(width: 32, height: 32)
                GlyphSnake().frame(width: 32, height: 32)
                GlyphSliding().frame(width: 32, height: 32)
                GlyphLightsOut().frame(width: 32, height: 32)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
