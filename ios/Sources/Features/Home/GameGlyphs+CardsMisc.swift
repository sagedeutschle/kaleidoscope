import SwiftUI

// MARK: - Cards & misc game glyphs (app-icon style)
//
// Self-contained, pure-SwiftUI vector glyphs for the Home cards, matching the
// conventions established in GameGlyphs+Arcade.swift. Each glyph is a `View` that
// draws a SQUARE icon filling its frame edge-to-edge; the caller sizes it (~28–64pt)
// and clips it to a rounded rectangle. Everything is normalized to the smaller side
// so it scales cleanly at any size. No image assets, no bundled files, no network.
//
// Authentic references baked into the palettes below:
//  • GlyphSolitaire — Klondike/Windows Solitaire: green baize felt + white cards with a
//                     red heart and a black spade (classic playing-card look).
//  • GlyphBrickBench — LEGO 2x4 brick in the classic bright "LEGO Red" with cylindrical
//                     studs on top and a slight 3D bevel.
//  • GlyphOracle    — fortune-teller / oracle: a gold all-seeing eye inside a crystal ball
//                     with stars/sparkles, on deep indigo (jewel-tone mystic palette).
//  • GlyphDebtClock — national-debt ticker: dark tile with a rising red line chart and a
//                     glowing "$" (usdebtclock.org dark board + red digits vibe).
//  • GlyphWordgame  — word-guessing tiles: a row of letter squares (green / amber / grey)
//                     with generic bold letters (guess-tile motif, no trademark).

// Shared corner-rounding ratio for the background tile — matches GameGlyphs+Arcade.
private let cardsGlyphTileCornerRatio: CGFloat = 0.225

// A filled rounded-square background tile used by every glyph for consistency.
// (Named distinctly from the Arcade file's private helper to avoid any collision.)
private struct CardsGlyphTile<Content: View>: View {
    let fill: CardsAnyShapeView
    let inset: CGFloat            // fraction of side reserved as internal padding (~0.12–0.15)
    @ViewBuilder let content: (CGFloat) -> Content   // receives the inner content side length

    init<S: ShapeStyle>(fill: S, inset: CGFloat = 0.13, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.fill = CardsAnyShapeView(fill)
        self.inset = inset
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let corner = side * cardsGlyphTileCornerRatio
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

// Type-erased ShapeStyle wrapper so CardsGlyphTile can accept Color or Gradient uniformly.
private struct CardsAnyShapeView {
    let style: AnyShapeStyle
    init<S: ShapeStyle>(_ s: S) { style = AnyShapeStyle(s) }
}

// A heart suit shape, drawn normalized into a unit-ish rect.
private struct SuitHeart: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        // Start at bottom tip, sweep up each lobe with cubic curves.
        p.move(to: CGPoint(x: x + w * 0.50, y: y + h * 0.98))
        p.addCurve(to: CGPoint(x: x + w * 0.02, y: y + h * 0.32),
                   control1: CGPoint(x: x + w * 0.28, y: y + h * 0.78),
                   control2: CGPoint(x: x + w * 0.02, y: y + h * 0.56))
        p.addArc(center: CGPoint(x: x + w * 0.26, y: y + h * 0.26),
                 radius: w * 0.24, startAngle: .degrees(160), endAngle: .degrees(-20),
                 clockwise: false)
        p.addArc(center: CGPoint(x: x + w * 0.74, y: y + h * 0.26),
                 radius: w * 0.24, startAngle: .degrees(200), endAngle: .degrees(20),
                 clockwise: false)
        p.addCurve(to: CGPoint(x: x + w * 0.50, y: y + h * 0.98),
                   control1: CGPoint(x: x + w * 0.98, y: y + h * 0.56),
                   control2: CGPoint(x: x + w * 0.72, y: y + h * 0.78))
        p.closeSubpath()
        return p
    }
}

// A spade suit shape (inverted heart body + a small stem).
private struct SuitSpade: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        // Top tip at center-top, lobes below (mirror of a heart, flipped vertically).
        p.move(to: CGPoint(x: x + w * 0.50, y: y + h * 0.04))
        p.addCurve(to: CGPoint(x: x + w * 0.98, y: y + h * 0.66),
                   control1: CGPoint(x: x + w * 0.72, y: y + h * 0.22),
                   control2: CGPoint(x: x + w * 0.98, y: y + h * 0.46))
        p.addArc(center: CGPoint(x: x + w * 0.74, y: y + h * 0.72),
                 radius: w * 0.24, startAngle: .degrees(-20), endAngle: .degrees(160),
                 clockwise: false)
        p.addArc(center: CGPoint(x: x + w * 0.26, y: y + h * 0.72),
                 radius: w * 0.24, startAngle: .degrees(20), endAngle: .degrees(200),
                 clockwise: false)
        p.addCurve(to: CGPoint(x: x + w * 0.50, y: y + h * 0.04),
                   control1: CGPoint(x: x + w * 0.02, y: y + h * 0.46),
                   control2: CGPoint(x: x + w * 0.28, y: y + h * 0.22))
        p.closeSubpath()
        // Stem below the body.
        p.move(to: CGPoint(x: x + w * 0.50, y: y + h * 0.62))
        p.addLine(to: CGPoint(x: x + w * 0.64, y: y + h * 0.98))
        p.addLine(to: CGPoint(x: x + w * 0.36, y: y + h * 0.98))
        p.closeSubpath()
        return p
    }
}

// A 5-pointed star, used for oracle sparkles.
private struct SparkleStar: Shape {
    var points: Int = 4
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rOuter = min(rect.width, rect.height) / 2
        let rInner = rOuter * 0.38
        let total = points * 2
        for i in 0..<total {
            let angle = (Double(i) / Double(total)) * 2 * .pi - .pi / 2
            let r = (i % 2 == 0) ? rOuter : rInner
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r,
                             y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Solitaire

/// Klondike solitaire: a green baize felt tile with two fanned white playing cards —
/// the front card shows a red heart, the one behind shows a black spade.
struct GlyphSolitaire: View {
    private let feltLo = Color(red: 0.078, green: 0.396, blue: 0.204)   // deep baize green
    private let feltHi = Color(red: 0.145, green: 0.510, blue: 0.278)   // lighter felt highlight
    private let card   = Color(red: 0.985, green: 0.980, blue: 0.965)   // warm white card face
    private let cardEdge = Color(red: 0.70, green: 0.72, blue: 0.70)    // subtle card outline
    private let heart  = Color(red: 0.847, green: 0.153, blue: 0.180)   // classic red suit
    private let spade  = Color(red: 0.086, green: 0.090, blue: 0.110)   // classic black suit

    var body: some View {
        CardsGlyphTile(fill: LinearGradient(colors: [feltHi, feltLo],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                       inset: 0.13) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)
                let cardW = s * 0.52
                let cardH = cardW * 1.42
                let corner = cardW * 0.14

                // Back card (spade) — rotated left, offset up-left.
                var backCtx = ctx
                let backCenter = CGPoint(x: s * 0.40, y: s * 0.46)
                backCtx.translateBy(x: backCenter.x, y: backCenter.y)
                backCtx.rotate(by: .degrees(-14))
                let backRect = CGRect(x: -cardW / 2, y: -cardH / 2, width: cardW, height: cardH)
                let backPath = Path(roundedRect: backRect, cornerRadius: corner)
                backCtx.fill(backPath, with: .color(card))
                backCtx.stroke(backPath, with: .color(cardEdge), lineWidth: max(s * 0.008, 0.5))
                // Spade pip centered on back card.
                let spSide = cardW * 0.52
                let spRect = CGRect(x: -spSide / 2, y: -spSide * 0.56, width: spSide, height: spSide)
                backCtx.fill(SuitSpade().path(in: spRect), with: .color(spade))

                // Front card (heart) — rotated right, offset down-right, drawn on top.
                var frontCtx = ctx
                let frontCenter = CGPoint(x: s * 0.60, y: s * 0.56)
                frontCtx.translateBy(x: frontCenter.x, y: frontCenter.y)
                frontCtx.rotate(by: .degrees(12))
                let frontRect = CGRect(x: -cardW / 2, y: -cardH / 2, width: cardW, height: cardH)
                let frontPath = Path(roundedRect: frontRect, cornerRadius: corner)
                // Soft drop shadow so the front card reads as on top.
                frontCtx.fill(frontPath, with: .color(.black.opacity(0.18)),
                              style: FillStyle())
                frontCtx.fill(frontPath.applying(.init(translationX: -s * 0.012, y: -s * 0.012)),
                              with: .color(card))
                frontCtx.stroke(frontPath.applying(.init(translationX: -s * 0.012, y: -s * 0.012)),
                                with: .color(cardEdge), lineWidth: max(s * 0.008, 0.5))
                // Heart pip centered on front card.
                let hSide = cardW * 0.50
                let hRect = CGRect(x: -hSide / 2 - s * 0.012, y: -hSide * 0.52 - s * 0.012,
                                   width: hSide, height: hSide)
                frontCtx.fill(SuitHeart().path(in: hRect), with: .color(heart))
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Brick Bench (LEGO brick)

/// A classic LEGO 2x4 brick in bright "LEGO Red" with four cylindrical studs and a
/// slight 3D bevel (top face + front face) to read as a toy building block.
struct GlyphBrickBench: View {
    // Authentic bright LEGO Red (~#D01012) with lighter top and darker side for 3D shading.
    private let redTop  = Color(red: 0.878, green: 0.169, blue: 0.157)  // top face
    private let redSide = Color(red: 0.647, green: 0.106, blue: 0.106)  // shaded front face
    private let redStud = Color(red: 0.925, green: 0.271, blue: 0.251)  // stud top (lit)
    private let studRim = Color(red: 0.741, green: 0.129, blue: 0.129)  // stud side
    private let tile    = Color(red: 0.984, green: 0.898, blue: 0.541)  // warm yellow backdrop

    var body: some View {
        CardsGlyphTile(fill: LinearGradient(colors: [tile, Color(red: 0.968, green: 0.831, blue: 0.412)],
                                            startPoint: .top, endPoint: .bottom),
                       inset: 0.13) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)
                // Brick body geometry (a wide 2x4-proportioned block, centered).
                let brickW = s * 0.86
                let brickH = s * 0.46
                let bx = (s - brickW) / 2
                let by = s * 0.34            // leaves room for studs above
                let corner = brickH * 0.14
                let sideH = brickH * 0.34    // front (shaded) lip height

                // Studs: 4 across, sitting on top of the body.
                let studCount = 4
                let studD = brickW * 0.155
                let studGap = (brickW - CGFloat(studCount) * studD) / CGFloat(studCount + 1)
                let studCY = by - studD * 0.28
                for i in 0..<studCount {
                    let cx = bx + studGap + CGFloat(i) * (studD + studGap) + studD / 2
                    // Stud cylinder side (short rounded rect) then elliptical top cap.
                    let sideRect = CGRect(x: cx - studD / 2, y: studCY - studD * 0.10,
                                          width: studD, height: studD * 0.72)
                    ctx.fill(Path(roundedRect: sideRect, cornerRadius: studD * 0.18),
                             with: .color(studRim))
                    let capRect = CGRect(x: cx - studD / 2, y: studCY - studD * 0.34,
                                         width: studD, height: studD * 0.5)
                    ctx.fill(Path(ellipseIn: capRect), with: .color(redStud))
                }

                // Front (shaded) face of the brick.
                let frontRect = CGRect(x: bx, y: by + brickH - sideH, width: brickW, height: sideH + corner)
                ctx.fill(Path(roundedRect: frontRect, cornerRadius: corner), with: .color(redSide))
                // Top face of the brick (drawn over the front's upper edge).
                let topRect = CGRect(x: bx, y: by, width: brickW, height: brickH - sideH + corner)
                ctx.fill(Path(roundedRect: topRect, cornerRadius: corner), with: .color(redTop))
                // Subtle top-edge highlight for gloss.
                let glossRect = CGRect(x: bx + brickW * 0.06, y: by + brickH * 0.06,
                                       width: brickW * 0.88, height: brickH * 0.10)
                ctx.fill(Path(roundedRect: glossRect, cornerRadius: brickH * 0.05),
                         with: .color(.white.opacity(0.20)))
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Oracle

/// Mystical oracle: a glowing crystal ball on a stand containing a gold all-seeing eye,
/// framed by sparkle-stars, on a deep indigo/purple night tile.
struct GlyphOracle: View {
    private let skyTop  = Color(red: 0.180, green: 0.114, blue: 0.353)  // indigo top
    private let skyBot  = Color(red: 0.086, green: 0.055, blue: 0.204)  // deeper indigo
    private let orbLo   = Color(red: 0.451, green: 0.322, blue: 0.706)  // orb violet
    private let orbHi   = Color(red: 0.741, green: 0.639, blue: 0.925)  // orb glossy highlight
    private let gold    = Color(red: 0.949, green: 0.788, blue: 0.353)  // arcane gold
    private let goldHi  = Color(red: 1.000, green: 0.902, blue: 0.560)  // brighter gold
    private let irisInk = Color(red: 0.145, green: 0.086, blue: 0.267)  // dark eye center

    var body: some View {
        CardsGlyphTile(fill: LinearGradient(colors: [skyTop, skyBot],
                                            startPoint: .top, endPoint: .bottom),
                       inset: 0.13) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)
                let cx = s * 0.5
                let orbCY = s * 0.44
                let orbR = s * 0.34

                // Gold crescent stand beneath the ball.
                let standW = orbR * 1.7
                let standRect = CGRect(x: cx - standW / 2, y: orbCY + orbR * 0.62,
                                       width: standW, height: orbR * 0.5)
                ctx.fill(Path(roundedRect: standRect, cornerRadius: standW * 0.16),
                         with: .color(gold))
                let standShade = CGRect(x: cx - standW / 2, y: orbCY + orbR * 0.86,
                                        width: standW, height: orbR * 0.26)
                ctx.fill(Path(roundedRect: standShade, cornerRadius: standW * 0.14),
                         with: .color(gold.opacity(0.55)))

                // Crystal ball with a radial violet glow.
                let orbRect = CGRect(x: cx - orbR, y: orbCY - orbR, width: orbR * 2, height: orbR * 2)
                ctx.fill(Path(ellipseIn: orbRect),
                         with: .radialGradient(Gradient(colors: [orbHi, orbLo]),
                                               center: CGPoint(x: cx - orbR * 0.28, y: orbCY - orbR * 0.30),
                                               startRadius: 0, endRadius: orbR * 1.6))
                // Thin gold rim on the ball.
                ctx.stroke(Path(ellipseIn: orbRect), with: .color(gold.opacity(0.85)),
                           lineWidth: max(s * 0.012, 0.6))

                // All-seeing eye inside the ball (gold almond + dark iris + spark).
                let eyeW = orbR * 1.15
                let eyeH = orbR * 0.66
                let eyeRect = CGRect(x: cx - eyeW / 2, y: orbCY - eyeH / 2, width: eyeW, height: eyeH)
                var eye = Path()
                eye.move(to: CGPoint(x: eyeRect.minX, y: eyeRect.midY))
                eye.addQuadCurve(to: CGPoint(x: eyeRect.maxX, y: eyeRect.midY),
                                 control: CGPoint(x: eyeRect.midX, y: eyeRect.minY))
                eye.addQuadCurve(to: CGPoint(x: eyeRect.minX, y: eyeRect.midY),
                                 control: CGPoint(x: eyeRect.midX, y: eyeRect.maxY))
                eye.closeSubpath()
                ctx.fill(eye, with: .color(goldHi))
                // Iris.
                let irisD = eyeH * 0.82
                let irisRect = CGRect(x: cx - irisD / 2, y: orbCY - irisD / 2, width: irisD, height: irisD)
                ctx.fill(Path(ellipseIn: irisRect), with: .color(irisInk))
                // Pupil highlight sparkle.
                let pupD = irisD * 0.34
                let pupRect = CGRect(x: cx - pupD * 0.1, y: orbCY - pupD * 0.9,
                                     width: pupD, height: pupD)
                ctx.fill(Path(ellipseIn: pupRect), with: .color(goldHi.opacity(0.9)))

                // Glossy specular on the orb.
                let gloss = CGRect(x: cx - orbR * 0.66, y: orbCY - orbR * 0.72,
                                   width: orbR * 0.5, height: orbR * 0.34)
                ctx.fill(Path(ellipseIn: gloss), with: .color(.white.opacity(0.28)))

                // Sparkle stars around the orb.
                let sparks: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.16, 0.16, 0.15), (0.86, 0.22, 0.11), (0.80, 0.60, 0.08)
                ]
                for sp in sparks {
                    let d = s * sp.2
                    let r = CGRect(x: s * sp.0 - d / 2, y: s * sp.1 - d / 2, width: d, height: d)
                    ctx.fill(SparkleStar(points: 4).path(in: r), with: .color(goldHi))
                }
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Debt Clock

/// National-debt ticker: dark board with a rising red trend line over a baseline grid,
/// an up-arrowhead at the peak, and a glowing gold "$" — evokes a debt counter.
struct GlyphDebtClock: View {
    private let boardLo = Color(red: 0.055, green: 0.063, blue: 0.086)  // near-black board
    private let boardHi = Color(red: 0.114, green: 0.129, blue: 0.169)  // slate top
    private let grid    = Color(red: 0.243, green: 0.267, blue: 0.322)  // faint grid lines
    private let lineRed = Color(red: 0.917, green: 0.235, blue: 0.235)  // rising red line
    private let lineHi  = Color(red: 1.000, green: 0.408, blue: 0.376)  // brighter red tip
    private let dollar  = Color(red: 0.235, green: 0.796, blue: 0.416)  // ticker green $ (money)

    var body: some View {
        CardsGlyphTile(fill: LinearGradient(colors: [boardHi, boardLo],
                                            startPoint: .top, endPoint: .bottom),
                       inset: 0.13) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)
                // Faint baseline grid (a few horizontal lines).
                for i in 1...3 {
                    let y = s * (0.30 + CGFloat(i) * 0.17)
                    var g = Path()
                    g.move(to: CGPoint(x: s * 0.10, y: y))
                    g.addLine(to: CGPoint(x: s * 0.90, y: y))
                    ctx.stroke(g, with: .color(grid), lineWidth: max(s * 0.008, 0.4))
                }

                // Rising trend line (zig-zag climbing to the top-right).
                let pts: [CGPoint] = [
                    CGPoint(x: s * 0.12, y: s * 0.78),
                    CGPoint(x: s * 0.32, y: s * 0.64),
                    CGPoint(x: s * 0.50, y: s * 0.70),
                    CGPoint(x: s * 0.68, y: s * 0.44),
                    CGPoint(x: s * 0.86, y: s * 0.22)
                ]
                var line = Path()
                line.move(to: pts[0])
                for p in pts.dropFirst() { line.addLine(to: p) }
                ctx.stroke(line, with: .linearGradient(
                    Gradient(colors: [lineRed, lineHi]),
                    startPoint: pts[0], endPoint: pts.last!),
                    style: StrokeStyle(lineWidth: max(s * 0.045, 1.2),
                                       lineCap: .round, lineJoin: .round))

                // Up-arrowhead at the peak.
                let tip = pts.last!
                var head = Path()
                let a = s * 0.11
                head.move(to: tip)
                head.addLine(to: CGPoint(x: tip.x - a, y: tip.y + a * 0.55))
                head.addLine(to: CGPoint(x: tip.x - a * 0.45, y: tip.y + a * 1.0))
                head.closeSubpath()
                ctx.fill(head, with: .color(lineHi))

                // Glowing green "$" in the lower-left, on a subtle dark pill.
                let dollarText = Text("$")
                    .font(.system(size: s * 0.34, weight: .heavy, design: .rounded))
                    .foregroundColor(dollar)
                ctx.draw(ctx.resolve(dollarText), at: CGPoint(x: s * 0.24, y: s * 0.34))
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Wordgame

/// Word-guessing tiles: a 2x2 cluster of letter squares colored green / amber / grey
/// with GENERIC bold letters (guess-tile feedback motif; no trademarked word/logo).
struct GlyphWordgame: View {
    private let bg      = Color(red: 0.098, green: 0.106, blue: 0.129)  // charcoal tile backdrop
    private let green   = Color(red: 0.416, green: 0.667, blue: 0.392)  // correct-spot green (#6aaa64)
    private let amber   = Color(red: 0.788, green: 0.706, blue: 0.345)  // present amber (#c9b458)
    private let grey    = Color(red: 0.471, green: 0.486, blue: 0.494)  // absent grey (#787c7e)
    private let letterInk = Color.white

    // 2x2 grid: (letter, color). Generic letters, guess-tile colors.
    private let cells: [(String, Int)] = [
        ("A", 0), ("B", 1),   // green, amber
        ("C", 2), ("D", 0)    // grey, green
    ]

    var body: some View {
        CardsGlyphTile(fill: LinearGradient(colors: [Color(red: 0.145, green: 0.153, blue: 0.180), bg],
                                            startPoint: .top, endPoint: .bottom),
                       inset: 0.14) { inner in
            Canvas { ctx, size in
                let s = min(size.width, size.height)
                let cols = 2
                let spacing = s * 0.08
                let cell = (s - spacing * CGFloat(cols - 1)) / CGFloat(cols)
                let palette = [green, amber, grey]
                for row in 0..<cols {
                    for col in 0..<cols {
                        let idx = row * cols + col
                        let (letter, colorIdx) = cells[idx]
                        let x = CGFloat(col) * (cell + spacing)
                        let y = CGFloat(row) * (cell + spacing)
                        let rect = CGRect(x: x, y: y, width: cell, height: cell)
                        let path = Path(roundedRect: rect, cornerRadius: cell * 0.16)
                        ctx.fill(path, with: .color(palette[colorIdx]))
                        // Subtle top gloss on each tile.
                        let g = CGRect(x: rect.minX + cell * 0.12, y: rect.minY + cell * 0.10,
                                       width: cell * 0.76, height: cell * 0.14)
                        ctx.fill(Path(roundedRect: g, cornerRadius: cell * 0.06),
                                 with: .color(.white.opacity(0.14)))
                        // Bold generic letter.
                        let label = Text(letter)
                            .font(.system(size: cell * 0.58, weight: .heavy, design: .rounded))
                            .foregroundColor(letterInk)
                        ctx.draw(ctx.resolve(label), at: CGPoint(x: rect.midX, y: rect.midY))
                    }
                }
            }
            .frame(width: inner, height: inner)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct GameGlyphsCardsMisc_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                GlyphSolitaire().frame(width: 64, height: 64)
                GlyphBrickBench().frame(width: 64, height: 64)
                GlyphOracle().frame(width: 64, height: 64)
                GlyphDebtClock().frame(width: 64, height: 64)
                GlyphWordgame().frame(width: 64, height: 64)
            }
            HStack(spacing: 12) {
                GlyphSolitaire().frame(width: 32, height: 32)
                GlyphBrickBench().frame(width: 32, height: 32)
                GlyphOracle().frame(width: 32, height: 32)
                GlyphDebtClock().frame(width: 32, height: 32)
                GlyphWordgame().frame(width: 32, height: 32)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
