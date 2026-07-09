import XCTest
@testable import Kaleidoscope

final class WordleSessionTests: XCTestCase {
    func testHomeShowsWordleInDailyForV8Build() {
        let card = GameCard.all.first { $0.id == "wordle" }
        // "Wordgame" is the App Store-safe display name ("Wordle" is trademarked).
        XCTAssertEqual(card?.title, "Wordgame")
        XCTAssertEqual(card?.category, "Daily")
    }

    func testBrokerDailyIsEnabledByDefaultForV8Build() {
        XCTAssertTrue(WordleLaunchConfiguration.isEnabledForLaunchReview)
        XCTAssertTrue(WordleLaunchConfiguration.isRemoteDailyEnabled)
        XCTAssertEqual(WordleLaunchConfiguration.remoteDailyURL?.host, "prismet.xyz")
        XCTAssertEqual(WordleLaunchConfiguration.remoteDailyURL?.path, "/api/wordle")
    }

    @MainActor
    func testDefaultSessionCanLoadRemoteDailyFromBroker() {
        let session = WordleSession()

        XCTAssertTrue(session.canLoadRemoteDaily)
    }

    func testBrokerPayloadDefaultsToDailySourceName() throws {
        let data = #"{"answer":"Crane","date":"2026-07-01"}"#.data(using: .utf8)!
        let word = try DailyWordProvider.decodeRemotePayload(data)

        XCTAssertEqual(word.answer, "crane")
        XCTAssertEqual(word.dateLabel, "2026-07-01")
        XCTAssertEqual(word.source.displayName, "Daily")
    }

    func testDailyWordCacheRoundTripsRemoteDailyByURLAndDate() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("daily-word-cache-\(UUID().uuidString).json")
        let cache = DailyWordCache(fileURL: fileURL)
        let url = try XCTUnwrap(WordleLaunchConfiguration.remoteDailyURL)
        let word = DailyWord(answer: "crane", dateLabel: "2026-07-02", source: .remote(name: "Daily"))

        try cache.save(word, url: url)

        XCTAssertEqual(try cache.load(url: url, dateLabel: "2026-07-02"), word)
        XCTAssertNil(try cache.load(url: url, dateLabel: "2026-07-03"))
        XCTAssertNil(try cache.load(url: URL(string: "https://example.com/other.json")!, dateLabel: "2026-07-02"))
    }

    @MainActor
    func testSessionCanShowCachedDailyBeforeFreshRemoteCompletes() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("daily-word-cache-\(UUID().uuidString).json")
        let cache = DailyWordCache(fileURL: fileURL)
        let url = try XCTUnwrap(WordleLaunchConfiguration.remoteDailyURL)
        let today = DailyWordProvider(localWords: ["crane"]).localWord().dateLabel
        try cache.save(DailyWord(answer: "crane", dateLabel: today, source: .remote(name: "Daily")), url: url)
        let provider = DailyWordProvider(localWords: ["slate"], remoteCache: cache)
        let session = WordleSession(provider: provider)

        XCTAssertTrue(session.loadCachedDailyIfAvailable())

        XCTAssertEqual(session.mode, .daily)
        XCTAssertEqual(session.dailyWord.answer, "crane")
        XCTAssertEqual(session.message, "Daily puzzle loaded")
    }

    @MainActor
    func testFreshLaunchCorrectsChangedIncompleteRemoteDaily() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountID = UUID()
        let today = DailyWordProvider(localWords: ["crane"]).localWord().dateLabel
        let provider = DailyWordProvider(localWords: ["crane"]) { _ in
            DailyWord(answer: "maven", dateLabel: today, source: .remote(name: "Daily"))
        }
        let snapshot = WordleSnapshot(
            dailyWord: DailyWord(answer: "crane", dateLabel: today, source: .remote(name: "Daily")),
            game: WordPuzzleGame(answer: "crane", allowedWords: WordleWords.all),
            currentGuess: "",
            mode: .daily,
            didSubmitResult: false
        )
        let record = try GameSaveRecord.make(
            accountID: accountID,
            gameID: .wordle,
            score: nil,
            snapshot: snapshot
        )
        try store.save(record)

        let restored = WordleSession(provider: provider)
        restored.configure(accountID: accountID, store: store)
        await restored.loadDailyIfFreshStart()

        XCTAssertEqual(restored.mode, .daily)
        XCTAssertEqual(restored.dailyWord.answer, "maven")
        XCTAssertEqual(restored.game.answer, "maven")
        XCTAssertEqual(restored.message, "Daily puzzle updated")
    }

    @MainActor
    func testRemoteDailyFallsBackToLocalWhenDisabled() async throws {
        let provider = DailyWordProvider(localWords: ["crane", "slate"])
        let session = WordleSession(provider: provider, isRemoteDailyEnabled: false)

        await session.loadDaily()

        XCTAssertEqual(session.mode, .localDaily)
        XCTAssertEqual(session.dailyWord.source, .localDaily)
        XCTAssertEqual(session.message, "Local daily puzzle")
    }

    @MainActor
    func testNativeKeyboardTextInputAppendsOnlyLettersUntilWordLength() {
        let provider = DailyWordProvider(localWords: ["crane", "slate"])
        let session = WordleSession(provider: provider)

        session.appendTextInput("cR")
        session.appendTextInput("a1neXYZ")

        XCTAssertEqual(session.currentGuess, "crane")
    }

    @MainActor
    func testNativeKeyboardBackspaceReportsDeleteWhenInputFieldIsEmpty() {
        let field = NativeKeyboardBackspaceTextField(frame: .zero)
        var deleteCount = 0
        field.onDeleteBackward = { deleteCount += 1 }

        field.text = ""
        field.deleteBackward()

        XCTAssertEqual(deleteCount, 1)
    }

    func testModeSwitchingControlsAreInTopBarNotKeyboardAccessory() throws {
        let testURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Features/Games/WordleView.swift")
        let source = try String(contentsOf: sourceURL)

        XCTAssertFalse(source.contains("placement: .keyboard"))
        XCTAssertTrue(source.contains("placement: .topBarTrailing"))
        XCTAssertTrue(source.contains("Text(\"Daily\")"))
        XCTAssertTrue(source.contains("Text(\"Practice\")"))
    }

    @MainActor
    func testDisplayDateLabelFormatsBrokerDateForPlayers() {
        XCTAssertEqual(WordleSession.displayDateLabel("2026-07-01"), "Jul 1, 2026")
        XCTAssertEqual(WordleSession.displayDateLabel("Practice"), "Practice")
    }

    @MainActor
    func testWordleSessionPracticeModePersistsAndRestores() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountID = UUID()
        let session = WordleSession(provider: DailyWordProvider(localWords: ["crane", "slate"]))

        session.configure(accountID: accountID, store: store)
        session.startPractice(answer: "crane")
        session.appendLetter("c")
        session.appendLetter("r")
        session.appendLetter("a")
        session.appendLetter("n")
        session.appendLetter("e")
        XCTAssertTrue(session.submitGuess())

        let restored = WordleSession(provider: DailyWordProvider(localWords: ["crane", "slate"]))
        restored.configure(accountID: accountID, store: store)

        XCTAssertEqual(restored.mode, .practice)
        XCTAssertEqual(restored.game.answer, "crane")
        XCTAssertTrue(restored.game.isSolved)
    }

    @MainActor
    func testFreshLaunchLoadsDailyInsteadOfRestoredPractice() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountID = UUID()
        let provider = DailyWordProvider(localWords: ["crane", "slate"])
        let savedPractice = WordleSession(provider: provider, isRemoteDailyEnabled: false)

        savedPractice.configure(accountID: accountID, store: store)
        savedPractice.startPractice(answer: "slate")
        savedPractice.saveNow()

        let restored = WordleSession(provider: provider, isRemoteDailyEnabled: false)
        restored.configure(accountID: accountID, store: store)
        await restored.loadDailyIfFreshStart()

        XCTAssertEqual(restored.mode, .localDaily)
        XCTAssertEqual(restored.dailyWord.source, .localDaily)
        XCTAssertNotEqual(restored.dailyWord.dateLabel, "Practice")
        XCTAssertEqual(restored.message, "Local daily puzzle")
    }

    @MainActor
    func testRestoredCompletedTodayDailyPuzzlePromptsForPractice() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = GameSaveStore(rootURL: root)
        let accountID = UUID()
        let provider = DailyWordProvider(localWords: ["crane", "slate"])
        let today = Date()
        var solved = WordPuzzleGame(answer: "crane", allowedWords: WordleWords.all)
        XCTAssertTrue(solved.submit("crane"))
        let todayLabel = provider.localWord(for: today).dateLabel
        let snapshot = WordleSnapshot(
            dailyWord: DailyWord(answer: "crane", dateLabel: todayLabel, source: .remote(name: "Daily")),
            game: solved,
            currentGuess: "",
            mode: .daily,
            didSubmitResult: true
        )
        let record = try GameSaveRecord.make(
            accountID: accountID,
            gameID: .wordle,
            score: 1,
            snapshot: snapshot
        )
        try store.save(record)

        let restored = WordleSession(provider: provider)
        restored.configure(accountID: accountID, store: store)

        XCTAssertTrue(restored.shouldPromptPractice)
        XCTAssertEqual(restored.message, "Today's daily puzzle is complete. Practice instead?")
    }

    @MainActor
    func testWordleLeaderboardKeepsSolvedPracticeResults() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordle-leaderboard-\(UUID().uuidString).json")
        let leaderboard = WordleLeaderboardStore(fileURL: fileURL)
        let accountID = UUID()

        let slow = WordleLeaderboardEntry(
            accountID: accountID,
            mode: .practice,
            sourceName: "Practice",
            dateLabel: "Practice",
            guesses: 5,
            maxGuesses: 6,
            submittedAt: Date(timeIntervalSince1970: 200)
        )
        let fast = WordleLeaderboardEntry(
            accountID: accountID,
            mode: .practice,
            sourceName: "Practice",
            dateLabel: "Practice",
            guesses: 2,
            maxGuesses: 6,
            submittedAt: Date(timeIntervalSince1970: 100)
        )

        try await leaderboard.submit(slow)
        try await leaderboard.submit(fast)

        let entries = try await leaderboard.entries(mode: .practice, limit: 10)
        let personalBest = try await leaderboard.personalBest(mode: .practice)
        XCTAssertEqual(entries.map(\.guesses), [2, 5])
        XCTAssertEqual(personalBest?.guesses, 2)
    }
}
