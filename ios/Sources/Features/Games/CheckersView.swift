// PRISM: RELEASE Agent-Design(checkers) 2026-07-03 - v10 design pass
import SwiftUI

// MARK: - Skins & Theme ("The Club Board")

enum CheckersSkin: String, CaseIterable, Identifiable {
    case classic = "Classic Red & Black"
    case clubWalnut = "Club Walnut"
    case tournament = "Tournament Green"
    var id: String { rawValue }
}

/// Game-local material palette. The classic red-and-black board ships by
/// default; the walnut and green-tournament skins are optional swaps.
private struct CheckersTheme {
    var accent: Color
    var lightSquare: Color
    var darkSquare: Color
    var frame: Color
    var frameEdge: Color
    var darkBase: Color, darkRim: Color, darkGroove: Color
    var lightBase: Color, lightRim: Color, lightGroove: Color

    /// Classic American set: bright red squares with deep charcoal playing
    /// squares, glossy vermilion discs vs ebony discs. Charcoal (not pure
    /// black) so the ebony discs keep an edge; graphite grooves catch light.
    static let classic = CheckersTheme(
        accent: Color(red: 0.80, green: 0.18, blue: 0.14),
        lightSquare: Color(red: 0.72, green: 0.22, blue: 0.17),
        darkSquare: Color(red: 0.205, green: 0.185, blue: 0.185),
        frame: Color(red: 0.115, green: 0.10, blue: 0.10),
        frameEdge: Color(red: 0.05, green: 0.044, blue: 0.044),
        darkBase: Color(red: 0.135, green: 0.125, blue: 0.13),
        darkRim: Color(red: 0.035, green: 0.03, blue: 0.035),
        darkGroove: Color(red: 0.44, green: 0.43, blue: 0.44),
        lightBase: Color(red: 0.80, green: 0.16, blue: 0.13),
        lightRim: Color(red: 0.46, green: 0.075, blue: 0.06),
        lightGroove: Color(red: 0.96, green: 0.47, blue: 0.39)
    )

    static let clubWalnut = CheckersTheme(
        accent: Color(red: 0.70, green: 0.30, blue: 0.25),
        lightSquare: Color(red: 0.89, green: 0.83, blue: 0.70),
        darkSquare: Color(red: 0.33, green: 0.23, blue: 0.155),
        frame: Color(red: 0.29, green: 0.19, blue: 0.12),
        frameEdge: Color(red: 0.19, green: 0.125, blue: 0.08),
        darkBase: Color(red: 0.145, green: 0.115, blue: 0.10),
        darkRim: Color(red: 0.06, green: 0.05, blue: 0.045),
        darkGroove: Color(red: 0.38, green: 0.32, blue: 0.27),
        lightBase: Color(red: 0.91, green: 0.86, blue: 0.74),
        lightRim: Color(red: 0.66, green: 0.58, blue: 0.44),
        lightGroove: Color(red: 0.60, green: 0.52, blue: 0.38)
    )

    static let tournament = CheckersTheme(
        accent: Color(red: 0.72, green: 0.18, blue: 0.15),
        lightSquare: Color(red: 0.88, green: 0.85, blue: 0.74),
        darkSquare: Color(red: 0.16, green: 0.32, blue: 0.22),
        frame: Color(red: 0.14, green: 0.13, blue: 0.12),
        frameEdge: Color(red: 0.07, green: 0.065, blue: 0.06),
        darkBase: Color(red: 0.12, green: 0.115, blue: 0.125),
        darkRim: Color(red: 0.03, green: 0.03, blue: 0.035),
        darkGroove: Color(red: 0.37, green: 0.36, blue: 0.37),
        lightBase: Color(red: 0.62, green: 0.16, blue: 0.14),
        lightRim: Color(red: 0.38, green: 0.085, blue: 0.075),
        lightGroove: Color(red: 0.85, green: 0.46, blue: 0.39)
    )

    static func theme(for skin: CheckersSkin) -> CheckersTheme {
        switch skin {
        case .classic: return .classic
        case .clubWalnut: return .clubWalnut
        case .tournament: return .tournament
        }
    }
}

// MARK: - View

struct CheckersView: View {
    private let accountID: UUID?
    private let launchPlayMode: GamePlayMode
    private let isOnline: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var online: OnlineMatchSession
    @StateObject private var persistence = PersistedGameSession<CheckersSnapshot>(gameID: .checkers)
    @AppStorage("checkers.playAgainstAI") private var playAgainstAI = true
    @AppStorage("checkers.aiELO") private var aiELO: Double = 1200
    @AppStorage("checkers.skin") private var skinRaw = CheckersSkin.classic.rawValue
    @State private var game = CheckersGame()
    @State private var selected: CheckersPoint?
    @State private var moveTick = 0
    @State private var isAIThinking = false
    @State private var undoStack: [CheckersGame] = []
    @State private var didSubmitResult = false
    @State private var showingResult = false
    @State private var showingLeaderboard = false
    @State private var appliedMoveCount = -1

    init(accountID: UUID? = nil, playMode: GamePlayMode = .soloBot, online: OnlineMatchSession? = nil) {
        self.accountID = accountID
        self.launchPlayMode = playMode
        self.isOnline = online != nil
        self._online = ObservedObject(wrappedValue: online ?? OnlineMatchSession.inert)
    }

    private var theme: CheckersTheme {
        CheckersTheme.theme(for: CheckersSkin(rawValue: skinRaw) ?? .classic)
    }

    /// Host plays dark (dark moves first).
    private var mySide: CheckersPlayer { online.isHost ? .dark : .light }

    private var destinations: [CheckersMove] {
        guard !isAITurn, let sel = selected else { return [] }
        if isOnline && !canMoveNow { return [] }
        return game.legalMoves().filter { $0.from.row == sel.row && $0.from.col == sel.col }
    }

    private var aiPlayer: CheckersPlayer { .light }

    private var usesAI: Bool { playAgainstAI && !isOnline }

    private var isAITurn: Bool {
        usesAI && game.currentPlayer == aiPlayer && !game.isGameOver
    }

    private var canMoveNow: Bool {
        guard !game.isGameOver else { return false }
        guard isOnline else { return true }
        return game.currentPlayer == mySide && online.isMyTurn
    }

    private var subtitleText: String {
        if isOnline { return onlineSubtitle }
        if game.isGameOver {
            if let w = game.winner {
                return w == .dark ? "Black wins" : "Red wins"
            }
            return "Game over"
        }
        if isAIThinking {
            return "Red is thinking"
        }
        if usesAI {
            return game.currentPlayer == .dark ? "Your move" : "Red AI to move"
        }
        return game.currentPlayer == .dark ? "Black to move" : "Red to move"
    }

    private var onlineSubtitle: String {
        let opponent = online.opponentName ?? "Friend"
        if let w = game.winner {
            return w == mySide ? "You win!" : "\(opponent) wins!"
        }
        if online.phase == .finished {
            switch online.iWon {
            case .some(true): return "You win!"
            case .some(false): return "\(opponent) wins!"
            case .none: return "Game over"
            }
        }
        if game.currentPlayer == mySide {
            return game.activeJumpOrigin != nil ? "Keep jumping!" : "Your move"
        }
        return "\(opponent)'s move"
    }

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(
                title: "Checkers",
                systemImage: "crown.fill",
                accent: theme.accent,
                subtitle: subtitleText
            ) {
                if isOnline {
                    StatBadge(label: "You", value: mySide == .dark ? "Black" : "Red", accent: mySide == .dark ? Kaleido.ink : theme.accent)
                    StatBadge(
                        label: online.opponentName ?? "Friend",
                        value: mySide == .dark ? "Red" : "Black",
                        accent: mySide == .dark ? theme.accent : Kaleido.ink
                    )
                } else {
                    capturedTray(label: "Black", victim: .light)
                    capturedTray(label: "Red", victim: .dark)
                }
            }

            board

            controls
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(theme.accent)
        .navigationTitle("Checkers")
        .navigationBarTitleDisplayMode(.inline)
        .gameFeedback(.pieceMove, trigger: moveTick)
        .gameFeedback(.win, trigger: game.isGameOver)
        .onAppear {
            if isOnline {
                applyRemoteIfNeeded()
            } else {
                applyLaunchPlayMode()
                persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
                scheduleAIMoveIfNeeded()
            }
        }
        .onChange(of: playAgainstAI) { _, _ in
            guard !isOnline else { return }
            selected = nil
            save()
            scheduleAIMoveIfNeeded()
        }
        .onChange(of: aiELO) { _, _ in scheduleAIMoveIfNeeded() }
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
        .sheet(isPresented: $showingResult) {
            CheckersResultSheet(
                winner: game.winner,
                score: game.winner.flatMap { game.resultScore(for: $0) },
                theme: theme,
                onNewGame: {
                    showingResult = false
                    resetGame()
                },
                onLeaderboard: {
                    showingResult = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showingLeaderboard = true
                    }
                }
            )
        }
        .sheet(isPresented: $showingLeaderboard) {
            LeaderboardView(
                accountID: accountID,
                gcAccountID: LeaderboardCoordinator.shared.gcAccountID,
                initialSelection: .checkers
            )
        }
    }

    // MARK: - Captured-piece trays (header)

    /// Score told in the game's own vocabulary: the discs each side has taken,
    /// stacked and overlapping like a rail on a club table.
    private func capturedTray(label: String, victim: CheckersPlayer) -> some View {
        let captured = max(0, 12 - game.count(for: victim))
        return VStack(alignment: .trailing, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold)).tracking(0.7)
                .foregroundStyle(Kaleido.ink3)
            HStack(spacing: 5) {
                if captured == 0 {
                    Circle()
                        .strokeBorder(Kaleido.ink3.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2.5, 2.5]))
                        .frame(width: 18, height: 18)
                } else {
                    HStack(spacing: -11) {
                        ForEach(0..<min(captured, 6), id: \.self) { _ in
                            CheckersDisc(player: victim, isKing: false, size: 18, theme: theme)
                        }
                    }
                    Text("\(captured)")
                        .font(Kaleido.rounded(15, .bold)).monospacedDigit()
                        .foregroundStyle(Kaleido.ink2)
                }
            }
            .frame(height: 20)
        }
        .frame(minWidth: 60, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) captured \(captured) pieces")
    }

    // MARK: - Board

    private var board: some View {
        GeometryReader { geo in
            let n = CheckersGame.size
            let side = min(geo.size.width, geo.size.height)
            let frameW = max(8, side * 0.030)
            let inner = side - frameW * 2
            let cell = inner / CGFloat(n)
            let dests = destinations

            ZStack {
                // Wooden frame border around the playing field.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.frame, theme.frameEdge],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .inset(by: 1.5)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 14, y: 8)

                ZStack(alignment: .topLeading) {
                    ForEach(0..<n, id: \.self) { row in
                        ForEach(0..<n, id: \.self) { col in
                            cellView(row: row, col: col, cell: cell, dests: dests)
                                .frame(width: cell, height: cell)
                                .position(
                                    x: (CGFloat(col) + 0.5) * cell,
                                    y: (CGFloat(row) + 0.5) * cell
                                )
                        }
                    }
                }
                .frame(width: inner, height: inner)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.30), lineWidth: 1)
                )
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 620)
    }

    private var pieceTransition: AnyTransition {
        reduceMotion ? .opacity : AnyTransition.scale(scale: 0.7).combined(with: .opacity)
    }

    @ViewBuilder
    private func cellView(row: Int, col: Int, cell: CGFloat, dests: [CheckersMove]) -> some View {
        let playable = CheckersGame.isPlayable(row: row, col: col)
        let isSelected = selected.map { $0.row == row && $0.col == col } ?? false
        let dest = dests.first { $0.to.row == row && $0.to.col == col }

        ZStack {
            Rectangle()
                .fill(playable ? theme.darkSquare : theme.lightSquare)

            if playable {
                // Faint top shading so the playing squares read carved-in.
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.16), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }

            if isSelected {
                Rectangle()
                    .fill(Kaleido.gold.opacity(0.26))
                Rectangle()
                    .strokeBorder(Kaleido.gold.opacity(0.9), lineWidth: max(2, cell * 0.05))
            }

            if let piece = game.piece(row: row, col: col) {
                CheckersDisc(player: piece.player, isKing: piece.kind == .king, size: cell * 0.78, theme: theme)
                    .transition(pieceTransition)
            }

            if let dest {
                // Soft inset ring on legal destinations; captures get a double ring.
                Circle()
                    .strokeBorder(Kaleido.gold.opacity(0.85), lineWidth: max(1.5, cell * 0.045))
                    .frame(width: cell * 0.46, height: cell * 0.46)
                if dest.isCapture {
                    Circle()
                        .strokeBorder(Kaleido.gold.opacity(0.5), lineWidth: max(1, cell * 0.03))
                        .frame(width: cell * 0.68, height: cell * 0.68)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap(row: row, col: col, destination: dest)
        }
    }

    private func handleTap(row: Int, col: Int, destination: CheckersMove?) {
        guard !game.isGameOver, !isAITurn, !isAIThinking else { return }
        if isOnline { guard canMoveNow else { return } }

        // Tapping a highlighted destination commits the move.
        if let move = destination {
            let previous = game
            let shouldPushUndo = game.activeJumpOrigin == nil
            var applied = false
            withAnimation(.easeInOut(duration: 0.2)) {
                applied = game.applyMove(move)
            }
            guard applied else { return }
            if !isOnline, shouldPushUndo { pushUndo(previous) }
            moveTick += 1
            // legalMoves already enforces multi-jump continuation by restricting
            // to the landing square; reselect it so the same player keeps jumping.
            if !game.isGameOver,
               game.legalMoves().contains(where: { $0.from.row == move.to.row && $0.from.col == move.to.col }),
               game.legalMoves().allSatisfy({ $0.from.row == move.to.row && $0.from.col == move.to.col }) {
                selected = move.to
            } else {
                selected = nil
            }
            if isOnline {
                sendMyMove()
                return
            }
            submitResultIfNeeded()
            if game.isGameOver { showingResult = true }
            save(forceCloud: game.isGameOver)
            scheduleAIMoveIfNeeded()
            return
        }

        // Tapping one of the current player's own pieces selects it.
        if let piece = game.piece(row: row, col: col), piece.player == game.currentPlayer {
            let point = CheckersPoint(row: row, col: col)
            if let sel = selected, sel.row == row, sel.col == col {
                selected = nil
            } else {
                selected = point
            }
        } else {
            selected = nil
        }
        save()
    }

    /// Ship my move (or jump segment — mid multi-jump the turn stays mine).
    private func sendMyMove() {
        guard let stateJSON = try? GameSaveCodec.encodeSnapshot(CheckersSnapshot(game: game, selected: nil)) else { return }
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
        guard let snapshot = try? GameSaveCodec.decodeSnapshot(CheckersSnapshot.self, from: match.stateJSON) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            game = snapshot.game
            selected = nil
        }
        appliedMoveCount = match.moveCount
        moveTick += 1
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        Group {
            if isOnline {
                if online.phase == .finished || game.isGameOver {
                    Text("Head back for a rematch — host a fresh code.")
                        .font(.footnote)
                        .foregroundStyle(Kaleido.ink3)
                } else {
                    Button(role: .destructive) {
                        Task { await online.resign() }
                    } label: {
                        Label("Resign", systemImage: "flag.fill")
                    }
                    .buttonStyle(ClubChipStyle(theme: theme, kind: .destructive))
                    .accessibilityLabel("Resign game")
                }
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Button {
                            resetGame()
                        } label: {
                            Text("New Game")
                        }
                        .buttonStyle(ClubChipStyle(theme: theme, kind: .wood))

                        Button {
                            undo()
                        } label: {
                            Text("Undo")
                        }
                        .buttonStyle(ClubChipStyle(theme: theme, kind: .quiet))
                        .disabled(!canUndo)

                        Spacer(minLength: 0)

                        Menu {
                            Picker("Board style", selection: $skinRaw) {
                                ForEach(CheckersSkin.allCases) { skin in
                                    Text(skin.rawValue).tag(skin.rawValue)
                                }
                            }
                        } label: {
                            Image(systemName: "paintbrush")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Kaleido.ink2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Kaleido.panel)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(Kaleido.outline, lineWidth: 1)
                                        )
                                )
                        }
                        .accessibilityLabel("Board style")
                    }

                    opponentCard
                }
            }
        }
        .frame(maxWidth: 620)
    }

    private var opponentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("OPPONENT")
                    .font(.caption2.weight(.bold)).tracking(1.1)
                    .foregroundStyle(Kaleido.ink3)
                Spacer()
                HStack(spacing: 4) {
                    modeChip("vs AI", active: playAgainstAI) { playAgainstAI = true }
                    modeChip("2 Player", active: !playAgainstAI) { playAgainstAI = false }
                }
            }
            if playAgainstAI {
                difficultyControl
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Kaleido.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Kaleido.hairline, lineWidth: 1)
                )
        )
    }

    private func modeChip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? Color(red: 0.97, green: 0.93, blue: 0.85) : Kaleido.ink2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(active
                              ? AnyShapeStyle(LinearGradient(colors: [theme.frame, theme.frameEdge], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color.clear))
                        .overlay(
                            Capsule().strokeBorder(active ? Color.white.opacity(0.10) : Kaleido.outline, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    private var difficultyControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(tierName(forELO: Int(aiELO)))
                    .font(Kaleido.title(22))
                    .foregroundStyle(Kaleido.ink)
                Spacer()
                Text("ELO \(Int(aiELO))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
            }
            Slider(value: $aiELO, in: 600...2400, step: 100) {
                Text("AI strength")
            }
            .tint(theme.accent)
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

    private var canUndo: Bool {
        !undoStack.isEmpty && !isAIThinking && !game.isGameOver
    }

    private func scheduleAIMoveIfNeeded() {
        guard isAITurn, !isAIThinking else { return }
        isAIThinking = true
        Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            await MainActor.run { performAIMoveStep() }
        }
    }

    @MainActor
    private func performAIMoveStep() {
        guard isAITurn else {
            isAIThinking = false
            return
        }
        guard let move = CheckersAI(player: aiPlayer, targetELO: Int(aiELO)).move(in: game) else {
            selected = nil
            isAIThinking = false
            submitResultIfNeeded()
            if game.isGameOver { showingResult = true }
            save(forceCloud: true)
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            _ = game.applyMove(move)
        }
        moveTick += 1
        selected = game.activeJumpOrigin
        submitResultIfNeeded()
        if game.isGameOver { showingResult = true }
        save(forceCloud: game.isGameOver)

        if isAITurn {
            Task {
                try? await Task.sleep(nanoseconds: 260_000_000)
                await MainActor.run { performAIMoveStep() }
            }
        } else {
            selected = nil
            isAIThinking = false
        }
    }

    private func snapshot() -> CheckersSnapshot {
        CheckersSnapshot(
            game: game,
            selected: selected,
            undoStack: undoStack,
            didSubmitResult: didSubmitResult
        )
    }

    private func restore(_ snapshot: CheckersSnapshot) {
        game = snapshot.game
        selected = snapshot.selected
        undoStack = snapshot.undoStack
        didSubmitResult = snapshot.didSubmitResult
        showingResult = snapshot.game.isGameOver
        applyLaunchPlayMode()
        scheduleAIMoveIfNeeded()
    }

    private func applyLaunchPlayMode() {
        switch launchPlayMode {
        case .soloBot:
            playAgainstAI = true
        case .localTwoPlayer:
            playAgainstAI = false
            isAIThinking = false
        case .onlineFriend:
            break
        }
    }

    private func save(forceCloud: Bool = false) {
        guard !isOnline else { return }
        persistence.save(snapshot: snapshot(), score: game.count(for: .dark), forceCloud: forceCloud)
    }

    private func resetGame() {
        withAnimation(.easeInOut(duration: 0.25)) {
            game = CheckersGame()
            selected = nil
            isAIThinking = false
            undoStack = []
            didSubmitResult = false
            showingResult = false
        }
        save(forceCloud: true)
        scheduleAIMoveIfNeeded()
    }

    private func pushUndo(_ previous: CheckersGame) {
        undoStack.append(previous)
        if undoStack.count > 80 {
            undoStack.removeFirst(undoStack.count - 80)
        }
    }

    private func undo() {
        guard canUndo, let previous = undoStack.popLast() else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            game = previous
            selected = nil
            isAIThinking = false
            showingResult = false
        }
        save(forceCloud: true)
    }

    private func submitResultIfNeeded() {
        guard game.isGameOver,
              usesAI,
              game.winner == .dark,
              !didSubmitResult,
              let score = game.resultScore(for: .dark) else { return }
        LeaderboardCoordinator.shared.submit(.checkers, score: score)
        didSubmitResult = true
    }
}

// MARK: - The drafts piece (the signature)

/// A lacquered club-hall checker: stacked disc thickness, an outer rim,
/// concentric grooves with radial ticks, a sheen highlight, and an embossed
/// crown stamp for kings. Reused at cell size, 18pt tray size, and hero size
/// on the result sheet.
private struct CheckersDisc: View {
    let player: CheckersPlayer
    let isKing: Bool
    let size: CGFloat
    let theme: CheckersTheme

    var body: some View {
        let base = player == .dark ? theme.darkBase : theme.lightBase
        let rim = player == .dark ? theme.darkRim : theme.lightRim
        let groove = player == .dark ? theme.darkGroove : theme.lightGroove

        ZStack {
            // Disc thickness peeking out below the face.
            Circle()
                .fill(rim)
                .offset(y: size * 0.045)

            // Lacquered face.
            Circle()
                .fill(base)
                .overlay(
                    Circle().fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(player == .dark ? 0.14 : 0.28),
                                .clear,
                                Color.black.opacity(0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    Circle().strokeBorder(rim, lineWidth: max(1, size * 0.05))
                )

            // Radial groove ticks between rim and inner ring.
            if size >= 30 {
                ForEach(0..<12, id: \.self) { i in
                    Capsule()
                        .fill(groove)
                        .frame(width: max(1, size * 0.02), height: size * 0.085)
                        .offset(y: -size * 0.40)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            }

            // Concentric grooves.
            Circle()
                .strokeBorder(groove, lineWidth: max(0.8, size * 0.028))
                .padding(size * 0.15)
            if size >= 44 {
                Circle()
                    .strokeBorder(groove.opacity(0.55), lineWidth: max(0.6, size * 0.02))
                    .padding(size * 0.24)
            }

            // Lacquer sheen.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(player == .dark ? 0.22 : 0.38), .clear],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 1,
                        endRadius: size * 0.55
                    )
                )

            if isKing {
                if size >= 26 {
                    CrownStamp()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.96, green: 0.82, blue: 0.40), Kaleido.gold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            CrownStamp().stroke(Color.black.opacity(0.30), lineWidth: max(0.5, size * 0.012))
                        )
                        .frame(width: size * 0.40, height: size * 0.28)
                        .shadow(color: Color.black.opacity(0.35), radius: max(0.5, size * 0.012), y: max(0.5, size * 0.015))
                } else {
                    Circle()
                        .fill(Kaleido.gold)
                        .frame(width: size * 0.26, height: size * 0.26)
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.32), radius: size * 0.05, y: size * 0.035)
        .accessibilityHidden(true)
    }
}

/// A simple three-point crown, stamped into king pieces.
private struct CrownStamp: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.35))
        p.addLine(to: CGPoint(x: w * 0.25, y: h * 0.60))
        p.addLine(to: CGPoint(x: w * 0.50, y: 0))
        p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.60))
        p.addLine(to: CGPoint(x: w, y: h * 0.35))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Chips

/// Compact in-world buttons: wood for the primary action, quiet panel for
/// secondary, red-tinted for resign.
private struct ClubChipStyle: ButtonStyle {
    enum Kind {
        case wood, quiet, destructive
    }

    var theme: CheckersTheme
    var kind: Kind = .quiet
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(border, lineWidth: 1)
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .wood: return Color(red: 0.97, green: 0.93, blue: 0.85)
        case .quiet: return Kaleido.ink
        case .destructive: return Color(red: 0.85, green: 0.36, blue: 0.30)
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .wood:
            return AnyShapeStyle(
                LinearGradient(colors: [theme.frame, theme.frameEdge], startPoint: .top, endPoint: .bottom)
            )
        case .quiet, .destructive:
            return AnyShapeStyle(Kaleido.panel)
        }
    }

    private var border: Color {
        switch kind {
        case .wood: return Color.white.opacity(0.12)
        case .quiet: return Kaleido.outline
        case .destructive: return Color(red: 0.85, green: 0.36, blue: 0.30).opacity(0.5)
        }
    }
}

// MARK: - Result sheet (felt table)

private struct CheckersResultSheet: View {
    let winner: CheckersPlayer?
    let score: Int?
    let theme: CheckersTheme
    let onNewGame: () -> Void
    let onLeaderboard: () -> Void

    private let feltInk = Color(red: 0.93, green: 0.90, blue: 0.80)

    private var title: String {
        guard let winner else { return "Game Over" }
        return winner == .dark ? "Black wins" : "Red wins"
    }

    var body: some View {
        VStack(spacing: 16) {
            CheckersDisc(player: winner ?? .dark, isKing: true, size: 86, theme: theme)
                .padding(.top, 4)

            Text(title)
                .font(Kaleido.title(28))
                .foregroundStyle(feltInk)

            if let score {
                VStack(spacing: 2) {
                    Text("RESULT SCORE")
                        .font(.caption2.weight(.bold)).tracking(1.1)
                        .foregroundStyle(feltInk.opacity(0.6))
                    Text("\(score)")
                        .font(Kaleido.rounded(24)).monospacedDigit()
                        .foregroundStyle(Kaleido.gold)
                }
            }

            HStack(spacing: 10) {
                Button {
                    onNewGame()
                } label: {
                    Text("New Game")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FeltChipStyle(prominent: true))

                Button {
                    onLeaderboard()
                } label: {
                    Text("Leaderboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FeltChipStyle(prominent: false))
            }
            .padding(.top, 2)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 0.10, green: 0.23, blue: 0.155)
                RadialGradient(
                    colors: [Color.white.opacity(0.07), .clear],
                    center: UnitPoint(x: 0.5, y: 0.25),
                    startRadius: 10,
                    endRadius: 380
                )
            }
            .ignoresSafeArea()
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Kaleido.gold.opacity(0.30), lineWidth: 1)
                .padding(10)
                .allowsHitTesting(false)
        )
        .presentationDetents([.height(320), .medium])
        .presentationDragIndicator(.visible)
    }
}

private struct FeltChipStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(prominent ? Color(red: 0.16, green: 0.13, blue: 0.05) : Color(red: 0.93, green: 0.90, blue: 0.80))
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(prominent
                          ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.90, green: 0.73, blue: 0.34), Kaleido.gold], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.white.opacity(0.08)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(prominent ? 0.25 : 0.18), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

#Preview {
    NavigationStack {
        CheckersView()
    }
}
