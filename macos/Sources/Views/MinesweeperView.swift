import SwiftUI

// PRISM: RELEASE Agent-A 2026-06-27 — Minesweeper STYLE switcher (Modern/Classic '97/Cyberpunk) shipped + built. Classic chrome is a clean-room recreation (no MS assets).

struct MinesweeperView: View {
    @ObservedObject private var session: MinesweeperSession

    private var layout: MinesweeperBoardLayout {
        MinesweeperBoardLayout.tight.scaled(by: session.zoom)
    }
    private let accent = FacetRegistry.accent(for: "minesweeper")
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let neonCyan = Color(red: 0.0, green: 0.9, blue: 1.0)
    private let neonMagenta = Color(red: 1.0, green: 0.20, blue: 0.60)

    // Pan/zoom over the board (no scroll bars; pinch + drag, mobile-ready).
    @GestureState private var pinch: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero

    init(session: MinesweeperSession = MinesweeperSession()) {
        self.session = session
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 16) {
            content
            stylePicker
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(styleBackground)
        .environment(\.colorScheme, session.style == .classic ? .light : .dark)
        .onReceive(ticker) { _ in
            if session.started && session.game.status == .playing { session.elapsed = min(999, session.elapsed + 1) }
        }
    }

    @ViewBuilder private var content: some View {
        switch session.style {
        case .modern: modernLayout
        case .classic: classicLayout
        case .cyber: cyberLayout
        }
    }

    private var stylePicker: some View {
        Picker("Style", selection: $session.style.animation(.easeInOut(duration: 0.2))) {
            ForEach(MinesweeperStyle.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
    }

    @ViewBuilder private var styleBackground: some View {
        switch session.style {
        case .modern:
            FacetBackdrop(accent: accent)
        case .classic:
            Color(white: 0.76).ignoresSafeArea()
        case .cyber:
            Image("minesweeper_cyber")
                .resizable().scaledToFill()
                .overlay(
                    LinearGradient(colors: [.black.opacity(0.62), neonMagenta.opacity(0.18), .black.opacity(0.72)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .clipped().ignoresSafeArea()
        }
    }

    // MARK: Layouts

    private var modernLayout: some View {
        VStack(spacing: 18) {
            GameHeader(title: "Minesweeper", systemImage: "flag.fill", accent: accent, subtitle: statusText)
                .frame(maxWidth: 480)
            boardViewport {
                boardGrid
                    .padding(CGFloat(layout.boardPadding))
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(PrismetDesign.panel.opacity(0.8)))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(PrismetDesign.hairline, lineWidth: 1))
            }
            controlStack(tint: accent)
        }
    }

    private var classicLayout: some View {
        VStack(spacing: 14) {
            Text("Minesweeper")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
            VStack(spacing: 8) {
                classicStatusBar
                boardViewport {
                    boardGrid.padding(4).background(Color(white: 0.76)).overlay(ClassicBevel(raised: false))
                }
            }
            .padding(8)
            .background(Color(white: 0.76))
            .overlay(ClassicBevel(raised: true))
            controlStack(tint: Color(red: 0.0, green: 0.0, blue: 0.5))
        }
    }

    private var cyberLayout: some View {
        VStack(spacing: 18) {
            Text("M I N E S W E E P E R")
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .foregroundStyle(neonCyan)
                .shadow(color: neonCyan.opacity(0.9), radius: 10)
                .shadow(color: neonMagenta.opacity(0.6), radius: 18)
            Text(statusText)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(neonCyan.opacity(0.75))
            boardViewport {
                boardGrid
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.55)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(neonCyan, lineWidth: 1.5)
                            .shadow(color: neonCyan.opacity(0.8), radius: 8)
                    )
            }
            controlStack(tint: neonCyan)
        }
    }

    /// A clean pan/zoom window over the board — pinch to zoom, drag to pan, no scroll bars.
    @ViewBuilder
    private func boardViewport<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .scaleEffect(CGFloat(session.zoom) * pinch)
            .offset(pan)
            .frame(maxWidth: .infinity, maxHeight: 540)
            .contentShape(Rectangle())
            .clipped()
            .gesture(
                DragGesture()
                    .onChanged { value in
                        pan = CGSize(width: lastPan.width + value.translation.width,
                                     height: lastPan.height + value.translation.height)
                    }
                    .onEnded { _ in lastPan = pan }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($pinch) { value, state, _ in state = value }
                    .onEnded { value in
                        session.zoom = min(2.2, max(0.4, session.zoom * Double(value)))
                    }
            )
    }

    private var classicStatusBar: some View {
        HStack {
            ledBox(max(0, mineCount - flagCount))
            Spacer()
            Button { session.newGame() } label: {
                Text(smileyFace)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(Color(white: 0.76))
                    .overlay(ClassicBevel(raised: true))
            }
            .buttonStyle(.plain)
            Spacer()
            ledBox(session.elapsed)
        }
        .padding(6)
        .background(Color(white: 0.76))
        .overlay(ClassicBevel(raised: false))
    }

    private func ledBox(_ value: Int) -> some View {
        Text(String(format: "%03d", max(0, min(999, value))))
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(red: 1.0, green: 0.12, blue: 0.08))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Color.black)
            .overlay(Rectangle().strokeBorder(Color(white: 0.45), lineWidth: 1))
    }

    private var smileyFace: String {
        switch session.game.status {
        case .won: return "😎"
        case .lost: return "😵"
        case .playing: return "🙂"
        }
    }

    // MARK: Controls

    private func controlStack(tint: Color) -> some View {
        VStack(spacing: 9) {
            modeControls(tint: tint)
            configurationControls(tint: tint)
        }
    }

    private func modeControls(tint: Color) -> some View {
        HStack(spacing: 8) {
            modeButton(.choose, title: "Choose", systemImage: "cursorarrow.click", tint: tint)
            modeButton(.flag, title: "Flag", systemImage: "flag.fill", tint: tint)
            Button { zoomOut() } label: { Image(systemName: "minus.magnifyingglass") }
                .buttonStyle(MinesweeperIconButtonStyle(isSelected: false, accent: tint))
                .disabled(session.zoom <= 0.4)
            Button { zoomIn() } label: { Image(systemName: "plus.magnifyingglass") }
                .buttonStyle(MinesweeperIconButtonStyle(isSelected: false, accent: tint))
                .disabled(session.zoom >= 2.2)
            Button { session.newGame() } label: { Label("New Game", systemImage: "arrow.clockwise") }
                .buttonStyle(MinesweeperModeButtonStyle(isSelected: true, accent: tint))
        }
    }

    private func configurationControls(tint: Color) -> some View {
        VStack(spacing: 8) {
            Picker("Difficulty", selection: $session.difficulty) {
                ForEach(MinesweeperDifficulty.allCases) { difficulty in
                    Text(difficulty.rawValue).tag(difficulty)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 480)
            .onChange(of: session.difficulty) { _, difficulty in
                if difficulty != .custom { session.newGame() }
            }

            if session.difficulty == .custom {
                customConfigurationControls(tint: tint)
            } else {
                presetSummary
            }
        }
        .font(.callout.weight(.semibold))
        .frame(maxWidth: 560)
    }

    private var presetSummary: some View {
        HStack(spacing: 10) {
            Text(presetDescription)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Spacer()
            Button { session.newGame() } label: {
                Label("Start", systemImage: "play.fill")
            }
            .buttonStyle(GlassButtonStyle())
        }
        .frame(maxWidth: 480)
    }

    private var presetDescription: String {
        guard let preset = session.difficulty.preset else {
            return "\(session.settings.width)×\(session.settings.height) · \(session.settings.mineCount) mines"
        }
        return "\(preset.width)×\(preset.height) · \(preset.mineCount) mines"
    }

    private func customConfigurationControls(tint: Color) -> some View {
        VStack(spacing: 8) {
            customSizeControls

            HStack(spacing: 10) {
                Text("\(Int((session.settings.mineDensity * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
                Slider(value: $session.settings.mineDensity,
                       in: MinesweeperSettings.minMineDensity...MinesweeperSettings.maxMineDensity)
                    .frame(width: 180)
                Button { session.undo() } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(!session.canUndo)
                Button { session.newGame() } label: {
                    Label("Apply", systemImage: "checkmark.circle")
                }
                .buttonStyle(AccentButtonStyle(accent: tint))
                Menu {
                    Button("Save") { session.saveNow() }
                    Button("Load") { session.reloadSavedState() }
                } label: {
                    Label("State", systemImage: "externaldrive")
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
    }

    private var customSizeControls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("W")
                TextField("", value: $session.settings.width, format: .number)
                    .labelsHidden()
                    .frame(width: 42)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                Stepper("", value: $session.settings.width,
                        in: MinesweeperSettings.minWidth...MinesweeperSettings.maxWidth)
                    .labelsHidden()
            }
            HStack(spacing: 4) {
                Text("H")
                TextField("", value: $session.settings.height, format: .number)
                    .labelsHidden()
                    .frame(width: 42)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                Stepper("", value: $session.settings.height,
                        in: MinesweeperSettings.minHeight...MinesweeperSettings.maxHeight)
                    .labelsHidden()
            }
            Text("\(session.settings.mineCount) mines")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .trailing)
        }
        .onChange(of: session.settings.width) { _, v in
            let c = min(max(v, MinesweeperSettings.minWidth), MinesweeperSettings.maxWidth)
            if c != v { session.settings.width = c }
        }
        .onChange(of: session.settings.height) { _, v in
            let c = min(max(v, MinesweeperSettings.minHeight), MinesweeperSettings.maxHeight)
            if c != v { session.settings.height = c }
        }
    }

    private func modeButton(_ mode: MinesweeperInteractionMode, title: String, systemImage: String, tint: Color) -> some View {
        Button { session.primaryMode = mode } label: { Label(title, systemImage: systemImage) }
            .buttonStyle(MinesweeperModeButtonStyle(isSelected: session.primaryMode == mode, accent: tint))
    }

    private var statusText: String {
        switch session.game.status {
        case .playing: return "Choose reveals · flag marks · right-click flags · first pick is safe."
        case .won: return "Cleared."
        case .lost: return "Mine hit."
        }
    }

    // MARK: Board

    private var cellSpacing: CGFloat {
        switch session.style {
        case .modern: return CGFloat(layout.cellSpacing)
        case .classic: return 0
        case .cyber: return 2
        }
    }

    private var boardGrid: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<session.game.height, id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    ForEach(0..<session.game.width, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
        }
    }

    private func cell(row: Int, col: Int) -> some View {
        MinesweeperCellClickTarget(isEnabled: session.game.status == .playing) { buttonNumber in
            let mode = buttonNumber == 0 ? session.primaryMode : MinesweeperInteractionMode.mode(forMouseButton: buttonNumber)
            if mode == .flag {
                session.toggleFlag(row: row, col: col)
            } else {
                session.reveal(row: row, col: col)
            }
        } label: {
            cellBody(row: row, col: col)
                .frame(width: CGFloat(layout.cellSize), height: CGFloat(layout.cellSize))
        }
    }

    @ViewBuilder private func cellBody(row: Int, col: Int) -> some View {
        switch session.style {
        case .modern: modernCell(row: row, col: col)
        case .classic: classicCell(row: row, col: col)
        case .cyber: cyberCell(row: row, col: col)
        }
    }

    // MARK: Modern cell

    @ViewBuilder private func modernCell(row: Int, col: Int) -> some View {
        let revealed = session.game.isRevealed(row: row, col: col)
        ZStack {
            RoundedRectangle(cornerRadius: CGFloat(layout.cornerRadius), style: .continuous)
                .fill(revealed
                      ? (session.game.hasMine(row: row, col: col) ? Color(red: 0.78, green: 0.20, blue: 0.22) : Color(red: 0.91, green: 0.87, blue: 0.77))
                      : PrismetDesign.panelHi)
                .overlay(revealed ? nil : RoundedRectangle(cornerRadius: CGFloat(layout.cornerRadius), style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .top, endPoint: .bottom)))
            cellGlyph(row: row, col: col,
                      flag: { Image(systemName: "flag.fill").foregroundStyle(Color(red: 0.98, green: 0.80, blue: 0.30)) },
                      mine: { Image(systemName: "staroflife.fill").foregroundStyle(.white) },
                      number: { n in Text("\(n)").foregroundStyle(modernNumberColor(n)) },
                      font: .system(size: CGFloat(layout.numberFontSize), weight: .black, design: .rounded))
        }
    }

    // MARK: Classic cell

    @ViewBuilder private func classicCell(row: Int, col: Int) -> some View {
        let revealed = session.game.isRevealed(row: row, col: col)
        let isHitMine = revealed && session.game.hasMine(row: row, col: col)
        ZStack {
            Rectangle().fill(isHitMine ? Color(red: 0.86, green: 0.0, blue: 0.0) : Color(white: 0.75))
            if revealed {
                Rectangle().strokeBorder(Color(white: 0.55), lineWidth: 0.5)
            } else {
                ClassicBevel(raised: true)
            }
            cellGlyph(row: row, col: col,
                      flag: { ClassicFlag() },
                      mine: { ClassicMine() },
                      number: { n in Text("\(n)").foregroundStyle(classicNumberColor(n)) },
                      font: .system(size: CGFloat(layout.numberFontSize), weight: .heavy, design: .monospaced))
        }
    }

    // MARK: Cyber cell

    @ViewBuilder private func cyberCell(row: Int, col: Int) -> some View {
        let revealed = session.game.isRevealed(row: row, col: col)
        ZStack {
            Rectangle().fill(revealed ? Color.black.opacity(0.5) : Color(red: 0.05, green: 0.08, blue: 0.14).opacity(0.85))
            Rectangle()
                .strokeBorder(neonCyan.opacity(revealed ? 0.22 : 0.7), lineWidth: 1)
                .shadow(color: neonCyan.opacity(revealed ? 0 : 0.55), radius: 3)
            cellGlyph(row: row, col: col,
                      flag: { Image(systemName: "flag.fill").foregroundStyle(neonCyan).shadow(color: neonCyan, radius: 6) },
                      mine: { Image(systemName: "burst.fill").foregroundStyle(neonMagenta).shadow(color: neonMagenta, radius: 8) },
                      number: { n in Text("\(n)").foregroundStyle(cyberNumberColor(n)).shadow(color: cyberNumberColor(n).opacity(0.9), radius: 5) },
                      font: .system(size: CGFloat(layout.numberFontSize), weight: .heavy, design: .monospaced))
        }
    }

    // MARK: Shared glyph dispatcher

    @ViewBuilder private func cellGlyph<F: View, M: View, N: View>(
        row: Int, col: Int,
        flag: () -> F, mine: () -> M, number: (Int) -> N, font: Font
    ) -> some View {
        if session.game.isFlagged(row: row, col: col) {
            flag().font(font)
        } else if session.game.isRevealed(row: row, col: col) {
            if session.game.hasMine(row: row, col: col) {
                mine().font(font)
            } else {
                let n = session.game.adjacentMineCount(row: row, col: col)
                if n > 0 { number(n).font(font).monospacedDigit() }
            }
        }
    }

    // MARK: Number palettes

    private func modernNumberColor(_ n: Int) -> Color {
        switch n {
        case 1: return Color(red: 0.16, green: 0.36, blue: 0.78)
        case 2: return Color(red: 0.16, green: 0.52, blue: 0.28)
        case 3: return Color(red: 0.78, green: 0.20, blue: 0.22)
        case 4: return Color(red: 0.34, green: 0.22, blue: 0.62)
        case 5: return Color(red: 0.60, green: 0.28, blue: 0.16)
        case 6: return Color(red: 0.12, green: 0.52, blue: 0.55)
        case 7: return Color(red: 0.12, green: 0.14, blue: 0.18)
        default: return Color(red: 0.40, green: 0.42, blue: 0.46)
        }
    }

    private func classicNumberColor(_ n: Int) -> Color {
        switch n {
        case 1: return Color(red: 0.0, green: 0.0, blue: 1.0)
        case 2: return Color(red: 0.0, green: 0.5, blue: 0.0)
        case 3: return Color(red: 1.0, green: 0.0, blue: 0.0)
        case 4: return Color(red: 0.0, green: 0.0, blue: 0.5)
        case 5: return Color(red: 0.5, green: 0.0, blue: 0.0)
        case 6: return Color(red: 0.0, green: 0.5, blue: 0.5)
        case 7: return Color.black
        default: return Color(white: 0.5)
        }
    }

    private func cyberNumberColor(_ n: Int) -> Color {
        switch n {
        case 1: return neonCyan
        case 2: return Color(red: 0.22, green: 1.0, blue: 0.30)
        case 3: return neonMagenta
        case 4: return Color(red: 0.70, green: 0.40, blue: 1.0)
        case 5: return Color(red: 1.0, green: 0.62, blue: 0.18)
        case 6: return Color(red: 0.18, green: 0.95, blue: 0.85)
        case 7: return .white
        default: return Color(white: 0.7)
        }
    }

    // MARK: Helpers

    private var mineCount: Int {
        session.game.mineCount
    }

    private var flagCount: Int {
        var c = 0
        for r in 0..<session.game.height {
            for col in 0..<session.game.width where session.game.isFlagged(row: r, col: col) {
                c += 1
            }
        }
        return c
    }

    private func newGame() {
        session.newGame()
    }

    private func zoomIn() {
        session.zoom = min(2.2, ((session.zoom + 0.15) * 100).rounded() / 100)
    }

    private func zoomOut() {
        session.zoom = max(0.4, ((session.zoom - 0.15) * 100).rounded() / 100)
    }
}

// MARK: - Classic chrome pieces (clean-room recreation, no Microsoft assets)

/// A beveled border: raised (light top/left, dark bottom/right) or sunken (inverted).
private struct ClassicBevel: View {
    var raised: Bool
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let light = Color.white
            let dark = Color(white: 0.5)
            ZStack {
                Path { p in p.move(to: CGPoint(x: 1, y: 1)); p.addLine(to: CGPoint(x: w - 1, y: 1)) }
                    .stroke(raised ? light : dark, lineWidth: 2)
                Path { p in p.move(to: CGPoint(x: 1, y: 1)); p.addLine(to: CGPoint(x: 1, y: h - 1)) }
                    .stroke(raised ? light : dark, lineWidth: 2)
                Path { p in p.move(to: CGPoint(x: 1, y: h - 1)); p.addLine(to: CGPoint(x: w - 1, y: h - 1)) }
                    .stroke(raised ? dark : light, lineWidth: 2)
                Path { p in p.move(to: CGPoint(x: w - 1, y: 1)); p.addLine(to: CGPoint(x: w - 1, y: h - 1)) }
                    .stroke(raised ? dark : light, lineWidth: 2)
            }
        }
    }
}

private struct ClassicMine: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = s * 0.36
            ZStack {
                Path { p in
                    for a in stride(from: 0.0, to: 180.0, by: 45.0) {
                        let rad = a * .pi / 180
                        p.move(to: CGPoint(x: c.x - cos(rad) * r, y: c.y - sin(rad) * r))
                        p.addLine(to: CGPoint(x: c.x + cos(rad) * r, y: c.y + sin(rad) * r))
                    }
                }.stroke(Color.black, lineWidth: 1.8)
                Circle().fill(Color.black).frame(width: s * 0.5, height: s * 0.5).position(c)
                Circle().fill(Color.white).frame(width: s * 0.14, height: s * 0.14)
                    .position(x: c.x - s * 0.1, y: c.y - s * 0.1)
            }
        }
    }
}

private struct ClassicFlag: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Rectangle().fill(Color.black)
                    .frame(width: max(1.5, w * 0.06), height: h * 0.46)
                    .position(x: w * 0.58, y: h * 0.44)
                Rectangle().fill(Color.black)
                    .frame(width: w * 0.5, height: max(2, h * 0.09))
                    .position(x: w * 0.5, y: h * 0.74)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.58, y: h * 0.2))
                    p.addLine(to: CGPoint(x: w * 0.26, y: h * 0.33))
                    p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.46))
                    p.closeSubpath()
                }.fill(Color.red)
            }
        }
    }
}

private struct MinesweeperModeButtonStyle: ButtonStyle {
    var isSelected: Bool
    var accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(PrismetDesign.panelHi))
                    .overlay(Capsule().strokeBorder(isSelected ? Color.white.opacity(0.34) : PrismetDesign.hairline, lineWidth: 1))
            )
            .foregroundStyle(isSelected ? .white : PrismetDesign.ink)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct MinesweeperIconButtonStyle: ButtonStyle {
    var isSelected: Bool
    var accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(width: 36, height: 34)
            .background(
                Circle()
                    .fill(isSelected ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(PrismetDesign.panelHi))
                    .overlay(Circle().strokeBorder(isSelected ? Color.white.opacity(0.34) : PrismetDesign.hairline, lineWidth: 1))
            )
            .foregroundStyle(isSelected ? .white : PrismetDesign.ink)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct MinesweeperCellClickTarget<Content: View>: NSViewRepresentable {
    var isEnabled: Bool
    var onClick: (Int) -> Void
    @ViewBuilder var label: () -> Content

    func makeNSView(context: Context) -> ClickHostingView<Content> {
        let view = ClickHostingView(rootView: label())
        view.onClick = onClick
        view.isEnabled = isEnabled
        return view
    }

    func updateNSView(_ nsView: ClickHostingView<Content>, context: Context) {
        nsView.rootView = label()
        nsView.onClick = onClick
        nsView.isEnabled = isEnabled
    }

    final class ClickHostingView<Root: View>: NSHostingView<Root> {
        var onClick: ((Int) -> Void)?
        var isEnabled = true

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) { handle(event) }
        override func rightMouseDown(with event: NSEvent) { handle(event) }

        private func handle(_ event: NSEvent) {
            guard isEnabled else { return }
            onClick?(event.buttonNumber)
        }
    }
}
