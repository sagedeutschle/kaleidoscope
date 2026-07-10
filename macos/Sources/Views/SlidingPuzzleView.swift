import SwiftUI

// PRISM: RELEASE Agent-B 2026-06-27 — keyboard and persisted session controls.

struct SlidingPuzzleView: View {
    @ObservedObject private var session: SlidingPuzzleSession
    @FocusState private var isFocused: Bool

    private let tileSize: CGFloat = 82
    private let accent = FacetRegistry.accent(for: "sliding-15")

    init(session: SlidingPuzzleSession = SlidingPuzzleSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Sliding-15", systemImage: "square.grid.4x3.fill", accent: accent,
                       subtitle: session.puzzle.isSolved ? "Solved." : "Slide tiles into order.")
                .frame(maxWidth: 440)

            board.prismetCard()
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
    }

    private var board: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { col in
                        tile(at: row * 4 + col)
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                session.shuffle()
                isFocused = true
            } label: {
                Label("Shuffle", systemImage: "shuffle")
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

            Button {
                session.reset()
                isFocused = true
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
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

    private func tile(at index: Int) -> some View {
        let value = session.puzzle.tiles[index]
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                session.moveTile(at: index)
            }
            isFocused = true
        } label: {
            ZStack {
                if value == 0 {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.gradient)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LinearGradient(colors: [.white.opacity(0.18), .clear],
                                                     startPoint: .top, endPoint: .bottom))
                        )
                        .shadow(color: accent.opacity(0.35), radius: 6, y: 3)
                    Text("\(value)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .frame(width: tileSize, height: tileSize)
        }
        .buttonStyle(.plain)
        .disabled(value == 0 || session.puzzle.isSolved)
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow: session.moveBlank(.left)
        case .rightArrow: session.moveBlank(.right)
        case .upArrow: session.moveBlank(.up)
        case .downArrow: session.moveBlank(.down)
        default: return .ignored
        }
        isFocused = true
        return .handled
    }
}
