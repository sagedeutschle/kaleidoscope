import SwiftUI

// MARK: - Theme ("The Tabletop Toy")

/// Game-local material palette for the physical Connect Four toy: a translucent
/// glossy blue plastic rack standing in a warm wooden tray, with punched holes
/// that show the table through empty slots and chunky glossy discs. Kept local
/// on purpose — these are toy materials, not shared design tokens. Disc colors
/// track the app's Connect Four tile icon (red vs gold, ink-outlined).
private struct ConnectFourTheme {
    // Wooden tray the rack stands in.
    let trayWood = Color(red: 0.42, green: 0.28, blue: 0.16)
    let trayWoodDark = Color(red: 0.28, green: 0.175, blue: 0.095)
    let trayEdge = Color(red: 0.185, green: 0.115, blue: 0.06)

    // Translucent blue plastic rack (the signature). Two tones give it the
    // moulded-plastic gradient; the rim highlights read as a glossy bevel.
    let rackTop = Color(red: 0.22, green: 0.47, blue: 0.86)
    let rackBottom = Color(red: 0.105, green: 0.30, blue: 0.66)
    let rackRimLight = Color.white.opacity(0.55)
    let rackRimDark = Color(red: 0.07, green: 0.235, blue: 0.55)
    let rackHoleWall = Color(red: 0.065, green: 0.185, blue: 0.42)

    // Discs — glossy red vs glossy gold/yellow, ink-outlined to match the icon.
    let redFace = Color(red: 0.84, green: 0.23, blue: 0.18)
    let redDeep = Color(red: 0.60, green: 0.12, blue: 0.09)
    let redInk = Color(red: 0.09, green: 0.08, blue: 0.18)

    let goldFace = Color(red: 0.96, green: 0.78, blue: 0.24)
    let goldDeep = Color(red: 0.74, green: 0.55, blue: 0.11)
    let goldInk = Color(red: 0.09, green: 0.08, blue: 0.18)

    // Header accent — warm gold, carried over from the original so header badges
    // and the difficulty slider keep their hue.
    let accent = Color(red: 0.85, green: 0.55, blue: 0.20)

    func face(for player: ConnectFourPlayer) -> Color { player == .red ? redFace : goldFace }
    func deep(for player: ConnectFourPlayer) -> Color { player == .red ? redDeep : goldDeep }
    func ink(for player: ConnectFourPlayer) -> Color { player == .red ? redInk : goldInk }
}

struct ConnectFourView: View {
    private let accountID: UUID?
    private let playMode: GamePlayMode
    private let isOnline: Bool
    @ObservedObject private var online: OnlineMatchSession
    @StateObject private var persistence = PersistedGameSession<ConnectFourSnapshot>(gameID: .connectFour)
    @AppStorage("connectfour.aiELO") private var aiELO: Double = 1200
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var game = ConnectFourGame()
    @State private var moveTick = 0
    @State private var isBotThinking = false
    @State private var appliedMoveCount = -1
    /// Column the last disc fell into — drives the drop animation.
    @State private var dropColumn: Int?
    @State private var dropTick = 0

    private let theme = ConnectFourTheme()
    private var accent: Color { theme.accent }

    init(accountID: UUID? = nil, playMode: GamePlayMode = .soloBot, online: OnlineMatchSession? = nil) {
        self.accountID = accountID
        self.playMode = playMode
        self.isOnline = online != nil
        self._online = ObservedObject(wrappedValue: online ?? OnlineMatchSession.inert)
    }

    /// Host drops first, so host is red.
    private var mySide: ConnectFourPlayer { online.isHost ? .red : .yellow }
    private var botPlayer: ConnectFourPlayer { .yellow }
    private var usesBot: Bool { playMode == .soloBot && !isOnline }
    private var isBotTurn: Bool {
        usesBot && game.currentPlayer == botPlayer && !game.isGameOver
    }

    private var subtitle: String {
        if isOnline { return onlineSubtitle }
        if let winner = game.winner {
            return winner == .red ? "Red wins!" : "Yellow wins!"
        }
        if game.isDraw {
            return "Draw"
        }
        if isBotThinking {
            return "\(name(botPlayer)) is thinking"
        }
        if usesBot {
            return game.currentPlayer == botPlayer ? "\(name(botPlayer)) AI to move" : "Your move"
        }
        return game.currentPlayer == .red ? "Red's move" : "Yellow's move"
    }

    private var onlineSubtitle: String {
        let opponent = online.opponentName ?? "Friend"
        if let winner = game.winner {
            return winner == mySide ? "You win!" : "\(opponent) wins!"
        }
        if game.isDraw { return "Draw" }
        if online.phase == .finished {
            switch online.iWon {
            case .some(true): return "You win!"
            case .some(false): return "\(opponent) wins!"
            case .none: return "Draw"
            }
        }
        return game.currentPlayer == mySide ? "Your move" : "\(opponent)'s move"
    }

    private func color(for player: ConnectFourPlayer) -> Color {
        theme.face(for: player)
    }

    private func name(_ player: ConnectFourPlayer) -> String {
        player == .red ? "Red" : "Yellow"
    }

    private var turnAccent: Color {
        if let winner = game.winner {
            return color(for: winner)
        }
        if game.isDraw {
            return Kaleido.ink2
        }
        return color(for: game.currentPlayer)
    }

    private var canMoveNow: Bool {
        guard !game.isGameOver else { return false }
        guard !isBotTurn, !isBotThinking else { return false }
        guard isOnline else { return true }
        return game.currentPlayer == mySide && online.isMyTurn
    }

    private func drop(in column: Int) {
        guard canMoveNow, game.legalColumns.contains(column) else { return }
        markDrop(column: column)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            _ = game.dropToken(in: column)
        }
        moveTick += 1
        if isOnline {
            sendMyMove()
        } else {
            save(forceCloud: game.isGameOver)
            scheduleBotMoveIfNeeded()
        }
    }

    private func sendMyMove() {
        guard let stateJSON = try? GameSaveCodec.encodeSnapshot(ConnectFourSnapshot(game: game)) else { return }
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
        guard let snapshot = try? GameSaveCodec.decodeSnapshot(ConnectFourSnapshot.self, from: match.stateJSON) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            game = snapshot.game
        }
        appliedMoveCount = match.moveCount
        moveTick += 1
    }

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(
                title: "Connect Four",
                systemImage: "circle.grid.3x3.fill",
                accent: accent,
                subtitle: subtitle
            ) {
                if isOnline {
                    StatBadge(
                        label: "You",
                        value: mySide == .red ? "Red" : "Yellow",
                        accent: color(for: mySide)
                    )
                    StatBadge(
                        label: online.opponentName ?? "Friend",
                        value: mySide == .red ? "Yellow" : "Red",
                        accent: color(for: mySide == .red ? .yellow : .red)
                    )
                } else {
                    StatBadge(
                        label: "Mode",
                        value: usesBot ? "Bot" : "Local",
                        accent: accent
                    )
                    StatBadge(
                        label: "Turn",
                        value: game.isGameOver ? "Over" : name(game.currentPlayer),
                        accent: turnAccent
                    )
                }
            }

            board

            if isOnline {
                onlineControls
            } else {
                localControls
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .navigationTitle("Connect Four")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: moveTick)
        .sensoryFeedback(.success, trigger: game.isGameOver)
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

    private var localControls: some View {
        VStack(spacing: 12) {
            if usesBot {
                difficultyControl
            }

            Button {
                resetGame()
            } label: {
                Label("New Game", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle(accent: accent))
        }
    }

    private var difficultyControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Difficulty", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Kaleido.ink2)
                Spacer()
                Text("ELO \(Int(aiELO)) · \(tierName(forELO: Int(aiELO)))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .monospacedDigit()
            }
            Slider(value: $aiELO, in: 600...2400, step: 100) {
                Text("AI strength")
            } minimumValueLabel: {
                Text("600").font(.caption2).foregroundStyle(Kaleido.ink3)
            } maximumValueLabel: {
                Text("2400").font(.caption2).foregroundStyle(Kaleido.ink3)
            }
            .tint(accent)
        }
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

    private var onlineControls: some View {
        Group {
            if online.phase == .finished || game.isGameOver {
                Text("Head back for a rematch — host a fresh code.")
                    .font(.caption)
                    .foregroundStyle(Kaleido.ink3)
            } else {
                Button(role: .destructive) {
                    Task { await online.resign() }
                } label: {
                    Label("Resign", systemImage: "flag.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(accent: Kaleido.ink))
            }
        }
    }

    private var board: some View {
        GeometryReader { geo in
            let columns = ConnectFourGame.columnCount
            let rows = ConnectFourGame.rowCount
            // The rack is taller than it is wide (6 rows over 7 columns) and
            // stands in a wooden lip along the bottom, so the toy fills the
            // available box while keeping square holes.
            let maxCellW = geo.size.width / CGFloat(columns)
            let maxCellH = geo.size.height / (CGFloat(rows) + 1.15)
            let cell = max(1, min(maxCellW, maxCellH))
            let gridWidth = cell * CGFloat(columns)
            let gridHeight = cell * CGFloat(rows)
            let rackPad = cell * 0.16          // plastic border around the holes
            let rackW = gridWidth + rackPad * 2
            let trayLip = cell * 0.34          // wooden foot the rack sits in
            let rackH = gridHeight + rackPad * 2

            ZStack {
                // Wooden tray/foot the rack stands in.
                RoundedRectangle(cornerRadius: cell * 0.34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.trayWood, theme.trayWoodDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cell * 0.34, style: .continuous)
                            .strokeBorder(theme.trayEdge, lineWidth: max(1, cell * 0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cell * 0.34, style: .continuous)
                            .inset(by: max(1, cell * 0.05))
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .frame(width: rackW + cell * 0.28, height: rackH + trayLip + cell * 0.14)
                    .offset(y: (trayLip - cell * 0.14) / 2)
                    .shadow(color: Color.black.opacity(0.34), radius: cell * 0.22, y: cell * 0.14)

                // The signature: the translucent glossy blue plastic rack, with
                // punched holes that reveal the tray behind empty slots.
                rackFace(cell: cell)
                    .frame(width: rackW, height: rackH)
                    .clipShape(RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous))
                    .overlay(
                        // Glossy bevel: bright top-left edge, dark bottom-right.
                        RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [theme.rackRimLight, theme.rackRimDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: max(1.2, cell * 0.05)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: cell * 0.08, y: cell * 0.04)

                // Column tap targets, spanning the full height so a tap anywhere
                // in a column drops there.
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { column in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: cell, height: gridHeight)
                            .onTapGesture {
                                drop(in: column)
                            }
                            .allowsHitTesting(canMoveNow && game.legalColumns.contains(column))
                            .accessibilityLabel("Column \(column + 1)")
                            .accessibilityHint(game.legalColumns.contains(column) ? "Drop disc" : "Column full")
                    }
                }
                .frame(width: gridWidth, height: gridHeight)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(7.0 / 7.15, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    /// The blue plastic face. Rendered as a translucent moulded panel, then the
    /// grid of holes is punched out (each hole shows the tray-brown wall and the
    /// disc that has settled in it).
    private func rackFace(cell: CGFloat) -> some View {
        let rows = ConnectFourGame.rowCount
        let columns = ConnectFourGame.columnCount
        return ZStack {
            // Moulded plastic body with a top-lit gradient.
            LinearGradient(
                colors: [theme.rackTop, theme.rackBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            // Broad specular streak so the plastic reads glossy.
            LinearGradient(
                colors: [Color.white.opacity(0.22), .clear, Color.white.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)

            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<columns, id: \.self) { column in
                            hole(row: row, column: column, cell: cell)
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .padding(cell * 0.16)
        }
    }

    /// A single punched hole. Empty holes are see-through (tray-brown wall with
    /// a recessed shadow); filled holes carry a glossy disc that drops in.
    @ViewBuilder
    private func hole(row: Int, column: Int, cell: CGFloat) -> some View {
        let holeInset = cell * 0.13
        let token = game.token(row: row, column: column)
        // Newest disc in the just-dropped column animates its fall from above.
        let isNewest = token != nil && column == dropColumn && row == topFilledRow(in: column)

        ZStack {
            // The see-through hole: tray colour behind, with an inner-wall
            // shadow so it reads as a punched-out cylinder.
            Circle()
                .fill(theme.trayWoodDark)
                .overlay(
                    Circle().fill(
                        RadialGradient(
                            colors: [Color.black.opacity(0.42), Color.black.opacity(0.10), .clear],
                            center: .center,
                            startRadius: cell * 0.10,
                            endRadius: cell * 0.42
                        )
                    )
                )
                .overlay(
                    Circle().strokeBorder(theme.rackHoleWall, lineWidth: max(1, cell * 0.045))
                )
                .padding(holeInset)

            if let token {
                ConnectFourDisc(
                    face: theme.face(for: token),
                    deep: theme.deep(for: token),
                    ink: theme.ink(for: token),
                    diameter: cell - holeInset * 2
                )
                .padding(holeInset)
                .modifier(
                    DropFall(
                        active: isNewest,
                        rowsAbove: row + 1,
                        cell: cell,
                        reduceMotion: reduceMotion,
                        tick: dropTick
                    )
                )
                .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
            }
        }
    }

    /// Row index of the highest occupied cell in a column (the disc that just
    /// landed sits here), or nil if the column is empty.
    private func topFilledRow(in column: Int) -> Int? {
        (0..<ConnectFourGame.rowCount).first { game.token(row: $0, column: column) != nil }
    }

    private func snapshot() -> ConnectFourSnapshot {
        ConnectFourSnapshot(game: game)
    }

    private func restore(_ snapshot: ConnectFourSnapshot) {
        game = snapshot.game
        isBotThinking = false
        scheduleBotMoveIfNeeded()
    }

    private func save(forceCloud: Bool = false) {
        guard !isOnline else { return }
        persistence.save(snapshot: snapshot(), score: game.moveCount, forceCloud: forceCloud)
    }

    private func resetGame() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            game.reset()
            isBotThinking = false
        }
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
            let column = await Task.detached(priority: .userInitiated) {
                ConnectFourAI(player: bot, targetELO: elo).move(in: snapshot)
            }.value
            await MainActor.run {
                applyBotMove(column, expectedGame: snapshot, bot: bot)
            }
        }
    }

    @MainActor
    private func applyBotMove(_ column: Int?, expectedGame: ConnectFourGame, bot: ConnectFourPlayer) {
        guard usesBot, game == expectedGame, game.currentPlayer == bot, !game.isGameOver else {
            isBotThinking = false
            return
        }
        guard let column else {
            isBotThinking = false
            save(forceCloud: true)
            return
        }

        markDrop(column: column)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            _ = game.dropToken(in: column)
        }
        moveTick += 1
        isBotThinking = false
        save(forceCloud: game.isGameOver)
    }

    /// Record which column just took a disc so the newest token animates its
    /// fall. A short async reset lets the same column drop again next turn.
    private func markDrop(column: Int) {
        dropColumn = column
        dropTick += 1
        let tick = dropTick
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            if dropTick == tick { dropColumn = nil }
        }
    }
}

// MARK: - The disc (the signature piece)

/// A chunky glossy Connect Four disc: a thick coloured token with a peeking
/// edge of thickness, an ink outline (matching the app's tile icon), a recessed
/// concentric ring like the moulded plastic play pieces, and a bright specular
/// glint up top. Sized to the hole it settles into.
private struct ConnectFourDisc: View {
    let face: Color
    let deep: Color
    let ink: Color
    let diameter: CGFloat

    var body: some View {
        ZStack {
            // Disc thickness peeking below the face.
            Circle()
                .fill(deep)
                .offset(y: diameter * 0.05)

            // Glossy coloured face with a top-lit sheen.
            Circle()
                .fill(face)
                .overlay(
                    Circle().fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.30), .clear, deep.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )

            // Recessed moulded ring, like the real toy discs.
            Circle()
                .strokeBorder(deep.opacity(0.75), lineWidth: max(1, diameter * 0.055))
                .padding(diameter * 0.20)

            // Ink outline to match the tile icon.
            Circle()
                .strokeBorder(ink.opacity(0.9), lineWidth: max(1, diameter * 0.05))

            // Bright specular glint (the glossy plastic highlight).
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.55), .clear],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 0,
                        endRadius: diameter * 0.42
                    )
                )
                .padding(diameter * 0.06)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: Color.black.opacity(0.30), radius: diameter * 0.05, y: diameter * 0.03)
        .accessibilityHidden(true)
    }
}

// MARK: - Drop animation

/// Slides a freshly-dropped disc down from above the rack into its resting hole.
/// The offset starts high (proportional to how many rows the disc fell through)
/// and settles with a springy bounce; a change of `tick` re-triggers it. When
/// Reduce Motion is on, the disc simply appears in place.
private struct DropFall: ViewModifier {
    let active: Bool
    let rowsAbove: Int
    let cell: CGFloat
    let reduceMotion: Bool
    let tick: Int

    @State private var settled = false

    func body(content: Content) -> some View {
        content
            .offset(y: yOffset)
            .onAppear { settle() }
            .onChange(of: tick) { _, _ in
                if active { settled = false; settle() }
            }
    }

    private var yOffset: CGFloat {
        guard active, !reduceMotion, !settled else { return 0 }
        // Start above the rack: clear the disc's own hole plus every row over it.
        return -cell * CGFloat(rowsAbove + 1)
    }

    private func settle() {
        guard active, !reduceMotion else { settled = true; return }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
                settled = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConnectFourView()
    }
}
