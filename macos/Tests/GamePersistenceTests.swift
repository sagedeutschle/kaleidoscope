import XCTest
@testable import Kaleidoscope

@MainActor
final class GamePersistenceTests: XCTestCase {
    private func play(_ game: GameState, _ from: Square, _ to: Square) {
        game.tap(from)
        game.tap(to)
    }

    func testChessSnapshotRestoresUndoHistory() {
        let game = GameState()
        game.vsComputer = false
        play(game, Square(file: 6, rank: 0), Square(file: 5, rank: 2))

        let snapshot = game.snapshot()
        let restored = GameState()
        restored.restore(from: snapshot)

        restored.undo()

        XCTAssertEqual(restored.position, .initial)
        XCTAssertEqual(restored.status, .ongoing)
    }

    func testWordPuzzleSnapshotRestoresGameAndDraft() {
        var game = WordPuzzleGame(answer: "cider", allowedWords: ["cider", "crane"])
        XCTAssertTrue(game.submit("crane"))

        let snapshot = WordPuzzleSessionSnapshot(
            version: 1,
            dailyWord: DailyWord(answer: "cider", dateLabel: "2026-06-26", source: .localDaily),
            game: game,
            guess: "cid",
            message: "Guess accepted.",
            isLoadingDaily: true
        )

        let restored = WordPuzzleSessionState(snapshot: snapshot)

        XCTAssertEqual(restored.dailyWord.answer, "cider")
        XCTAssertEqual(restored.game.rows.count, 1)
        XCTAssertEqual(restored.guess, "cid")
        XCTAssertEqual(restored.message, "Guess accepted.")
        // Restoring a snapshot is never an active fetch — the transient loading
        // flag must clear so a session saved mid-fetch can't strand the spinner.
        XCTAssertFalse(restored.isLoadingDaily)
    }

    func testWordPuzzleSessionReloadsCachedStateAfterTransientChanges() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GamePersistenceStore(rootURL: root)
        let sessionID = UUID().uuidString

        let session = WordPuzzleSession()
        session.configurePersistence(windowSessionID: sessionID, store: store)
        session.handleKey("C")
        session.handleKey("R")
        session.handleKey("A")
        session.handleKey("N")
        session.handleKey("E")

        let saved = session.snapshot()

        let otherSnapshot = WordPuzzleSessionSnapshot(
            version: 1,
            dailyWord: DailyWord(answer: "brick", dateLabel: "2026-06-26", source: .random),
            game: WordPuzzleGame(answer: "brick", allowedWords: ["brick"]),
            guess: "brick",
            message: "Different transient state",
            isLoadingDaily: false
        )

        session.restore(from: otherSnapshot, persist: false)
        session.reloadSavedState()

        XCTAssertEqual(session.snapshot(), saved)
    }

    func testPersistenceStoreWritesAndLoadsChessSession() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GamePersistenceStore(rootURL: root)

        let snapshot = ChessGameSnapshot(
            version: 1,
            position: .initial,
            status: .ongoing,
            lastMove: nil,
            selectedSquare: nil,
            vsComputer: false,
            humanColor: .white,
            aiLevel: 7,
            undoStack: [],
            positionHistory: [.initial]
        )

        try store.saveChess(snapshot, windowSessionID: "window-a")
        let loaded = try store.loadChess(windowSessionID: "window-a")

        XCTAssertEqual(loaded, snapshot)
    }

    func testPersistenceStoreWritesAndLoadsMinesweeperSession() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GamePersistenceStore(rootURL: root)
        let session = MinesweeperSession()
        session.settings = MinesweeperSettings(width: 11, height: 9, mineDensity: 0.20)
        session.newGame()
        session.toggleFlag(row: 0, col: 0)
        session.elapsed = 15

        let snapshot = session.snapshot()

        try store.saveMinesweeper(snapshot, windowSessionID: "window-a")
        let loaded = try store.loadMinesweeper(windowSessionID: "window-a")

        XCTAssertEqual(loaded, snapshot)
    }

    func testPersistenceStoreWritesAndLoadsSimplePuzzleSessions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GamePersistenceStore(rootURL: root)
        let sessionID = UUID().uuidString

        let lights = LightsOutSession()
        lights.configurePersistence(windowSessionID: sessionID, store: store)
        lights.press(row: 0, col: 0)
        XCTAssertEqual(try XCTUnwrap(store.loadLightsOut(windowSessionID: sessionID)), lights.snapshot())

        let sudoku = SudokuSession()
        sudoku.configurePersistence(windowSessionID: sessionID, store: store)
        sudoku.select(index: 2)
        sudoku.enter(4)
        XCTAssertEqual(try XCTUnwrap(store.loadSudoku(windowSessionID: sessionID)), sudoku.snapshot())

        let sliding = SlidingPuzzleSession()
        sliding.configurePersistence(windowSessionID: sessionID, store: store)
        sliding.puzzle = SlidingPuzzle(tiles: [1, 2, 3, 4,
                                               5, 6, 7, 8,
                                               9, 10, 11, 12,
                                               13, 14, 0, 15])
        sliding.moveTile(at: 15)
        XCTAssertEqual(try XCTUnwrap(store.loadSlidingPuzzle(windowSessionID: sessionID)), sliding.snapshot())

        let nonogram = NonogramSession()
        nonogram.configurePersistence(windowSessionID: sessionID, store: store)
        nonogram.cycle(row: 2, col: 2)
        XCTAssertEqual(try XCTUnwrap(store.loadNonogram(windowSessionID: sessionID)), nonogram.snapshot())

        let reversi = ReversiSession()
        reversi.configurePersistence(windowSessionID: sessionID, store: store)
        reversi.applyMove(row: 2, col: 3)
        XCTAssertEqual(try XCTUnwrap(store.loadReversi(windowSessionID: sessionID)), reversi.snapshot())

        let connectFour = ConnectFourSession()
        connectFour.configurePersistence(windowSessionID: sessionID, store: store)
        connectFour.dropToken(in: 3)
        XCTAssertEqual(try XCTUnwrap(store.loadConnectFour(windowSessionID: sessionID)), connectFour.snapshot())

        let checkers = CheckersSession()
        checkers.configurePersistence(windowSessionID: sessionID, store: store)
        checkers.applyMove(CheckersMove(from: CheckersPoint(row: 5, col: 0),
                                        to: CheckersPoint(row: 4, col: 1)))
        XCTAssertEqual(try XCTUnwrap(store.loadCheckers(windowSessionID: sessionID)), checkers.snapshot())
    }

    func testPersistenceStoreWritesAndLoadsActiveGameSessions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GamePersistenceStore(rootURL: root)
        let sessionID = UUID().uuidString

        let game2048 = Game2048Session()
        game2048.configurePersistence(windowSessionID: sessionID, store: store)
        game2048.game = Game2048(grid: [
            2, 2, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ])
        game2048.commit(try XCTUnwrap(game2048.startMove(.left)))
        XCTAssertEqual(try XCTUnwrap(store.loadGame2048(windowSessionID: sessionID)), game2048.snapshot())

        let snake = SnakeSession()
        snake.configurePersistence(windowSessionID: sessionID, store: store)
        snake.turn(.down)
        snake.toggleRunning()
        XCTAssertEqual(try XCTUnwrap(store.loadSnake(windowSessionID: sessionID)), snake.snapshot())

        let rubiks = RubiksCubeSession()
        rubiks.configurePersistence(windowSessionID: sessionID, store: store)
        rubiks.turn(face: .R)
        rubiks.elapsed = 12.5
        rubiks.saveNow()
        XCTAssertEqual(try XCTUnwrap(store.loadRubiksCube(windowSessionID: sessionID)), rubiks.snapshot())
    }

    func testSimplePuzzleSessionsReloadCachedStateAfterTransientChanges() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GamePersistenceStore(rootURL: root)
        let sessionID = UUID().uuidString

        let lights = LightsOutSession()
        lights.configurePersistence(windowSessionID: sessionID, store: store)
        lights.press(row: 0, col: 0)
        let savedLights = lights.snapshot()
        lights.restore(from: LightsOutSessionSnapshot(version: 1, game: LightsOut(), pressCount: 0, scrambleSeed: 99, undoStack: []), persist: false)
        lights.reloadSavedState()
        XCTAssertEqual(lights.snapshot(), savedLights)

        let sudoku = SudokuSession()
        sudoku.configurePersistence(windowSessionID: sessionID, store: store)
        sudoku.select(index: 2)
        sudoku.enter(4)
        let savedSudoku = sudoku.snapshot()
        sudoku.restore(from: SudokuSessionSnapshot(version: 1, game: SudokuGame.standardPuzzle(), selectedIndex: 10, undoStack: []), persist: false)
        sudoku.reloadSavedState()
        XCTAssertEqual(sudoku.snapshot(), savedSudoku)

        let sliding = SlidingPuzzleSession()
        sliding.configurePersistence(windowSessionID: sessionID, store: store)
        sliding.puzzle = SlidingPuzzle(tiles: [1, 2, 3, 4,
                                               5, 6, 7, 8,
                                               9, 10, 11, 12,
                                               13, 14, 0, 15])
        sliding.moveTile(at: 15)
        let savedSliding = sliding.snapshot()
        sliding.restore(from: SlidingPuzzleSessionSnapshot(version: 1, puzzle: .solved, seed: 100, undoStack: []), persist: false)
        sliding.reloadSavedState()
        XCTAssertEqual(sliding.snapshot(), savedSliding)

        let nonogram = NonogramSession()
        nonogram.configurePersistence(windowSessionID: sessionID, store: store)
        nonogram.cycle(row: 2, col: 2)
        let savedNonogram = nonogram.snapshot()
        nonogram.restore(from: NonogramSessionSnapshot(version: 1, game: NonogramGame.crossPuzzle(), undoStack: []), persist: false)
        nonogram.reloadSavedState()
        XCTAssertEqual(nonogram.snapshot(), savedNonogram)

        let reversi = ReversiSession()
        reversi.configurePersistence(windowSessionID: sessionID, store: store)
        reversi.applyMove(row: 2, col: 3)
        let savedReversi = reversi.snapshot()
        reversi.restore(from: ReversiSessionSnapshot(version: 1, game: ReversiGame(), undoStack: []), persist: false)
        reversi.reloadSavedState()
        XCTAssertEqual(reversi.snapshot(), savedReversi)
    }

    func testDefaultRootMigratesOldApplicationSupportDirectory() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let oldRoot = base.appendingPathComponent("ChessHotSwap", isDirectory: true)
        let marker = oldRoot.appendingPathComponent("marker.txt", isDirectory: false)

        try FileManager.default.createDirectory(at: oldRoot, withIntermediateDirectories: true)
        try "saved".write(to: marker, atomically: true, encoding: .utf8)

        let migrated = GamePersistenceStore.defaultRootURL(baseURL: base)

        XCTAssertEqual(migrated.lastPathComponent, "Kaleidoscope")
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldRoot.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: migrated.appendingPathComponent("marker.txt").path))
    }

    func testDefaultRootKeepsExistingKaleidoscopeDirectory() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let oldRoot = base.appendingPathComponent("ChessHotSwap", isDirectory: true)
        let newRoot = base.appendingPathComponent("Kaleidoscope", isDirectory: true)

        try FileManager.default.createDirectory(at: oldRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newRoot, withIntermediateDirectories: true)
        try "old".write(to: oldRoot.appendingPathComponent("marker.txt"), atomically: true, encoding: .utf8)
        try "new".write(to: newRoot.appendingPathComponent("marker.txt"), atomically: true, encoding: .utf8)

        let root = GamePersistenceStore.defaultRootURL(baseURL: base)
        let preserved = try String(contentsOf: root.appendingPathComponent("marker.txt"), encoding: .utf8)

        XCTAssertEqual(root, newRoot)
        XCTAssertEqual(preserved, "new")
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldRoot.path))
    }
}
