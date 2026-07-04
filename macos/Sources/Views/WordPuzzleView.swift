import SwiftUI
import UniformTypeIdentifiers

struct WordPuzzleView: View {
    @ObservedObject var session: WordPuzzleSession
    @FocusState private var keyboardFocused: Bool
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument = WordPuzzleFileDocument(snapshot: .placeholder)

    private let keyboardRows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["ENTER", "Z", "X", "C", "V", "B", "N", "M", "DEL"]
    ]

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            puzzleSurface
            controlsPanel
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.wordlePage)
        .environment(\.colorScheme, .light)
        .focusable()
        .focusEffectDisabled()
        .focused($keyboardFocused)
        .onKeyPress(action: handlePhysicalKey)
        .onAppear { keyboardFocused = true }
        .fileExporter(isPresented: $isExporting,
                      document: exportDocument,
                      contentType: .json,
                      defaultFilename: "wordgame-save") { _ in }
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
    }

    private var puzzleSurface: some View {
        VStack(spacing: 18) {
            Text("Wordgame")
                .font(.system(size: 42, weight: .heavy, design: .serif))
                .foregroundStyle(Color.wordleInk)
                .padding(.bottom, 6)

            board
            keyboard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var board: some View {
        VStack(spacing: 5) {
            ForEach(0..<session.game.maxGuesses, id: \.self) { rowIndex in
                HStack(spacing: 5) {
                    ForEach(0..<max(session.game.answer.count, 1), id: \.self) { colIndex in
                        letterTile(row: rowIndex, col: colIndex)
                    }
                }
            }
        }
        .frame(width: 320, height: 392)
    }

    private var keyboard: some View {
        VStack(spacing: 6) {
            ForEach(keyboardRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(keyboardRows[rowIndex], id: \.self) { key in
                        keyboardButton(key)
                    }
                }
            }
        }
        .frame(width: 520)
    }

    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Daily Word")
                .font(.title2.bold())
                .foregroundStyle(Color.wordleInk)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.dailyWord.source.displayName)
                    .font(.headline)
                Text(session.dailyWord.dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(session.message)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44, alignment: .topLeading)

            Text("Just type - Return submits, Delete fixes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Submit", action: session.submitGuess)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                Button("Reset") {
                    session.resetGame(with: session.dailyWord, message: "Puzzle reset.")
                }
            }

            HStack(spacing: 8) {
                Button("Save") { session.saveNow() }
                Button("Load") { session.reloadSavedState() }
                Button("Export") {
                    exportDocument = session.exportableDocument()
                    isExporting = true
                }
                Button("Import") {
                    isImporting = true
                }
            }
            .buttonStyle(.bordered)

            Divider()

            Text("New Game")
                .font(.headline)
            HStack {
                Button {
                    session.loadBrokerDaily()
                } label: {
                    Label("Daily", systemImage: "calendar")
                }
                .disabled(session.isLoadingDaily)

                Button {
                    session.newRandomGame()
                } label: {
                    Label("Random", systemImage: "shuffle")
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Local Daily") {
                session.loadLocalDaily()
            }
            .controlSize(.small)

            Text(session.isLoadingDaily
                 ? "Fetching today's daily word..."
                 : "Daily = today's brokered puzzle. Random = a fresh puzzle each click.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                legendRow(color: .wordleCorrect, text: "right letter, right spot")
                legendRow(color: .wordlePresent, text: "right letter, wrong spot")
                legendRow(color: .wordleAbsent, text: "not in the word")
            }

            Spacer()
        }
        .frame(width: 300)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.wordleBorder, lineWidth: 1))
    }

    private var canSubmit: Bool {
        session.guess.count == session.game.answer.count && !session.game.isComplete
    }

    private func letterTile(row: Int, col: Int) -> some View {
        // Guard the column too: a restored/imported snapshot whose answer isn't 5
        // letters yields rows narrower than the board, so `rows[row][col]` would
        // index out of range and crash.
        let result = (row < session.game.rows.count && col < session.game.rows[row].count)
            ? session.game.rows[row][col] : nil
        let activeLetter = row == session.game.rows.count ? characterInGuess(at: col) : ""
        let character = result.map { String($0.letter).uppercased() } ?? activeLetter
        let isSubmitted = result != nil
        let color = result?.score.tileColor ?? Color.white
        let borderColor = character.isEmpty ? Color.wordleBorder : Color.wordleActiveBorder

        return Text(character)
            .font(.system(size: 30, weight: .heavy, design: .default))
            .foregroundStyle(isSubmitted ? Color.white : Color.wordleInk)
            .frame(width: 58, height: 58)
            .background(color)
            .overlay(Rectangle().stroke(borderColor, lineWidth: 2))
    }

    private func keyboardButton(_ key: String) -> some View {
        let score = key.count == 1 ? keyScore(for: Character(key.lowercased())) : nil
        let isWide = key.count > 1

        return Button {
            handleKey(key)
        } label: {
            Text(key)
                .font(.system(size: isWide ? 12 : 15, weight: .bold))
                .foregroundStyle(score == nil ? Color.wordleInk : Color.white)
                .frame(width: isWide ? 68 : 42, height: 48)
                .background(score?.tileColor ?? Color.wordleKey)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(session.game.isComplete && key != "DEL")
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack {
            Rectangle().fill(color).frame(width: 24, height: 24)
            Text(text)
        }
        .font(.caption)
    }

    private func handleKey(_ key: String) {
        session.handleKey(key)
        keyboardFocused = true
    }

    private func handlePhysicalKey(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .return || press.characters == "\r" || press.characters == "\n" {
            handleKey("ENTER")
            return .handled
        }
        if press.key == .delete || press.characters == "\u{7F}" || press.characters == "\u{08}" {
            handleKey("DEL")
            return .handled
        }
        if let ch = press.characters.first, press.characters.count == 1, ch.isLetter {
            handleKey(String(ch).uppercased())
            return .handled
        }
        return .ignored
    }

    private func characterInGuess(at index: Int) -> String {
        guard !session.game.isComplete, index < session.guess.count else { return "" }
        let letters = Array(session.guess.uppercased())
        return String(letters[index])
    }

    private func keyScore(for letter: Character) -> WordPuzzleLetterScore? {
        var bestScore: WordPuzzleLetterScore?
        for row in session.game.rows {
            for result in row where result.letter == letter {
                switch result.score {
                case .correct:
                    return .correct
                case .present:
                    bestScore = .present
                case .absent:
                    if bestScore == nil {
                        bestScore = .absent
                    }
                }
            }
        }
        return bestScore
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            session.importSnapshot(from: url)
        } catch {
            session.message = "Import failed."
        }
    }
}

private extension WordPuzzleLetterScore {
    var tileColor: Color {
        switch self {
        case .correct: return .wordleCorrect
        case .present: return .wordlePresent
        case .absent: return .wordleAbsent
        }
    }
}

private extension Color {
    static let wordlePage = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let wordleInk = Color(red: 0.12, green: 0.14, blue: 0.16)
    static let wordleBorder = Color(red: 0.83, green: 0.84, blue: 0.85)
    static let wordleActiveBorder = Color(red: 0.52, green: 0.54, blue: 0.56)
    static let wordleKey = Color(red: 0.82, green: 0.84, blue: 0.85)
    static let wordleCorrect = Color(red: 0.42, green: 0.67, blue: 0.39)
    static let wordlePresent = Color(red: 0.79, green: 0.71, blue: 0.35)
    static let wordleAbsent = Color(red: 0.47, green: 0.49, blue: 0.49)
}
