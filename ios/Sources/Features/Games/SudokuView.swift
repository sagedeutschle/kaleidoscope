// PRISM: RELEASE Agent-Design(sudoku) 2026-07-03 — v10 design pass
import SwiftUI

// MARK: - Theme ("The Newspaper Pencil Puzzle")

/// Game-local material palette. Sudoku here is the puzzle you tear out of the
/// Sunday paper: warm newsprint stock set into a slate press frame, the "given"
/// clues struck in crisp typeset serif *ink*, your own answers written in a
/// softer graphite *pencil* hand, and candidates jotted as tiny margin marks.
///
/// The signature is that printed-vs-penciled type distinction; every other
/// choice (paper tone, engraved box rules, a warm graphite highlight) stays
/// quiet so the two hands carry the world. Adapts to the active Kaleido paper:
/// on dark stock the newsprint becomes an engraved slate and the ink turns
/// chalk-white, so the same puzzle reads as "printed vs penciled" either way.
private struct SudokuTheme {
    var accent: Color          // masthead + selection warmth (muted, not app-loud)
    var paper: Color           // newsprint field the grid is printed on
    var paperEdge: Color       // subtle press-vignette toward the edges
    var frame: Color           // slate press border around the sheet
    var frameEdge: Color
    var rule: Color            // heavy 3x3 press rules
    var hairline: Color        // fine cell rules
    var inkGiven: Color        // typeset serif clues (the "printed" hand)
    var pencilLead: Color      // the player's graphite entries
    var pencilNote: Color      // faint margin candidate marks
    var conflict: Color        // red editor's mark on a clash
    var selectFill: Color      // warm wash under the caret cell
    var sameFill: Color        // lighter wash on matching numbers
    var peerFill: Color        // faintest wash down the row/col/box

    static var current: SudokuTheme {
        Kaleido.isDark ? .slate : .newsprint
    }

    /// Warm off-white newsprint with charcoal ink — the daily-paper default.
    static let newsprint = SudokuTheme(
        accent: Color(red: 0.62, green: 0.31, blue: 0.28),
        paper: Color(red: 0.960, green: 0.945, blue: 0.912),
        paperEdge: Color(red: 0.902, green: 0.876, blue: 0.822),
        frame: Color(red: 0.205, green: 0.195, blue: 0.190),
        frameEdge: Color(red: 0.110, green: 0.104, blue: 0.100),
        rule: Color(red: 0.145, green: 0.135, blue: 0.128),
        hairline: Color(red: 0.36, green: 0.33, blue: 0.30).opacity(0.42),
        inkGiven: Color(red: 0.105, green: 0.095, blue: 0.085),
        pencilLead: Color(red: 0.315, green: 0.335, blue: 0.400),
        pencilNote: Color(red: 0.40, green: 0.42, blue: 0.48).opacity(0.85),
        conflict: Color(red: 0.760, green: 0.180, blue: 0.155),
        selectFill: Color(red: 0.85, green: 0.62, blue: 0.34).opacity(0.26),
        sameFill: Color(red: 0.60, green: 0.52, blue: 0.32).opacity(0.16),
        peerFill: Color(red: 0.40, green: 0.36, blue: 0.28).opacity(0.075)
    )

    /// Engraved slate: dark pressed stone, clues struck in chalk-white ink,
    /// answers in a cooler pencil lead. Same two hands, night edition.
    static let slate = SudokuTheme(
        accent: Color(red: 0.80, green: 0.50, blue: 0.42),
        paper: Color(red: 0.120, green: 0.128, blue: 0.170),
        paperEdge: Color(red: 0.070, green: 0.076, blue: 0.112),
        frame: Color(red: 0.055, green: 0.060, blue: 0.090),
        frameEdge: Color(red: 0.028, green: 0.032, blue: 0.055),
        rule: Color(red: 0.72, green: 0.74, blue: 0.82).opacity(0.85),
        hairline: Color.white.opacity(0.14),
        inkGiven: Color(red: 0.955, green: 0.965, blue: 0.990),
        pencilLead: Color(red: 0.60, green: 0.66, blue: 0.78),
        pencilNote: Color(red: 0.56, green: 0.60, blue: 0.72).opacity(0.90),
        conflict: Color(red: 0.945, green: 0.360, blue: 0.315),
        selectFill: Color(red: 0.85, green: 0.55, blue: 0.40).opacity(0.30),
        sameFill: Color(red: 0.80, green: 0.56, blue: 0.42).opacity(0.20),
        peerFill: Color.white.opacity(0.055)
    )
}

struct SudokuView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let accountID: UUID?
    @StateObject private var persistence = PersistedGameSession<SudokuSnapshot>(gameID: .sudoku)
    @State private var game = SudokuGame.standardPuzzle()
    @State private var rng = SeededGenerator(seed: 9)
    @State private var selectedRow: Int? = nil
    @State private var selectedCol: Int? = nil

    // Difficulty persists across launches; drives which puzzle bank "New Game" draws from.
    @AppStorage("sudoku.difficulty") private var difficultyRaw = SudokuDifficulty.easy.rawValue

    // Pencil-notes mode: when on, tapping a number toggles a candidate instead of placing.
    // Session-scoped (not persisted) — a UI mode, not board state.
    @State private var notesMode = false

    // Haptic triggers
    @State private var moveCounter = 0
    @State private var conflictTrigger = false
    @State private var didSolve = false

    private var difficulty: SudokuDifficulty {
        SudokuDifficulty(rawValue: difficultyRaw) ?? .easy
    }

    private var theme: SudokuTheme { .current }
    private var accent: Color { theme.accent }

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    private var filledCount: Int {
        var n = 0
        for r in 0..<SudokuGame.size {
            for c in 0..<SudokuGame.size where game.value(row: r, col: c) != 0 { n += 1 }
        }
        return n
    }

    private var subtitle: String {
        if game.isComplete { return "Solved — final edition" }
        return notesMode ? "Pencil: tap a cell, then candidates" : "Ink: tap a cell, then a number"
    }

    // The value in the currently selected cell (0 if none / empty).
    private var selectedValue: Int {
        guard let r = selectedRow, let c = selectedCol else { return 0 }
        return game.value(row: r, col: c)
    }

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(title: "Sudoku", systemImage: "newspaper.fill", accent: accent, subtitle: subtitle) {
                HStack(spacing: 16) {
                    StatBadge(label: "Filled", value: "\(filledCount)/81", accent: accent)
                    StatBadge(label: "Edition", value: difficulty.label, accent: accent)
                }
            }

            masthead

            difficultyPicker

            board

            numberPad

            HStack(spacing: 12) {
                Button { newGame() } label: {
                    Label("New Edition", systemImage: "newspaper")
                }
                .buttonStyle(AccentButtonStyle(accent: accent))

                Button { resetGame() } label: {
                    Label("Clear Sheet", systemImage: "eraser")
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent)
        .navigationTitle("Sudoku")
        .navigationBarTitleDisplayMode(.inline)
        // Light tap on each number entry / clear / cell change.
        .sensoryFeedback(.impact(weight: .light), trigger: moveCounter)
        // Error buzz when an entry creates a conflict.
        .sensoryFeedback(.error, trigger: conflictTrigger)
        // Success when the puzzle is fully and correctly solved.
        .sensoryFeedback(.success, trigger: didSolve)
        .onAppear {
            persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
        }
        .onDisappear { save(forceCloud: true) }
    }

    // Newspaper masthead: a small-caps dateline kicker over a double press rule,
    // the way a puzzle column is titled in the paper. Purely decorative.
    private var masthead: some View {
        VStack(spacing: 5) {
            HStack {
                Text("THE DAILY GRID")
                    .font(.system(size: 11, weight: .heavy, design: .serif))
                    .tracking(2.2)
                    .foregroundStyle(Kaleido.ink2)
                Spacer()
                Text(game.isComplete ? "COMPLETE" : "NO. \(filledCount)")
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .tracking(1.6)
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
            VStack(spacing: 2) {
                Rectangle().fill(Kaleido.ink2.opacity(0.55)).frame(height: 1.5)
                Rectangle().fill(Kaleido.ink2.opacity(0.35)).frame(height: 0.75)
            }
        }
        .accessibilityHidden(true)
    }

    private var board: some View {
        GeometryReader { geo in
            let full = min(geo.size.width, geo.size.height)
            // The slate press frame wraps a printed newsprint sheet.
            let frameW = max(7, full * 0.028)
            let side = full - frameW * 2
            let cell = side / CGFloat(SudokuGame.size)

            ZStack {
                // Slate press frame.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(colors: [theme.frame, theme.frameEdge],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.35), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .inset(by: 1.5)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.30), radius: 14, y: 8)

                ZStack {
                    // Newsprint sheet with a faint press vignette toward the edges.
                    Rectangle()
                        .fill(theme.paper)
                        .overlay(
                            RadialGradient(
                                colors: [.clear, theme.paperEdge.opacity(0.9)],
                                center: .center,
                                startRadius: side * 0.34,
                                endRadius: side * 0.72
                            )
                        )

                    // Cells (printed numbers, penciled answers & candidates)
                    ForEach(0..<SudokuGame.size, id: \.self) { r in
                        ForEach(0..<SudokuGame.size, id: \.self) { c in
                            cellView(row: r, col: c, size: cell)
                                .frame(width: cell, height: cell)
                                .position(x: cell * (CGFloat(c) + 0.5), y: cell * (CGFloat(r) + 0.5))
                        }
                    }
                    // Press rules (heavy dividers between the 3x3 boxes)
                    gridLines(cell: cell, side: side)
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(theme.rule, lineWidth: 2.5)
                )
            }
            .frame(width: full, height: full)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var difficultyPicker: some View {
        // Changing the difficulty deals a fresh puzzle at that level.
        let selection = Binding<SudokuDifficulty>(
            get: { difficulty },
            set: { newValue in
                guard newValue != difficulty else { return }
                difficultyRaw = newValue.rawValue
                newGame()
            }
        )
        return Picker("Difficulty", selection: selection) {
            ForEach(SudokuDifficulty.allCases) { level in
                Text(level.label).tag(level)
            }
        }
        .pickerStyle(.segmented)
    }

    // Does the cell at (r, c) share the selected cell's row, column, or 3x3 box?
    private func isPeer(row r: Int, col c: Int) -> Bool {
        guard let sr = selectedRow, let sc = selectedCol else { return false }
        if r == sr || c == sc { return true }
        return (r / 3 == sr / 3) && (c / 3 == sc / 3)
    }

    // Does the cell at (r, c) hold the same (non-zero) number as the selected cell?
    private func isSameNumber(row r: Int, col c: Int) -> Bool {
        let v = selectedValue
        guard v != 0 else { return false }
        if r == selectedRow && c == selectedCol { return false }
        return game.value(row: r, col: c) == v
    }

    private func cellView(row r: Int, col c: Int, size: CGFloat) -> some View {
        let v = game.value(row: r, col: c)
        let given = game.isGiven(row: r, col: c)
        let conflict = v != 0 && game.hasConflict(row: r, col: c)
        let isSelected = (selectedRow == r && selectedCol == c)
        let peer = !isSelected && isPeer(row: r, col: c)
        let sameNumber = !isSelected && isSameNumber(row: r, col: c)

        // THE SIGNATURE: two hands. Given clues are struck in a typeset serif
        // "ink"; the player's answers are written in a softer graphite "pencil".
        let textColor: Color = {
            if conflict { return theme.conflict }
            return given ? theme.inkGiven : theme.pencilLead
        }()

        // Editor's washes: a warm graphite tint on the caret cell, lighter on
        // matching numbers, faintest down the row/col/box. Given/answer cells
        // stay on the bare newsprint so the paper reads through.
        let fill: Color = {
            if isSelected { return theme.selectFill }
            if sameNumber { return theme.sameFill }
            if peer { return theme.peerFill }
            return .clear
        }()

        let cellNotes = game.notes(row: r, col: c)

        return ZStack {
            Rectangle()
                .fill(fill)
            if v != 0 {
                if given {
                    // Printed at the press: crisp serif, full ink weight.
                    Text("\(v)")
                        .font(.system(size: size * 0.54, weight: .bold, design: .serif))
                        .monospacedDigit()
                        .foregroundColor(textColor)
                } else {
                    // The reader's own hand: rounded graphite pencil, lighter.
                    Text("\(v)")
                        .font(.system(size: size * 0.50, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(textColor)
                }
            } else if !cellNotes.isEmpty {
                notesGrid(cellNotes, size: size)
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(theme.hairline, lineWidth: 0.6)
        )
        // A pencil caret ring on the selected cell — reads as a hand-drawn box.
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .inset(by: 1.5)
                    .strokeBorder(accent.opacity(0.9), lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.16)) {
                selectedRow = r
                selectedCol = c
            }
            save()
        }
    }

    // Penciled candidates: tiny graphite margin marks in a 3x3 mini-grid, set in
    // the same rounded pencil hand as the player's answers (just smaller/fainter).
    private func notesGrid(_ marks: Set<Int>, size: CGFloat) -> some View {
        let noteFont = Font.system(size: size * 0.19, weight: .regular, design: .rounded)
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { col in
                        let candidate = row * 3 + col + 1
                        Text(marks.contains(candidate) ? "\(candidate)" : " ")
                            .font(noteFont)
                            .monospacedDigit()
                            .foregroundColor(theme.pencilNote)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(size * 0.06)
        .allowsHitTesting(false)
    }

    // Engraved rules: fine cell hairlines everywhere, heavy press rules on the
    // 3x3 box boundaries (the outer edge is drawn by the sheet's border overlay).
    private func gridLines(cell: CGFloat, side: CGFloat) -> some View {
        ZStack {
            ForEach(1..<SudokuGame.size, id: \.self) { i in
                let thick = (i % 3 == 0)
                let pos = cell * CGFloat(i)
                let color = thick ? theme.rule : theme.hairline
                let w: CGFloat = thick ? 2.5 : 0.6
                // Vertical
                Rectangle()
                    .fill(color)
                    .frame(width: w, height: side)
                    .position(x: pos, y: side / 2)
                // Horizontal
                Rectangle()
                    .fill(color)
                    .frame(width: side, height: w)
                    .position(x: side / 2, y: pos)
            }
        }
        .allowsHitTesting(false)
    }

    private var numberPad: some View {
        VStack(spacing: 10) {
            notesToggle
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { n in padButton(n) }
            }
            HStack(spacing: 8) {
                ForEach(6...9, id: \.self) { n in padButton(n) }
                clearButton
            }
        }
    }

    // A newsprint pad-key face: a printed paper chip with a fine rule. Tinted
    // graphite when it's "on" (notes armed / a set candidate).
    private func keyFace<Content: View>(tinted: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tinted ? AnyShapeStyle(theme.selectFill) : AnyShapeStyle(theme.paper))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(tinted ? accent.opacity(0.7) : theme.hairline, lineWidth: tinted ? 1.5 : 1)
            )
    }

    // Ink/Pencil toggle: switches the pad between striking values in ink and
    // jotting pencil candidates. The label speaks the two-hands vocabulary.
    private var notesToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.16)) { notesMode.toggle() }
            moveCounter += 1
        } label: {
            keyFace(tinted: notesMode) {
                Label(notesMode ? "Pencil (notes)" : "Ink (answers)",
                      systemImage: notesMode ? "pencil" : "pencil.tip")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundColor(notesMode ? theme.pencilLead : theme.inkGiven)
            }
        }
        .accessibilityLabel("Notes mode")
        .accessibilityValue(notesMode ? "On" : "Off")
    }

    private func padButton(_ n: Int) -> some View {
        // In notes mode a digit is active when the selected cell is empty & editable.
        let active = notesMode ? canToggleNote : canPlace
        let noted = notesMode && isNoteSet(n)
        return Button {
            if notesMode {
                toggleNote(n)
            } else {
                place(n)
            }
        } label: {
            keyFace(tinted: noted) {
                // The key digit is set in whichever hand it will write: serif ink
                // when placing answers, rounded pencil when jotting candidates.
                Text("\(n)")
                    .font(notesMode
                          ? .system(size: 21, weight: .medium, design: .rounded)
                          : .system(size: 22, weight: .semibold, design: .serif))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundColor(active ? (notesMode ? theme.pencilLead : theme.inkGiven)
                                            : theme.inkGiven.opacity(0.30))
            }
        }
        .disabled(!active)
    }

    private var clearButton: some View {
        Button {
            place(0)
        } label: {
            keyFace(tinted: false) {
                Image(systemName: "eraser")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundColor(canPlace ? accent : theme.inkGiven.opacity(0.30))
            }
        }
        .disabled(!canPlace)
    }

    private var canPlace: Bool {
        guard let r = selectedRow, let c = selectedCol else { return false }
        return !game.isGiven(row: r, col: c)
    }

    // A note can be toggled only on a selected, editable, currently-empty cell.
    private var canToggleNote: Bool {
        guard let r = selectedRow, let c = selectedCol else { return false }
        return !game.isGiven(row: r, col: c) && game.value(row: r, col: c) == 0
    }

    private func isNoteSet(_ n: Int) -> Bool {
        guard let r = selectedRow, let c = selectedCol else { return false }
        return game.notes(row: r, col: c).contains(n)
    }

    private func toggleNote(_ n: Int) {
        guard let r = selectedRow, let c = selectedCol else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.16)) {
            game.toggleNote(n, row: r, col: c)
        }
        moveCounter += 1
        save()
    }

    private func place(_ n: Int) {
        guard let r = selectedRow, let c = selectedCol else { return }
        guard !game.isGiven(row: r, col: c) else { return }

        withAnimation(reduceMotion ? nil : .snappy(duration: 0.16)) {
            game.setValue(n, row: r, col: c)
        }

        // Light tap for every entry / clear.
        moveCounter += 1

        // Error buzz if this entry now conflicts with a peer.
        if n != 0 && game.hasConflict(row: r, col: c) {
            conflictTrigger.toggle()
        }

        // Success when the board is fully and correctly solved.
        if game.isComplete {
            didSolve.toggle()
        }
        save(forceCloud: game.isComplete)
    }

    private func newGame() {
        // Draw a different curated puzzle at the chosen difficulty.
        let puzzle = SudokuPuzzleBank.random(
            for: difficulty,
            excludingGivens: game.puzzle,
            using: &rng
        )
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.16)) {
            game = SudokuGame(puzzle)
            selectedRow = nil
            selectedCol = nil
        }
        moveCounter += 1
        save(forceCloud: true)
    }

    private func resetGame() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.16)) {
            game.reset()
            selectedRow = nil
            selectedCol = nil
        }
        moveCounter += 1
        save(forceCloud: true)
    }

    private func snapshot() -> SudokuSnapshot {
        SudokuSnapshot(game: game, rng: rng, selectedRow: selectedRow, selectedCol: selectedCol)
    }

    private func restore(_ snapshot: SudokuSnapshot) {
        game = snapshot.game
        rng = snapshot.rng
        selectedRow = snapshot.selectedRow
        selectedCol = snapshot.selectedCol
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: filledCount, forceCloud: forceCloud)
    }
}
