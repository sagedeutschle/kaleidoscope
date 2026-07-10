// PRISM: RELEASE Agent-Design(2048) 2026-07-03 - v10 design pass
import SwiftUI

struct Game2048TilePalette {
    struct RGB: Equatable {
        let red: Double
        let green: Double
        let blue: Double

        var swiftUIColor: Color {
            Color(red: red, green: green, blue: blue)
        }

        var relativeLuminance: Double {
            func linear(_ component: Double) -> Double {
                component <= 0.03928
                    ? component / 12.92
                    : pow((component + 0.055) / 1.055, 2.4)
            }

            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
    }

    struct TileStyle: Equatable {
        let background: RGB
        let foreground: RGB

        var contrastRatio: Double {
            let lighter = max(background.relativeLuminance, foreground.relativeLuminance)
            let darker = min(background.relativeLuminance, foreground.relativeLuminance)
            return (lighter + 0.05) / (darker + 0.05)
        }
    }

    /// Classic warm 2048 ramp, retuned so every tile's number is clearly legible.
    /// Bright low/mid tiles (2…256) carry dark ink; the deep high tiles (512+)
    /// carry light ink. Each pairing clears WCAG AA contrast (all ≥ 4.8, most ≥ 7)
    /// while keeping every value a visually distinct shade.
    static func style(for value: Int) -> TileStyle {
        switch value {
        case 2:
            return TileStyle(background: RGB(red: 0.93, green: 0.89, blue: 0.80), foreground: darkInk)
        case 4:
            return TileStyle(background: RGB(red: 0.94, green: 0.86, blue: 0.67), foreground: darkInk)
        case 8:
            return TileStyle(background: RGB(red: 0.98, green: 0.80, blue: 0.52), foreground: darkInk)
        case 16:
            return TileStyle(background: RGB(red: 0.99, green: 0.72, blue: 0.42), foreground: darkInk)
        case 32:
            return TileStyle(background: RGB(red: 0.99, green: 0.63, blue: 0.36), foreground: darkInk)
        case 64:
            return TileStyle(background: RGB(red: 0.99, green: 0.55, blue: 0.31), foreground: darkInk)
        case 128:
            return TileStyle(background: RGB(red: 0.97, green: 0.84, blue: 0.42), foreground: darkInk)
        case 256:
            return TileStyle(background: RGB(red: 0.96, green: 0.77, blue: 0.28), foreground: darkInk)
        case 512:
            return TileStyle(background: RGB(red: 0.76, green: 0.30, blue: 0.11), foreground: lightInk)
        case 1024:
            return TileStyle(background: RGB(red: 0.68, green: 0.20, blue: 0.13), foreground: lightInk)
        case 2048:
            return TileStyle(background: RGB(red: 0.46, green: 0.24, blue: 0.62), foreground: lightInk)
        default:
            return TileStyle(background: RGB(red: 0.20, green: 0.22, blue: 0.30), foreground: lightInk)
        }
    }

    private static let darkInk = RGB(red: 0.16, green: 0.11, blue: 0.07)
    private static let lightInk = RGB(red: 1.0, green: 1.0, blue: 1.0)
}

// MARK: - The Wooden Tray (game-local theme)

/// Material palette for the 2048 tray world. Tile faces always come from
/// `Game2048TilePalette` (WCAG-verified) — only the tray, wells, and controls
/// change with the skin.
private struct Game2048Theme {
    let tray: Color        // tray surface (top of gradient)
    let trayDeep: Color    // tray surface (bottom of gradient)
    let trayRim: Color     // outer rim stroke
    let well: Color        // recessed well floor
    let wellDeep: Color    // well floor near the top edge (carved shading)
    let wellShade: Color   // 1pt top-inner shadow line
    let woodTop: Color     // hero button face (top)
    let woodBottom: Color  // hero button face (bottom)
    let woodRim: Color     // hero button rim
    let woodInk: Color     // hero button text
    let pipOn: Color       // remaining shuffle charge
    let pipOff: Color      // consumed shuffle charge socket
}

private enum Game2048Skin: String, CaseIterable, Identifiable {
    case walnut = "Walnut"
    case slate = "Slate"
    case cream = "Classic Cream"

    var id: String { rawValue }

    var theme: Game2048Theme {
        switch self {
        case .walnut:
            return Game2048Theme(
                tray: Color(red: 0.42, green: 0.35, blue: 0.28),
                trayDeep: Color(red: 0.35, green: 0.28, blue: 0.22),
                trayRim: Color(red: 0.25, green: 0.19, blue: 0.14),
                well: Color(red: 0.315, green: 0.255, blue: 0.198),
                wellDeep: Color(red: 0.270, green: 0.214, blue: 0.163),
                wellShade: Color(red: 0.13, green: 0.09, blue: 0.06),
                woodTop: Color(red: 0.55, green: 0.44, blue: 0.33),
                woodBottom: Color(red: 0.43, green: 0.33, blue: 0.24),
                woodRim: Color(red: 0.28, green: 0.21, blue: 0.15),
                woodInk: Color(red: 0.97, green: 0.92, blue: 0.83),
                pipOn: Color(red: 0.99, green: 0.83, blue: 0.44),
                pipOff: Color.black.opacity(0.28)
            )
        case .slate:
            return Game2048Theme(
                tray: Color(red: 0.30, green: 0.32, blue: 0.37),
                trayDeep: Color(red: 0.24, green: 0.26, blue: 0.31),
                trayRim: Color(red: 0.15, green: 0.17, blue: 0.21),
                well: Color(red: 0.225, green: 0.245, blue: 0.290),
                wellDeep: Color(red: 0.190, green: 0.208, blue: 0.250),
                wellShade: Color(red: 0.06, green: 0.07, blue: 0.10),
                woodTop: Color(red: 0.44, green: 0.47, blue: 0.53),
                woodBottom: Color(red: 0.34, green: 0.37, blue: 0.43),
                woodRim: Color(red: 0.20, green: 0.22, blue: 0.26),
                woodInk: Color(red: 0.96, green: 0.97, blue: 1.00),
                pipOn: Color(red: 0.99, green: 0.83, blue: 0.44),
                pipOff: Color.black.opacity(0.28)
            )
        case .cream:
            return Game2048Theme(
                tray: Color(red: 0.733, green: 0.678, blue: 0.627),
                trayDeep: Color(red: 0.690, green: 0.632, blue: 0.578),
                trayRim: Color(red: 0.555, green: 0.498, blue: 0.440),
                well: Color(red: 0.805, green: 0.757, blue: 0.706),
                wellDeep: Color(red: 0.770, green: 0.718, blue: 0.664),
                wellShade: Color(red: 0.47, green: 0.41, blue: 0.35),
                woodTop: Color(red: 0.62, green: 0.53, blue: 0.44),
                woodBottom: Color(red: 0.53, green: 0.45, blue: 0.37),
                woodRim: Color(red: 0.42, green: 0.35, blue: 0.28),
                woodInk: Color(red: 0.98, green: 0.96, blue: 0.92),
                pipOn: Color(red: 0.99, green: 0.86, blue: 0.52),
                pipOff: Color.black.opacity(0.24)
            )
        }
    }
}

// MARK: - Button styles

/// The hero: a turned-wood button that visibly presses into the tray.
private struct Wood2048ButtonStyle: ButtonStyle {
    let theme: Game2048Theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.woodInk)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [theme.woodTop, theme.woodBottom],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(theme.woodRim, lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .inset(by: 1)
                            .strokeBorder(
                                LinearGradient(colors: [Color.white.opacity(0.20), .clear],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.12 : 0.28),
                            radius: configuration.isPressed ? 1 : 3,
                            y: configuration.isPressed ? 1 : 2.5)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

/// Quiet glass chip for secondary actions (New Game, gear).
private struct Glass2048ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PrismetDesign.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PrismetDesign.panel.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(PrismetDesign.outline, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// iOS 2048 — swipe to combine tiles. Uses the shared `Game2048` model.
struct Game2048View: View {
    @StateObject private var session = Game2048Session()
    private let accountID: UUID?

    // Haptic triggers (iOS 17 .sensoryFeedback).
    @State private var moveCounter = 0      // flips on every successful swipe-move (light impact)
    @State private var mergeCounter = 0     // flips on a merge or reaching 2048 (medium impact)
    @State private var didWin = false       // flips true the first time hasWon becomes true (.success)

    // Merge pulse: cells whose value grew on the last merging move briefly swell.
    @State private var pulsingCells: Set<Int> = []
    @State private var showSettings = false

    @AppStorage("2048.hintSeen") private var hintSeen = false
    @AppStorage("2048.skin") private var skinRaw = Game2048Skin.walnut.rawValue

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let accent = Color(red: 0.86, green: 0.55, blue: 0.18)

    private var skin: Game2048Skin { Game2048Skin(rawValue: skinRaw) ?? .walnut }
    private var theme: Game2048Theme { skin.theme }

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    private var subtitle: String? {
        if session.game.isGameOver { return "No moves left — tap New Game" }
        if session.game.hasWon { return "You made 2048! Keep going." }
        return hintSeen ? nil : "Swipe to combine tiles"
    }

    var body: some View {
        VStack(spacing: 16) {
            GameHeader(title: "2048", systemImage: "square.grid.4x3.fill", accent: accent,
                       subtitle: subtitle) {
                HStack(spacing: 16) {
                    StatBadge(label: "Score", value: "\(session.game.score)", accent: accent)
                    StatBadge(label: "Best", value: "\(session.best)", accent: PrismetDesign.ink)
                }
            }

            board

            controls

            if !hintSeen {
                Text("Swipe up · down · left · right")
                    .font(.caption).foregroundStyle(PrismetDesign.ink3)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 640)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .contentShape(Rectangle())
        .gesture(swipe)
        .navigationTitle("2048")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let accountID {
                session.configure(accountID: accountID, cloudStore: .shared)
            }
        }
        .onDisappear { session.saveNow() }
        .gameFeedback(.tileSlide, trigger: moveCounter)
        .gameFeedback(.tileMerge, trigger: mergeCounter)
        .gameFeedback(.win, trigger: didWin)
        .sheet(isPresented: $showSettings) {
            settingsSheet
                .presentationDetents([.height(420), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(PrismetDesign.ground)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 12) {
            Button { newGame() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                    Text("New Game")
                }
            }
            .buttonStyle(Glass2048ChipStyle())

            Button { triggerVisualShuffle() } label: {
                HStack(spacing: 9) {
                    Text("Shuffle")
                    if session.shufflePowerUps.usesPerGame > 0 {
                        chargePips
                    }
                }
            }
            .buttonStyle(Wood2048ButtonStyle(theme: theme))
            .disabled(session.game.isGameOver || session.visualShuffle != nil || session.shufflePowerUps.remainingUses == 0)
            .accessibilityLabel("Shuffle tiles")
            .accessibilityValue("\(session.shufflePowerUps.remainingUses) of \(session.shufflePowerUps.usesPerGame) charges left")

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PrismetDesign.ink2)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(PrismetDesign.panel.opacity(0.85))
                            .overlay(Circle().strokeBorder(PrismetDesign.outline, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tray settings")
        }
    }

    /// Charge pips: one dot per shuffle for this game; consumed ones read as
    /// empty sockets drilled into the wood.
    private var chargePips: some View {
        HStack(spacing: 4.5) {
            ForEach(0..<session.shufflePowerUps.usesPerGame, id: \.self) { i in
                Circle()
                    .fill(i < session.shufflePowerUps.remainingUses ? theme.pipOn : theme.pipOff)
                    .frame(width: 6.5, height: 6.5)
                    .overlay(Circle().strokeBorder(theme.woodRim.opacity(0.55), lineWidth: 0.5))
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Board (the wooden tray)

    private var board: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let gap: CGFloat = 8
            let cell = (side - gap * 5) / 4
            ZStack {
                // The tray: a solid slab with a darker base edge and rim,
                // lifted off the paper by a soft drop shadow.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [theme.tray, theme.trayDeep],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(theme.trayRim, lineWidth: 1.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .inset(by: 1.5)
                            .strokeBorder(
                                LinearGradient(colors: [Color.white.opacity(0.10), .clear],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(PrismetDesign.isDark ? 0.45 : 0.22), radius: 14, y: 8)

                VStack(spacing: gap) {
                    ForEach(0..<4, id: \.self) { r in
                        HStack(spacing: gap) {
                            ForEach(0..<4, id: \.self) { c in
                                boardCell(row: r, col: c, size: cell)
                            }
                        }
                    }
                }
                .padding(gap)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 520)
    }

    private func boardCell(row: Int, col: Int, size: CGFloat) -> some View {
        let value = session.game[row, col]
        let index = row * 4 + col
        return ZStack {
            well(size: size)
            if value != 0 {
                tileFace(value: value, size: size, index: index)
                    .transition(spawnTransition)
            }
        }
        .frame(width: size, height: size)
    }

    /// A recessed well carved into the tray: darker floor, shaded toward the
    /// top, with a 1pt top-inner shadow line under the lip.
    private func well(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [theme.wellDeep, theme.well],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [theme.wellShade.opacity(0.9), theme.wellShade.opacity(0)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.2
                    )
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var spawnTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: AnyTransition.scale(scale: 0.6).combined(with: .opacity)
                .animation(.spring(response: 0.30, dampingFraction: 0.62)),
            removal: AnyTransition.opacity.animation(.easeOut(duration: 0.10))
        )
    }

    private func tileFace(value: Int, size: CGFloat, index: Int) -> some View {
        let effect = session.visualShuffle?.effect(forTileIndex: index)
        let style = Game2048TilePalette.style(for: value)
        let pulsing = pulsingCells.contains(index)

        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(style.background.swiftUIColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
            .overlay(
                Text("\(value)")
                    .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(style.foreground.swiftUIColor)
                    .contentTransition(.numericText())
            )
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.30), radius: 1, y: 1.5)
            .scaleEffect((effect.map { CGFloat($0.scale) } ?? 1) * (pulsing ? 1.12 : 1))
            .rotationEffect(.degrees(effect?.rotationDegrees ?? 0))
            .offset(x: CGFloat(effect?.xOffset ?? 0), y: CGFloat(effect?.yOffset ?? 0))
            .animation(.snappy(duration: 0.16), value: value)
            .animation(.snappy(duration: 0.2), value: session.visualShuffle)
            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.5), value: pulsingCells)
    }

    // MARK: - Settings sheet (gear)

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("The Wooden Tray")
                .font(PrismetDesign.title(20))
                .foregroundStyle(PrismetDesign.ink)
                .padding(.top, 22)

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Tray finish")
                HStack(spacing: 12) {
                    ForEach(Game2048Skin.allCases) { option in
                        skinChip(option)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Shuffle")

                settingRow {
                    Toggle(isOn: Binding(
                        get: { session.shuffleAnimationEnabled },
                        set: { session.setShuffleAnimationEnabled($0) }
                    )) {
                        Text("Scatter animation")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PrismetDesign.ink)
                    }
                    .tint(accent)
                }

                settingRow {
                    HStack {
                        Text("Charges per game")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PrismetDesign.ink)
                        Spacer()
                        HStack(spacing: 12) {
                            stepChip("minus", disabled: session.shuffleUsesPerGame <= 0) {
                                session.setShuffleUsesPerGame(session.shuffleUsesPerGame - 1)
                            }
                            .accessibilityLabel("Fewer shuffle charges")

                            Text("\(session.shuffleUsesPerGame)")
                                .font(PrismetDesign.rounded(18))
                                .monospacedDigit()
                                .foregroundStyle(PrismetDesign.ink)
                                .frame(minWidth: 22)

                            stepChip("plus", disabled: session.shuffleUsesPerGame >= Game2048ShufflePowerUps.maxUsesPerGame) {
                                session.setShuffleUsesPerGame(session.shuffleUsesPerGame + 1)
                            }
                            .accessibilityLabel("More shuffle charges")
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PrismetDesign.ground)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(PrismetDesign.ink3)
    }

    private func settingRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PrismetDesign.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(PrismetDesign.hairline, lineWidth: 1)
                    )
            )
    }

    private func stepChip(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.woodInk)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [theme.woodTop, theme.woodBottom],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(Circle().strokeBorder(theme.woodRim, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    private func skinChip(_ option: Game2048Skin) -> some View {
        let t = option.theme
        let selected = option == skin
        return Button { skinRaw = option.rawValue } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [t.tray, t.trayDeep],
                                             startPoint: .top, endPoint: .bottom))
                    VStack(spacing: 4) {
                        ForEach(0..<2, id: \.self) { _ in
                            HStack(spacing: 4) {
                                ForEach(0..<2, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                        .fill(t.well)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                                .strokeBorder(t.wellShade.opacity(0.6), lineWidth: 0.5)
                                        )
                                }
                            }
                        }
                    }
                    .padding(7)
                }
                .frame(width: 68, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(selected ? accent : PrismetDesign.outline, lineWidth: selected ? 2 : 1)
                )

                Text(option.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selected ? PrismetDesign.ink : PrismetDesign.ink2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.rawValue) finish")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Input + game flow

    private var swipe: some Gesture {
        // Small minimumDistance so the swipe registers immediately and feels responsive.
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard abs(dx) > 10 || abs(dy) > 10 else { return }
                let dir: Game2048.Direction = abs(dx) > abs(dy)
                    ? (dx > 0 ? .right : .left)
                    : (dy > 0 ? .down : .up)
                apply(dir)
            }
    }

    private func apply(_ dir: Game2048.Direction) {
        let scoreBefore = session.game.score
        let wonBefore = session.game.hasWon
        var gridBefore = [Int](repeating: 0, count: 16)
        for i in 0..<16 { gridBefore[i] = session.game[i / 4, i % 4] }

        var moved = false
        withAnimation(.snappy(duration: 0.16)) {
            moved = session.apply(dir)
        }

        // A move only counts (and only spawns a tile) when the board actually changed.
        guard moved else { return }

        // The swipe hint has done its job after the first real move.
        if !hintSeen { hintSeen = true }

        // Light impact on each successful swipe-move.
        moveCounter &+= 1

        // Medium impact when a merge happens (score rises only on a merge) or 2048 is reached.
        let merged = session.game.score > scoreBefore
        if merged || (session.game.hasWon && !wonBefore) {
            mergeCounter &+= 1
        }

        // .success the first time the player makes 2048.
        if session.game.hasWon && !wonBefore {
            didWin.toggle()
        }

        // Merge pulse: cells that held a value and now hold a different one
        // briefly swell (1 → 1.12 → 1). Gated on the score-delta merge signal.
        if merged && !reduceMotion {
            var changed: Set<Int> = []
            for i in 0..<16 {
                let now = session.game[i / 4, i % 4]
                if now != 0, gridBefore[i] != 0, now != gridBefore[i] {
                    changed.insert(i)
                }
            }
            if !changed.isEmpty {
                pulsingCells = changed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    pulsingCells = []
                }
            }
        }
    }

    private func newGame() {
        withAnimation(.snappy(duration: 0.16)) {
            session.newGame()
        }
    }

    private func triggerVisualShuffle() {
        guard session.shufflePowerUps.remainingUses > 0 else { return }

        let shuffle = session.shuffleTilesForPowerUp()

        guard shuffle != nil else { return }
        moveCounter &+= 1

        if session.shuffleAnimationEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                guard session.visualShuffle != nil else { return }
                withAnimation(.snappy(duration: 0.2)) {
                    session.visualShuffle = nil
                }
            }
        } else {
            session.visualShuffle = nil
        }
    }
}
