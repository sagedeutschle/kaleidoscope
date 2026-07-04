import SwiftUI

struct ReversiView: View {
    private let accountID: UUID?
    private let playMode: GamePlayMode
    private let isOnline: Bool
    @ObservedObject private var online: OnlineMatchSession
    @StateObject private var persistence = PersistedGameSession<ReversiSnapshot>(gameID: .reversi)
    @AppStorage("reversi.aiELO") private var aiELO: Double = 1200
    @State private var game = ReversiGame()
    @State private var moveTick = 0
    @State private var isBotThinking = false
    @State private var appliedMoveCount = -1

    private let accent = Color(red: 0.20, green: 0.55, blue: 0.40)

    init(accountID: UUID? = nil, playMode: GamePlayMode = .soloBot, online: OnlineMatchSession? = nil) {
        self.accountID = accountID
        self.playMode = playMode
        self.isOnline = online != nil
        self._online = ObservedObject(wrappedValue: online ?? OnlineMatchSession.inert)
    }

    /// Host plays black (black moves first in Reversi).
    private var mySide: ReversiPiece { online.isHost ? .black : .white }
    private var botPlayer: ReversiPiece { .white }
    private var usesBot: Bool { playMode == .soloBot && !isOnline }
    private var isBotTurn: Bool {
        usesBot && game.currentPlayer == botPlayer && !game.isGameOver
    }

    private func name(_ piece: ReversiPiece) -> String {
        piece == .black ? "Black" : "White"
    }

    private var subtitleText: String {
        if game.isGameOver {
            let black = game.count(for: .black)
            let white = game.count(for: .white)
            if black == white { return "Draw \(black)–\(white)" }
            if isOnline {
                let winner: ReversiPiece = black > white ? .black : .white
                let opponent = online.opponentName ?? "Friend"
                return winner == mySide
                    ? "You win \(max(black, white))–\(min(black, white))!"
                    : "\(opponent) wins \(max(black, white))–\(min(black, white))"
            }
            let winner = black > white ? "Black" : "White"
            return "\(winner) wins \(max(black, white))–\(min(black, white))"
        }
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

    private var legalSet: Set<Int> {
        guard canMoveNow else { return [] }
        var s = Set<Int>()
        for m in game.legalMoves() {
            s.insert(m.row * ReversiGame.size + m.col)
        }
        return s
    }

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(
                title: "Reversi",
                systemImage: "circle.circle.fill",
                accent: accent,
                subtitle: subtitleText
            ) {
                if isOnline {
                    StatBadge(label: "You", value: name(mySide), accent: accent)
                    StatBadge(
                        label: online.opponentName ?? "Friend",
                        value: name(mySide.opponent),
                        accent: accent
                    )
                } else {
                    StatBadge(label: "Mode", value: usesBot ? "Bot" : "Local", accent: accent)
                    StatBadge(label: "Black", value: "\(game.count(for: .black))", accent: accent)
                    StatBadge(label: "White", value: "\(game.count(for: .white))", accent: accent)
                }
            }

            board

            controls
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .navigationTitle("Reversi")
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

    private var board: some View {
        GeometryReader { geo in
            let n = ReversiGame.size
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(n)
            let legal = legalSet

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(Kaleido.isDark ? 0.32 : 0.45))
                    .frame(width: side, height: side)

                Path { path in
                    for i in 0...n {
                        let p = CGFloat(i) * cell
                        path.move(to: CGPoint(x: p, y: 0))
                        path.addLine(to: CGPoint(x: p, y: side))
                        path.move(to: CGPoint(x: 0, y: p))
                        path.addLine(to: CGPoint(x: side, y: p))
                    }
                }
                .stroke(Kaleido.outline.opacity(0.6), lineWidth: 1)
                .frame(width: side, height: side)

                ForEach(0..<n, id: \.self) { row in
                    ForEach(0..<n, id: \.self) { col in
                        let idx = row * n + col
                        let piece = game.piece(row: row, col: col)
                        ZStack {
                            if let piece {
                                Circle()
                                    .fill(piece == .black ? Color(white: 0.08) : Color(white: 0.96))
                                    .overlay(
                                        Circle().strokeBorder(
                                            (piece == .black ? Color.white.opacity(0.18)
                                                             : Color.black.opacity(0.22)),
                                            lineWidth: 1
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                                    .padding(cell * 0.12)
                                    .transition(.scale.combined(with: .opacity))
                            } else if legal.contains(idx) {
                                Circle()
                                    .fill(accent.opacity(0.55))
                                    .frame(width: cell * 0.28, height: cell * 0.28)
                                    .transition(.opacity)
                            }
                        }
                        .frame(width: cell, height: cell)
                        .position(
                            x: cell * (CGFloat(col) + 0.5),
                            y: cell * (CGFloat(row) + 0.5)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleTap(row: row, col: col, isLegal: legal.contains(idx))
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .kaleidoCard()
    }

    private func handleTap(row: Int, col: Int, isLegal: Bool) {
        guard isLegal, canMoveNow else { return }
        withAnimation(.easeInOut(duration: 0.24)) {
            _ = game.applyMove(row: row, col: col)
            game.passIfNeeded()
        }
        moveTick &+= 1
        if isOnline {
            sendMyMove()
        } else {
            save(forceCloud: game.isGameOver)
            scheduleBotMoveIfNeeded()
        }
    }

    @ViewBuilder
    private var controls: some View {
        if isOnline {
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
        } else {
            localControls
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

    private func sendMyMove() {
        guard let stateJSON = try? GameSaveCodec.encodeSnapshot(ReversiSnapshot(game: game)) else { return }
        appliedMoveCount = (online.match?.moveCount ?? appliedMoveCount) + 1
        let finished = game.isGameOver
        var winnerIsMe: Bool? = nil
        if finished {
            let black = game.count(for: .black)
            let white = game.count(for: .white)
            if black != white {
                let winner: ReversiPiece = black > white ? .black : .white
                winnerIsMe = winner == mySide
            }
        }
        // If the opponent has no legal reply, Reversi passes back to me.
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
        guard let snapshot = try? GameSaveCodec.decodeSnapshot(ReversiSnapshot.self, from: match.stateJSON) else { return }
        withAnimation(.easeInOut(duration: 0.24)) {
            game = snapshot.game
        }
        appliedMoveCount = match.moveCount
        moveTick &+= 1
    }

    private func snapshot() -> ReversiSnapshot {
        ReversiSnapshot(game: game)
    }

    private func restore(_ snapshot: ReversiSnapshot) {
        game = snapshot.game
        isBotThinking = false
        scheduleBotMoveIfNeeded()
    }

    private func save(forceCloud: Bool = false) {
        guard !isOnline else { return }
        persistence.save(snapshot: snapshot(), score: game.count(for: .black), forceCloud: forceCloud)
    }

    private func resetGame() {
        withAnimation(.easeInOut(duration: 0.25)) {
            game = ReversiGame()
            isBotThinking = false
        }
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
                ReversiAI(player: bot, targetELO: elo).move(in: snapshot)
            }.value
            await MainActor.run {
                applyBotMove(move, expectedGame: snapshot, bot: bot)
            }
        }
    }

    @MainActor
    private func applyBotMove(_ move: ReversiMove?, expectedGame: ReversiGame, bot: ReversiPiece) {
        guard usesBot, game == expectedGame, game.currentPlayer == bot, !game.isGameOver else {
            isBotThinking = false
            return
        }

        if let move {
            withAnimation(.easeInOut(duration: 0.24)) {
                _ = game.applyMove(row: move.row, col: move.col)
                game.passIfNeeded()
            }
            moveTick &+= 1
        } else {
            game.passIfNeeded()
        }

        isBotThinking = false
        save(forceCloud: game.isGameOver)
        if isBotTurn {
            scheduleBotMoveIfNeeded()
        }
    }
}
