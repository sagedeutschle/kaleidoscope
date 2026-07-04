// PRISM: RELEASE Agent-Design(snake) 2026-07-03 - v10 design pass
import SwiftUI

// MARK: - Snake theme ("The Neon Terrarium")
//
// Game-local material tokens — a dark recessed arcade cabinet housing a
// bioluminescent vivarium. The snake is the signature: an emerald→lime glowing
// body with a soft phosphor bloom and glossy eyes. Everything else is quiet —
// a near-black tube, a faint dotted grid that reads as a board (not a
// spreadsheet), a vignette + scanlines for CRT depth, and a glossy power-orb
// for food. Kept private and local per the design-pass convention; do not move
// to KaleidoDesign.
private enum SnakeTheme {
    // Recessed cabinet / CRT tube — near-black with a faint cool cast so the
    // neon reads as light emitted, not paint.
    static let tubeTop = Color(red: 0.055, green: 0.075, blue: 0.075)
    static let tubeBottom = Color(red: 0.020, green: 0.032, blue: 0.036)
    static let bezel = Color(red: 0.090, green: 0.100, blue: 0.115)
    static let bezelEdge = Color(red: 0.030, green: 0.036, blue: 0.044)

    // Phosphor grid — barely-there dots, cool green, so the field has structure
    // without turning into graph paper.
    static let gridDot = Color(red: 0.36, green: 0.90, blue: 0.55).opacity(0.10)

    // The living snake — bioluminescent emerald head fading to a cooler teal
    // tail, with a bright core highlight and an outer bloom. The three gradient
    // stops are kept as raw RGB so the head→tail tint can be interpolated per
    // segment without resolving a UIColor at render time.
    static let neonHeadRGB: (r: Double, g: Double, b: Double) = (0.44, 1.00, 0.55)
    static let neonBodyRGB: (r: Double, g: Double, b: Double) = (0.16, 0.86, 0.52)
    static let neonTailRGB: (r: Double, g: Double, b: Double) = (0.10, 0.62, 0.58)
    static let neonCore = Color(red: 0.82, green: 1.00, blue: 0.80)
    static let bloom = Color(red: 0.30, green: 1.00, blue: 0.55)

    // Food — a glossy magenta power-orb, the complementary pop against all that
    // green, with its own warm bloom.
    static let orb = Color(red: 1.00, green: 0.31, blue: 0.62)
    static let orbCore = Color(red: 1.00, green: 0.72, blue: 0.86)
    static let orbBloom = Color(red: 1.00, green: 0.28, blue: 0.58)

    // Phosphor accent used for the HUD accent (score / iris ring / button).
    static let accent = Color(red: 0.24, green: 0.92, blue: 0.60)
    // Eye pupil / dark ink for contrast on the glowing head.
    static let pupil = Color(red: 0.03, green: 0.10, blue: 0.08)
}

/// iOS Snake — swipe to steer the snake around a 14x14 board. Uses the shared `SnakeGame` model.
struct SnakeView: View {
    @StateObject private var session = SnakeSession()
    private let accountID: UUID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Haptic triggers (flip on the relevant event).
    @State private var ateTrigger = 0
    @State private var diedTrigger = false

    // Slow neon breathing for the bloom — purely cosmetic, guarded by reduceMotion.
    @State private var glow = false

    // Current tick interval — starts gentle and gently speeds up as the score grows.
    // Sourced from the pure `SnakeGame.tickInterval(forScore:)` model function.
    @State private var tickInterval: Double = SnakeGame.initialTickInterval

    // Neon-terrarium accent (phosphor green) drives the shared HUD chrome.
    private let accent = SnakeTheme.accent
    private let tick = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()
    @State private var accumulated: Double = 0

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    private var currentTick: Double {
        SnakeGame.tickInterval(forScore: session.game.score)
    }

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(title: "Snake", systemImage: "scribble.variable", accent: accent,
                       subtitle: session.game.status == .lost ? "Game over — tap New Game" : "Swipe to steer") {
                HStack(spacing: 16) {
                    StatBadge(label: "Score", value: "\(session.game.score)", accent: accent)
                    StatBadge(label: "Best", value: "\(session.best)", accent: Kaleido.ink)
                }
            }
            board
            Button { newGame() } label: {
                Label("New Game", systemImage: "arrow.clockwise")
            }
            .buttonStyle(AccentButtonStyle(accent: accent))
            Text("Swipe up · down · left · right")
                .font(.caption).foregroundStyle(Kaleido.ink3)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .onReceive(tick) { _ in
            guard session.game.status == .playing else { return }
            // Accumulate fixed sub-ticks until the (score-adjusted) interval elapses,
            // so the step animation can glide for the full duration of each move.
            accumulated += 0.06
            let interval = currentTick
            guard accumulated >= interval else { return }
            accumulated = 0
            tickInterval = interval

            var result = SnakeStepResult(ateApple: false, died: false)
            withAnimation(.linear(duration: interval)) {
                result = session.step()
            }

            if result.ateApple { ateTrigger &+= 1 }
            if result.died { diedTrigger.toggle() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: ateTrigger)
        .sensoryFeedback(.error, trigger: diedTrigger)
        .navigationTitle("Snake")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let accountID {
                session.configure(accountID: accountID, cloudStore: .shared)
            }
            // Kick off the slow neon breathing once (reduce-motion users skip it).
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
        }
        .onDisappear { session.saveNow() }
    }

    private var board: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(session.game.width)
            ZStack {
                cabinetTube(cell: cell)
                phosphorGrid(cell: cell)
                orbView(cell: cell)
                    .position(center(session.game.apple, cell: cell))
                snakeBody(cell: cell)
                crtOverlay
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                // Machined bezel around the tube.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [SnakeTheme.bezel, SnakeTheme.bezelEdge],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 3
                    )
            }
            .overlay {
                // A hair of emitted phosphor light rimming the glass.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(SnakeTheme.accent.opacity(0.22), lineWidth: 1)
                    .blur(radius: 0.5)
            }
            .shadow(color: Color.black.opacity(0.45), radius: 16, y: 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(swipe)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func center(_ p: SnakePoint, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(p.col) + 0.5) * cell, y: (CGFloat(p.row) + 0.5) * cell)
    }

    /// The recessed CRT tube: a dark tinted glass with a soft top-lit sheen and
    /// a heavy corner vignette so the field feels curved and inset, not flat.
    private func cabinetTube(cell: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [SnakeTheme.tubeTop, SnakeTheme.tubeBottom],
                           startPoint: .top, endPoint: .bottom)
            // Faint phosphor wash rising from the floor of the tube.
            RadialGradient(colors: [SnakeTheme.accent.opacity(0.06), .clear],
                           center: UnitPoint(x: 0.5, y: 0.62),
                           startRadius: cell, endRadius: cell * 11)
            // Corner vignette — the tube curving away at the edges.
            RadialGradient(colors: [.clear, Color.black.opacity(0.45)],
                           center: .center,
                           startRadius: cell * 4, endRadius: cell * 10)
        }
    }

    /// Faint phosphor dots at the grid intersections — enough to read the board
    /// as a lattice, not a spreadsheet of hard lines.
    private func phosphorGrid(cell: CGFloat) -> some View {
        let cols = session.game.width
        let rows = session.game.height
        return Canvas { context, _ in
            let r: CGFloat = max(0.6, cell * 0.045)
            for row in 0...rows {
                for col in 0...cols {
                    let rect = CGRect(x: CGFloat(col) * cell - r,
                                      y: CGFloat(row) * cell - r,
                                      width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(SnakeTheme.gridDot))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// The snake as overlapping rounded segments so it reads as one continuous,
    /// glowing body — a bright emerald head fading to teal tail, wrapped in a
    /// soft neon bloom, with eyes on the head looking where it goes.
    private func snakeBody(cell: CGFloat) -> some View {
        let body = session.game.body
        let count = max(body.count, 1)
        let bloomOpacity = reduceMotion ? 0.5 : (glow ? 0.62 : 0.38)
        return ZStack {
            // Outer bloom — a blurred halo tracing the whole body so the snake
            // looks like it emits light. This is the signature element.
            ForEach(Array(body.enumerated().reversed()), id: \.offset) { _, segment in
                RoundedRectangle(cornerRadius: cell * 0.5, style: .continuous)
                    .fill(SnakeTheme.bloom)
                    .frame(width: cell * 1.28, height: cell * 1.28)
                    .position(center(segment, cell: cell))
            }
            .compositingGroup()
            .blur(radius: cell * 0.42)
            .opacity(bloomOpacity)

            // Solid body — head→tail gradient tint, overlapping rounded segments.
            ForEach(Array(body.enumerated().reversed()), id: \.offset) { index, segment in
                let t = Double(index) / Double(count)
                RoundedRectangle(cornerRadius: cell * 0.46, style: .continuous)
                    .fill(segmentColor(t: t))
                    .frame(width: cell * (index == 0 ? 1.02 : 0.96),
                           height: cell * (index == 0 ? 1.02 : 0.96))
                    .overlay(
                        // Bright top-lit core so each segment looks tubular/glossy.
                        RoundedRectangle(cornerRadius: cell * 0.46, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [SnakeTheme.neonCore.opacity(index == 0 ? 0.55 : 0.35), .clear],
                                    startPoint: .top, endPoint: .center
                                )
                            )
                            .frame(width: cell * (index == 0 ? 1.02 : 0.96),
                                   height: cell * (index == 0 ? 1.02 : 0.96))
                    )
                    .position(center(segment, cell: cell))
            }
            if let head = body.first {
                headEyes(cell: cell)
                    .position(center(head, cell: cell))
            }
        }
    }

    /// Emerald head → cooler teal tail, so the body reads as living and directional.
    private func segmentColor(t: Double) -> Color {
        if t < 0.5 {
            return blend(SnakeTheme.neonHeadRGB, SnakeTheme.neonBodyRGB, t / 0.5)
        } else {
            return blend(SnakeTheme.neonBodyRGB, SnakeTheme.neonTailRGB, (t - 0.5) / 0.5)
        }
    }

    private func blend(_ a: (r: Double, g: Double, b: Double),
                       _ b: (r: Double, g: Double, b: Double),
                       _ f: Double) -> Color {
        let f = min(max(f, 0), 1)
        return Color(red: a.r + (b.r - a.r) * f,
                     green: a.g + (b.g - a.g) * f,
                     blue: a.b + (b.b - a.b) * f)
    }

    private func headEyes(cell: CGFloat) -> some View {
        let d = session.game.direction.delta
        let forward = CGVector(dx: CGFloat(d.col), dy: CGFloat(d.row))
        let side = CGVector(dx: -forward.dy, dy: forward.dx)
        let eyeR = cell * 0.15
        let pupilR = cell * 0.07
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { s in
                let ex = forward.dx * cell * 0.14 + side.dx * cell * 0.22 * s
                let ey = forward.dy * cell * 0.14 + side.dy * cell * 0.22 * s
                Circle().fill(.white)
                    .frame(width: eyeR * 2, height: eyeR * 2)
                    .offset(x: ex, y: ey)
                Circle().fill(SnakeTheme.pupil)
                    .frame(width: pupilR * 2, height: pupilR * 2)
                    .offset(x: ex + forward.dx * eyeR * 0.45, y: ey + forward.dy * eyeR * 0.45)
            }
        }
    }

    /// Food as a glossy magenta power-orb: a warm bloom, a saturated core, and a
    /// specular highlight so it reads as a glass sphere catching the tube light.
    private func orbView(cell: CGFloat) -> some View {
        ZStack {
            // Warm halo.
            Circle()
                .fill(SnakeTheme.orbBloom)
                .frame(width: cell * 1.35, height: cell * 1.35)
                .blur(radius: cell * 0.34)
                .opacity(reduceMotion ? 0.55 : (glow ? 0.7 : 0.5))
            // Glass sphere.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [SnakeTheme.orbCore, SnakeTheme.orb,
                                 SnakeTheme.orb.opacity(0.85)],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0.5, endRadius: cell * 0.5
                    )
                )
                .frame(width: cell * 0.74, height: cell * 0.74)
            // Specular highlight.
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: cell * 0.15, height: cell * 0.15)
                .offset(x: -cell * 0.15, y: -cell * 0.17)
        }
        .transition(.scale.combined(with: .opacity))
    }

    /// Thin CRT scanlines + a faint bright top sheen laid over the whole tube —
    /// quiet enough to feel like an old monitor, not stripes on a shirt.
    private var crtOverlay: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.14), location: 0.0),
                    .init(color: .clear, location: 0.5),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .blendMode(.multiply)
            Scanlines()
                .fill(Color.black.opacity(0.10))
        }
        .allowsHitTesting(false)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard abs(dx) > 6 || abs(dy) > 6 else { return }
                let dir: SnakeGame.Direction = abs(dx) > abs(dy)
                    ? (dx > 0 ? .right : .left)
                    : (dy > 0 ? .down : .up)
                // Buffer the turn; the model commits it on the next tick and
                // ignores 180° reversals so a quick flick can't self-collide.
                withAnimation(.snappy(duration: 0.16)) {
                    session.turn(dir)
                }
            }
    }

    private func newGame() {
        accumulated = 0
        tickInterval = SnakeGame.initialTickInterval
        withAnimation(.snappy(duration: 0.16)) {
            session.newGame()
        }
    }
}

// MARK: - CRT scanlines

/// Evenly spaced horizontal lines across the tube, drawn as a shape so they
/// scale with the board and cost nothing to animate.
private struct Scanlines: Shape {
    var spacing: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y: CGFloat = 0
        while y < rect.height {
            p.addRect(CGRect(x: 0, y: y, width: rect.width, height: 1))
            y += spacing
        }
        return p
    }
}
