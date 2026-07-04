// PRISM: RELEASE Agent-Design(wordle) 2026-07-03 - v10 design pass
import SwiftUI
import UIKit

// MARK: - Theme

/// Wordgame-local palette. The letter tracker, board tiles, and leaderboard sheet
/// must stay in lockstep, so the canonical tile colors live here as named tokens.
private enum WordleTheme {
    /// Muted leaf green used by the header and chrome accents.
    static let accent = Color(red: 0.40, green: 0.60, blue: 0.35)

    /// Canonical tile palette (classic Wordle homage) — single source of truth.
    static let correct = Color(red: 0.36, green: 0.62, blue: 0.36)
    static let present = Color(red: 0.84, green: 0.66, blue: 0.22)
    static var absent: Color { Kaleido.isDark ? Color(white: 0.30) : Color(white: 0.55) }

    /// Own-world "classic light" keycap for letters not tried yet.
    static let keyIdle = Color(red: 0.82, green: 0.83, blue: 0.86)
    static let keyIdleInk = Color(red: 0.13, green: 0.14, blue: 0.16)

    static var tileBlank: Color { Kaleido.isDark ? Kaleido.panelHi : Color.white }

    static func score(_ score: WordPuzzleLetterScore) -> Color {
        switch score {
        case .correct: return correct
        case .present: return present
        case .absent: return absent
        }
    }
}

struct WordleView: View {
    private let accountID: UUID?
    @StateObject private var session = WordleSession()
    @State private var shakeRow: Int = 0
    @State private var showScores = false
    @State private var isNativeKeyboardFocused = false

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    private var subtitle: String {
        if session.game.isSolved {
            return "Got it!"
        } else if session.game.isComplete {
            return "The word was \(session.game.answer.uppercased())"
        } else if session.mode == .practice {
            return session.mode.displayName
        } else {
            return "\(session.mode.displayName) · \(WordleSession.displayDateLabel(session.dailyWord.dateLabel))"
        }
    }

    private var wordLength: Int { session.game.answer.count }

    private var practicePromptBinding: Binding<Bool> {
        Binding {
            session.shouldPromptPractice
        } set: { isPresented in
            if !isPresented {
                session.dismissPracticePrompt()
            }
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            GameHeader(
                title: "Wordgame",
                systemImage: "textformat.abc",
                accent: WordleTheme.accent,
                subtitle: subtitle
            ) {
                StatBadge(
                    label: "Guess",
                    value: "\(min(session.game.rows.count + (session.game.isComplete ? 0 : 1), session.game.maxGuesses))/\(session.game.maxGuesses)",
                    accent: WordleTheme.accent
                )
            }

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                board
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .kaleidoCard()

            nativeKeyboardInput

            if !session.message.isEmpty {
                Text(session.message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Kaleido.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minHeight: 18)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            WordleLetterTracker(states: letterStates)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
                .allowsHitTesting(false)
        }
        .facetBackground(WordleTheme.accent)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .contentShape(Rectangle())
        .onTapGesture {
            focusNativeKeyboard()
        }
        .task {
            session.configure(accountID: accountID, cloudStore: .shared)
            await session.loadDailyIfFreshStart()
            focusNativeKeyboard()
        }
        .onDisappear { session.saveNow() }
        .sheet(isPresented: $showScores, onDismiss: focusNativeKeyboard) {
            WordleLeaderboardSheet(mode: session.mode, entries: session.leaderboardEntries)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    loadDaily()
                    focusNativeKeyboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text("Daily")
                    }
                }

                Button {
                    newPractice()
                    focusNativeKeyboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Practice")
                    }
                }

                Button {
                    showScores = true
                    Task { await session.refreshLeaderboard() }
                } label: {
                    Label("Scores", systemImage: "list.number")
                }
            }
        }
        .confirmationDialog(
            "Today's daily puzzle is complete",
            isPresented: practicePromptBinding,
            titleVisibility: .visible
        ) {
            Button("Start Practice") {
                newPractice()
            }
            Button("Keep Results", role: .cancel) {
                session.dismissPracticePrompt()
            }
        } message: {
            Text("You've already finished today's daily puzzle. Start a practice puzzle instead?")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: session.currentGuess)
        .sensoryFeedback(.impact(weight: .light), trigger: session.game.rows.count)
        .sensoryFeedback(.success, trigger: session.game.isSolved)
    }

    // MARK: - Board

    private var board: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 6
            let cols = max(wordLength, 1)
            let rowsCount = session.game.maxGuesses
            let cellW = (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (geo.size.height - spacing * CGFloat(rowsCount - 1)) / CGFloat(rowsCount)
            let cell = min(cellW, cellH)
            let gridW = cell * CGFloat(cols) + spacing * CGFloat(cols - 1)
            let gridH = cell * CGFloat(rowsCount) + spacing * CGFloat(rowsCount - 1)

            VStack(spacing: spacing) {
                ForEach(0..<rowsCount, id: \.self) { rowIndex in
                    HStack(spacing: spacing) {
                        ForEach(0..<cols, id: \.self) { colIndex in
                            tile(row: rowIndex, col: colIndex, size: cell)
                        }
                    }
                    .offset(x: shakeRow == rowIndex ? shakeOffset : 0)
                }
            }
            .frame(width: gridW, height: gridH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }

    @State private var shakeOffset: CGFloat = 0

    private func tile(row: Int, col: Int, size: CGFloat) -> some View {
        let info = tileInfo(row: row, col: col)
        return RoundedRectangle(cornerRadius: max(6, size * 0.16), style: .continuous)
            .fill(info.fill)
            .overlay(
                RoundedRectangle(cornerRadius: max(6, size * 0.16), style: .continuous)
                    .strokeBorder(info.border, lineWidth: 1.5)
            )
            .overlay(
                Text(info.letter)
                    .font(Kaleido.rounded(size * 0.46, .heavy))
                    .foregroundStyle(info.textColor)
                    .minimumScaleFactor(0.5)
            )
            .frame(width: size, height: size)
    }

    private struct TileInfo {
        var letter: String
        var fill: Color
        var border: Color
        var textColor: Color
    }

    private func tileInfo(row: Int, col: Int) -> TileInfo {
        // Submitted rows
        if row < session.game.rows.count {
            let result = session.game.rows[row]
            if col < result.count {
                let cell = result[col]
                let color = scoreColor(cell.score)
                return TileInfo(
                    letter: String(cell.letter).uppercased(),
                    fill: color,
                    border: color,
                    textColor: .white
                )
            }
            return emptyTile()
        }

        // Current in-progress row
        let inProgressRow = session.game.isComplete ? -1 : session.game.rows.count
        if row == inProgressRow {
            let letters = Array(session.currentGuess.uppercased())
            if col < letters.count {
                return TileInfo(
                    letter: String(letters[col]),
                    fill: tileBlank,
                    border: WordleTheme.accent.opacity(0.55),
                    textColor: Kaleido.ink
                )
            }
            return emptyTile()
        }

        return emptyTile()
    }

    /// Best-known state per guessed letter, folded across all completed rows.
    /// Duplicate-letter nuance: one guess can score the same letter `correct`
    /// in one cell and `absent` in another — keep the strongest signal.
    private var letterStates: [Character: WordPuzzleLetterScore] {
        var states: [Character: WordPuzzleLetterScore] = [:]
        func rank(_ s: WordPuzzleLetterScore) -> Int {
            switch s {
            case .correct: return 3
            case .present: return 2
            case .absent: return 1
            }
        }
        for row in session.game.rows {
            for cell in row {
                let key = Character(String(cell.letter).uppercased())
                if let existing = states[key], rank(existing) >= rank(cell.score) { continue }
                states[key] = cell.score
            }
        }
        return states
    }

    private var tileBlank: Color {
        Kaleido.isDark ? Kaleido.panelHi : Color.white
    }

    private func emptyTile() -> TileInfo {
        TileInfo(
            letter: "",
            fill: tileBlank.opacity(Kaleido.isDark ? 0.35 : 0.85),
            border: Kaleido.hairline,
            textColor: Kaleido.ink
        )
    }

    private func scoreColor(_ score: WordPuzzleLetterScore) -> Color {
        switch score {
        case .correct: return Color(red: 0.36, green: 0.62, blue: 0.36)
        case .present: return Color(red: 0.84, green: 0.66, blue: 0.22)
        case .absent:  return Kaleido.isDark ? Color(white: 0.30) : Color(white: 0.55)
        }
    }

    // MARK: - Keyboard

    private var nativeKeyboardInput: some View {
        WordleNativeKeyboardInput(
            isFocused: isNativeKeyboardFocused,
            onTextInput: { text in
                session.appendTextInput(text)
            },
            onDeleteBackward: {
                deleteLetter()
            },
            onSubmit: {
                submitGuess()
            }
        )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
    }

    // MARK: - Actions

    private func deleteLetter() {
        session.deleteLetter()
    }

    private func submitGuess() {
        guard !session.game.isComplete else { return }
        guard session.currentGuess.count == wordLength else {
            triggerShake()
            return
        }
        if !session.submitGuess() {
            triggerShake()
        }
    }

    private func triggerShake() {
        shakeRow = session.game.rows.count
        withAnimation(.default) { shakeOffset = -8 }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.25)) { shakeOffset = 0 }
    }

    private func newPractice() {
        session.startPractice()
        shakeOffset = 0
        focusNativeKeyboard()
    }

    private func loadDaily() {
        if session.canLoadRemoteDaily {
            Task { await session.loadDaily() }
        } else {
            session.startLocalDaily()
        }
    }

    private func focusNativeKeyboard() {
        guard !showScores else { return }
        isNativeKeyboardFocused = true
    }
}

final class NativeKeyboardBackspaceTextField: UITextField {
    var onDeleteBackward: (() -> Void)?

    override func deleteBackward() {
        if text?.isEmpty ?? true {
            onDeleteBackward?()
            return
        }
        super.deleteBackward()
    }
}

// MARK: - Letter tracker (visual keyboard)

/// Sage's v10 feature: a NON-INTERACTIVE QWERTY strip that visualizes which
/// letters have been used and how they scored. Floats as a bottom overlay so
/// it can never resize the guess grid or the native keyboard.
private struct WordleLetterTracker: View {
    let states: [Character: WordPuzzleLetterScore]

    private static let rows: [[Character]] = [
        Array("QWERTYUIOP"), Array("ASDFGHJKL"), Array("ZXCVBNM"),
    ]

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<Self.rows.count, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(Self.rows[r], id: \.self) { letter in
                        key(letter)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Kaleido.isDark ? Color(white: 0.12).opacity(0.92) : Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Kaleido.outline.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        )
        .frame(maxWidth: 430)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func key(_ letter: Character) -> some View {
        let state = states[letter]
        return Text(String(letter))
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(ink(for: state))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fill(for: state))
            )
    }

    private func fill(for state: WordPuzzleLetterScore?) -> Color {
        switch state {
        case .correct: return WordleTheme.correct
        case .present: return WordleTheme.present
        case .absent: return WordleTheme.absent.opacity(Kaleido.isDark ? 0.55 : 0.85)
        case nil: return WordleTheme.keyIdle
        }
    }

    private func ink(for state: WordPuzzleLetterScore?) -> Color {
        state == nil ? WordleTheme.keyIdleInk : .white
    }

    private var accessibilitySummary: String {
        let correct = states.filter { $0.value == .correct }.keys.sorted().map(String.init).joined(separator: ", ")
        let present = states.filter { $0.value == .present }.keys.sorted().map(String.init).joined(separator: ", ")
        let absent = states.filter { $0.value == .absent }.keys.sorted().map(String.init).joined(separator: ", ")
        var parts: [String] = []
        if !correct.isEmpty { parts.append("Correct: \(correct)") }
        if !present.isEmpty { parts.append("In the word: \(present)") }
        if !absent.isEmpty { parts.append("Not in the word: \(absent)") }
        return parts.isEmpty ? "Letter tracker: no guesses yet" : "Letter tracker. " + parts.joined(separator: ". ")
    }
}

private struct WordleNativeKeyboardInput: UIViewRepresentable {
    var isFocused: Bool
    var onTextInput: (String) -> Void
    var onDeleteBackward: () -> Void
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> NativeKeyboardBackspaceTextField {
        let field = NativeKeyboardBackspaceTextField(frame: .zero)
        field.delegate = context.coordinator
        field.autocapitalizationType = .allCharacters
        field.autocorrectionType = .no
        field.keyboardType = .alphabet
        field.returnKeyType = .done
        field.textColor = .clear
        field.tintColor = .clear
        field.backgroundColor = .clear
        field.onDeleteBackward = {
            context.coordinator.handleDeleteBackward()
        }
        return field
    }

    func updateUIView(_ field: NativeKeyboardBackspaceTextField, context: Context) {
        context.coordinator.onTextInput = onTextInput
        context.coordinator.onDeleteBackward = onDeleteBackward
        context.coordinator.onSubmit = onSubmit

        if isFocused && !field.isFirstResponder {
            DispatchQueue.main.async {
                field.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTextInput: onTextInput,
            onDeleteBackward: onDeleteBackward,
            onSubmit: onSubmit
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var onTextInput: (String) -> Void
        var onDeleteBackward: () -> Void
        var onSubmit: () -> Void

        init(
            onTextInput: @escaping (String) -> Void,
            onDeleteBackward: @escaping () -> Void,
            onSubmit: @escaping () -> Void
        ) {
            self.onTextInput = onTextInput
            self.onDeleteBackward = onDeleteBackward
            self.onSubmit = onSubmit
        }

        func handleDeleteBackward() {
            onDeleteBackward()
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            if string.isEmpty {
                onDeleteBackward()
            } else {
                onTextInput(string)
            }
            textField.text = ""
            return false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
        }
    }
}

private struct WordleLeaderboardSheet: View {
    let mode: WordleMode
    let entries: [WordleLeaderboardEntry]

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No scores yet",
                        systemImage: "list.number",
                        description: Text("Solved \(mode.displayName.lowercased()) games will appear here.")
                    )
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(WordleTheme.accent)
                                .frame(width: 28, alignment: .trailing)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.sourceName)
                                    .font(.subheadline.weight(.semibold))
                                Text(entry.dateLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(entry.guesses)/\(entry.maxGuesses)")
                                .font(.headline.monospacedDigit())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("\(mode.displayName) Scores")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
