import SwiftUI

// PRISM: RELEASE Agent-B 2026-06-27 — persisted session controls and undo.
// PRISM: RELEASE Agent-Mac 2026-07-03 — mirrored iOS v10 "Wooden Tray" (walnut) material (visual layer only; layout/session/logic untouched). Build green.

// MARK: - Walnut tray material (mirrored from iOS v10 Game2048Theme.walnut)

/// Game-local material palette for the 2048 tray. Tile faces keep their existing
/// value colors; only the tray slab + empty wells become turned walnut.
private enum Game2048Material {
    static let tray = Color(red: 0.42, green: 0.35, blue: 0.28)      // tray surface (top)
    static let trayDeep = Color(red: 0.35, green: 0.28, blue: 0.22) // tray surface (bottom)
    static let trayRim = Color(red: 0.25, green: 0.19, blue: 0.14)  // outer rim stroke
    static let well = Color(red: 0.315, green: 0.255, blue: 0.198)  // recessed well floor
    static let wellDeep = Color(red: 0.270, green: 0.214, blue: 0.163)
}

private enum Game2048Modal: Identifiable {
    case result(GameResult)
    case leaderboard

    var id: String {
        switch self {
        case .result(let result): return "result-\(result.id.uuidString)"
        case .leaderboard: return "leaderboard"
        }
    }
}

struct Game2048View: View {
    @ObservedObject private var session: Game2048Session
    @State private var modal: Game2048Modal?
    @State private var hasSubmittedTerminalResult = false
    @FocusState private var isFocused: Bool

    private let accent = FacetRegistry.accent(for: "2048")
    private let leaderboardService = KaleidoscopeLeaderboardService.shared
    private var boardLayout: Game2048BoardLayout {
        Game2048BoardLayout(tileSize: tileSize(for: session.game.size))
    }

    init(session: Game2048Session = Game2048Session()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "2048", systemImage: "square.grid.2x2", accent: accent, subtitle: statusText) {
                StatBadge(label: "Score", value: "\(session.game.score)", accent: accent)
            }
            .frame(maxWidth: 520)

            board
            controls
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(action: handleKeyPress)
        .gesture(dragGesture)
        .sheet(item: $modal) { modal in
            switch modal {
            case .result(let result):
                ResultSlipView(result: result,
                               accent: accent,
                               onPlayAgain: {
                                   self.modal = nil
                                   reset()
                               },
                               onLeaderboard: {
                                   self.modal = .leaderboard
                               },
                               onDismiss: {
                                   self.modal = nil
                                   isFocused = true
                               })
            case .leaderboard:
                LocalLeaderboardPanel(service: leaderboardService,
                                      facetID: "2048",
                                      mode: "standard",
                                      accent: accent)
            }
        }
    }

    private var board: some View {
        let boardSide = boardLayout.boardSide(for: session.game.size)
        let cardSide = boardLayout.cardSide(for: session.game.size)

        return ZStack(alignment: .topLeading) {
            ForEach(session.game.grid.indices, id: \.self) { index in
                tile(staticTileValue(at: index), index: index)
                    .position(tileCenter(for: index))
            }

            if let activeMovePlan = session.activeMovePlan {
                ForEach(activeMovePlan.slides) { slide in
                    movingTile(slide)
                }
            }
        }
        .frame(width: boardSide, height: boardSide, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Game2048Material.tray, Game2048Material.trayDeep],
                                     startPoint: .top, endPoint: .bottom))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Game2048Material.trayRim, lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .inset(by: 1.5)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.10), .clear],
                                             startPoint: .top, endPoint: .bottom),
                              lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.30), radius: 14, y: 8)
        .frame(width: cardSide, height: cardSide, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            VStack(spacing: 10) {
                Button { perform(.up) } label: { Image(systemName: "arrow.up") }
                HStack(spacing: 10) {
                    Button { perform(.left) } label: { Image(systemName: "arrow.left") }
                    Button { perform(.down) } label: { Image(systemName: "arrow.down") }
                    Button { perform(.right) } label: { Image(systemName: "arrow.right") }
                }
            }
            .font(.title3.bold())
            .buttonStyle(GlassButtonStyle())

            HStack(spacing: 12) {
                Button {
                    reset()
                } label: {
                    Label("New Game", systemImage: "arrow.clockwise")
                }
                .buttonStyle(AccentButtonStyle(accent: accent))

                Button {
                    session.undo()
                    isFocused = true
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

                Button {
                    modal = .leaderboard
                } label: {
                    Label("Scores", systemImage: "trophy")
                }
                .buttonStyle(GlassButtonStyle())
            }

            HStack(spacing: 12) {
                Button {
                    triggerVisualShuffle()
                } label: {
                    Label("Shuffle \(session.shufflePowerUps.remainingUses)", systemImage: "sparkles")
                }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(session.game.isGameOver || session.activeMovePlan != nil || session.visualShuffle != nil || session.shufflePowerUps.remainingUses == 0)
                Toggle("Shuffle animation", isOn: $session.shuffleAnimationEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: session.shuffleAnimationEnabled) { _, _ in
                        session.saveNow()
                        isFocused = true
                    }
            }
            .font(.callout.weight(.semibold))

            Stepper("Shuffles/game: \(session.shuffleUsesPerGame)", value: $session.shuffleUsesPerGame, in: 0...Game2048ShufflePowerUps.maxUsesPerGame)
                .font(.callout.weight(.semibold))
                .frame(width: 230)
                .onChange(of: session.shuffleUsesPerGame) { _, newValue in
                    session.setShuffleUsesPerGame(newValue)
                    isFocused = true
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Board size")
                    Spacer()
                    Text("\(session.boardSize) x \(session.boardSize)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Stepper("\(session.boardSize * session.boardSize) tiles", value: $session.boardSize, in: Game2048.minSize...Game2048.maxSize)
                    .onChange(of: session.boardSize) { _, _ in
                        reset()
                    }
            }
            .font(.callout.weight(.semibold))
            .frame(width: 230)
        }
    }

    private var statusText: String {
        if session.game.hasWon { return "You made 2048." }
        if session.game.isGameOver { return "No moves left." }
        return "Slide tiles to merge matching values."
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    perform(dx < 0 ? .left : .right)
                } else {
                    perform(dy < 0 ? .up : .down)
                }
            }
    }

    private func tile(_ value: Int, index: Int) -> some View {
        let effect = session.visualShuffle?.effect(forTileIndex: index)
        return Text(value == 0 ? "" : "\(value)")
            .font(.system(
                size: value >= 1024 ? boardLayout.largeTileFontSize : boardLayout.regularTileFontSize,
                weight: .black,
                design: .rounded
            ))
            .monospacedDigit()
            .foregroundStyle(value <= 4 ? Color(red: 0.45, green: 0.40, blue: 0.34) : .white)
            .frame(width: boardLayout.tileSize, height: boardLayout.tileSize)
            .background(
                ZStack {
                    tileColor(value)
                    if value == 0 {
                        // Recessed well: darker floor toward the bottom, shaded lip up top.
                        LinearGradient(colors: [Game2048Material.wellDeep, Game2048Material.well],
                                       startPoint: .top, endPoint: .bottom)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [Color.black.opacity(0.28), .clear],
                                                         startPoint: .top, endPoint: .center),
                                          lineWidth: 1.2)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(effect?.scale ?? 1)
            .rotationEffect(.degrees(effect?.rotationDegrees ?? 0))
            .offset(x: effect?.xOffset ?? 0, y: effect?.yOffset ?? 0)
    }

    private func movingTile(_ slide: Game2048TileSlide) -> some View {
        let from = tileCenter(for: slide.fromIndex)
        let to = tileCenter(for: slide.toIndex)
        let x = session.slideTilesAtDestination ? to.x : from.x
        let y = session.slideTilesAtDestination ? to.y : from.y

        return tile(slide.value, index: slide.fromIndex)
            .position(x: x, y: y)
            .zIndex(2)
    }

    private func tileColor(_ value: Int) -> Color {
        switch value {
        case 0: return Game2048Material.well
        case 2: return Color(red: 0.93, green: 0.89, blue: 0.82)
        case 4: return Color(red: 0.92, green: 0.86, blue: 0.74)
        case 8: return Color(red: 0.90, green: 0.54, blue: 0.31)
        case 16: return Color(red: 0.85, green: 0.36, blue: 0.24)
        case 32: return Color(red: 0.78, green: 0.24, blue: 0.24)
        case 64: return Color(red: 0.68, green: 0.16, blue: 0.20)
        case 128: return Color(red: 0.39, green: 0.61, blue: 0.78)
        case 256: return Color(red: 0.28, green: 0.49, blue: 0.71)
        case 512: return Color(red: 0.22, green: 0.38, blue: 0.62)
        case 1024: return Color(red: 0.16, green: 0.29, blue: 0.51)
        default: return Color(red: 0.11, green: 0.20, blue: 0.37)
        }
    }

    private func perform(_ direction: Game2048.Direction) {
        guard let plan = session.startMove(direction) else { return }

        Task {
            await Task.yield()
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.16)) {
                    session.slideTilesAtDestination = true
                }
            }
            try? await Task.sleep(nanoseconds: 170_000_000)
            await MainActor.run {
                guard session.activeMovePlan == plan else { return }
                session.commit(plan)
                submitTerminalResultIfNeeded()
            }
        }
    }

    private func reset() {
        session.reset()
        hasSubmittedTerminalResult = false
        isFocused = true
    }

    private func submitTerminalResultIfNeeded() {
        guard !hasSubmittedTerminalResult,
              let result = GameResultExtractor.result(for: session.game) else { return }
        hasSubmittedTerminalResult = true
        modal = .result(result)

        Task {
            try? await leaderboardService.submit(result)
        }
    }

    private func triggerVisualShuffle() {
        guard session.activeMovePlan == nil, session.shufflePowerUps.remainingUses > 0 else { return }
        isFocused = true

        let shuffle: Game2048VisualShuffle?
        if session.shuffleAnimationEnabled {
            shuffle = withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                session.shuffleTilesForPowerUp()
            }
        } else {
            shuffle = session.shuffleTilesForPowerUp()
        }
        guard let shuffle else { return }

        applyVisualShuffle(shuffle)

        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            await MainActor.run {
                guard session.visualShuffle == shuffle else { return }
                clearVisualShuffle()
            }
        }
    }

    private func applyVisualShuffle(_ shuffle: Game2048VisualShuffle) {
        if session.shuffleAnimationEnabled {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                session.visualShuffle = shuffle
            }
        } else {
            session.visualShuffle = shuffle
        }
    }

    private func clearVisualShuffle() {
        if session.shuffleAnimationEnabled {
            withAnimation(.easeOut(duration: 0.18)) {
                session.visualShuffle = nil
            }
        } else {
            session.visualShuffle = nil
        }
    }

    private func tileSize(for boardSize: Int) -> Double {
        switch boardSize {
        case 3: return 104
        case 4: return Game2048BoardLayout.defaultTileSize
        case 5: return 72
        default: return Game2048BoardLayout.minTileSize
        }
    }

    private func staticTileValue(at index: Int) -> Int {
        guard let activeMovePlan = session.activeMovePlan else { return session.game.grid[index] }
        return activeMovePlan.slides.contains(where: { $0.fromIndex == index }) ? 0 : session.game.grid[index]
    }

    private func tileCenter(for index: Int) -> CGPoint {
        let center = boardLayout.tileCenter(for: index, boardSize: session.game.size)
        return CGPoint(x: center.x, y: center.y)
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow: perform(.left); return .handled
        case .rightArrow: perform(.right); return .handled
        case .upArrow: perform(.up); return .handled
        case .downArrow: perform(.down); return .handled
        default: return .ignored
        }
    }
}
