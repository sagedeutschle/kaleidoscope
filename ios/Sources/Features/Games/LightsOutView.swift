import SwiftUI

struct LightsOutView: View {
    private let accent = Color(red: 0.85, green: 0.70, blue: 0.20)

    @StateObject private var session = LightsOutSession()
    private let accountID: UUID?

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(
                title: "Lights Out",
                systemImage: "lightbulb.fill",
                accent: accent,
                subtitle: session.game.isSolved ? "Solved!" : "Turn them all off"
            ) {
                StatBadge(label: "Lit", value: "\(session.game.litCount)", accent: accent)
                StatBadge(label: "Moves", value: "\(session.moves)", accent: Kaleido.ink)
            }

            board

            HStack(spacing: 12) {
                Button {
                    newGame()
                } label: {
                    Label("New Game", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentButtonStyle(accent: accent))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .navigationTitle("Lights Out")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let accountID {
                session.configure(accountID: accountID, cloudStore: .shared)
            }
        }
        .onDisappear { session.saveNow() }
        .sensoryFeedback(.impact(weight: .light), trigger: session.moves)
        .sensoryFeedback(.success, trigger: session.game.isSolved)
    }

    private var board: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let spacing: CGFloat = 10
            let cell = (side - spacing * 4) / 5

            VStack(spacing: spacing) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<5, id: \.self) { col in
                            cellView(row: row, col: col, size: cell)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(16)
        .kaleidoCard()
    }

    private func cellView(row: Int, col: Int, size: CGFloat) -> some View {
        let lit = session.game.isLit(row: row, col: col)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(lit ? accent : Kaleido.panelHi)
            .opacity(lit ? 1.0 : 0.45)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(lit ? accent.opacity(0.9) : Kaleido.hairline, lineWidth: 1)
            )
            .overlay(
                Image(systemName: lit ? "lightbulb.fill" : "lightbulb")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(lit ? Kaleido.ground : Kaleido.ink3)
            )
            .frame(width: size, height: size)
            .shadow(color: lit ? accent.opacity(0.55) : .clear, radius: lit ? 10 : 0, x: 0, y: 0)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    session.press(row: row, col: col)
                }
            }
    }

    private func newGame() {
        withAnimation(.easeInOut(duration: 0.2)) {
            session.newGame()
        }
    }
}
