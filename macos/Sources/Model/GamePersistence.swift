import Foundation
import SwiftUI
import UniformTypeIdentifiers

// PRISM: RELEASE Agent-B 2026-06-27 — simple puzzle persistence/input congruency

private enum PersistenceJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum GamePersistenceKind: String, CaseIterable, Codable {
    case chess
    case wordPuzzle
    case legoBuilder
    case minesweeper
    case game2048
    case lightsOut
    case snake
    case sudoku
    case slidingPuzzle
    case nonogram
    case reversi
    case connectFour
    case checkers
    case rubiksCube

    var fileName: String {
        switch self {
        case .chess: return "chess.json"
        case .wordPuzzle: return "word-puzzle.json"
        case .legoBuilder: return "lego-builder.json"
        case .minesweeper: return "minesweeper.json"
        case .game2048: return "2048.json"
        case .lightsOut: return "lights-out.json"
        case .snake: return "snake.json"
        case .sudoku: return "sudoku.json"
        case .slidingPuzzle: return "sliding-puzzle.json"
        case .nonogram: return "nonogram.json"
        case .reversi: return "reversi.json"
        case .connectFour: return "connect-four.json"
        case .checkers: return "checkers.json"
        case .rubiksCube: return "rubiks-cube.json"
        }
    }
}

struct ChessUndoEntry: Codable, Hashable {
    var position: Position
    var lastMove: Move?
    var status: GameStatus
}

struct ChessGameSnapshot: Codable, Hashable {
    var version: Int
    var position: Position
    var status: GameStatus
    var lastMove: Move?
    var selectedSquare: Square?
    var vsComputer: Bool
    var humanColor: PieceColor
    var aiLevel: Int
    var undoStack: [ChessUndoEntry]
    var positionHistory: [Position]

    static var placeholder: ChessGameSnapshot {
        ChessGameSnapshot(version: 1,
                          position: .initial,
                          status: .ongoing,
                          lastMove: nil,
                          selectedSquare: nil,
                          vsComputer: true,
                          humanColor: .white,
                          aiLevel: 5,
                          undoStack: [],
                          positionHistory: [.initial])
    }
}

struct WordPuzzleSessionSnapshot: Codable, Hashable {
    var version: Int
    var dailyWord: DailyWord
    var game: WordPuzzleGame
    var guess: String
    var message: String
    var isLoadingDaily: Bool

    static var placeholder: WordPuzzleSessionSnapshot {
        let answer = "cider"
        return WordPuzzleSessionSnapshot(version: 1,
                                         dailyWord: DailyWord(answer: answer, dateLabel: "—", source: .localDaily),
                                         game: WordPuzzleGame(answer: answer, allowedWords: [answer]),
                                         guess: "",
                                         message: "Guess the hidden word.",
                                         isLoadingDaily: false)
    }
}

struct WordPuzzleSessionState: Hashable {
    var dailyWord: DailyWord
    var game: WordPuzzleGame
    var guess: String
    var message: String
    var isLoadingDaily: Bool

    init(dailyWord: DailyWord, game: WordPuzzleGame, guess: String, message: String, isLoadingDaily: Bool) {
        self.dailyWord = dailyWord
        self.game = game
        self.guess = guess
        self.message = message
        self.isLoadingDaily = isLoadingDaily
    }

    init(snapshot: WordPuzzleSessionSnapshot) {
        self.init(dailyWord: snapshot.dailyWord,
                  game: snapshot.game,
                  guess: snapshot.guess,
                  message: snapshot.message,
                  isLoadingDaily: false)   // transient: never restore a mid-fetch spinner
    }

    var snapshot: WordPuzzleSessionSnapshot {
        WordPuzzleSessionSnapshot(version: 1,
                                  dailyWord: dailyWord,
                                  game: game,
                                  guess: guess,
                                  message: message,
                                  isLoadingDaily: isLoadingDaily)
    }
}

final class GamePersistenceStore {
    static let shared = GamePersistenceStore()

    let rootURL: URL

    init(rootURL: URL = GamePersistenceStore.defaultRootURL()) {
        self.rootURL = rootURL
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func saveChess(_ snapshot: ChessGameSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .chess, windowSessionID: windowSessionID))
    }

    func loadChess(windowSessionID: String) throws -> ChessGameSnapshot? {
        try load(ChessGameSnapshot.self, from: url(for: .chess, windowSessionID: windowSessionID))
    }

    func saveWordPuzzle(_ snapshot: WordPuzzleSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .wordPuzzle, windowSessionID: windowSessionID))
    }

    func loadWordPuzzle(windowSessionID: String) throws -> WordPuzzleSessionSnapshot? {
        try load(WordPuzzleSessionSnapshot.self, from: url(for: .wordPuzzle, windowSessionID: windowSessionID))
    }

    func saveLegoBuilder(_ snapshot: LegoBuilderSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .legoBuilder, windowSessionID: windowSessionID))
    }

    func loadLegoBuilder(windowSessionID: String) throws -> LegoBuilderSnapshot? {
        try load(LegoBuilderSnapshot.self, from: url(for: .legoBuilder, windowSessionID: windowSessionID))
    }

    func saveMinesweeper(_ snapshot: MinesweeperSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .minesweeper, windowSessionID: windowSessionID))
    }

    func loadMinesweeper(windowSessionID: String) throws -> MinesweeperSessionSnapshot? {
        try load(MinesweeperSessionSnapshot.self, from: url(for: .minesweeper, windowSessionID: windowSessionID))
    }

    func saveGame2048(_ snapshot: Game2048SessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .game2048, windowSessionID: windowSessionID))
    }

    func loadGame2048(windowSessionID: String) throws -> Game2048SessionSnapshot? {
        try load(Game2048SessionSnapshot.self, from: url(for: .game2048, windowSessionID: windowSessionID))
    }

    func saveLightsOut(_ snapshot: LightsOutSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .lightsOut, windowSessionID: windowSessionID))
    }

    func loadLightsOut(windowSessionID: String) throws -> LightsOutSessionSnapshot? {
        try load(LightsOutSessionSnapshot.self, from: url(for: .lightsOut, windowSessionID: windowSessionID))
    }

    func saveSnake(_ snapshot: SnakeSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .snake, windowSessionID: windowSessionID))
    }

    func loadSnake(windowSessionID: String) throws -> SnakeSessionSnapshot? {
        try load(SnakeSessionSnapshot.self, from: url(for: .snake, windowSessionID: windowSessionID))
    }

    func saveSudoku(_ snapshot: SudokuSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .sudoku, windowSessionID: windowSessionID))
    }

    func loadSudoku(windowSessionID: String) throws -> SudokuSessionSnapshot? {
        try load(SudokuSessionSnapshot.self, from: url(for: .sudoku, windowSessionID: windowSessionID))
    }

    func saveSlidingPuzzle(_ snapshot: SlidingPuzzleSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .slidingPuzzle, windowSessionID: windowSessionID))
    }

    func loadSlidingPuzzle(windowSessionID: String) throws -> SlidingPuzzleSessionSnapshot? {
        try load(SlidingPuzzleSessionSnapshot.self, from: url(for: .slidingPuzzle, windowSessionID: windowSessionID))
    }

    func saveNonogram(_ snapshot: NonogramSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .nonogram, windowSessionID: windowSessionID))
    }

    func loadNonogram(windowSessionID: String) throws -> NonogramSessionSnapshot? {
        try load(NonogramSessionSnapshot.self, from: url(for: .nonogram, windowSessionID: windowSessionID))
    }

    func saveReversi(_ snapshot: ReversiSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .reversi, windowSessionID: windowSessionID))
    }

    func loadReversi(windowSessionID: String) throws -> ReversiSessionSnapshot? {
        try load(ReversiSessionSnapshot.self, from: url(for: .reversi, windowSessionID: windowSessionID))
    }

    func saveConnectFour(_ snapshot: ConnectFourSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .connectFour, windowSessionID: windowSessionID))
    }

    func loadConnectFour(windowSessionID: String) throws -> ConnectFourSessionSnapshot? {
        try load(ConnectFourSessionSnapshot.self, from: url(for: .connectFour, windowSessionID: windowSessionID))
    }

    func saveCheckers(_ snapshot: CheckersSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .checkers, windowSessionID: windowSessionID))
    }

    func loadCheckers(windowSessionID: String) throws -> CheckersSessionSnapshot? {
        try load(CheckersSessionSnapshot.self, from: url(for: .checkers, windowSessionID: windowSessionID))
    }

    func saveRubiksCube(_ snapshot: RubiksCubeSessionSnapshot, windowSessionID: String) throws {
        try save(snapshot, to: url(for: .rubiksCube, windowSessionID: windowSessionID))
    }

    func loadRubiksCube(windowSessionID: String) throws -> RubiksCubeSessionSnapshot? {
        try load(RubiksCubeSessionSnapshot.self, from: url(for: .rubiksCube, windowSessionID: windowSessionID))
    }

    func exportChess(_ snapshot: ChessGameSnapshot, to url: URL) throws {
        try write(snapshot, to: url)
    }

    func importChess(from url: URL) throws -> ChessGameSnapshot {
        try read(ChessGameSnapshot.self, from: url)
    }

    func exportWordPuzzle(_ snapshot: WordPuzzleSessionSnapshot, to url: URL) throws {
        try write(snapshot, to: url)
    }

    func importWordPuzzle(from url: URL) throws -> WordPuzzleSessionSnapshot {
        try read(WordPuzzleSessionSnapshot.self, from: url)
    }

    private func url(for kind: GamePersistenceKind, windowSessionID: String) -> URL {
        rootURL
            .appendingPathComponent(windowSessionID, isDirectory: true)
            .appendingPathComponent(kind.fileName, isDirectory: false)
    }

    private func save<T: Codable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PersistenceJSON.encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private func load<T: Codable>(_ type: T.Type, from url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try read(type, from: url)
    }

    private func read<T: Codable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try PersistenceJSON.decoder.decode(type, from: data)
    }

    private func write<T: Codable>(_ value: T, to url: URL) throws {
        let data = try PersistenceJSON.encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    static func defaultRootURL(baseURL: URL, fileManager fm: FileManager = .default) -> URL {
        let oldRoot = baseURL.appendingPathComponent("ChessHotSwap", isDirectory: true)
        let newRoot = baseURL.appendingPathComponent("Kaleidoscope", isDirectory: true)
        if fm.fileExists(atPath: oldRoot.path), !fm.fileExists(atPath: newRoot.path) {
            try? fm.moveItem(at: oldRoot, to: newRoot)
        }
        return newRoot
    }

    private static func defaultRootURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        return defaultRootURL(baseURL: base, fileManager: fm)
    }
}

struct ChessGameFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var snapshot: ChessGameSnapshot

    init(snapshot: ChessGameSnapshot) {
        self.snapshot = snapshot
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        snapshot = try PersistenceJSON.decoder.decode(ChessGameSnapshot.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try PersistenceJSON.encoder.encode(snapshot)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct WordPuzzleFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var snapshot: WordPuzzleSessionSnapshot

    init(snapshot: WordPuzzleSessionSnapshot) {
        self.snapshot = snapshot
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        snapshot = try PersistenceJSON.decoder.decode(WordPuzzleSessionSnapshot.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try PersistenceJSON.encoder.encode(snapshot)
        return FileWrapper(regularFileWithContents: data)
    }
}

extension DailyWordSource {
    private enum CodingKeys: String, CodingKey { case kind, name }
    private enum Kind: String, Codable { case localDaily, random, remote }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .localDaily:
            try container.encode(Kind.localDaily, forKey: .kind)
        case .random:
            try container.encode(Kind.random, forKey: .kind)
        case .remote(let name):
            try container.encode(Kind.remote, forKey: .kind)
            try container.encode(name, forKey: .name)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .localDaily:
            self = .localDaily
        case .random:
            self = .random
        case .remote:
            self = .remote(name: try container.decode(String.self, forKey: .name))
        }
    }
}

@MainActor
final class WordPuzzleSession: ObservableObject {
    static let wordBank = [
        "cider", "cigar", "array", "brick", "plane", "crane", "slate", "adieu",
        "stone", "light", "forge", "crown", "rider", "mango", "prism", "cable",
        "about", "other", "which", "their", "there", "first", "would", "these",
        "click", "build", "plate", "studs", "parts", "stack", "model", "bench"
    ]

    @Published var dailyWord: DailyWord
    @Published var game: WordPuzzleGame
    @Published var guess = ""
    @Published var message = "Guess the hidden word."
    @Published var isLoadingDaily = false

    let provider: DailyWordProvider
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    init() {
        let provider = DailyWordProvider(localWords: Self.wordBank)
        let dailyWord = provider.localWord()
        self.provider = provider
        self.dailyWord = dailyWord
        self.game = WordPuzzleGame(answer: dailyWord.answer,
                                   allowedWords: Self.allowedWords(with: dailyWord.answer))
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadWordPuzzle(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            } else {
                save()
            }
        } catch {
            save()
        }
    }

    func reloadSavedState() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        do {
            if let snapshot = try persistenceStore.loadWordPuzzle(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> WordPuzzleSessionSnapshot {
        WordPuzzleSessionSnapshot(version: 1,
                                  dailyWord: dailyWord,
                                  game: game,
                                  guess: guess,
                                  message: message,
                                  isLoadingDaily: isLoadingDaily)
    }

    func restore(from snapshot: WordPuzzleSessionSnapshot, persist: Bool = true) {
        dailyWord = snapshot.dailyWord
        game = snapshot.game
        guess = snapshot.guess
        message = snapshot.message
        // A restored session is never mid-fetch; clear the transient loading flag
        // so a snapshot taken during a fetch cannot strand a spinner.
        isLoadingDaily = false
        if persist { save() }
    }

    func handleKey(_ key: String) {
        if key == "ENTER" {
            submitGuess()
        } else if key == "DEL" {
            deleteCharacter()
        } else if key.count == 1, key.first?.isLetter == true, guess.count < game.answer.count {
            guess.append(key.uppercased())
            save()
        }
    }

    func submitGuess() {
        guard !game.isComplete else { return }
        let accepted = game.submit(guess)
        if accepted {
            if game.isSolved {
                message = "Solved."
            } else if game.isComplete {
                message = "Out of guesses. Answer: \(game.answer.uppercased())."
            } else {
                message = "Guess accepted."
            }
            guess = ""
        } else {
            message = "Enter all \(game.answer.count) letters."
        }
        save()
    }

    func loadBrokerDaily() {
        isLoadingDaily = true
        message = "Fetching today's daily word..."
        save()
        Task {
            do {
                let daily = try await provider.brokerDailyWord()
                await MainActor.run {
                    self.resetGame(with: daily, message: "Daily word loaded: \(daily.dateLabel).")
                    self.isLoadingDaily = false
                    self.save()
                }
            } catch {
                await MainActor.run {
                    self.resetGame(with: provider.localWord(), message: "Daily word unavailable; loaded local daily instead.")
                    self.isLoadingDaily = false
                    self.save()
                }
            }
        }
    }

    func newRandomGame() {
        resetGame(with: provider.randomWord(), message: "New random puzzle.")
        save()
    }

    func loadLocalDaily() {
        resetGame(with: provider.localWord(), message: "Local daily loaded.")
        save()
    }

    func resetGame(with word: DailyWord, message: String) {
        dailyWord = word
        game = WordPuzzleGame(answer: word.answer,
                              allowedWords: Self.allowedWords(with: word.answer))
        guess = ""
        self.message = message
        save()
    }

    func exportableDocument() -> WordPuzzleFileDocument {
        WordPuzzleFileDocument(snapshot: snapshot())
    }

    func importSnapshot(from document: WordPuzzleFileDocument) {
        restore(from: document.snapshot)
    }

    func importSnapshot(from url: URL) {
        guard let persistenceStore else { return }
        if let snapshot = try? persistenceStore.importWordPuzzle(from: url) {
            restore(from: snapshot)
        }
    }

    private func deleteCharacter() {
        guard !guess.isEmpty else { return }
        guess.removeLast()
        save()
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveWordPuzzle(snapshot(), windowSessionID: windowSessionID)
    }

    private static func allowedWords(with answer: String) -> [String] {
        Array(Set(wordBank + [answer.lowercased()])).sorted()
    }
}
