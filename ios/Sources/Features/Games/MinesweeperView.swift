import SwiftUI

enum MinesweeperStyle: String, CaseIterable, Identifiable {
    case modern = "Modern"
    case classic = "Classic '97"
    case cyber = "Cyberpunk"

    var id: String { rawValue }
}

struct MinesweeperView: View {
    private let accent = Color(red: 0.30, green: 0.55, blue: 0.42)
    private let accountID: UUID?

    // Board dimensions follow the ACTIVE game, so a custom-sized board renders
    // (and its stats read) correctly after New Game or a restore.
    private var columns: Int { game.width }
    private var rows: Int { game.height }
    private var mines: Int { game.mineCount }

    @StateObject private var persistence = PersistedGameSession<MinesweeperSnapshot>(gameID: .minesweeper)
    @State private var seed: UInt64 = 1
    @State private var game = MinesweeperGame(width: 9, height: 9, mineCount: 10, seed: 1)
    @State private var style: MinesweeperStyle = .modern

    // Customization chosen BEFORE starting a game — persisted like Sudoku's
    // difficulty and Chess's ELO. Presets start a fresh game immediately;
    // Custom width/height/density are staged and applied on the next New Game.
    @AppStorage("minesweeper.difficulty") private var difficultyRaw = MinesweeperDifficulty.beginner.rawValue
    @AppStorage("minesweeper.customWidth") private var customWidth = 9
    @AppStorage("minesweeper.customHeight") private var customHeight = 9
    @AppStorage("minesweeper.customDensity") private var customDensity = 10.0 / 81.0

    // Tap-mode: when true, a single tap places/removes a flag instead of revealing.
    @State private var flagMode = false

    // Zoom: 1 = board fits the viewport; higher magnifies (cells re-layout at the
    // zoomed size, so numbers stay sharp) and the board pans in a 2-axis scroll.
    @State private var zoom: CGFloat = 1
    @GestureState private var pinchScale: CGFloat = 1
    @State private var showCustomSheet = false

    // Haptic triggers — small @State that flips on each event so .sensoryFeedback fires.
    @State private var revealTick = 0
    @State private var flagTick = 0
    @State private var didWin = false
    @State private var didLose = false

    /// Cells never magnify past this — comfortably tappable, not comically big.
    private static let maxCellSize: CGFloat = 46
    /// Below this fit-size a fresh board auto-zooms so it's playable immediately.
    private static let comfortableCellSize: CGFloat = 30

    init(accountID: UUID? = nil, initialGame: MinesweeperGame? = nil) {
        self.accountID = accountID
        if let initialGame {
            _game = State(initialValue: initialGame)
        }
    }

    private var flagCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<columns where game.isFlagged(row: r, col: c) {
                count += 1
            }
        }
        return count
    }

    private var subtitle: String {
        switch game.status {
        case .playing:
            return flagMode ? "Flag mode · tap to flag" : "Tap to reveal · long-press to flag"
        case .won: return "Cleared!"
        case .lost: return "Boom — tap New Game"
        }
    }

    // MARK: - Customization

    private var difficulty: MinesweeperDifficulty {
        MinesweeperDifficulty(rawValue: difficultyRaw) ?? .beginner
    }

    /// The staged custom board (clamped to the shared valid ranges).
    private var customSettings: MinesweeperSettings {
        MinesweeperSettings(width: customWidth, height: customHeight, mineDensity: customDensity).clamped()
    }

    /// The width/height/mine-count the next New Game will use.
    private var effectiveConfig: (width: Int, height: Int, mineCount: Int) {
        if let preset = difficulty.preset { return preset }
        let s = customSettings
        return (s.width, s.height, s.mineCount)
    }

    /// Changing the preset immediately deals a fresh board (like Sudoku's level).
    private var difficultyBinding: Binding<MinesweeperDifficulty> {
        Binding(
            get: { difficulty },
            set: { newValue in
                guard newValue != difficulty else { return }
                difficultyRaw = newValue.rawValue
                newGame()
            }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            GameHeader(title: "Minesweeper",
                       systemImage: "flag.fill",
                       accent: accent,
                       subtitle: subtitle) {
                HStack(spacing: 16) {
                    StatBadge(label: "Mines", value: "\(mines)", accent: accent)
                    StatBadge(label: "Flags", value: "\(flagCount)")
                }
            }
            board
                .layoutPriority(1)

            controlBar
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .navigationTitle("Minesweeper")
        .navigationBarTitleDisplayMode(.inline)
        // Light tap on a normal reveal, a distinct medium tap on flag toggles,
        // success on a solve, error on hitting a mine.
        .gameFeedback(.move, trigger: revealTick)
        .gameFeedback(.select, trigger: flagTick)
        .gameFeedback(.win, trigger: didWin)
        .gameFeedback(.lose, trigger: didLose)
        .onAppear {
            persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
        }
        .onDisappear { save(forceCloud: true) }
        .onChange(of: style) { _, _ in save() }
        .sheet(isPresented: $showCustomSheet) {
            customBoardSheet
                .presentationDetents([.height(360), .medium])
                .presentationDragIndicator(.visible)
        }
    }

    /// One compact row: New Game, tap-mode toggle, and a Board menu holding the
    /// difficulty presets, the custom-board editor, and the visual style — so the
    /// board itself gets nearly the whole screen.
    private var controlBar: some View {
        HStack(spacing: 10) {
            Button { newGame() } label: {
                Label("New Game", systemImage: "arrow.clockwise")
            }
            .buttonStyle(AccentButtonStyle(accent: accent))

            Button {
                withAnimation(.snappy(duration: 0.16)) {
                    flagMode.toggle()
                }
                save()
            } label: {
                Label(flagMode ? "Flag" : "Reveal",
                      systemImage: flagMode ? "flag.fill" : "hand.tap.fill")
            }
            .buttonStyle(GlassButtonStyle())

            Menu {
                Picker("Difficulty", selection: difficultyBinding) {
                    ForEach(MinesweeperDifficulty.allCases.filter { $0 != .custom }) { level in
                        if let p = level.preset {
                            Text("\(level.rawValue) · \(p.width)×\(p.height)").tag(level)
                        }
                    }
                }
                Button {
                    showCustomSheet = true
                } label: {
                    if difficulty == .custom {
                        Label("Custom · \(game.width)×\(game.height)…", systemImage: "checkmark")
                    } else {
                        Text("Custom Board…")
                    }
                }
                Divider()
                Picker("Look", selection: $style) {
                    ForEach(MinesweeperStyle.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Label("Board", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    // MARK: - Board (zoomable)

    /// A key that changes whenever a differently-shaped board arrives (new game,
    /// restore) so the auto-zoom can re-run.
    private var boardKey: String { "\(game.width)x\(game.height)" }

    private var board: some View {
        GeometryReader { geo in
            let spacing = boardSpacing
            let cols = CGFloat(columns)
            let rowsF = CGFloat(rows)
            // Square cells sized to fit BOTH axes at zoom 1, so non-square custom
            // boards (e.g. 30×16 Expert) render fully instead of clipping.
            let fit = max(1, min(
                (geo.size.width - spacing * (cols + 1)) / cols,
                (geo.size.height - spacing * (rowsF + 1)) / rowsF
            ))
            let maxZoom = max(1, Self.maxCellSize / fit)
            let layoutZoom = min(max(zoom, 1), maxZoom)
            let liveZoomScale = min(max(pinchScale, 1 / max(layoutZoom, 0.001)), maxZoom / max(layoutZoom, 0.001))
            let cell = max(1, fit * layoutZoom)
            let boardW = cell * cols + spacing * (cols + 1)
            let boardH = cell * rowsF + spacing * (rowsF + 1)
            let liveBoardW = boardW * liveZoomScale
            let liveBoardH = boardH * liveZoomScale
            let scrolls = liveBoardW > geo.size.width + 0.5 || liveBoardH > geo.size.height + 0.5

            Group {
                if scrolls {
                    // Zoomed past the viewport: pan around the board section by
                    // section, in both axes.
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        scaledBoardGrid(
                            cell: cell,
                            spacing: spacing,
                            width: boardW,
                            height: boardH,
                            liveZoomScale: liveZoomScale
                        )
                            .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    scaledBoardGrid(
                        cell: cell,
                        spacing: spacing,
                        width: boardW,
                        height: boardH,
                        liveZoomScale: liveZoomScale
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($pinchScale) { value, state, _ in
                        let raw = layoutZoom * value
                        let clamped = min(max(raw, 1), maxZoom)
                        state = clamped / max(layoutZoom, 0.001)
                    }
                    .onEnded { value in
                        let raw = layoutZoom * value
                        zoom = min(max((raw * 24).rounded() / 24, 1), maxZoom)
                    }
            )
            .overlay(alignment: .bottomTrailing) {
                // Only boards that are cramped at fit-size benefit from zooming;
                // a 9×9 with 38pt cells doesn't need the extra chrome.
                if maxZoom > 1.02, fit < Self.comfortableCellSize {
                    zoomControls(maxZoom: maxZoom, current: layoutZoom)
                }
            }
            .onAppear { autoZoom(fit: fit, maxZoom: maxZoom, freshBoard: false) }
            .onChange(of: boardKey) { _, _ in autoZoom(fit: fit, maxZoom: maxZoom, freshBoard: true) }
        }
    }

    private func boardGrid(cell: CGFloat, spacing: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { c in
                        cellView(row: r, col: c, size: cell)
                    }
                }
            }
        }
        .padding(spacing)
        .frame(width: width, height: height)
        .modifier(BoardChrome(style: style))
        .padding(4)
    }

    private func scaledBoardGrid(
        cell: CGFloat,
        spacing: CGFloat,
        width: CGFloat,
        height: CGFloat,
        liveZoomScale: CGFloat
    ) -> some View {
        boardGrid(cell: cell, spacing: spacing, width: width, height: height)
            .scaleEffect(liveZoomScale, anchor: .topLeading)
            .frame(width: width * liveZoomScale, height: height * liveZoomScale, alignment: .topLeading)
    }

    /// Pinch is continuous; these are the reliable fallback. `+`/`−` step the
    /// magnification, the arrows snap back to fit-the-whole-board.
    private func zoomControls(maxZoom: CGFloat, current: CGFloat) -> some View {
        VStack(spacing: 2) {
            Button { zoom = min(current + 0.5, maxZoom) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(current >= maxZoom - 0.01)
            Divider().frame(width: 26)
            Button { zoom = max(current - 0.5, 1) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(current <= 1.01)
            Divider().frame(width: 26)
            Button { zoom = 1 } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .disabled(current <= 1.01)
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Kaleido.ink)
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Kaleido.outline, lineWidth: 1))
        .padding(10)
    }

    /// Big boards start zoomed to a playable cell size (panning covers the rest);
    /// boards that fit comfortably start at fit.
    private func autoZoom(fit: CGFloat, maxZoom: CGFloat, freshBoard: Bool) {
        if fit >= Self.comfortableCellSize {
            if freshBoard { zoom = 1 }
        } else if freshBoard || zoom <= 1.01 {
            zoom = min(Self.comfortableCellSize / fit, maxZoom)
        }
    }

    // MARK: - Custom board sheet

    private var customBoardSheet: some View {
        VStack(spacing: 16) {
            Text("Custom Board")
                .font(Kaleido.rounded(22, .bold))
                .foregroundStyle(Kaleido.ink)

            VStack(spacing: 12) {
                Stepper(value: $customWidth,
                        in: MinesweeperSettings.minWidth...MinesweeperSettings.maxWidth) {
                    labeledValue("Width", "\(customWidth)")
                }
                Stepper(value: $customHeight,
                        in: MinesweeperSettings.minHeight...MinesweeperSettings.maxHeight) {
                    labeledValue("Height", "\(customHeight)")
                }
                VStack(spacing: 4) {
                    labeledValue("Mines",
                                 "\(customSettings.mineCount) · \(Int((customSettings.mineDensity * 100).rounded()))%")
                    Slider(value: $customDensity,
                           in: MinesweeperSettings.minMineDensity...MinesweeperSettings.maxMineDensity)
                    .tint(accent)
                }
            }
            .font(Kaleido.rounded(15, .semibold))
            .foregroundStyle(Kaleido.ink)
            .padding(14)
            .kaleidoCard()

            Button {
                difficultyRaw = MinesweeperDifficulty.custom.rawValue
                showCustomSheet = false
                newGame()
            } label: {
                Label("Start \(customSettings.width)×\(customSettings.height) Game",
                      systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle(accent: accent))
        }
        .padding(20)
        .frame(maxWidth: 460)
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(Kaleido.ink2)
        }
    }

    private var boardSpacing: CGFloat {
        switch style {
        case .modern: return 4
        case .classic: return 2
        case .cyber: return 5
        }
    }

    @ViewBuilder
    private func cellView(row: Int, col: Int, size: CGFloat) -> some View {
        let revealed = game.isRevealed(row: row, col: col)
        let flagged = game.isFlagged(row: row, col: col)
        let isMine = game.hasMine(row: row, col: col)
        let showMine = game.status == .lost && isMine
        let count = game.adjacentMineCount(row: row, col: col)

        Group {
            switch style {
            case .modern:
                modernCell(row: row, col: col, size: size,
                           revealed: revealed, flagged: flagged,
                           showMine: showMine, count: count)
            case .classic:
                classicCell(row: row, col: col, size: size,
                            revealed: revealed, flagged: flagged,
                            showMine: showMine, count: count)
            case .cyber:
                cyberCell(row: row, col: col, size: size,
                          revealed: revealed, flagged: flagged,
                          showMine: showMine, count: count)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture {
            if flagMode {
                flag(row: row, col: col)
            } else {
                reveal(row: row, col: col)
            }
        }
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    flag(row: row, col: col)
                }
        )
    }

    // MARK: - Actions

    private func reveal(row: Int, col: Int) {
        guard game.status == .playing else { return }
        // Don't reveal an already-revealed cell or a flagged one.
        guard !game.isRevealed(row: row, col: col),
              !game.isFlagged(row: row, col: col) else { return }

        withAnimation(.snappy(duration: 0.16)) {
            game.reveal(row: row, col: col)
        }
        revealTick &+= 1
        checkOutcome()
        save(forceCloud: game.status != .playing)
    }

    private func flag(row: Int, col: Int) {
        guard game.status == .playing else { return }
        guard !game.isRevealed(row: row, col: col) else { return }

        withAnimation(.snappy(duration: 0.16)) {
            game.toggleFlag(row: row, col: col)
        }
        flagTick &+= 1
        checkOutcome()
        save()
    }

    private func checkOutcome() {
        switch game.status {
        case .won: didWin.toggle()
        case .lost: didLose.toggle()
        case .playing: break
        }
    }

    // MARK: - Modern

    @ViewBuilder
    private func modernCell(row: Int, col: Int, size: CGFloat,
                            revealed: Bool, flagged: Bool,
                            showMine: Bool, count: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill((revealed || showMine) ? Kaleido.panel : Kaleido.panelHi)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Kaleido.outline, lineWidth: 1)
                )

            if flagged && !showMine {
                Image(systemName: "flag.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(accent)
                    .transition(.scale.combined(with: .opacity))
            } else if showMine {
                Image(systemName: "burst.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(Kaleido.ink)
            } else if revealed && count > 0 {
                Text("\(count)")
                    .font(Kaleido.rounded(size * 0.52))
                    .monospacedDigit()
                    .foregroundStyle(modernNumberColor(count))
                    .transition(.opacity)
            }
        }
    }

    private func modernNumberColor(_ count: Int) -> Color {
        switch count {
        case 1: return Color(red: 0.20, green: 0.40, blue: 0.75)
        case 2: return Color(red: 0.25, green: 0.55, blue: 0.32)
        case 3: return Color(red: 0.78, green: 0.30, blue: 0.25)
        case 4: return Color(red: 0.30, green: 0.25, blue: 0.62)
        case 5: return Color(red: 0.60, green: 0.30, blue: 0.20)
        case 6: return Color(red: 0.20, green: 0.55, blue: 0.58)
        case 7: return Kaleido.ink
        case 8: return Kaleido.ink2
        default: return Kaleido.ink
        }
    }

    // MARK: - Classic '97

    @ViewBuilder
    private func classicCell(row: Int, col: Int, size: CGFloat,
                             revealed: Bool, flagged: Bool,
                             showMine: Bool, count: Int) -> some View {
        let face = Color(white: 0.75)
        let lightBevel = Color(white: 0.97)
        let darkBevel = Color(white: 0.42)

        ZStack {
            if revealed || showMine {
                // Sunken / flat revealed cell with a thin inset border.
                Rectangle()
                    .fill(Color(white: 0.78))
                    .overlay(
                        Rectangle()
                            .strokeBorder(darkBevel, lineWidth: 1)
                    )
            } else {
                // Raised button: light top+left bevel, dark bottom+right bevel.
                Rectangle()
                    .fill(face)
                Rectangle()
                    .fill(lightBevel)
                    .frame(width: size, height: 2)
                    .frame(maxHeight: .infinity, alignment: .top)
                Rectangle()
                    .fill(lightBevel)
                    .frame(width: 2, height: size)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle()
                    .fill(darkBevel)
                    .frame(width: size, height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                Rectangle()
                    .fill(darkBevel)
                    .frame(width: 2, height: size)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if flagged && !showMine {
                Image(systemName: "flag.fill")
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundStyle(Color(red: 1.0, green: 0.0, blue: 0.0))
                    .transition(.scale.combined(with: .opacity))
            } else if showMine {
                Image(systemName: "burst.fill")
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundStyle(Color.black)
            } else if revealed && count > 0 {
                Text("\(count)")
                    .font(.system(size: size * 0.55, weight: .bold, design: .monospaced))
                    .foregroundStyle(classicNumberColor(count))
                    .transition(.opacity)
            }
        }
        .compositingGroup()
    }

    private func classicNumberColor(_ count: Int) -> Color {
        switch count {
        case 1: return Color(red: 0.0, green: 0.0, blue: 1.0)
        case 2: return Color(red: 0.0, green: 0.5, blue: 0.0)
        case 3: return Color(red: 1.0, green: 0.0, blue: 0.0)
        case 4: return Color(red: 0.0, green: 0.0, blue: 0.5)
        case 5: return Color(red: 0.5, green: 0.0, blue: 0.0)
        case 6: return Color(red: 0.0, green: 0.5, blue: 0.5)
        case 7: return Color.black
        case 8: return Color(white: 0.5)
        default: return Color.black
        }
    }

    // MARK: - Cyberpunk

    @ViewBuilder
    private func cyberCell(row: Int, col: Int, size: CGFloat,
                           revealed: Bool, flagged: Bool,
                           showMine: Bool, count: Int) -> some View {
        let neonCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
        let neonMagenta = Color(red: 1.0, green: 0.18, blue: 0.85)
        let edge = (row + col).isMultiple(of: 2) ? neonCyan : neonMagenta

        ZStack {
            if revealed || showMine {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.06, blue: 0.11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(edge.opacity(0.25), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.09, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(edge, lineWidth: 1.5)
                    )
                    .shadow(color: edge.opacity(0.7), radius: 6)
            }

            if flagged && !showMine {
                Image(systemName: "flag.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(neonMagenta)
                    .shadow(color: neonMagenta.opacity(0.8), radius: 5)
                    .transition(.scale.combined(with: .opacity))
            } else if showMine {
                Image(systemName: "burst.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(neonCyan)
                    .shadow(color: neonCyan.opacity(0.85), radius: 6)
            } else if revealed && count > 0 {
                let glow = cyberNumberColor(count)
                Text("\(count)")
                    .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(glow)
                    .shadow(color: glow.opacity(0.85), radius: 5)
                    .transition(.opacity)
            }
        }
    }

    private func cyberNumberColor(_ count: Int) -> Color {
        switch count {
        case 1: return Color(red: 0.0, green: 0.95, blue: 1.0)   // cyan
        case 2: return Color(red: 0.45, green: 1.0, blue: 0.20)  // lime
        case 3: return Color(red: 1.0, green: 0.18, blue: 0.85)  // magenta
        case 4: return Color(red: 1.0, green: 0.92, blue: 0.20)  // yellow
        case 5: return Color(red: 1.0, green: 0.55, blue: 0.10)  // orange
        case 6: return Color(red: 0.30, green: 0.80, blue: 1.0)  // sky
        case 7: return Color(red: 0.85, green: 0.45, blue: 1.0)  // violet
        case 8: return Color(red: 1.0, green: 0.30, blue: 0.40)  // hot red
        default: return Color(red: 0.0, green: 0.95, blue: 1.0)
        }
    }

    private func newGame() {
        let config = effectiveConfig
        seed = UInt64.random(in: 1...UInt64.max)
        withAnimation(.snappy(duration: 0.16)) {
            game = MinesweeperGame(width: config.width,
                                   height: config.height,
                                   mineCount: config.mineCount,
                                   seed: seed)
        }
        save(forceCloud: true)
    }

    private func snapshot() -> MinesweeperSnapshot {
        MinesweeperSnapshot(seed: seed, game: game, styleRawValue: style.rawValue, flagMode: flagMode)
    }

    private func restore(_ snapshot: MinesweeperSnapshot) {
        seed = snapshot.seed
        game = snapshot.game
        style = MinesweeperStyle(rawValue: snapshot.styleRawValue) ?? .modern
        flagMode = snapshot.flagMode
        syncDifficultyToGame()
    }

    /// After restoring a saved board, point the controls at whatever size was
    /// loaded — a matching preset, else Custom seeded from the board.
    private func syncDifficultyToGame() {
        let w = game.width, h = game.height, m = game.mineCount
        if let match = MinesweeperDifficulty.allCases.first(where: { level in
            guard let p = level.preset else { return false }
            return p.width == w && p.height == h && p.mineCount == m
        }) {
            difficultyRaw = match.rawValue
        } else {
            difficultyRaw = MinesweeperDifficulty.custom.rawValue
            customWidth = w
            customHeight = h
            let cells = max(1, w * h)
            customDensity = min(max(Double(m) / Double(cells),
                                    MinesweeperSettings.minMineDensity),
                                MinesweeperSettings.maxMineDensity)
        }
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: flagCount, forceCloud: forceCloud)
    }
}

// MARK: - Board background per style

private struct BoardChrome: ViewModifier {
    let style: MinesweeperStyle

    func body(content: Content) -> some View {
        switch style {
        case .modern:
            content.kaleidoCard()
        case .classic:
            content
                .background(Color(white: 0.75))
                .overlay(
                    Rectangle()
                        .strokeBorder(Color(white: 0.45), lineWidth: 2)
                )
        case .cyber:
            content
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.05, green: 0.04, blue: 0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.4), lineWidth: 1)
                )
        }
    }
}
