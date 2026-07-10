import XCTest
@testable import Prismet

final class GameSessionStateTests: XCTestCase {
    func testGame2048SessionRetainsProgressAcrossReuse() {
        let session = Game2048Session()
        session.game = Game2048(grid: [
            2, 4, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ], score: 16)
        session.boardSize = 5
        session.shufflePowerUps = Game2048ShufflePowerUps(usesPerGame: 3)
        _ = session.shufflePowerUps.use()

        let reused = session

        XCTAssertEqual(reused.game.score, 16)
        XCTAssertEqual(reused.boardSize, 5)
        XCTAssertEqual(reused.shufflePowerUps.remainingUses, 2)
    }

    func testPuzzleSessionsRetainUserProgressAcrossReuse() {
        let lights = LightsOutSession()
        let originalLights = lights.game
        lights.game.press(row: 0, col: 0)
        lights.pressCount = 1

        let sudoku = SudokuSession()
        _ = sudoku.game.setValue(4, row: 0, col: 2)
        sudoku.selectedIndex = 2

        let nonogram = NonogramSession()
        nonogram.game.cycle(row: 2, col: 2)

        let reusedLights = lights
        let reusedSudoku = sudoku
        let reusedNonogram = nonogram

        XCTAssertEqual(reusedLights.pressCount, 1)
        XCTAssertNotEqual(reusedLights.game, originalLights)
        XCTAssertEqual(reusedSudoku.game.value(row: 0, col: 2), 4)
        XCTAssertEqual(reusedSudoku.selectedIndex, 2)
        XCTAssertEqual(reusedNonogram.game.mark(row: 2, col: 2), .filled)
    }

    func testArcadeSessionsRetainProgressAcrossReuse() {
        let snake = SnakeSession()
        snake.game.turn(.down)
        snake.isRunning = false

        let sliding = SlidingPuzzleSession()
        sliding.puzzle = .solved
        sliding.seed = 99

        let reversi = ReversiSession()
        _ = reversi.game.applyMove(row: 2, col: 3)

        let connectFour = ConnectFourSession()
        connectFour.dropToken(in: 3)

        let checkers = CheckersSession()
        _ = checkers.applyMove(CheckersMove(from: CheckersPoint(row: 5, col: 0),
                                            to: CheckersPoint(row: 4, col: 1)))

        XCTAssertEqual(snake.game.direction, .down)
        XCTAssertFalse(snake.isRunning)
        XCTAssertTrue(sliding.puzzle.isSolved)
        XCTAssertEqual(sliding.seed, 99)
        XCTAssertEqual(reversi.game.count(for: .black), 4)
        XCTAssertEqual(connectFour.game.token(row: 5, column: 3), .red)
        XCTAssertEqual(checkers.game.piece(row: 4, col: 1), CheckersPiece(player: .dark, kind: .man))
    }

    func testTimerAndModeSessionsRetainProgressAcrossReuse() {
        let minesweeper = MinesweeperSession()
        minesweeper.style = .classic
        minesweeper.zoom = 1.3
        minesweeper.started = true
        minesweeper.elapsed = 42

        let rubiks = RubiksCubeSession()
        rubiks.moveCount = 7
        rubiks.elapsed = 12.5
        rubiks.direction = .half
        rubiks.hasStarted = true

        XCTAssertEqual(minesweeper.style, .classic)
        XCTAssertEqual(minesweeper.zoom, 1.3)
        XCTAssertTrue(minesweeper.started)
        XCTAssertEqual(minesweeper.elapsed, 42)
        XCTAssertEqual(rubiks.moveCount, 7)
        XCTAssertEqual(rubiks.elapsed, 12.5)
        XCTAssertEqual(rubiks.direction, .half)
        XCTAssertTrue(rubiks.hasStarted)
    }

    func testMinesweeperSessionUndoRestoresPreviousBoard() {
        let session = MinesweeperSession()
        session.game = MinesweeperGame(width: 3, height: 3, mines: [0])
        let original = session.game

        session.toggleFlag(row: 0, col: 1)
        XCTAssertNotEqual(session.game, original)

        session.undo()

        XCTAssertEqual(session.game, original)
        XCTAssertFalse(session.canUndo)
    }

    func testMinesweeperSessionSnapshotRestoresConfigurationAndUndoStack() {
        let session = MinesweeperSession()
        session.difficulty = .custom
        session.settings = MinesweeperSettings(width: 12, height: 10, mineDensity: 0.22)
        session.newGame()
        session.toggleFlag(row: 0, col: 0)
        session.style = .classic
        session.zoom = 1.3
        session.elapsed = 42

        let restored = MinesweeperSession()
        restored.restore(from: session.snapshot(), persist: false)

        XCTAssertEqual(restored.settings, session.settings.clamped())
        XCTAssertEqual(restored.difficulty, .custom)
        XCTAssertEqual(restored.game, session.game)
        XCTAssertEqual(restored.style, .classic)
        XCTAssertEqual(restored.zoom, 1.3)
        XCTAssertEqual(restored.elapsed, 42)
        XCTAssertTrue(restored.canUndo)
    }

    func testMinesweeperPresetDifficultyStartsIOSParityBoard() {
        let session = MinesweeperSession()
        session.difficulty = .expert

        session.newGame()

        XCTAssertEqual(session.game.width, 30)
        XCTAssertEqual(session.game.height, 30)
        XCTAssertEqual(session.game.mineCount, 186)
        XCTAssertEqual(session.settings.width, 30)
        XCTAssertEqual(session.settings.height, 30)
    }

    func testMinesweeperCustomDifficultyUsesClampedSettings() {
        let session = MinesweeperSession()
        session.difficulty = .custom
        session.settings = MinesweeperSettings(width: 40, height: 40, mineDensity: 0.20)

        session.newGame()

        XCTAssertEqual(session.game.width, 30)
        XCTAssertEqual(session.game.height, 30)
        XCTAssertEqual(session.game.mineCount, 180)
        XCTAssertEqual(session.settings, MinesweeperSettings(width: 30, height: 30, mineDensity: 0.20))
    }

    func testSimplePuzzleSessionUndoRestoresPreviousState() {
        let lights = LightsOutSession()
        let lightsOriginal = lights.game
        lights.press(row: 0, col: 0)
        lights.undo()
        XCTAssertEqual(lights.game, lightsOriginal)
        XCTAssertEqual(lights.pressCount, 0)

        let sudoku = SudokuSession()
        sudoku.select(index: 2)
        sudoku.enter(4)
        sudoku.undo()
        XCTAssertEqual(sudoku.game.value(row: 0, col: 2), 0)

        let sliding = SlidingPuzzleSession()
        sliding.puzzle = SlidingPuzzle(tiles: [1, 2, 3, 4,
                                               5, 6, 7, 8,
                                               9, 10, 11, 12,
                                               13, 14, 0, 15])
        let slidingOriginal = sliding.puzzle
        sliding.moveTile(at: 15)
        sliding.undo()
        XCTAssertEqual(sliding.puzzle, slidingOriginal)

        let nonogram = NonogramSession()
        nonogram.cycle(row: 2, col: 2)
        nonogram.undo()
        XCTAssertEqual(nonogram.game.mark(row: 2, col: 2), .empty)

        let reversi = ReversiSession()
        reversi.applyMove(row: 2, col: 3)
        reversi.undo()
        XCTAssertEqual(reversi.game, ReversiGame())

        let connectFour = ConnectFourSession()
        connectFour.dropToken(in: 3)
        connectFour.undo()
        XCTAssertEqual(connectFour.game, ConnectFourGame())

        let checkers = CheckersSession()
        checkers.applyMove(CheckersMove(from: CheckersPoint(row: 5, col: 0),
                                        to: CheckersPoint(row: 4, col: 1)))
        checkers.undo()
        XCTAssertEqual(checkers.game, CheckersGame())
    }

    func testSimplePuzzleSessionSnapshotsRestoreStateAndUndoStacks() {
        let lights = LightsOutSession()
        lights.press(row: 0, col: 0)
        let restoredLights = LightsOutSession()
        restoredLights.restore(from: lights.snapshot(), persist: false)
        XCTAssertEqual(restoredLights.snapshot(), lights.snapshot())
        XCTAssertTrue(restoredLights.canUndo)

        let sudoku = SudokuSession()
        sudoku.select(index: 2)
        sudoku.enter(4)
        let restoredSudoku = SudokuSession()
        restoredSudoku.restore(from: sudoku.snapshot(), persist: false)
        XCTAssertEqual(restoredSudoku.snapshot(), sudoku.snapshot())
        XCTAssertTrue(restoredSudoku.canUndo)

        let sliding = SlidingPuzzleSession()
        sliding.puzzle = SlidingPuzzle(tiles: [1, 2, 3, 4,
                                               5, 6, 7, 8,
                                               9, 10, 11, 12,
                                               13, 14, 0, 15])
        sliding.moveTile(at: 15)
        let restoredSliding = SlidingPuzzleSession()
        restoredSliding.restore(from: sliding.snapshot(), persist: false)
        XCTAssertEqual(restoredSliding.snapshot(), sliding.snapshot())
        XCTAssertTrue(restoredSliding.canUndo)

        let nonogram = NonogramSession()
        nonogram.cycle(row: 2, col: 2)
        let restoredNonogram = NonogramSession()
        restoredNonogram.restore(from: nonogram.snapshot(), persist: false)
        XCTAssertEqual(restoredNonogram.snapshot(), nonogram.snapshot())
        XCTAssertTrue(restoredNonogram.canUndo)

        let reversi = ReversiSession()
        reversi.applyMove(row: 2, col: 3)
        let restoredReversi = ReversiSession()
        restoredReversi.restore(from: reversi.snapshot(), persist: false)
        XCTAssertEqual(restoredReversi.snapshot(), reversi.snapshot())
        XCTAssertTrue(restoredReversi.canUndo)

        let connectFour = ConnectFourSession()
        connectFour.dropToken(in: 3)
        let restoredConnectFour = ConnectFourSession()
        restoredConnectFour.restore(from: connectFour.snapshot(), persist: false)
        XCTAssertEqual(restoredConnectFour.snapshot(), connectFour.snapshot())
        XCTAssertTrue(restoredConnectFour.canUndo)

        let checkers = CheckersSession()
        checkers.applyMove(CheckersMove(from: CheckersPoint(row: 5, col: 0),
                                        to: CheckersPoint(row: 4, col: 1)))
        let restoredCheckers = CheckersSession()
        restoredCheckers.restore(from: checkers.snapshot(), persist: false)
        XCTAssertEqual(restoredCheckers.snapshot(), checkers.snapshot())
        XCTAssertTrue(restoredCheckers.canUndo)
    }

    func testActiveGameSessionUndoAndSnapshotsRestoreState() throws {
        let game2048 = Game2048Session()
        game2048.game = Game2048(grid: [
            2, 2, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0
        ])
        let original2048 = game2048.game
        let plan = game2048.startMove(.left)
        game2048.commit(try XCTUnwrap(plan))
        XCTAssertTrue(game2048.canUndo)
        game2048.undo()
        XCTAssertEqual(game2048.game, original2048)

        let snake = SnakeSession()
        snake.turn(.down)
        snake.toggleRunning()
        let restoredSnake = SnakeSession()
        restoredSnake.restore(from: snake.snapshot(), persist: false)
        XCTAssertEqual(restoredSnake.snapshot(), snake.snapshot())

        let rubiks = RubiksCubeSession()
        rubiks.turn(face: .R)
        XCTAssertTrue(rubiks.canUndo)
        let restoredRubiks = RubiksCubeSession()
        restoredRubiks.restore(from: rubiks.snapshot(), persist: false)
        XCTAssertEqual(restoredRubiks.snapshot(), rubiks.snapshot())
        rubiks.undo()
        XCTAssertEqual(rubiks.cube, RubiksCube())
    }
}
