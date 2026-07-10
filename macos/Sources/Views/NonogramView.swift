import SwiftUI

// PRISM: RELEASE Agent-B 2026-06-27 — route input through persisted session state.

struct NonogramView: View {
    @ObservedObject private var session: NonogramSession

    private let accent = FacetRegistry.accent(for: "nonogram")
    private let cellSide: CGFloat = 46

    init(session: NonogramSession = NonogramSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Nonogram", systemImage: "squareshape.split.3x3", accent: accent,
                       subtitle: session.game.isSolved ? "Picture complete." : "Use the clues to reveal the pattern.") {
                StatBadge(label: "Grid", value: "\(session.game.size)x\(session.game.size)", accent: accent)
            }
            .frame(maxWidth: 560)

            board

            controls
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                session.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(AccentButtonStyle(accent: accent))

            Button {
                session.undo()
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
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                Color.clear.frame(width: 78, height: 54)
                HStack(spacing: 6) {
                    ForEach(0..<session.game.size, id: \.self) { col in
                        clueText(session.game.columnClues[col], vertical: true)
                            .frame(width: cellSide, height: 54)
                    }
                }
            }

            ForEach(0..<session.game.size, id: \.self) { row in
                HStack(spacing: 8) {
                    clueText(session.game.rowClues[row], vertical: false)
                        .frame(width: 78, height: cellSide, alignment: .trailing)

                    HStack(spacing: 6) {
                        ForEach(0..<session.game.size, id: \.self) { col in
                            cell(row: row, col: col)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(PrismetDesign.panelHi)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PrismetDesign.outline, lineWidth: 1))
        .prismetCard()
    }

    private func clueText(_ clues: [Int], vertical: Bool) -> some View {
        let text = clues.map(String.init).joined(separator: vertical ? "\n" : " ")
        return Text(text)
            .font(.caption.bold())
            .monospacedDigit()
            .multilineTextAlignment(vertical ? .center : .trailing)
            .foregroundStyle(PrismetDesign.ink2)
    }

    private func cell(row: Int, col: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) {
                session.cycle(row: row, col: col)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(cellFill(session.game.mark(row: row, col: col)))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(PrismetDesign.hairline, lineWidth: 1))
                if session.game.mark(row: row, col: col) == .crossed {
                    Image(systemName: "xmark")
                        .font(.headline.bold())
                        .foregroundStyle(PrismetDesign.ink3)
                }
            }
            .frame(width: cellSide, height: cellSide)
        }
        .buttonStyle(.plain)
    }

    private func cellFill(_ mark: NonogramMark) -> Color {
        switch mark {
        case .empty: return Color.white.opacity(0.64)
        case .filled: return accent
        case .crossed: return PrismetDesign.panel
        }
    }
}
