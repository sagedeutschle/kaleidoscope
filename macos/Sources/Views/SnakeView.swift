import SwiftUI

// PRISM: RELEASE Agent-A 2026-06-27 — Snake reskinned to clean vector (garden): sage board, emerald snake w/ direction-aware eyes, red apple. Removed pixel sprites. Built green.
// PRISM: RELEASE Agent-B 2026-06-27 — persisted session controls.

private enum SnakeModal: Identifiable {
    case result(GameResult)
    case leaderboard

    var id: String {
        switch self {
        case .result(let result): return "result-\(result.id.uuidString)"
        case .leaderboard: return "leaderboard"
        }
    }
}

struct SnakeView: View {
    @ObservedObject private var session: SnakeSession
    @State private var modal: SnakeModal?
    @State private var hasSubmittedTerminalResult = false
    @FocusState private var isFocused: Bool

    private let timer = Timer.publish(every: 0.16, on: .main, in: .common).autoconnect()
    private let cellSize: CGFloat = 24
    private let accent = FacetRegistry.accent(for: "snake")
    private let leaderboardService = KaleidoscopeLeaderboardService.shared

    // Garden palette — emerald snake on a sage bed, framed by the vellum card.
    private let sageLight = Color(red: 0.78, green: 0.81, blue: 0.65)
    private let sageDark = Color(red: 0.70, green: 0.75, blue: 0.58)
    private let bodyGreen = Color(red: 0.17, green: 0.46, blue: 0.28)
    private let headGreen = Color(red: 0.22, green: 0.58, blue: 0.34)
    private let appleRed = Color(red: 0.82, green: 0.20, blue: 0.22)
    private let leafGreen = Color(red: 0.30, green: 0.52, blue: 0.27)

    init(session: SnakeSession = SnakeSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Snake", systemImage: "scribble.variable", accent: accent,
                       subtitle: session.game.status == .lost ? "Crashed." : "Eat apples. Avoid walls and yourself.") {
                StatBadge(label: "Score", value: "\(session.game.score)", accent: accent)
            }
            .frame(maxWidth: 480)

            board.kaleidoCard()
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
        .onReceive(timer) { _ in
            guard session.isRunning else { return }
            session.step()
            submitTerminalResultIfNeeded()
        }
        .sheet(item: $modal) { modal in
            switch modal {
            case .result(let result):
                ResultSlipView(result: result,
                               accent: accent,
                               onPlayAgain: {
                                   self.modal = nil
                                   newGame()
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
                                      facetID: "snake",
                                      mode: "standard",
                                      accent: accent)
            }
        }
    }

    private var board: some View {
        VStack(spacing: 0) {
            ForEach(0..<session.game.height, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<session.game.width, id: \.self) { col in
                        tile(SnakePoint(row: row, col: col))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Kaleido.outline, lineWidth: 1))
    }

    @ViewBuilder
    private func tile(_ p: SnakePoint) -> some View {
        ZStack {
            Rectangle().fill((p.row + p.col).isMultiple(of: 2) ? sageLight : sageDark)
            switch kind(of: p) {
            case .empty:
                EmptyView()
            case .apple:
                appleView
            case .head:
                segment(color: headGreen, inset: 1.5, head: true)
            case .body:
                segment(color: bodyGreen, inset: 2, head: false)
            case .tail:
                segment(color: bodyGreen.opacity(0.85), inset: 4, head: false)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private func segment(color: Color, inset: CGFloat, head: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: head ? 8 : 6, style: .continuous)
                .fill(color.gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: head ? 8 : 6, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
                )
                .padding(inset)
            if head { eyes }
        }
    }

    private var eyes: some View {
        ZStack {
            ForEach(Array(eyePositions().enumerated()), id: \.offset) { _, pos in
                Circle().fill(.white)
                    .frame(width: cellSize * 0.24, height: cellSize * 0.24)
                    .overlay(Circle().fill(.black).frame(width: cellSize * 0.11, height: cellSize * 0.11))
                    .position(pos)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private func eyePositions() -> [CGPoint] {
        let c = cellSize / 2
        let fwd = cellSize * 0.16
        let sep = cellSize * 0.20
        switch session.game.direction {
        case .up:    return [CGPoint(x: c - sep, y: c - fwd), CGPoint(x: c + sep, y: c - fwd)]
        case .down:  return [CGPoint(x: c - sep, y: c + fwd), CGPoint(x: c + sep, y: c + fwd)]
        case .left:  return [CGPoint(x: c - fwd, y: c - sep), CGPoint(x: c - fwd, y: c + sep)]
        case .right: return [CGPoint(x: c + fwd, y: c - sep), CGPoint(x: c + fwd, y: c + sep)]
        }
    }

    private var appleView: some View {
        ZStack {
            Circle()
                .fill(appleRed.gradient)
                .overlay(
                    Circle().fill(.white.opacity(0.45))
                        .frame(width: cellSize * 0.16, height: cellSize * 0.16)
                        .offset(x: -cellSize * 0.12, y: -cellSize * 0.12)
                )
                .padding(4)
            Capsule()
                .fill(leafGreen)
                .frame(width: cellSize * 0.12, height: cellSize * 0.24)
                .rotationEffect(.degrees(42))
                .offset(x: cellSize * 0.13, y: -cellSize * 0.22)
        }
    }

    private func kind(of p: SnakePoint) -> SnakeTilePresentation.Kind {
        if p == session.game.apple { return .apple }
        guard let index = session.game.body.firstIndex(of: p) else { return .empty }
        if index == 0 { return .head }
        if index == session.game.body.count - 1 && session.game.body.count > 1 { return .tail }
        return .body
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                if session.game.status == .playing {
                    session.toggleRunning()
                    isFocused = true
                }
            } label: {
                Label(session.isRunning ? "Pause" : "Run", systemImage: session.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(GlassButtonStyle())

            Button {
                newGame()
            } label: {
                Label("New Game", systemImage: "arrow.clockwise")
            }
            .buttonStyle(AccentButtonStyle(accent: accent))

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
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow: session.turn(.left)
        case .rightArrow: session.turn(.right)
        case .upArrow: session.turn(.up)
        case .downArrow: session.turn(.down)
        case "w", "W": session.turn(.up)
        case "a", "A": session.turn(.left)
        case "s", "S": session.turn(.down)
        case "d", "D": session.turn(.right)
        case " ":
            session.toggleRunning()
        default:
            return .ignored
        }
        return .handled
    }

    private func newGame() {
        session.newGame()
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
}
