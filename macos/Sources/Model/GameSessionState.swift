import Combine
import Foundation

// PRISM: RELEASE Agent-B 2026-06-27 — simple puzzle persistence/input congruency

struct Game2048UndoEntry: Codable, Hashable {
    var game: Game2048
    var rng: SeededGenerator
    var shufflePowerUps: Game2048ShufflePowerUps
    var visualShuffleSeed: UInt64
}

struct Game2048SessionSnapshot: Codable, Hashable {
    var version: Int
    var game: Game2048
    var rng: SeededGenerator
    var newGameSeed: UInt64
    var visualShuffleSeed: UInt64
    var shuffleAnimationEnabled: Bool
    var boardSize: Int
    var shuffleUsesPerGame: Int
    var shufflePowerUps: Game2048ShufflePowerUps
    var undoStack: [Game2048UndoEntry]
}

final class Game2048Session: ObservableObject {
    @Published var game = Game2048.newGame(seed: 1)
    @Published var rng = SeededGenerator(seed: 2)
    @Published var newGameSeed: UInt64 = 3
    @Published var visualShuffleSeed: UInt64 = 4
    @Published var visualShuffle: Game2048VisualShuffle?
    @Published var activeMovePlan: Game2048MovePlan?
    @Published var slideTilesAtDestination = false
    @Published var shuffleAnimationEnabled = true
    @Published var boardSize = Game2048.defaultSize
    @Published var shuffleUsesPerGame = 1
    @Published var shufflePowerUps = Game2048ShufflePowerUps()

    @Published private(set) var undoStack: [Game2048UndoEntry] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty && activeMovePlan == nil
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadGame2048(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadGame2048(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> Game2048SessionSnapshot {
        Game2048SessionSnapshot(version: 1,
                                game: game,
                                rng: rng,
                                newGameSeed: newGameSeed,
                                visualShuffleSeed: visualShuffleSeed,
                                shuffleAnimationEnabled: shuffleAnimationEnabled,
                                boardSize: boardSize,
                                shuffleUsesPerGame: shuffleUsesPerGame,
                                shufflePowerUps: shufflePowerUps,
                                undoStack: undoStack)
    }

    func restore(from snapshot: Game2048SessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        rng = snapshot.rng
        newGameSeed = snapshot.newGameSeed
        visualShuffleSeed = snapshot.visualShuffleSeed
        shuffleAnimationEnabled = snapshot.shuffleAnimationEnabled
        boardSize = min(max(snapshot.boardSize, Game2048.minSize), Game2048.maxSize)
        shuffleUsesPerGame = min(max(snapshot.shuffleUsesPerGame, 0), Game2048ShufflePowerUps.maxUsesPerGame)
        shufflePowerUps = snapshot.shufflePowerUps
        undoStack = snapshot.undoStack
        visualShuffle = nil
        activeMovePlan = nil
        slideTilesAtDestination = false
        if persist { save() }
    }

    func reset() {
        game = Game2048.newGame(size: boardSize, seed: newGameSeed)
        rng = SeededGenerator(seed: newGameSeed &+ 1)
        newGameSeed &+= 2
        visualShuffle = nil
        activeMovePlan = nil
        slideTilesAtDestination = false
        shufflePowerUps = Game2048ShufflePowerUps(usesPerGame: shuffleUsesPerGame)
        undoStack = []
        save()
    }

    func setShuffleUsesPerGame(_ uses: Int) {
        shuffleUsesPerGame = min(max(uses, 0), Game2048ShufflePowerUps.maxUsesPerGame)
        shufflePowerUps = Game2048ShufflePowerUps(usesPerGame: shuffleUsesPerGame)
        save()
    }

    func startMove(_ direction: Game2048.Direction) -> Game2048MovePlan? {
        guard !game.isGameOver, activeMovePlan == nil else { return nil }
        visualShuffle = nil
        let plan = game.plannedMove(direction)
        guard plan.grid != game.grid else { return nil }
        activeMovePlan = plan
        slideTilesAtDestination = false
        return plan
    }

    func commit(_ plan: Game2048MovePlan) {
        guard activeMovePlan == plan else { return }
        let previous = undoEntry()
        var nextGame = game
        guard nextGame.apply(plan, rng: &rng) else {
            activeMovePlan = nil
            slideTilesAtDestination = false
            return
        }
        pushUndo(previous)
        game = nextGame
        activeMovePlan = nil
        slideTilesAtDestination = false
        save()
    }

    func shuffleTilesForPowerUp() -> Game2048VisualShuffle? {
        guard activeMovePlan == nil, shufflePowerUps.remainingUses > 0 else { return nil }
        let previous = undoEntry()
        var nextGame = game
        var nextPowerUps = shufflePowerUps
        var shuffleRng = SeededGenerator(seed: visualShuffleSeed)
        guard nextGame.shuffleTiles(rng: &shuffleRng), nextPowerUps.use() else { return nil }
        pushUndo(previous)
        game = nextGame
        shufflePowerUps = nextPowerUps
        let shuffle = Game2048VisualShuffle(seed: visualShuffleSeed, slotCount: game.grid.count)
        visualShuffleSeed &+= 1
        save()
        return shuffle
    }

    func undo() {
        guard canUndo, let previous = undoStack.popLast() else { return }
        game = previous.game
        rng = previous.rng
        shufflePowerUps = previous.shufflePowerUps
        visualShuffleSeed = previous.visualShuffleSeed
        visualShuffle = nil
        activeMovePlan = nil
        slideTilesAtDestination = false
        save()
    }

    private func undoEntry() -> Game2048UndoEntry {
        Game2048UndoEntry(game: game,
                          rng: rng,
                          shufflePowerUps: shufflePowerUps,
                          visualShuffleSeed: visualShuffleSeed)
    }

    private func pushUndo(_ entry: Game2048UndoEntry) {
        undoStack.append(entry)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveGame2048(snapshot(), windowSessionID: windowSessionID)
    }
}

struct LightsOutSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: LightsOut
    var pressCount: Int
    var scrambleSeed: UInt64
    var undoStack: [LightsOut]
}

final class LightsOutSession: ObservableObject {
    @Published var game = LightsOut.newPuzzle(seed: 1)
    @Published var pressCount = 0
    @Published var scrambleSeed: UInt64 = 2

    @Published private(set) var undoStack: [LightsOut] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadLightsOut(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadLightsOut(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> LightsOutSessionSnapshot {
        LightsOutSessionSnapshot(version: 1,
                                 game: game,
                                 pressCount: pressCount,
                                 scrambleSeed: scrambleSeed,
                                 undoStack: undoStack)
    }

    func restore(from snapshot: LightsOutSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        pressCount = max(0, snapshot.pressCount)
        scrambleSeed = snapshot.scrambleSeed
        undoStack = snapshot.undoStack
        if persist { save() }
    }

    func press(row: Int, col: Int) {
        mutateGame {
            $0.press(row: row, col: col)
        }
    }

    func newGame() {
        game = LightsOut.newPuzzle(seed: scrambleSeed)
        scrambleSeed &+= 1
        pressCount = 0
        undoStack = []
        save()
    }

    func clear() {
        game = LightsOut()
        pressCount = 0
        undoStack = []
        save()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        game = previous
        pressCount = max(0, pressCount - 1)
        save()
    }

    private func mutateGame(_ mutation: (inout LightsOut) -> Void) {
        let previous = game
        var next = game
        mutation(&next)
        guard next != previous else { return }
        pushUndo(previous)
        game = next
        pressCount += 1
        save()
    }

    private func pushUndo(_ previous: LightsOut) {
        undoStack.append(previous)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveLightsOut(snapshot(), windowSessionID: windowSessionID)
    }
}

/// Drastically different visual skins for the same Minesweeper game.
enum MinesweeperStyle: String, CaseIterable, Codable, Hashable, Identifiable {
    case modern = "Modern"
    case classic = "Classic '97"
    case cyber = "Cyberpunk"
    var id: String { rawValue }
}

struct MinesweeperSettings: Codable, Hashable {
    static let minWidth = 6
    static let maxWidth = 30
    static let minHeight = 6
    static let maxHeight = 30
    static let minMineDensity = 0.08
    static let maxMineDensity = 0.35

    var width: Int = 9
    var height: Int = 9
    var mineDensity: Double = 10.0 / 81.0

    var mineCount: Int {
        let cells = width * height
        return min(max(1, Int((Double(cells) * mineDensity).rounded())), cells - 1)
    }

    func clamped() -> MinesweeperSettings {
        MinesweeperSettings(
            width: min(max(width, Self.minWidth), Self.maxWidth),
            height: min(max(height, Self.minHeight), Self.maxHeight),
            mineDensity: min(max(mineDensity, Self.minMineDensity), Self.maxMineDensity)
        )
    }
}

enum MinesweeperDifficulty: String, CaseIterable, Codable, Hashable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case expert = "Expert"
    case custom = "Custom"

    var id: String { rawValue }

    var preset: (width: Int, height: Int, mineCount: Int)? {
        switch self {
        case .beginner: return (9, 9, 10)
        case .intermediate: return (16, 16, 40)
        case .expert: return (30, 30, 186)
        case .custom: return nil
        }
    }

    var settings: MinesweeperSettings? {
        guard let preset else { return nil }
        return MinesweeperSettings(
            width: preset.width,
            height: preset.height,
            mineDensity: Double(preset.mineCount) / Double(preset.width * preset.height)
        )
    }
}

struct MinesweeperSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: MinesweeperGame
    var settings: MinesweeperSettings
    var difficulty: MinesweeperDifficulty
    var seed: UInt64
    var primaryMode: MinesweeperInteractionMode
    var style: MinesweeperStyle
    var zoom: Double
    var elapsed: Int
    var started: Bool
    var undoStack: [MinesweeperGame]

    init(version: Int,
         game: MinesweeperGame,
         settings: MinesweeperSettings,
         difficulty: MinesweeperDifficulty,
         seed: UInt64,
         primaryMode: MinesweeperInteractionMode,
         style: MinesweeperStyle,
         zoom: Double,
         elapsed: Int,
         started: Bool,
         undoStack: [MinesweeperGame]) {
        self.version = version
        self.game = game
        self.settings = settings
        self.difficulty = difficulty
        self.seed = seed
        self.primaryMode = primaryMode
        self.style = style
        self.zoom = zoom
        self.elapsed = elapsed
        self.started = started
        self.undoStack = undoStack
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        game = try container.decode(MinesweeperGame.self, forKey: .game)
        settings = try container.decode(MinesweeperSettings.self, forKey: .settings)
        difficulty = try container.decodeIfPresent(MinesweeperDifficulty.self, forKey: .difficulty) ?? .custom
        seed = try container.decode(UInt64.self, forKey: .seed)
        primaryMode = try container.decode(MinesweeperInteractionMode.self, forKey: .primaryMode)
        style = try container.decode(MinesweeperStyle.self, forKey: .style)
        zoom = try container.decode(Double.self, forKey: .zoom)
        elapsed = try container.decode(Int.self, forKey: .elapsed)
        started = try container.decode(Bool.self, forKey: .started)
        undoStack = try container.decode([MinesweeperGame].self, forKey: .undoStack)
    }
}

final class MinesweeperSession: ObservableObject {
    @Published var game = MinesweeperGame(seed: 17)
    @Published var settings = MinesweeperSettings()
    @Published var difficulty = MinesweeperDifficulty.beginner
    @Published var seed: UInt64 = 18
    @Published var primaryMode = MinesweeperInteractionMode.default
    @Published var style: MinesweeperStyle = .modern
    @Published var zoom = 1.0
    @Published var elapsed = 0
    @Published var started = false

    @Published private(set) var undoStack: [MinesweeperGame] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadMinesweeper(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadMinesweeper(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> MinesweeperSessionSnapshot {
        MinesweeperSessionSnapshot(version: 1,
                                   game: game,
                                   settings: settings.clamped(),
                                   difficulty: difficulty,
                                   seed: seed,
                                   primaryMode: primaryMode,
                                   style: style,
                                   zoom: zoom,
                                   elapsed: elapsed,
                                   started: started,
                                   undoStack: undoStack)
    }

    func restore(from snapshot: MinesweeperSessionSnapshot, persist: Bool = true) {
        settings = snapshot.settings.clamped()
        difficulty = snapshot.difficulty
        game = snapshot.game
        seed = snapshot.seed
        primaryMode = snapshot.primaryMode
        style = snapshot.style
        zoom = snapshot.zoom
        elapsed = snapshot.elapsed
        started = snapshot.started
        undoStack = snapshot.undoStack
        if persist { save() }
    }

    func newGame() {
        let nextSettings = difficulty.settings ?? settings.clamped()
        settings = nextSettings
        let mineCount = difficulty.preset?.mineCount ?? nextSettings.mineCount
        game = MinesweeperGame(width: nextSettings.width,
                               height: nextSettings.height,
                               mineCount: mineCount,
                               seed: seed)
        seed &+= 1
        elapsed = 0
        started = false
        undoStack = []
        save()
    }

    func reveal(row: Int, col: Int) {
        mutateGame(startsTimer: true) { game in
            game.reveal(row: row, col: col)
        }
    }

    func toggleFlag(row: Int, col: Int) {
        mutateGame(startsTimer: false) { game in
            game.toggleFlag(row: row, col: col)
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        game = previous
        started = !game.revealed.isEmpty
        save()
    }

    private func mutateGame(startsTimer: Bool, _ mutation: (inout MinesweeperGame) -> Void) {
        let previous = game
        var next = game
        mutation(&next)
        guard next != previous else { return }
        undoStack.append(previous)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
        game = next
        if startsTimer { started = true }
        save()
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveMinesweeper(snapshot(), windowSessionID: windowSessionID)
    }
}

struct SnakeSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: SnakeGame
    var rng: SeededGenerator
    var isRunning: Bool
}

final class SnakeSession: ObservableObject {
    @Published var game = SnakeGame()
    @Published var rng = SeededGenerator(seed: 24)
    @Published var isRunning = true

    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadSnake(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadSnake(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> SnakeSessionSnapshot {
        SnakeSessionSnapshot(version: 1, game: game, rng: rng, isRunning: isRunning)
    }

    func restore(from snapshot: SnakeSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        rng = snapshot.rng
        isRunning = snapshot.game.status == .playing && snapshot.isRunning
        if persist { save() }
    }

    func newGame() {
        game = SnakeGame()
        rng = SeededGenerator(seed: 24)
        isRunning = true
        save()
    }

    func toggleRunning() {
        guard game.status == .playing else { return }
        isRunning.toggle()
        save()
    }

    func turn(_ direction: SnakeGame.Direction) {
        let previous = game
        game.turn(direction)
        if game != previous { save() }
    }

    func step() {
        let previousScore = game.score
        let previousStatus = game.status
        game.step(rng: &rng)
        if game.status == .lost { isRunning = false }
        if game.score != previousScore || game.status != previousStatus {
            save()
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveSnake(snapshot(), windowSessionID: windowSessionID)
    }
}

struct SudokuSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: SudokuGame
    var selectedIndex: Int?
    var undoStack: [SudokuGame]
}

final class SudokuSession: ObservableObject {
    @Published var game = SudokuGame.standardPuzzle()
    @Published var selectedIndex: Int? = 2

    @Published private(set) var undoStack: [SudokuGame] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadSudoku(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadSudoku(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> SudokuSessionSnapshot {
        SudokuSessionSnapshot(version: 1,
                              game: game,
                              selectedIndex: selectedIndex,
                              undoStack: undoStack)
    }

    func restore(from snapshot: SudokuSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        selectedIndex = snapshot.selectedIndex
        undoStack = snapshot.undoStack
        if persist { save() }
    }

    func select(index: Int?) {
        if let index, !(0..<(SudokuGame.size * SudokuGame.size)).contains(index) { return }
        selectedIndex = index
        save()
    }

    func moveSelection(rowDelta: Int, colDelta: Int) {
        guard let selectedIndex else {
            select(index: 0)
            return
        }
        let row = selectedIndex / SudokuGame.size
        let col = selectedIndex % SudokuGame.size
        let nextRow = min(max(row + rowDelta, 0), SudokuGame.size - 1)
        let nextCol = min(max(col + colDelta, 0), SudokuGame.size - 1)
        select(index: nextRow * SudokuGame.size + nextCol)
    }

    func enter(_ value: Int) {
        guard let selectedIndex else { return }
        let row = selectedIndex / SudokuGame.size
        let col = selectedIndex % SudokuGame.size
        mutateGame {
            _ = $0.setValue(value, row: row, col: col)
        }
    }

    func reset() {
        game.reset()
        selectedIndex = 2
        undoStack = []
        save()
    }

    func solve() {
        mutateGame {
            $0.fillSolution()
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        game = previous
        save()
    }

    private func mutateGame(_ mutation: (inout SudokuGame) -> Void) {
        let previous = game
        var next = game
        mutation(&next)
        guard next != previous else { return }
        pushUndo(previous)
        game = next
        save()
    }

    private func pushUndo(_ previous: SudokuGame) {
        undoStack.append(previous)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveSudoku(snapshot(), windowSessionID: windowSessionID)
    }
}

struct SlidingPuzzleSessionSnapshot: Codable, Hashable {
    var version: Int
    var puzzle: SlidingPuzzle
    var seed: UInt64
    var undoStack: [SlidingPuzzle]
}

final class SlidingPuzzleSession: ObservableObject {
    @Published var puzzle = SlidingPuzzle.shuffled(seed: 31, moves: 45)
    @Published var seed: UInt64 = 32

    @Published private(set) var undoStack: [SlidingPuzzle] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadSlidingPuzzle(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadSlidingPuzzle(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> SlidingPuzzleSessionSnapshot {
        SlidingPuzzleSessionSnapshot(version: 1,
                                     puzzle: puzzle,
                                     seed: seed,
                                     undoStack: undoStack)
    }

    func restore(from snapshot: SlidingPuzzleSessionSnapshot, persist: Bool = true) {
        puzzle = snapshot.puzzle
        seed = snapshot.seed
        undoStack = snapshot.undoStack
        if persist { save() }
    }

    func shuffle() {
        puzzle = SlidingPuzzle.shuffled(seed: seed, moves: 60)
        seed &+= 1
        undoStack = []
        save()
    }

    func reset() {
        puzzle = .solved
        undoStack = []
        save()
    }

    func moveTile(at index: Int) {
        mutatePuzzle {
            _ = $0.moveTile(at: index)
        }
    }

    func moveBlank(_ direction: SlidingPuzzle.Direction) {
        mutatePuzzle {
            _ = $0.moveBlank(direction)
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        puzzle = previous
        save()
    }

    private func mutatePuzzle(_ mutation: (inout SlidingPuzzle) -> Void) {
        let previous = puzzle
        var next = puzzle
        mutation(&next)
        guard next != previous else { return }
        pushUndo(previous)
        puzzle = next
        save()
    }

    private func pushUndo(_ previous: SlidingPuzzle) {
        undoStack.append(previous)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveSlidingPuzzle(snapshot(), windowSessionID: windowSessionID)
    }
}

struct NonogramSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: NonogramGame
    var undoStack: [NonogramGame]
}

final class NonogramSession: ObservableObject {
    @Published var game = NonogramGame.crossPuzzle()

    @Published private(set) var undoStack: [NonogramGame] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadNonogram(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadNonogram(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> NonogramSessionSnapshot {
        NonogramSessionSnapshot(version: 1,
                                game: game,
                                undoStack: undoStack)
    }

    func restore(from snapshot: NonogramSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        undoStack = snapshot.undoStack
        if persist { save() }
    }

    func cycle(row: Int, col: Int) {
        mutateGame {
            $0.cycle(row: row, col: col)
        }
    }

    func reset() {
        game.reset()
        undoStack = []
        save()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        game = previous
        save()
    }

    private func mutateGame(_ mutation: (inout NonogramGame) -> Void) {
        let previous = game
        var next = game
        mutation(&next)
        guard next != previous else { return }
        pushUndo(previous)
        game = next
        save()
    }

    private func pushUndo(_ previous: NonogramGame) {
        undoStack.append(previous)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveNonogram(snapshot(), windowSessionID: windowSessionID)
    }
}

struct ReversiSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: ReversiGame
    var undoStack: [ReversiGame]
}

final class ReversiSession: ObservableObject {
    @Published var game = ReversiGame()

    @Published private(set) var undoStack: [ReversiGame] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadReversi(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadReversi(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> ReversiSessionSnapshot {
        ReversiSessionSnapshot(version: 1,
                               game: game,
                               undoStack: undoStack)
    }

    func restore(from snapshot: ReversiSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        undoStack = snapshot.undoStack
        if persist { save() }
    }

    func applyMove(row: Int, col: Int) {
        mutateGame {
            _ = $0.applyMove(row: row, col: col)
        }
    }

    func pass() {
        mutateGame {
            $0.passIfNeeded()
        }
    }

    func newGame() {
        game = ReversiGame()
        undoStack = []
        save()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        game = previous
        save()
    }

    private func mutateGame(_ mutation: (inout ReversiGame) -> Void) {
        let previous = game
        var next = game
        mutation(&next)
        guard next != previous else { return }
        pushUndo(previous)
        game = next
        save()
    }

    private func pushUndo(_ previous: ReversiGame) {
        undoStack.append(previous)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveReversi(snapshot(), windowSessionID: windowSessionID)
    }
}

struct ConnectFourSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: ConnectFourGame
    var undoStack: [ConnectFourGame]
}

final class ConnectFourSession: ObservableObject {
    @Published var game = ConnectFourGame()

    @Published private(set) var undoStack: [ConnectFourGame] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadConnectFour(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadConnectFour(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> ConnectFourSessionSnapshot {
        ConnectFourSessionSnapshot(version: 1,
                                   game: game,
                                   undoStack: undoStack)
    }

    func restore(from snapshot: ConnectFourSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        undoStack = snapshot.undoStack
        if persist { save() }
    }

    @discardableResult
    func dropToken(in column: Int) -> Bool {
        mutateGame {
            $0.dropToken(in: column)
        }
    }

    func newGame() {
        game = ConnectFourGame()
        undoStack = []
        save()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        game = previous
        save()
    }

    private func mutateGame(_ mutation: (inout ConnectFourGame) -> Bool) -> Bool {
        let previous = game
        var next = game
        guard mutation(&next), next != previous else { return false }
        pushUndo(previous)
        game = next
        save()
        return true
    }

    private func pushUndo(_ previous: ConnectFourGame) {
        undoStack.append(previous)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveConnectFour(snapshot(), windowSessionID: windowSessionID)
    }
}

struct CheckersSessionSnapshot: Codable, Hashable {
    var version: Int
    var game: CheckersGame
    var undoStack: [CheckersGame]
}

final class CheckersSession: ObservableObject {
    @Published var game = CheckersGame()

    @Published private(set) var undoStack: [CheckersGame] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadCheckers(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadCheckers(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> CheckersSessionSnapshot {
        CheckersSessionSnapshot(version: 1,
                                game: game,
                                undoStack: undoStack)
    }

    func restore(from snapshot: CheckersSessionSnapshot, persist: Bool = true) {
        game = snapshot.game
        undoStack = snapshot.undoStack
        if persist { save() }
    }

    @discardableResult
    func applyMove(_ move: CheckersMove) -> Bool {
        mutateGame {
            $0.applyMove(move)
        }
    }

    func newGame() {
        game = CheckersGame()
        undoStack = []
        save()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        game = previous
        save()
    }

    private func mutateGame(_ mutation: (inout CheckersGame) -> Bool) -> Bool {
        let previous = game
        var next = game
        guard mutation(&next), next != previous else { return false }
        pushUndo(previous)
        game = next
        save()
        return true
    }

    private func pushUndo(_ previous: CheckersGame) {
        undoStack.append(previous)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveCheckers(snapshot(), windowSessionID: windowSessionID)
    }
}

enum TurnDirection: String, CaseIterable, Codable, Hashable, Identifiable {
    case clockwise = "CW"
    case counter = "CCW"
    case half = "180°"

    var id: String { rawValue }

    /// Quarter turns to feed `RubiksMove.move(face:quarters:)`.
    var quarters: Int {
        switch self {
        case .clockwise: return 1
        case .counter: return 3
        case .half: return 2
        }
    }
}

struct RubiksCubeUndoEntry: Codable, Hashable {
    var cube: RubiksCube
    var moveCount: Int
    var elapsed: TimeInterval
    var timerRunning: Bool
    var hasStarted: Bool
}

struct RubiksCubeSessionSnapshot: Codable, Hashable {
    var version: Int
    var cube: RubiksCube
    var moveCount: Int
    var elapsed: TimeInterval
    var timerRunning: Bool
    var direction: TurnDirection
    var scrambleSeed: UInt64
    var hasStarted: Bool
    var undoStack: [RubiksCubeUndoEntry]
}

final class RubiksCubeSession: ObservableObject {
    @Published var cube = RubiksCube()
    @Published var moveCount = 0
    @Published var elapsed: TimeInterval = 0
    @Published var timerRunning = false
    @Published var direction: TurnDirection = .clockwise
    @Published var scrambleSeed: UInt64 = UInt64(bitPattern: Int64(Date().timeIntervalSince1970))
    @Published var hasStarted = false

    @Published private(set) var undoStack: [RubiksCubeUndoEntry] = []

    private let maxUndoEntries = 80
    private var persistenceStore: GamePersistenceStore?
    private var windowSessionID = ""

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    func configurePersistence(windowSessionID: String, store: GamePersistenceStore = .shared) {
        self.windowSessionID = windowSessionID
        persistenceStore = store

        do {
            if let snapshot = try store.loadRubiksCube(windowSessionID: windowSessionID) {
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
            if let snapshot = try persistenceStore.loadRubiksCube(windowSessionID: windowSessionID) {
                restore(from: snapshot, persist: false)
            }
        } catch {
            return
        }
    }

    func saveNow() {
        save()
    }

    func snapshot() -> RubiksCubeSessionSnapshot {
        RubiksCubeSessionSnapshot(version: 1,
                                  cube: cube,
                                  moveCount: moveCount,
                                  elapsed: elapsed,
                                  timerRunning: timerRunning,
                                  direction: direction,
                                  scrambleSeed: scrambleSeed,
                                  hasStarted: hasStarted,
                                  undoStack: undoStack)
    }

    func restore(from snapshot: RubiksCubeSessionSnapshot, persist: Bool = true) {
        cube = snapshot.cube
        moveCount = snapshot.moveCount
        elapsed = snapshot.elapsed
        timerRunning = snapshot.timerRunning
        direction = snapshot.direction
        scrambleSeed = snapshot.scrambleSeed
        hasStarted = snapshot.hasStarted
        undoStack = snapshot.undoStack
        if persist { save() }
    }

    func turn(face: CubeFace) {
        let previous = undoEntry()
        let move = RubiksMove.move(face: face, quarters: direction.quarters)
        cube.apply(move)
        moveCount += 1
        if !hasStarted { hasStarted = true }
        timerRunning = !cube.isSolved
        pushUndo(previous)
        save()
    }

    func turn(slice: CubeSlice) {
        let previous = undoEntry()
        cube.turn(slice: slice, quarters: direction.quarters)
        moveCount += 1
        if !hasStarted { hasStarted = true }
        timerRunning = !cube.isSolved
        pushUndo(previous)
        save()
    }

    func scramble() {
        var fresh = RubiksCube()
        _ = fresh.scramble(seed: scrambleSeed)
        scrambleSeed &+= 1
        cube = fresh
        moveCount = 0
        elapsed = 0
        hasStarted = true
        timerRunning = true
        undoStack = []
        save()
    }

    func reset() {
        cube = RubiksCube()
        moveCount = 0
        elapsed = 0
        hasStarted = false
        timerRunning = false
        undoStack = []
        save()
    }

    func tick(by interval: TimeInterval) {
        if timerRunning { elapsed += interval }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        cube = previous.cube
        moveCount = previous.moveCount
        elapsed = previous.elapsed
        timerRunning = previous.timerRunning
        hasStarted = previous.hasStarted
        save()
    }

    private func undoEntry() -> RubiksCubeUndoEntry {
        RubiksCubeUndoEntry(cube: cube,
                            moveCount: moveCount,
                            elapsed: elapsed,
                            timerRunning: timerRunning,
                            hasStarted: hasStarted)
    }

    private func pushUndo(_ entry: RubiksCubeUndoEntry) {
        undoStack.append(entry)
        if undoStack.count > maxUndoEntries {
            undoStack.removeFirst(undoStack.count - maxUndoEntries)
        }
    }

    private func save() {
        guard let persistenceStore, !windowSessionID.isEmpty else { return }
        try? persistenceStore.saveRubiksCube(snapshot(), windowSessionID: windowSessionID)
    }
}
