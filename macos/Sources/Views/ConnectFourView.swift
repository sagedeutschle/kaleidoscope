// PRISM: RELEASE Agent-B 2026-06-28 — standalone Connect Four facet view.

import SwiftUI

private enum ConnectFourModal: Identifiable {
    case result(GameResult)
    case leaderboard

    var id: String {
        switch self {
        case .result(let result): return "result-\(result.id.uuidString)"
        case .leaderboard: return "leaderboard"
        }
    }
}

struct ConnectFourView: View {
    @ObservedObject private var session: ConnectFourSession
    @State private var modal: ConnectFourModal?
    @State private var hasSubmittedTerminalResult = false

    private let accent = FacetRegistry.accent(for: "connect-four")
    private let leaderboardService = KaleidoscopeLeaderboardService.shared
    private let cellSide: CGFloat = 58
    private let gap: CGFloat = 7

    init(session: ConnectFourSession = ConnectFourSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Connect Four",
                       systemImage: "circle.grid.3x3.fill",
                       accent: accent,
                       subtitle: statusText) {
                HStack(spacing: 8) {
                    StatBadge(label: "Red", value: "\(session.game.tokenCount(for: .red))", accent: redToken)
                    StatBadge(label: "Yellow", value: "\(session.game.tokenCount(for: .yellow))", accent: yellowToken)
                    StatBadge(label: "Moves", value: "\(session.game.moveCount)", accent: accent)
                }
            }
            .frame(maxWidth: 720)

            board
            controls
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .onChange(of: session.game) { _, _ in
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
                               })
            case .leaderboard:
                LocalLeaderboardPanel(service: leaderboardService,
                                      facetID: "connect-four",
                                      mode: "standard",
                                      accent: accent)
            }
        }
    }

    private var board: some View {
        VStack(spacing: gap) {
            ForEach(0..<session.game.rows, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<session.game.columns, id: \.self) { column in
                        cell(row: row, column: column)
                    }
                }
            }
        }
        .padding(16)
        .background(boardBlue)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Kaleido.outline, lineWidth: 1))
        .shadow(color: Color(red: 0.25, green: 0.16, blue: 0.08).opacity(0.22), radius: 14, y: 8)
        .kaleidoCard()
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                newGame()
            } label: {
                Label("New Game", systemImage: "arrow.clockwise")
            }
            .buttonStyle(AccentButtonStyle(accent: accent))

            Button {
                session.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(!session.canUndo || session.game.isGameOver)

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

    private var statusText: String {
        if let winner = session.game.winner {
            return "\(winner.rawValue) wins."
        }
        if session.game.isDraw {
            return "Draw."
        }
        return "\(session.game.currentPlayer.rawValue) to move."
    }

    private func cell(row: Int, column: Int) -> some View {
        let token = session.game.token(row: row, column: column)
        let legal = session.game.legalColumns.contains(column)
        let landing = landingRow(in: column)

        return Button {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.72)) {
                _ = session.dropToken(in: column)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Kaleido.panelHi)
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)

                if let token {
                    tokenDisc(token)
                        .padding(5)
                } else if legal && landing == row {
                    Circle()
                        .fill(session.game.currentPlayer == .red ? redToken.opacity(0.22) : yellowToken.opacity(0.28))
                        .padding(10)
                }
            }
            .frame(width: cellSide, height: cellSide)
        }
        .buttonStyle(.plain)
        .disabled(!legal)
        .help(legal ? "Drop in column \(column + 1)" : "Column \(column + 1) is unavailable")
    }

    private func tokenDisc(_ player: ConnectFourPlayer) -> some View {
        let fill = player == .red ? redToken : yellowToken
        return Circle()
            .fill(fill.gradient)
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(player == .red ? 0.18 : 0.42), lineWidth: 2)
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(player == .red ? 0.18 : 0.30))
                    .frame(width: 14, height: 14)
                    .padding(11)
            }
            .shadow(color: .black.opacity(0.24), radius: 3, y: 2)
    }

    private func landingRow(in column: Int) -> Int? {
        guard session.game.legalColumns.contains(column) else { return nil }
        return stride(from: session.game.rows - 1, through: 0, by: -1).first {
            session.game.token(row: $0, column: column) == nil
        }
    }

    private func newGame() {
        withAnimation(.easeOut(duration: 0.16)) {
            session.newGame()
        }
        hasSubmittedTerminalResult = false
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

    private var boardBlue: Color {
        Color(red: 0.15, green: 0.32, blue: 0.57)
    }

    private var redToken: Color {
        Color(red: 0.78, green: 0.16, blue: 0.18)
    }

    private var yellowToken: Color {
        Color(red: 0.93, green: 0.68, blue: 0.18)
    }
}
