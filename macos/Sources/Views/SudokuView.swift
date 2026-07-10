import SwiftUI

// PRISM: RELEASE Agent-B 2026-06-27 — keyboard and persisted session controls.

struct SudokuView: View {
    @ObservedObject private var session: SudokuSession
    @FocusState private var isFocused: Bool

    private let accent = FacetRegistry.accent(for: "sudoku")

    init(session: SudokuSession = SudokuSession()) {
        self.session = session
    }

    var body: some View {
        VStack(spacing: 20) {
            GameHeader(title: "Sudoku", systemImage: "number.square", accent: accent, subtitle: statusText) {
                StatBadge(label: "Open", value: "\(openCount)", accent: accent)
            }
            .frame(maxWidth: 560)

            board
            keypad
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
        VStack(spacing: 3) {
            ForEach(0..<SudokuGame.size, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<SudokuGame.size, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
                .padding(.bottom, row == 2 || row == 5 ? 5 : 0)
            }
        }
        .padding(12)
        .background(PrismetDesign.panelHi)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PrismetDesign.outline, lineWidth: 1))
        .prismetCard()
    }

    private var keypad: some View {
        HStack(spacing: 8) {
            ForEach(1...9, id: \.self) { number in
                Button {
                    enter(number)
                } label: {
                    Text("\(number)")
                        .font(.title3.bold())
                        .frame(width: 40, height: 36)
                }
                .buttonStyle(GlassButtonStyle())
            }

            Button {
                enter(0)
            } label: {
                Image(systemName: "delete.left")
                    .frame(width: 40, height: 36)
            }
            .buttonStyle(GlassButtonStyle())
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                session.reset()
                isFocused = true
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
            Button {
                session.solve()
                isFocused = true
            } label: {
                Label("Solve", systemImage: "checkmark.seal")
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

    private var statusText: String {
        if session.game.isComplete { return "Solved." }
        return "Fill the parchment grid without duplicate rows, columns, or boxes."
    }

    private var openCount: Int {
        session.game.entries.filter { $0 == 0 }.count
    }

    private func cell(row: Int, col: Int) -> some View {
        let value = session.game.value(row: row, col: col)
        let index = row * SudokuGame.size + col
        let selected = session.selectedIndex == index
        let given = session.game.isGiven(row: row, col: col)
        let conflict = session.game.hasConflict(row: row, col: col)
        let correct = session.game.isCorrect(row: row, col: col)

        return Button {
            session.select(index: index)
            isFocused = true
        } label: {
            Text(value == 0 ? "" : "\(value)")
                .font(.system(size: 22, weight: given ? .black : .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(cellTextColor(given: given, conflict: conflict, correct: correct))
                .frame(width: 42, height: 42)
                .background(cellBackground(selected: selected, given: given, conflict: conflict))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(cellBorder(row: row, col: col), lineWidth: 1))
                .padding(.trailing, col == 2 || col == 5 ? 5 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sudoku row \(row + 1), column \(col + 1)")
    }

    private func enter(_ value: Int) {
        session.enter(value)
        isFocused = true
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow:
            session.moveSelection(rowDelta: 0, colDelta: -1)
        case .rightArrow:
            session.moveSelection(rowDelta: 0, colDelta: 1)
        case .upArrow:
            session.moveSelection(rowDelta: -1, colDelta: 0)
        case .downArrow:
            session.moveSelection(rowDelta: 1, colDelta: 0)
        case .delete:
            session.enter(0)
        default:
            if press.characters == "\u{7F}" || press.characters == "\u{08}" {
                session.enter(0)
            } else if let character = press.characters.first,
                      press.characters.count == 1,
                      let value = Int(String(character)),
                      (1...9).contains(value) {
                session.enter(value)
            } else {
                return .ignored
            }
        }
        isFocused = true
        return .handled
    }

    private func cellTextColor(given: Bool, conflict: Bool, correct: Bool) -> Color {
        if conflict || !correct { return Color(red: 0.70, green: 0.18, blue: 0.16) }
        return given ? PrismetDesign.ink : accent
    }

    private func cellBackground(selected: Bool, given: Bool, conflict: Bool) -> Color {
        if conflict { return Color(red: 0.96, green: 0.77, blue: 0.70) }
        if selected { return accent.opacity(0.22) }
        return given ? PrismetDesign.panel : Color.white.opacity(0.58)
    }

    private func cellBorder(row: Int, col: Int) -> Color {
        if row == 2 || row == 5 || col == 2 || col == 5 { return PrismetDesign.ink.opacity(0.35) }
        return PrismetDesign.hairline
    }
}
