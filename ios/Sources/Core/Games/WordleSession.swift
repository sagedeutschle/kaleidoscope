import Foundation

enum WordleLaunchConfiguration {
    static let isEnabledForLaunchReview = true
    static let isRemoteDailyEnabled = true
    static let remoteDailyURL = URL(string: "https://prismet.xyz/api/wordle")
}

@MainActor
final class WordleSession: ObservableObject {
    @Published private(set) var dailyWord: DailyWord
    @Published private(set) var game: WordPuzzleGame
    @Published private(set) var currentGuess = ""
    @Published private(set) var mode: WordleMode
    @Published private(set) var message = ""
    @Published private(set) var leaderboardEntries: [WordleLeaderboardEntry] = []
    @Published private(set) var shouldPromptPractice = false

    private let provider: DailyWordProvider
    private let leaderboard: WordleLeaderboardStore
    private let isRemoteDailyEnabled: Bool
    private let persistence = PersistedGameSession<WordleSnapshot>(gameID: .wordle)
    private var accountID: UUID?
    private var didSubmitResult = false

    var canLoadRemoteDaily: Bool { isRemoteDailyEnabled }

    init(
        provider: DailyWordProvider = DailyWordProvider(localWords: WordleWords.all),
        leaderboard: WordleLeaderboardStore = .shared,
        isRemoteDailyEnabled: Bool = WordleLaunchConfiguration.isRemoteDailyEnabled
    ) {
        self.provider = provider
        self.leaderboard = leaderboard
        self.isRemoteDailyEnabled = isRemoteDailyEnabled
        let word = provider.localWord()
        self.dailyWord = word
        self.game = WordPuzzleGame(answer: word.answer, allowedWords: WordleWords.approvedGuesses)
        self.mode = .localDaily
    }

    func configure(
        accountID: UUID?,
        store: GameSaveStore = .shared,
        cloudStore: GameCloudSyncStore? = nil
    ) {
        self.accountID = accountID
        persistence.configure(accountID: accountID, store: store, cloudStore: cloudStore) { [weak self] snapshot in
            self?.restore(snapshot)
        }
        Task { await refreshLeaderboard() }
    }

    func appendLetter(_ letter: String) {
        guard let first = letter.first else { return }
        appendLetter(first)
    }

    func appendLetter(_ letter: Character) {
        guard !game.isComplete, currentGuess.count < game.answer.count else { return }
        let normalized = String(letter).lowercased().filter(\.isLetter)
        guard normalized.count == 1 else { return }
        currentGuess.append(normalized)
        save()
    }

    func appendTextInput(_ text: String) {
        for letter in text where letter.isLetter {
            appendLetter(letter)
            if currentGuess.count == game.answer.count {
                break
            }
        }
    }

    static func displayDateLabel(_ label: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"

        guard let date = parser.date(from: label) else {
            return label
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    func deleteLetter() {
        guard !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
        save()
    }

    @discardableResult
    func submitGuess() -> Bool {
        guard !game.isComplete, currentGuess.count == game.answer.count else { return false }
        guard game.isAllowedGuess(currentGuess) else {
            message = "Not in word list"
            return false
        }
        guard game.submit(currentGuess) else { return false }
        currentGuess = ""
        message = game.isSolved ? "Got it!" : ""
        save(forceCloud: game.isComplete)

        if game.isComplete {
            Task { await submitLeaderboardIfNeeded() }
        }
        return true
    }

    func startPractice(answer: String? = nil) {
        let resolvedAnswer = Self.normalize(answer) ?? provider.randomWord().answer
        let word = DailyWord(answer: resolvedAnswer, dateLabel: "Practice", source: .random)
        start(word: word, mode: .practice, message: "Practice puzzle")
    }

    func startLocalDaily(date: Date = Date()) {
        let word = provider.localWord(for: date)
        start(word: word, mode: .localDaily, message: "Local daily puzzle")
    }

    func loadDaily(date: Date = Date()) async {
        guard isRemoteDailyEnabled, let remoteDailyURL = WordleLaunchConfiguration.remoteDailyURL else {
            startLocalDaily(date: date)
            return
        }

        if isCompletedTodayRemoteDaily(date: date) {
            promptPracticeForCompletedDaily()
            return
        }

        _ = loadCachedDailyIfAvailable(date: date)

        do {
            let word = try await provider.remoteWord(from: remoteDailyURL)
            if word != dailyWord {
                start(word: word, mode: .daily, message: "Daily puzzle loaded")
            }
        } catch {
            if mode != .daily {
                let fallback = provider.localWord(for: date)
                start(word: fallback, mode: .localDaily, message: "Daily unavailable; loaded local daily")
            }
        }
    }

    @discardableResult
    func loadCachedDailyIfAvailable(date: Date = Date()) -> Bool {
        guard isRemoteDailyEnabled,
              let remoteDailyURL = WordleLaunchConfiguration.remoteDailyURL,
              !isCompletedTodayRemoteDaily(date: date),
              let cached = provider.cachedRemoteWord(from: remoteDailyURL, date: date)
        else { return false }

        start(word: cached, mode: .daily, message: "Daily puzzle loaded")
        return true
    }

    func loadDailyIfFreshStart(date: Date = Date()) async {
        if mode == .practice {
            await loadDaily(date: date)
            return
        }

        if await refreshChangedCurrentDaily(date: date) {
            return
        }

        guard mode == .localDaily,
              game.rows.isEmpty,
              currentGuess.isEmpty,
              message.isEmpty
        else { return }

        await loadDaily(date: date)
    }

    func dismissPracticePrompt() {
        shouldPromptPractice = false
    }

    func refreshLeaderboard() async {
        do {
            leaderboardEntries = try await leaderboard.entries(mode: mode, limit: 10)
        } catch {
            leaderboardEntries = []
        }
    }

    func saveNow() {
        save(forceCloud: true)
    }

    func snapshot() -> WordleSnapshot {
        WordleSnapshot(
            dailyWord: dailyWord,
            game: game,
            currentGuess: currentGuess,
            mode: mode,
            didSubmitResult: didSubmitResult
        )
    }

    private func start(word: DailyWord, mode: WordleMode, message: String) {
        dailyWord = word
        game = WordPuzzleGame(answer: word.answer, allowedWords: WordleWords.approvedGuesses)
        currentGuess = ""
        self.mode = mode
        self.message = message
        didSubmitResult = false
        shouldPromptPractice = false
        save(forceCloud: true)
        Task { await refreshLeaderboard() }
    }

    private func restore(_ snapshot: WordleSnapshot) {
        dailyWord = snapshot.dailyWord
        game = snapshot.game.replacingAllowedWords(WordleWords.approvedGuesses)
        currentGuess = snapshot.currentGuess
        mode = snapshot.mode
        didSubmitResult = snapshot.didSubmitResult
        message = snapshot.mode.displayName
        updatePracticePromptForCurrentState()
        Task { await refreshLeaderboard() }
    }

    private func save(forceCloud: Bool = false) {
        let score = game.isSolved ? game.rows.count : nil
        persistence.save(snapshot: snapshot(), score: score, forceCloud: forceCloud)
    }

    private func submitLeaderboardIfNeeded() async {
        guard game.isSolved, !didSubmitResult, let accountID else {
            save(forceCloud: true)
            return
        }

        didSubmitResult = true
        let entry = WordleLeaderboardEntry(
            accountID: accountID,
            mode: mode,
            sourceName: mode == .practice ? "Practice" : dailyWord.source.displayName,
            dateLabel: dailyWord.dateLabel,
            guesses: game.rows.count,
            maxGuesses: game.maxGuesses
        )
        try? await leaderboard.submit(entry)
        LeaderboardCoordinator.shared.submit(.wordle, score: game.rows.count)
        save(forceCloud: true)
        await refreshLeaderboard()
    }

    private static func normalize(_ answer: String?) -> String? {
        guard let answer else { return nil }
        let normalized = answer.lowercased().filter(\.isLetter)
        return normalized.count == 5 ? normalized : nil
    }

    private func updatePracticePromptForCurrentState(date: Date = Date()) {
        if isCompletedTodayRemoteDaily(date: date) {
            promptPracticeForCompletedDaily()
        } else {
            shouldPromptPractice = false
        }
    }

    private func isCompletedTodayRemoteDaily(date: Date) -> Bool {
        mode == .daily &&
        game.isComplete &&
        dailyWord.dateLabel == provider.localWord(for: date).dateLabel
    }

    private func promptPracticeForCompletedDaily() {
        shouldPromptPractice = true
        message = "Today's daily puzzle is complete. Practice instead?"
    }

    private func refreshChangedCurrentDaily(date: Date) async -> Bool {
        guard mode == .daily,
              !game.isComplete,
              isRemoteDailyEnabled,
              let remoteDailyURL = WordleLaunchConfiguration.remoteDailyURL,
              dailyWord.dateLabel == provider.localWord(for: date).dateLabel
        else { return false }

        do {
            let word = try await provider.remoteWord(from: remoteDailyURL)
            guard word.dateLabel == dailyWord.dateLabel,
                  word.answer != dailyWord.answer
            else { return false }

            start(word: word, mode: .daily, message: "Daily puzzle updated")
            return true
        } catch {
            return false
        }
    }
}
