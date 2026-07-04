// PRISM: RELEASE Agent-Design(gomoku) 2026-07-03 - v10 design pass
import SwiftUI

// MARK: - Skin & theme (game-local tokens; do not move into KaleidoDesign)

private enum GomokuSkin: String, CaseIterable, Identifiable {
    case kaya = "Kaya"
    case ebony = "Ebony"
    var id: String { rawValue }
}

private struct GomokuTheme {
    // Playing field wood
    let boardHi: Color
    let boardLo: Color
    let grain: Color
    // Beveled outer frame
    let frameHi: Color
    let frameLo: Color
    let frameRule: Color
    // Grid + star points
    let line: Color
    let hoshi: Color
    // Wood-and-ink chips
    let chipHi: Color
    let chipLo: Color
    let chipEdge: Color
    let chipInk: Color
    // Screen accent (header iris / backdrop tint / slider)
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
                frameRule: Kaleido.gold.opacity(0.55),
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
                frameRule: Kaleido.gold.opacity(0.60),
                line: Color(white: 0.80).opacity(0.52),
                hoshi: Color(white: 0.85).opacity(0.72),
                chipHi: Color(red: 0.24, green: 0.22, blue: 0.20),
                chipLo: Color(red: 0.14, green: 0.13, blue: 0.12),
                chipEdge: Kaleido.gold.opacity(0.35),
                chipInk: Color(red: 0.92, green: 0.89, blue: 0.82),
                accent: Color(red: 0.55, green: 0.50, blue: 0.38)
            )
        }
    }
}

private struct GomokuChipStyle: ButtonStyle {
    let theme: GomokuTheme
    var ink: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .serif))
            .foregroundStyle(ink ?? theme.chipInk)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [theme.chipHi, theme.chipLo],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Capsule().strokeBorder(theme.chipEdge, lineWidth: 1))
                    .shadow(
                        color: .black.opacity(configuration.isPressed ? 0.10 : 0.30),
                        radius: configuration.isPressed ? 1 : 4,
                        y: configuration.isPressed ? 0.5 : 2.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
    }
}

// MARK: - View

struct GomokuView: View {
    private let accountID: UUID?
    private let playMode: GamePlayMode
    private let isOnline: Bool
    @ObservedObject private var online: OnlineMatchSession
    @StateObject private var persistence = PersistedGameSession<GomokuSnapshot>(gameID: .gomoku)
    @AppStorage("gomoku.aiELO") private var aiELO: Double = 1200
    @AppStorage("gomoku.skin") private var skinRaw: String = GomokuSkin.kaya.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var game = GomokuGame()
    @State private var moveTick = 0
    @State private var isBotThinking = false
    @State private var appliedMoveCount = -1
    @State private var lastMove: GomokuPoint?
    @State private var pressedCell: GomokuPoint?
    @State private var thinkPulse: Double = 1

    private var skin: GomokuSkin { GomokuSkin(rawValue: skinRaw) ?? .kaya }
    private var theme: GomokuTheme { GomokuTheme.theme(for: skin) }

    init(accountID: UUID? = nil, playMode: GamePlayMode = .localTwoPlayer, online: OnlineMatchSession? = nil) {
        self.accountID = accountID
        self.playMode = playMode
        self.isOnline = online != nil
        self._online = ObservedObject(wrappedValue: online ?? OnlineMatchSession.inert)
    }

    private var mySide: GomokuPlayer { online.isHost ? .black : .white }
    private var botPlayer: GomokuPlayer { .white }
    private var usesBot: Bool { playMode == .soloBot && !isOnline }
    private var isBotTurn: Bool {
        usesBot && game.currentPlayer == botPlayer && !game.isGameOver
    }

    private var subtitle: String {
        if let winner = game.winner {
            if isOnline {
                let opponent = online.opponentName ?? "Friend"
                return winner == mySide ? "You win!" : "\(opponent) wins"
            }
            return "\(name(winner)) wins"
        }
        if game.isDraw { return "Draw" }
        if isOnline {
            let opponent = online.opponentName ?? "Friend"
            return game.currentPlayer == mySide ? "Your move" : "\(opponent)'s move"
        }
        if isBotThinking {
            return "\(name(botPlayer)) is thinking"
        }
        if usesBot {
            return game.currentPlayer == botPlayer ? "\(name(botPlayer)) AI to move" : "Your move"
        }
        return "\(name(game.currentPlayer)) to move"
    }

    private var canMoveNow: Bool {
        guard !game.isGameOver else { return false }
        guard !isBotTurn, !isBotThinking else { return false }
        guard isOnline else { return true }
        return game.currentPlayer == mySide && online.isMyTurn
    }

    private func name(_ player: GomokuPlayer) -> String {
        player == .black ? "Black" : "White"
    }

    var body: some View {
        VStack(spacing: 14) {
            GameHeader(
                title: "Gomoku",
                systemImage: "circle.grid.3x3.fill",
                accent: theme.accent
            ) {
                if isOnline {
                    StatBadge(label: "You", value: name(mySide), accent: theme.accent)
                    StatBadge(label: online.opponentName ?? "Friend", value: name(mySide.opponent), accent: theme.accent)
                } else {
                    StatBadge(label: "Mode", value: usesBot ? "Bot" : "Local", accent: theme.accent)
                    StatBadge(label: "Stones", value: "\(game.moveCount)", accent: theme.accent)
                }
            }

            turnPlaque

            board

            controls
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(theme.accent)
        .navigationTitle("Gomoku")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                skinMenu
            }
        }
        .gameFeedback(.pieceMove, trigger: moveTick)
        .gameFeedback(.win, trigger: game.isGameOver)
        .onAppear {
            if isOnline {
                applyRemoteIfNeeded()
            } else {
                persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
                scheduleBotMoveIfNeeded()
            }
        }
        .onChange(of: aiELO) { _, _ in scheduleBotMoveIfNeeded() }
        .onChange(of: online.match?.moveCount) { _, _ in applyRemoteIfNeeded() }
        .onChange(of: isBotThinking) { _, thinking in
            if thinking && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    thinkPulse = 0.35
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    thinkPulse = 1
                }
            }
        }
        .onDisappear {
            if !isOnline { save(forceCloud: true) }
        }
        .alert(
            "Connection hiccup",
            isPresented: Binding(
                get: { online.lastError != nil },
                set: { if !$0 { online.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(online.lastError ?? "")
        }
    }

    // MARK: - Turn plaque (rendered stone + status)

    private var plaqueStone: GomokuPlayer? {
        if let winner = game.winner { return winner }
        if game.isDraw { return nil }
        return game.currentPlayer
    }

    private var turnPlaque: some View {
        HStack(spacing: 8) {
            if let player = plaqueStone {
                miniStone(player, size: 16)
                    .opacity(isBotThinking ? thinkPulse : 1)
                    .accessibilityHidden(true)
            }
            Text(subtitle)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Kaleido.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Kaleido.panelHi.opacity(0.85))
                .overlay(Capsule().strokeBorder(Kaleido.hairline, lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subtitle)
    }

    private func miniStone(_ player: GomokuPlayer, size: CGFloat) -> some View {
        Circle()
            .fill(stoneGradient(player, radius: size / 2))
            .overlay(
                Circle().strokeBorder(
                    player == .black ? Color.white.opacity(0.16) : Color.black.opacity(0.18),
                    lineWidth: 0.8
                )
            )
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.25), radius: 1, y: 0.8)
    }

    // MARK: - Skin picker (compact affordance, never on the play surface)

    private var skinMenu: some View {
        Menu {
            Picker("Board", selection: $skinRaw) {
                ForEach(GomokuSkin.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }
        } label: {
            Image(systemName: "paintbrush")
        }
        .accessibilityLabel("Board style")
    }

    // MARK: - The Kaya Goban

    private static let grainBands: [(y: CGFloat, drift: CGFloat, bow: CGFloat)] = [
        (0.12, 0.014, -0.020),
        (0.27, -0.010, 0.016),
        (0.44, 0.018, -0.012),
        (0.58, -0.006, 0.022),
        (0.73, 0.012, -0.018),
        (0.88, -0.014, 0.010)
    ]

    private var board: some View {
        GeometryReader { geo in
            let n = GomokuGame.size
            let frameW: CGFloat = 13
            let side = max(1, min(geo.size.width, geo.size.height) - frameW * 2)
            let cell = side / CGFloat(n)

            ZStack {
                gobanFrame(outer: side + frameW * 2)
                playingField(side: side, cell: cell, n: n)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
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
                // Bevel: light catches the top edge, shadow settles at the bottom.
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
                // Thin lacquer rule between frame and field.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.frameRule, lineWidth: 1)
                    .padding(9)
            )
            .frame(width: outer, height: outer)
    }

    private func playingField(side: CGFloat, cell: CGFloat, n: Int) -> some View {
        ZStack(alignment: .topLeading) {
            fieldWood(side: side)
            gridLines(side: side, cell: cell, n: n)
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
        .frame(width: side, height: side)
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

            // Traditional heavier border line around the outermost grid square.
            Rectangle()
                .strokeBorder(theme.line, lineWidth: 1.6)
                .frame(width: side - cell, height: side - cell)
                .offset(x: inset, y: inset)
        }
        .frame(width: side, height: side, alignment: .topLeading)
    }

    private func hoshiPoints(cell: CGFloat) -> some View {
        let spots: [(Int, Int)] = [(3, 3), (3, 11), (7, 7), (11, 3), (11, 11)]
        let dot = max(4, cell * 0.20)
        return ForEach(0..<spots.count, id: \.self) { i in
            Circle()
                .fill(theme.hoshi)
                .frame(width: dot, height: dot)
                .position(
                    x: cell * (CGFloat(spots[i].1) + 0.5),
                    y: cell * (CGFloat(spots[i].0) + 0.5)
                )
        }
    }

    // MARK: - Stones

    private func stoneGradient(_ player: GomokuPlayer, radius: CGFloat) -> RadialGradient {
        if player == .black {
            // Slate: cool top-left specular sliding into near-black.
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
        // Clamshell: faint warm radial falloff.
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
        ZStack {
            if let stone = game.stone(row: row, col: col) {
                stoneBody(stone, cell: cell, isLastMove: lastMove == here)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 1.15).combined(with: .opacity)
                    )
            } else if canMoveNow && pressedCell == here {
                // Ghost stone preview under the finger.
                Circle()
                    .fill(stoneGradient(game.currentPlayer, radius: cell * 0.5))
                    .opacity(0.45)
                    .padding(cell * 0.13)
            }
        }
        .frame(width: cell, height: cell)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if pressedCell != here { pressedCell = here }
                }
                .onEnded { value in
                    pressedCell = nil
                    guard abs(value.translation.width) < cell,
                          abs(value.translation.height) < cell else { return }
                    play(row: row, col: col)
                }
        )
        .allowsHitTesting(canMoveNow)
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
        .shadow(color: .black.opacity(0.32), radius: max(1.5, cell * 0.07), y: max(1, cell * 0.05))
        .padding(cell * 0.13)
    }

    // MARK: - Controls (wood-and-ink chips)

    private var controls: some View {
        Group {
            if isOnline {
                if online.phase == .finished || game.isGameOver {
                    onlineResultPlaque
                } else {
                    Button("Resign") {
                        Task { await online.resign() }
                    }
                    .buttonStyle(GomokuChipStyle(theme: theme, ink: Color(red: 0.94, green: 0.78, blue: 0.70)))
                    .accessibilityLabel("Resign game")
                }
            } else {
                localControls
            }
        }
        .frame(maxWidth: 620)
    }

    private var onlineResultPlaque: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                if let winner = game.winner {
                    miniStone(winner, size: 16)
                        .accessibilityHidden(true)
                }
                Text(subtitle)
                    .font(Kaleido.title(18))
                    .foregroundStyle(Kaleido.ink)
            }
            Text("Head back for a rematch — host a fresh code.")
                .font(.footnote)
                .foregroundStyle(Kaleido.ink3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Kaleido.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Kaleido.hairline, lineWidth: 1)
                )
        )
    }

    private var localControls: some View {
        VStack(spacing: 12) {
            if usesBot {
                opponentCard
            }

            Button("New Game") {
                resetGame()
            }
            .buttonStyle(GomokuChipStyle(theme: theme))
            .accessibilityLabel("New game")
        }
    }

    private var opponentCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("OPPONENT")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Kaleido.ink3)
                Spacer()
                Text("ELO \(Int(aiELO))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Kaleido.ink2)
            }
            Text(tierName(forELO: Int(aiELO)))
                .font(Kaleido.title(20))
                .foregroundStyle(Kaleido.ink)
            Slider(value: $aiELO, in: 600...2400, step: 100) {
                Text("AI strength")
            }
            .tint(theme.accent)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Kaleido.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Kaleido.hairline, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI difficulty")
        .accessibilityValue("ELO \(Int(aiELO)), \(tierName(forELO: Int(aiELO)))")
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

    // MARK: - Game flow (preserved wiring)

    private func play(row: Int, col: Int) {
        guard canMoveNow else { return }
        var didPlace = false
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
            didPlace = game.placeStone(row: row, col: col)
        }
        guard didPlace else { return }
        lastMove = GomokuPoint(row: row, col: col)
        moveTick += 1
        if isOnline {
            sendMyMove()
        } else {
            save(forceCloud: game.isGameOver)
            scheduleBotMoveIfNeeded()
        }
    }

    private func sendMyMove() {
        guard let stateJSON = try? GameSaveCodec.encodeSnapshot(GomokuSnapshot(game: game)) else { return }
        appliedMoveCount = (online.match?.moveCount ?? appliedMoveCount) + 1
        let finished = game.isGameOver
        let winnerIsMe: Bool? = game.winner.map { $0 == mySide }
        let nextTurnIsMine = game.currentPlayer == mySide
        Task {
            await online.sendMove(
                stateJSON: stateJSON,
                nextTurnIsMine: nextTurnIsMine,
                finished: finished,
                winnerIsMe: winnerIsMe
            )
        }
    }

    private func applyRemoteIfNeeded() {
        guard isOnline, let match = online.match, match.moveCount > appliedMoveCount else { return }
        guard let snapshot = try? GameSaveCodec.decodeSnapshot(GomokuSnapshot.self, from: match.stateJSON) else { return }
        let previous = game
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
            game = snapshot.game
        }
        lastMove = Self.newestStone(from: previous, to: snapshot.game)
        appliedMoveCount = match.moveCount
        moveTick += 1
    }

    /// Finds the single newly placed stone between two board states, if exactly one was added.
    private static func newestStone(from old: GomokuGame, to new: GomokuGame) -> GomokuPoint? {
        guard new.moveCount == old.moveCount + 1 else { return nil }
        for row in 0..<GomokuGame.size {
            for col in 0..<GomokuGame.size where old.stone(row: row, col: col) == nil {
                if new.stone(row: row, col: col) != nil {
                    return GomokuPoint(row: row, col: col)
                }
            }
        }
        return nil
    }

    private func snapshot() -> GomokuSnapshot {
        GomokuSnapshot(game: game)
    }

    private func restore(_ snapshot: GomokuSnapshot) {
        game = snapshot.game
        lastMove = nil
        isBotThinking = false
        scheduleBotMoveIfNeeded()
    }

    private func save(forceCloud: Bool = false) {
        guard !isOnline else { return }
        persistence.save(snapshot: snapshot(), score: game.moveCount, forceCloud: forceCloud)
    }

    private func resetGame() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
            game.reset()
            isBotThinking = false
        }
        lastMove = nil
        moveTick += 1
        save(forceCloud: true)
        scheduleBotMoveIfNeeded()
    }

    private func scheduleBotMoveIfNeeded() {
        guard isBotTurn, !isBotThinking else { return }
        isBotThinking = true
        let snapshot = game
        let elo = Int(aiELO)
        let bot = botPlayer
        Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            let move = await Task.detached(priority: .userInitiated) {
                GomokuAI(player: bot, targetELO: elo).move(in: snapshot)
            }.value
            await MainActor.run {
                applyBotMove(move, expectedGame: snapshot, bot: bot)
            }
        }
    }

    @MainActor
    private func applyBotMove(_ move: GomokuPoint?, expectedGame: GomokuGame, bot: GomokuPlayer) {
        guard usesBot, game == expectedGame, game.currentPlayer == bot, !game.isGameOver else {
            isBotThinking = false
            return
        }
        guard let move else {
            isBotThinking = false
            save(forceCloud: true)
            return
        }

        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
            _ = game.placeStone(row: move.row, col: move.col)
        }
        lastMove = move
        moveTick += 1
        isBotThinking = false
        save(forceCloud: game.isGameOver)
    }
}

#Preview {
    NavigationStack {
        GomokuView()
    }
}
