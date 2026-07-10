import SwiftUI

// MARK: - Game glyphs for grid-puzzle Home cards
//
// Self-contained, app-icon-style vector glyphs for four Prismet games.
// Each is a `View` that draws a SQUARE icon filling its frame edge-to-edge:
// a filled rounded-square background tile in the game's authentic color plus a
// bold, high-contrast, centered motif inset ~12-15%. Everything is normalized
// to a unit canvas and scaled to the frame, so a single struct reads cleanly at
// ~28pt on a Home card or ~1024pt on an App Store icon. Pure SwiftUI: no assets,
// no network, no bundled files. Static only.
//
// Authentic references (see delivery note):
//   Sudoku      — classic 9x9 grid, bold 3x3 subgrid dividers, blue/black numerals.
//   Nonogram    — Picross pixel grid revealing a picture, clue-number ticks on top/left.
//   Minesweeper — Windows-classic light-grey beveled field, black spiked mine, red flag.
//   Rubik's     — Western/BOY scheme: white, red, blue, orange, green, yellow, black gaps.

// MARK: Shared helpers

private extension Color {
    /// Convenience for authentic hex-derived literals kept as 0-1 components.
    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }
}

/// A rounded-square background tile in `fill`, with an optional soft top-down
/// gradient overlay so the glyph reads as a real app icon rather than a flat swatch.
private struct GlyphTile<Content: View>: View {
    var fill: Color
    var topSheen: Double = 0.10
    var bottomShade: Double = 0.10
    @ViewBuilder var content: (CGSize) -> Content

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let corner = s * 0.225 // app-icon "squircle"-ish rounding
            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(fill)
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(topSheen), .clear, Color.black.opacity(bottomShade)],
                            startPoint: .top, endPoint: .bottom))
                content(CGSize(width: s, height: s))
            }
            .frame(width: s, height: s)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - GlyphSudoku
//
// Cream tile; a 9x9 grid with thin hairlines, BOLD 3x3 subgrid dividers, and a
// scatter of blue and black numerals — the universally recognized Sudoku look.

struct GlyphSudoku: View {
    var body: some View {
        GlyphTile(fill: .rgb(0.985, 0.972, 0.940), topSheen: 0.0, bottomShade: 0.06) { size in
            let s = size.width
            let inset = s * 0.14
            let board = s - inset * 2
            let cell = board / 9
            let thin = max(0.6, s * 0.006)
            let bold = max(1.4, s * 0.020)

            let ink = Color.rgb(0.12, 0.12, 0.14)
            let blue = Color.rgb(0.12, 0.36, 0.78)

            ZStack {
                // Fixed numerals: (col, row, value, isBlue). Row/col 0-based from top-left.
                let numerals: [(Int, Int, String, Bool)] = [
                    (0, 0, "5", false), (2, 0, "3", true),  (4, 0, "7", false),
                    (1, 1, "6", true),  (5, 1, "1", false), (7, 1, "9", true),
                    (3, 2, "8", false), (8, 2, "2", true),
                    (0, 4, "4", true),  (4, 4, "5", false), (8, 4, "1", true),
                    (2, 5, "9", false), (6, 5, "6", true),
                    (1, 6, "2", false), (5, 6, "8", true),  (7, 6, "5", false),
                    (3, 7, "7", true),
                    (0, 8, "6", false), (4, 8, "3", true),  (8, 8, "4", false),
                ]
                ForEach(numerals.indices, id: \.self) { i in
                    let n = numerals[i]
                    Text(n.2)
                        .font(.system(size: cell * 0.72, weight: .heavy, design: .rounded))
                        .foregroundColor(n.3 ? blue : ink)
                        .frame(width: cell, height: cell)
                        .position(
                            x: inset + (CGFloat(n.0) + 0.5) * cell,
                            y: inset + (CGFloat(n.1) + 0.5) * cell)
                }

                // Grid lines.
                Path { p in
                    for i in 0...9 {
                        let x = inset + CGFloat(i) * cell
                        p.move(to: CGPoint(x: x, y: inset))
                        p.addLine(to: CGPoint(x: x, y: inset + board))
                        let y = inset + CGFloat(i) * cell
                        p.move(to: CGPoint(x: inset, y: y))
                        p.addLine(to: CGPoint(x: inset + board, y: y))
                    }
                }
                .stroke(ink.opacity(0.30), lineWidth: thin)

                // Bold 3x3 subgrid dividers + outer frame.
                Path { p in
                    for i in stride(from: 0, through: 9, by: 3) {
                        let x = inset + CGFloat(i) * cell
                        p.move(to: CGPoint(x: x, y: inset))
                        p.addLine(to: CGPoint(x: x, y: inset + board))
                        let y = inset + CGFloat(i) * cell
                        p.move(to: CGPoint(x: inset, y: y))
                        p.addLine(to: CGPoint(x: inset + board, y: y))
                    }
                }
                .stroke(ink, lineWidth: bold)
            }
        }
    }
}

// MARK: - GlyphNonogram
//
// Deep-teal tile; a small pixel grid whose filled cells form a HEART, with a few
// clue-number ticks along the top and left edges — the signature Picross layout.

struct GlyphNonogram: View {
    var body: some View {
        GlyphTile(fill: .rgb(0.18, 0.45, 0.50), topSheen: 0.14, bottomShade: 0.14) { size in
            let s = size.width
            // Reserve a clue gutter on top & left; grid sits bottom-right.
            let outer = s * 0.13
            let gutter = s * 0.16
            let gridX = outer + gutter
            let gridY = outer + gutter
            let gridSize = s - gridX - outer
            let n = 6
            let cell = gridSize / CGFloat(n)

            // 6x6 heart bitmap (1 = filled). Row 0 = top.
            let heart: [[Int]] = [
                [0, 1, 1, 0, 1, 1],
                [1, 1, 1, 1, 1, 1],
                [1, 1, 1, 1, 1, 1],
                [0, 1, 1, 1, 1, 0],
                [0, 0, 1, 1, 0, 0],
                [0, 0, 0, 0, 0, 0],
            ]
            let fillCol = Color.rgb(0.98, 0.36, 0.42)
            let line = Color.white.opacity(0.85)
            let clueColor = Color.white

            // Column clues (top): consecutive-run counts, bottom-aligned per column.
            let colClues = ["3", "5", "5", "4", "4", "3"]
            // Row clues (left): right-aligned per row.
            let rowClues = ["2·2", "6", "6", "4", "2", ""]

            ZStack {
                // Filled heart cells.
                ForEach(0..<n, id: \.self) { r in
                    ForEach(0..<n, id: \.self) { c in
                        if heart[r][c] == 1 {
                            RoundedRectangle(cornerRadius: cell * 0.12, style: .continuous)
                                .fill(fillCol)
                                .frame(width: cell * 0.96, height: cell * 0.96)
                                .position(
                                    x: gridX + (CGFloat(c) + 0.5) * cell,
                                    y: gridY + (CGFloat(r) + 0.5) * cell)
                        }
                    }
                }

                // Grid lines.
                Path { p in
                    for i in 0...n {
                        let x = gridX + CGFloat(i) * cell
                        p.move(to: CGPoint(x: x, y: gridY))
                        p.addLine(to: CGPoint(x: x, y: gridY + gridSize))
                        let y = gridY + CGFloat(i) * cell
                        p.move(to: CGPoint(x: gridX, y: y))
                        p.addLine(to: CGPoint(x: gridX + gridSize, y: y))
                    }
                }
                .stroke(line, lineWidth: max(0.6, s * 0.006))

                // Top clue numbers (one per column, sitting in the top gutter).
                ForEach(0..<n, id: \.self) { c in
                    Text(colClues[c])
                        .font(.system(size: cell * 0.52, weight: .bold, design: .rounded))
                        .foregroundColor(clueColor)
                        .frame(width: cell)
                        .position(
                            x: gridX + (CGFloat(c) + 0.5) * cell,
                            y: outer + gutter * 0.5)
                }

                // Left clue numbers (one per row, in the left gutter).
                ForEach(0..<n, id: \.self) { r in
                    Text(rowClues[r])
                        .font(.system(size: cell * 0.46, weight: .bold, design: .rounded))
                        .foregroundColor(clueColor)
                        .frame(width: gutter * 0.98, alignment: .trailing)
                        .position(
                            x: outer + gutter * 0.5,
                            y: gridY + (CGFloat(r) + 0.5) * cell)
                }
            }
        }
    }
}

// MARK: - GlyphMinesweeper
//
// Windows-classic silver field; a beveled light-grey cell with a black spiked
// MINE (shine dot + spokes) and a small red triangular FLAG on a black pole.

struct GlyphMinesweeper: View {
    var body: some View {
        GlyphTile(fill: .rgb(0.75, 0.75, 0.75), topSheen: 0.0, bottomShade: 0.0) { size in
            let s = size.width
            let pad = s * 0.10

            let cellLight = Color.rgb(0.86, 0.86, 0.86)
            let bevelHi = Color.white.opacity(0.95)
            let bevelLo = Color.rgb(0.50, 0.50, 0.50)
            let mineBlack = Color.rgb(0.08, 0.08, 0.09)
            let flagRed = Color.rgb(0.86, 0.13, 0.13)

            let bev = s * 0.055 // bevel thickness

            ZStack {
                // Beveled raised cell (classic 3D Windows button look).
                ZStack {
                    // Base face.
                    Rectangle().fill(cellLight)
                    // Top + left highlight.
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: s, y: 0))
                        p.addLine(to: CGPoint(x: s - bev, y: bev))
                        p.addLine(to: CGPoint(x: bev, y: bev))
                        p.addLine(to: CGPoint(x: bev, y: s - bev))
                        p.addLine(to: CGPoint(x: 0, y: s))
                        p.closeSubpath()
                    }.fill(bevelHi)
                    // Bottom + right shadow.
                    Path { p in
                        p.move(to: CGPoint(x: s, y: 0))
                        p.addLine(to: CGPoint(x: s, y: s))
                        p.addLine(to: CGPoint(x: 0, y: s))
                        p.addLine(to: CGPoint(x: bev, y: s - bev))
                        p.addLine(to: CGPoint(x: s - bev, y: s - bev))
                        p.addLine(to: CGPoint(x: s - bev, y: bev))
                        p.closeSubpath()
                    }.fill(bevelLo)
                }
                .frame(width: s - pad * 2, height: s - pad * 2)
                .position(x: s / 2, y: s / 2)

                // --- MINE (spiked black bomb) ---
                let cx = s * 0.42
                let cy = s * 0.56
                let r = s * 0.155
                let spike = r * 1.55
                // Eight spokes.
                Path { p in
                    for k in 0..<8 {
                        let a = Double(k) * .pi / 4.0
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: cx + spike * cos(a), y: cy + spike * sin(a)))
                    }
                }
                .stroke(mineBlack, style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))
                // Spoke tip caps.
                ForEach(0..<8, id: \.self) { k in
                    let a = Double(k) * .pi / 4.0
                    Circle()
                        .fill(mineBlack)
                        .frame(width: s * 0.05, height: s * 0.05)
                        .position(x: cx + spike * cos(a), y: cy + spike * sin(a))
                }
                // Body + shine.
                Circle().fill(mineBlack)
                    .frame(width: r * 2, height: r * 2)
                    .position(x: cx, y: cy)
                Circle().fill(Color.white.opacity(0.9))
                    .frame(width: r * 0.55, height: r * 0.55)
                    .position(x: cx - r * 0.35, y: cy - r * 0.35)

                // --- FLAG (small red pennant on a black pole) ---
                let poleX = s * 0.70
                let poleTop = s * 0.24
                let poleBot = s * 0.72
                // Pole.
                Path { p in
                    p.move(to: CGPoint(x: poleX, y: poleTop))
                    p.addLine(to: CGPoint(x: poleX, y: poleBot))
                }
                .stroke(mineBlack, style: StrokeStyle(lineWidth: s * 0.032, lineCap: .round))
                // Base tick.
                Path { p in
                    p.move(to: CGPoint(x: poleX - s * 0.06, y: poleBot))
                    p.addLine(to: CGPoint(x: poleX + s * 0.06, y: poleBot))
                }
                .stroke(mineBlack, style: StrokeStyle(lineWidth: s * 0.032, lineCap: .round))
                // Pennant triangle.
                Path { p in
                    p.move(to: CGPoint(x: poleX, y: poleTop))
                    p.addLine(to: CGPoint(x: poleX - s * 0.17, y: poleTop + s * 0.085))
                    p.addLine(to: CGPoint(x: poleX, y: poleTop + s * 0.17))
                    p.closeSubpath()
                }
                .fill(flagRed)
            }
        }
    }
}

// MARK: - GlyphRubiks
//
// Isometric 3-face cube with authentic Western/BOY stickers (white top, red &
// blue front faces, plus orange/green/yellow) separated by black gaps — the
// instantly recognizable Rubik's silhouette.

struct GlyphRubiks: View {
    // Western scheme stickers per visible face (3x3 each).
    private let white = Color.rgb(0.97, 0.97, 0.97)
    private let red = Color.rgb(0.72, 0.07, 0.20)   // C4181B-ish deep Rubik red
    private let blue = Color.rgb(0.00, 0.27, 0.68)
    private let orange = Color.rgb(0.98, 0.35, 0.00)
    private let green = Color.rgb(0.00, 0.61, 0.28)
    private let yellow = Color.rgb(1.00, 0.84, 0.00)

    var body: some View {
        GlyphTile(fill: .rgb(0.09, 0.09, 0.11), topSheen: 0.08, bottomShade: 0.14) { size in
            let s = size.width
            // Cube apex (top vertex) and the three edge axes from it.
            let apex = CGPoint(x: s * 0.5, y: s * 0.185)
            let ux = CGPoint(x: s * 0.205, y: s * 0.118)   // toward right corner
            let uy = CGPoint(x: -s * 0.205, y: s * 0.118)  // toward left corner
            let down = CGPoint(x: 0, y: s * 0.236)         // vertical drop per row

            // Full 3x3 sticker sets (row-major). A couple of stickers borrow the
            // remaining scheme colors so all six authentic colors are present.
            let topColors = mix(fill9(white), [(0, yellow), (8, green)])
            let leftColors = fill9(red)
            let rightColors = mix(fill9(blue), [(2, orange), (5, green)])

            ZStack {
                // TOP face — rhombus spanned by ux (cols) and uy (rows) from apex.
                RubiksFace(base: apex, a: ux, b: uy, colors: topColors)
                // LEFT face — from the left corner (apex+uy), cols along -ux back to
                // center, rows dropping straight down.
                RubiksFace(base: add(apex, uy), a: mul(ux, -1), b: down, colors: leftColors)
                // RIGHT face — from the right corner (apex+ux), cols along -uy back to
                // center, rows dropping straight down.
                RubiksFace(base: add(apex, ux), a: mul(uy, -1), b: down, colors: rightColors)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.35), radius: s * 0.012, y: s * 0.010)
        }
    }

    private func fill9(_ c: Color) -> [Color] { Array(repeating: c, count: 9) }
    private func add(_ p: CGPoint, _ q: CGPoint) -> CGPoint { CGPoint(x: p.x + q.x, y: p.y + q.y) }
    private func mul(_ p: CGPoint, _ k: CGFloat) -> CGPoint { CGPoint(x: p.x * k, y: p.y * k) }
    private func mix(_ base: [Color], _ overrides: [(Int, Color)]) -> [Color] {
        var out = base
        for (i, c) in overrides where i >= 0 && i < out.count { out[i] = c }
        return out
    }
}

/// One 3x3 face of the isometric cube: a parallelogram spanned by unit vectors
/// `a` (columns) and `b` (rows) from `base`, drawn as 9 sticker quads with gaps.
private struct RubiksFace: View {
    var base: CGPoint
    var a: CGPoint // full-face column axis (3 cells)
    var b: CGPoint // full-face row axis (3 cells)
    var colors: [Color]

    var body: some View {
        Canvas { ctx, _ in
            let ca = CGPoint(x: a.x / 3, y: a.y / 3)
            let cb = CGPoint(x: b.x / 3, y: b.y / 3)
            // Shrink factor to create black gaps between stickers.
            let inset: CGFloat = 0.10
            for row in 0..<3 {
                for col in 0..<3 {
                    let idx = row * 3 + col
                    let c = idx < colors.count ? colors[idx] : .gray
                    let o = CGPoint(
                        x: base.x + ca.x * CGFloat(col) + cb.x * CGFloat(row),
                        y: base.y + ca.y * CGFloat(col) + cb.y * CGFloat(row))
                    // Four corners of the sticker cell, inset toward its center.
                    let corners = [
                        blend(o, ca, cb, inset, inset),
                        blend(o, ca, cb, 1 - inset, inset),
                        blend(o, ca, cb, 1 - inset, 1 - inset),
                        blend(o, ca, cb, inset, 1 - inset),
                    ]
                    var path = Path()
                    path.move(to: corners[0])
                    path.addLine(to: corners[1])
                    path.addLine(to: corners[2])
                    path.addLine(to: corners[3])
                    path.closeSubpath()
                    ctx.fill(path, with: .color(c))
                }
            }
        }
    }

    private func blend(_ o: CGPoint, _ ca: CGPoint, _ cb: CGPoint, _ fa: CGFloat, _ fb: CGFloat) -> CGPoint {
        CGPoint(x: o.x + ca.x * fa + cb.x * fb, y: o.y + ca.y * fa + cb.y * fb)
    }
}

// MARK: - Previews

#if DEBUG
struct GameGlyphs_GridPuzzles_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            GlyphSudoku().frame(width: 64, height: 64)
            GlyphNonogram().frame(width: 64, height: 64)
            GlyphMinesweeper().frame(width: 64, height: 64)
            GlyphRubiks().frame(width: 64, height: 64)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
