import SwiftUI

private enum GomokuSkin: String, CaseIterable, Identifiable {
    case kaya = "Kaya"
    case ebony = "Ebony"

    var id: String { rawValue }
}

private struct GomokuTheme {
    let boardHi: Color
    let boardLo: Color
    let grain: Color
    let frameHi: Color
    let frameLo: Color
    let frameRule: Color
    let line: Color
    let hoshi: Color
    let chipHi: Color
    let chipLo: Color
    let chipEdge: Color
    let chipInk: Color
    let accent: Color

    static func theme(for skin: GomokuSkin) -> GomokuTheme {
        switch skin {
        case .kaya:
            return GomokuTheme(
                boardHi: Color(red: 0.87, green: 0.70, blue: 0.44),
                boardLo: Color(red: 0.77, green: 0.57, blue: 0.32),
                grain: Color(red: 0.45, green: 0.30, blue: 0.14).opacity(0.10),
                frameHi: Color(red: 0.47, green: 0.33, blue: 0.18),
                frameLo: Color(red: 0.33, green: 0.22, blue: 0.11),
                frameRule: PrismetDesign.gold.opacity(0.55),
                line: Color(red: 0.22, green: 0.14, blue: 0.06).opacity(0.78),
                hoshi: Color(red: 0.20, green: 0.13, blue: 0.06).opacity(0.85),
                chipHi: Color(red: 0.50, green: 0.36, blue: 0.20),
                chipLo: Color(red: 0.37, green: 0.25, blue: 0.13),
                chipEdge: Color.black.opacity(0.38),
                chipInk: Color(red: 0.95, green: 0.90, blue: 0.80),
                accent: Color(red: 0.60, green: 0.43, blue: 0.20)
            )
        case .ebony:
            return GomokuTheme(
                boardHi: Color(red: 0.18, green: 0.17, blue: 0.16),
                boardLo: Color(red: 0.12, green: 0.11, blue: 0.10),
                grain: Color.white.opacity(0.035),
                frameHi: Color(red: 0.13, green: 0.12, blue: 0.11),
                frameLo: Color(red: 0.06, green: 0.055, blue: 0.05),
                frameRule: PrismetDesign.gold.opacity(0.60),
                line: Color(white: 0.80).opacity(0.52),
                hoshi: Color(white: 0.85).opacity(0.72),
                chipHi: Color(red: 0.24, green: 0.22, blue: 0.20),
                chipLo: Color(red: 0.14, green: 0.13, blue: 0.12),
                chipEdge: PrismetDesign.gold.opacity(0.35),
                chipInk: Color(red: 0.92, green: 0.89, blue: 0.82),
                accent: Color(red: 0.55, green: 0.50, blue: 0.38)
            )
        }
    }
}

private struct GomokuChipStyle: ButtonStyle {
    let background: Color
    let ink: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .serif))
            .foregroundStyle(ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(background)
                    .overlay(Capsule().strokeBorder(ink.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.12 : 0.24), radius: configuration.isPressed ? 2 : 5, y: configuration.isPressed ? 1 : 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct GomokuBoardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
    }
}

struct GomokuView: View {
    @ObservedObject var session: GomokuSession
    @AppStorage("gomoku.skin") private var skinRaw = GomokuSkin.kaya.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hoveredCell: GomokuPoint?
    @State private var lastMove: GomokuPoint?
    @State private var isBotThinking = false
    @State private var botRequestID = 0

    private let accent = FacetRegistry.accent(for: "gomoku")

    private static let grainBands: [(y: CGFloat, drift: CGFloat, bow: CGFloat)] = [
        (0.12, 0.014, -0.020),
        (0.27, -0.010, 0.016),
        (0.44, 0.018, -0.012),
        (0.58, -0.006, 0.022),
        (0.73, 0.012, -0.018),
        (0.88, -0.014, 0.010)
    ]

    private var skin: GomokuSkin { GomokuSkin(rawValue: skinRaw) ?? .kaya }
    private var theme: GomokuTheme { GomokuTheme.theme(for: skin) }

    private var canPlay: Bool {
        !session.game.isGameOver && !isBotThinking && (!session.usesBot || session.game.currentPlayer == .black)
    }

    private var isBotTurn: Bool {
        session.usesBot && session.game.currentPlayer == .white && !session.game.isGameOver
    }

    private var statusText: String {
        if let winner = session.game.winner {
            return "\(name(winner)) wins"
        }
        if session.game.isDraw { return "Draw" }
        if isBotThinking { return "\(name(botPlayer)) is thinking" }
        if session.usesBot {
            return session.game.currentPlayer == botPlayer ? "\(name(botPlayer)) to move" : "Your move"
        }
        return "\(name(session.game.currentPlayer)) to move"
    }

    private var botPlayer: GomokuPlayer { .white }

    init(session: GomokuSession = GomokuSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 16) {
            GameHeader(title: "Gomoku",
                       systemImage: "circle.grid.3x3.fill",
                       accent: accent,
                       subtitle: statusText) {
                StatBadge(label: "Mode", value: session.usesBot ? "Solo" : "Local", accent: accent)
                StatBadge(label: "Stones", value: "\(session.game.moveCount)", accent: accent)
            }
            .frame(maxWidth: 620)

            board
            controls
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 700, minHeight: 620)
        .facetBackground(accent)
        .onAppear { scheduleBotMoveIfNeeded() }
        .onChange(of: session.usesBot) { _, _ in
            if !session.usesBot {
                isBotThinking = false
            }
            scheduleBotMoveIfNeeded()
        }
        .onChange(of: session.game.currentPlayer) { _, _ in
            lastMove = nil
            scheduleBotMoveIfNeeded()
        }
        .onChange(of: session.game.moveCount) { _, _ in
            session.aiELO = Self.clampELO(session.aiELO)
            session.saveNow()
        }
    }

    private var board: some View {
        GeometryReader { geo in
            let boardSide = min(geo.size.width, geo.size.height)
            let outer = boardSide
            let frame = max(1, outer - 26)
            let cell = frame / CGFloat(GomokuGame.size)

            ZStack {
                gobanFrame(outer: outer)
                playingField(frame: frame, cell: cell)
            }
            .frame(width: outer, height: outer)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 680, maxHeight: 680)
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    newGame()
                } label: {
                    Label("New Game", systemImage: "arrow.clockwise")
                }
                .buttonStyle(AccentButtonStyle(accent: theme.accent))

                Button {
                    undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(!session.canUndo)

                Menu {
                    Button("Save") { session.saveNow() }
                    Button("Load") { session.reloadSavedState() }
                } label: {
                    Label("State", systemImage: "externaldrive")
                }
                .buttonStyle(GlassButtonStyle())
            }

            HStack {
                Toggle("Play against bot", isOn: $session.usesBot)
                    .toggleStyle(.switch)
                    .onChange(of: session.usesBot) { _, _ in
                        if !session.usesBot { isBotThinking = false }
                    }

                Spacer()

                Menu {
                    ForEach(GomokuSkin.allCases) { option in
                        Button(option.rawValue) { skinRaw = option.rawValue }
                    }
                } label: {
                    Image(systemName: "paintbrush")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(GomokuChipStyle(background: theme.chipHi, ink: theme.chipInk))
            }

            if session.usesBot {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI opponent")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(PrismetDesign.ink3)
                        Spacer()
                        Text("ELO \(session.aiELO)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(PrismetDesign.ink2)
                    }
                    Text(tierName(forELO: session.aiELO))
                        .font(PrismetDesign.title(20))
                        .foregroundStyle(PrismetDesign.ink)
                    Slider(value: botELOBinding, in: 600...2400, step: 100) {
                        Text("AI strength")
                    }
                    .tint(theme.accent)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PrismetDesign.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(PrismetDesign.hairline, lineWidth: 1)
                        )
                )
            }
        }
        .frame(maxWidth: 620)
    }

    private func gobanFrame(outer: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [theme.frameHi, theme.frameLo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.frameRule, lineWidth: 1)
                    .padding(9)
            )
            .frame(width: outer, height: outer)
    }

    private func playingField(frame: CGFloat, cell: CGFloat) -> some View {
        let n = GomokuGame.size

        return ZStack(alignment: .topLeading) {
            fieldWood(side: frame)
            gridLines(side: frame, cell: cell, n: n)
            hoshiPoints(cell: cell)

            ForEach(0..<n, id: \.self) { row in
                ForEach(0..<n, id: \.self) { col in
                    point(row: row, col: col, cell: cell)
                        .position(
                            x: cell * (CGFloat(col) + 0.5),
                            y: cell * (CGFloat(row) + 0.5)
                        )
                }
            }
        }
        .frame(width: frame, height: frame)
    }

    private func fieldWood(side: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [theme.boardHi, theme.boardLo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Path { path in
                    for band in Self.grainBands {
                        let y = side * band.y
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addQuadCurve(
                            to: CGPoint(x: side, y: y + side * band.drift),
                            control: CGPoint(x: side * 0.5, y: y + side * band.bow)
                        )
                    }
                }
                .stroke(theme.grain, lineWidth: 1.4)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            )
            .frame(width: side, height: side)
    }

    private func gridLines(side: CGFloat, cell: CGFloat, n: Int) -> some View {
        let inset = cell / 2
        return ZStack(alignment: .topLeading) {
            Path { path in
                for i in 0..<n {
                    let p = inset + CGFloat(i) * cell
                    path.move(to: CGPoint(x: inset, y: p))
                    path.addLine(to: CGPoint(x: side - inset, y: p))
                    path.move(to: CGPoint(x: p, y: inset))
                    path.addLine(to: CGPoint(x: p, y: side - inset))
                }
            }
            .stroke(theme.line, lineWidth: 1)

            Rectangle()
                .strokeBorder(theme.line, lineWidth: 1.6)
                .frame(width: side - cell, height: side - cell)
                .offset(x: inset, y: inset)
        }
        .frame(width: side, height: side)
    }

    private func hoshiPoints(cell: CGFloat) -> some View {
        let points = [(3, 3), (3, 11), (7, 7), (11, 3), (11, 11)]
        return ForEach(points.indices, id: \.self) { index in
            let point = points[index]
            Circle()
                .fill(theme.hoshi)
                .frame(width: max(4, cell * 0.20), height: max(4, cell * 0.20))
                .position(
                    x: cell * (CGFloat(point.1) + 0.5),
                    y: cell * (CGFloat(point.0) + 0.5)
                )
        }
    }

    private func stoneGradient(_ player: GomokuPlayer, radius: CGFloat) -> RadialGradient {
        if player == .black {
            return RadialGradient(
                colors: [
                    Color(red: 0.38, green: 0.41, blue: 0.46),
                    Color(red: 0.13, green: 0.14, blue: 0.16),
                    Color(red: 0.04, green: 0.045, blue: 0.055)
                ],
                center: UnitPoint(x: 0.34, y: 0.28),
                startRadius: 0,
                endRadius: radius * 1.5
            )
        }

        return RadialGradient(
            colors: [
                Color(red: 1.0, green: 0.995, blue: 0.97),
                Color(red: 0.96, green: 0.94, blue: 0.89),
                Color(red: 0.87, green: 0.84, blue: 0.78)
            ],
            center: UnitPoint(x: 0.36, y: 0.30),
            startRadius: 0,
            endRadius: radius * 1.6
        )
    }

    @ViewBuilder
    private func point(row: Int, col: Int, cell: CGFloat) -> some View {
        let here = GomokuPoint(row: row, col: col)
        let stone = session.game.stone(row: row, col: col)
        let isTargeted = hoveredCell == here

        Button {
            place(row: row, col: col)
        } label: {
            ZStack {
                if let stone {
                    stoneBody(stone, cell: cell, isLastMove: lastMove == here)
                        .shadow(color: .black.opacity(0.32), radius: max(1.5, cell * 0.07), y: max(1, cell * 0.05))
                        .padding(cell * 0.13)
                        .frame(width: cell, height: cell)
                        .background(Color.clear)
                } else if canPlay && isTargeted {
                    Circle()
                        .fill(stoneGradient(session.game.currentPlayer, radius: cell * 0.5))
                        .opacity(0.44)
                        .padding(cell * 0.17)
                }

                if !session.game.isGameOver && isTargeted {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(stone == nil ? theme.accent : Color.clear,
                                      lineWidth: 1.4)
                        .frame(width: cell, height: cell)
                }
            }
            .frame(width: cell, height: cell)
        }
        .buttonStyle(GomokuBoardButtonStyle())
        .disabled(!canPlace(at: row, col: col))
        .onHover { hovering in
            if hovering {
                hoveredCell = here
            } else if hoveredCell == here {
                hoveredCell = nil
            }
        }
    }

    private func stoneBody(_ stone: GomokuPlayer, cell: CGFloat, isLastMove: Bool) -> some View {
        ZStack {
            Circle()
                .fill(stoneGradient(stone, radius: cell * 0.5))
            Circle()
                .strokeBorder(
                    stone == .black ? Color.white.opacity(0.15) : Color.black.opacity(0.16),
                    lineWidth: 0.8
                )
            if isLastMove {
                Circle()
                    .strokeBorder(
                        stone == .black ? Color(white: 0.93) : Color(white: 0.16),
                        lineWidth: max(1.3, cell * 0.055)
                    )
                    .padding(cell * 0.20)
            }
        }
    }

    private func canPlace(at row: Int, col: Int) -> Bool {
        canPlay && session.game.stone(row: row, col: col) == nil
    }

    private func name(_ player: GomokuPlayer) -> String {
        player == .black ? "Black" : "White"
    }

    private func tierName(forELO elo: Int) -> String {
        switch elo {
        case ..<900: return "Beginner"
        case 900..<1300: return "Casual"
        case 1300..<1700: return "Intermediate"
        case 1700..<2100: return "Advanced"
        default: return "Expert"
        }
    }

    private var botELOBinding: Binding<Double> {
        Binding(
            get: { Double(session.aiELO) },
            set: { session.aiELO = Self.clampELO(Int($0)) }
        )
    }

    private func place(row: Int, col: Int) {
        guard canPlace(at: row, col: col) else { return }

        withAnimation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.8)) {
            if session.play(row: row, col: col) {
                lastMove = GomokuPoint(row: row, col: col)
                hoveredCell = nil
            }
        }

        if !session.game.isGameOver {
            scheduleBotMoveIfNeeded()
        }
    }

    private func newGame() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8)) {
            session.reset()
        }
        lastMove = nil
        hoveredCell = nil
        isBotThinking = false
        scheduleBotMoveIfNeeded()
    }

    private func undo() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8)) {
            session.undo()
        }
        if session.usesBot && session.game.currentPlayer == botPlayer {
            isBotThinking = false
        }
        lastMove = nil
        scheduleBotMoveIfNeeded()
    }

    private func scheduleBotMoveIfNeeded() {
        guard session.usesBot, isBotTurn, !isBotThinking else { return }

        isBotThinking = true
        botRequestID += 1
        let requestID = botRequestID
        let snapshot = session.snapshot()
        let aiPlayer = botPlayer

        Task {
            if !reduceMotion {
                try? await Task.sleep(nanoseconds: 240_000_000)
            }

            let move = await Task.detached(priority: .userInitiated) {
                GomokuAI(player: aiPlayer, targetELO: snapshot.aiELO).move(in: snapshot.game)
            }.value

            await MainActor.run {
                guard requestID == botRequestID,
                      session.usesBot,
                      !session.game.isGameOver,
                      session.game == snapshot.game,
                      session.game.currentPlayer == aiPlayer else {
                    isBotThinking = false
                    return
                }

                if let move {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85)) {
                        _ = session.play(row: move.row, col: move.col)
                    }
                    lastMove = move
                }

                isBotThinking = false
            }
        }
    }

    private static func clampELO(_ value: Int) -> Int {
        min(2400, max(600, value))
    }
}

#Preview {
    NavigationStack {
        GomokuView()
    }
}
