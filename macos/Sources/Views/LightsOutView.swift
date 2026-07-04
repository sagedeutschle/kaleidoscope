import SwiftUI

// PRISM: RELEASE Agent-B 2026-06-27 — route input through persisted session state.

struct LightsOutView: View {
    @ObservedObject private var session: LightsOutSession

    private let accent = FacetRegistry.accent(for: "lights-out")

    init(session: LightsOutSession = LightsOutSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Lights Out", systemImage: "lightbulb.fill", accent: accent,
                       subtitle: session.game.isSolved ? "Solved." : "Turn every light off.") {
                StatBadge(label: "Presses", value: "\(session.pressCount)", accent: accent)
            }
            .frame(maxWidth: 460)

            grid.kaleidoCard()
            controls
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
    }

    private var grid: some View {
        VStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<5, id: \.self) { col in
                        lightButton(row: row, col: col)
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                session.newGame()
            } label: {
                Label("New Game", systemImage: "shuffle")
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
                session.clear()
            } label: {
                Label("Clear", systemImage: "lightbulb.slash")
            }
            .buttonStyle(GlassButtonStyle())
            Menu {
                Button("Save") { session.saveNow() }
                Button("Load") { session.reloadSavedState() }
            } label: {
                Label("State", systemImage: "externaldrive")
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    private func lightButton(row: Int, col: Int) -> some View {
        let isLit = session.game.isLit(row: row, col: col)

        return Button {
            withAnimation(.easeOut(duration: 0.12)) {
                session.press(row: row, col: col)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isLit ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(Kaleido.panelHi))
                    .overlay(Circle().stroke(isLit ? Color.white.opacity(0.85) : Kaleido.hairline, lineWidth: 2))
                    .shadow(color: isLit ? accent.opacity(0.6) : .clear, radius: 10)
                Image(systemName: isLit ? "lightbulb.fill" : "lightbulb")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isLit ? .white : Kaleido.ink3)
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Light \(row + 1), \(col + 1)")
        .accessibilityValue(isLit ? "on" : "off")
    }
}
