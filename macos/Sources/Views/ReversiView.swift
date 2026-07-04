import SwiftUI

// PRISM: RELEASE Agent-B 2026-06-27 — route input through persisted session state.

struct ReversiView: View {
    @ObservedObject private var session: ReversiSession

    private let accent = FacetRegistry.accent(for: "reversi")
    private let cellSide: CGFloat = 48

    init(session: ReversiSession = ReversiSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Reversi", systemImage: "circle.grid.cross", accent: accent, subtitle: statusText) {
                HStack(spacing: 8) {
                    StatBadge(label: "Black", value: "\(session.game.count(for: .black))", accent: .black)
                    StatBadge(label: "White", value: "\(session.game.count(for: .white))", accent: .white)
                }
            }
            .frame(maxWidth: 620)

            board
            controls
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
    }

    private var board: some View {
        VStack(spacing: 4) {
            ForEach(0..<ReversiGame.size, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<ReversiGame.size, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.16, green: 0.43, blue: 0.32))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Kaleido.outline, lineWidth: 1))
        .kaleidoCard()
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                session.newGame()
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
                .disabled(!session.canUndo)
            Button {
                session.pass()
            } label: {
                Label("Pass", systemImage: "forward.end")
            }
            .buttonStyle(GlassButtonStyle())
                .disabled(!session.game.legalMoves().isEmpty || session.game.isGameOver)
            Menu {
                Button("Save") { session.saveNow() }
                Button("Load") { session.reloadSavedState() }
            } label: {
                Label("State", systemImage: "externaldrive")
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    private var statusText: String {
        if session.game.isGameOver {
            if session.game.count(for: .black) == session.game.count(for: .white) { return "Draw." }
            return "\(session.game.count(for: .black) > session.game.count(for: .white) ? "Black" : "White") wins."
        }
        return "\(session.game.currentPlayer.rawValue) to move."
    }

    private func cell(row: Int, col: Int) -> some View {
        let piece = session.game.piece(row: row, col: col)
        let legal = session.game.legalMoves().contains(ReversiMove(row: row, col: col))

        return Button {
            withAnimation(.easeOut(duration: 0.14)) {
                session.applyMove(row: row, col: col)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(red: 0.19, green: 0.51, blue: 0.38))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.24), lineWidth: 1))
                if let piece {
                    Circle()
                        .fill(piece == .black ? Color.black : Color.white)
                        .overlay(Circle().stroke(piece == .black ? Color.white.opacity(0.12) : Color.black.opacity(0.18), lineWidth: 2))
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                        .padding(6)
                } else if legal {
                    Circle()
                        .fill(Color.white.opacity(0.34))
                        .frame(width: 14, height: 14)
                }
            }
            .frame(width: cellSide, height: cellSide)
        }
        .buttonStyle(.plain)
        .disabled(piece != nil || !legal)
    }
}
