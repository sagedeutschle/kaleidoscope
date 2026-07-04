import Foundation

enum DailyWordSource: Hashable, Codable {
    case localDaily
    case random
    case remote(name: String)

    var displayName: String {
        switch self {
        case .localDaily:
            return "Local Daily"
        case .random:
            return "Random"
        case .remote(let name):
            return name
        }
    }
}

struct DailyWord: Hashable, Codable {
    let answer: String
    let dateLabel: String
    let source: DailyWordSource
}

struct DailyWordCache {
    private struct Entry: Codable {
        var urlString: String
        var word: DailyWord
    }

    var fileURL: URL

    init(fileURL: URL = Self.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func load(url: URL, dateLabel: String) throws -> DailyWord? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let entry = try JSONDecoder().decode(Entry.self, from: Data(contentsOf: fileURL))
        guard entry.urlString == url.absoluteString,
              entry.word.dateLabel == dateLabel
        else { return nil }
        return entry.word
    }

    func save(_ word: DailyWord, url: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(Entry(urlString: url.absoluteString, word: word))
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Kaleidoscope", isDirectory: true)
            .appendingPathComponent("DailyWordCache.json", isDirectory: false)
    }
}

struct RemoteDailyWordPayload: Decodable {
    let answer: String
    let date: String
    let sourceName: String?
}

struct DailyWordProvider {
    let localWords: [String]
    var calendar: Calendar
    var remoteCache: DailyWordCache?
    var remoteLoader: ((URL) async throws -> DailyWord)?

    init(
        localWords: [String],
        calendar: Calendar = Calendar(identifier: .gregorian),
        remoteCache: DailyWordCache? = DailyWordCache(),
        remoteLoader: ((URL) async throws -> DailyWord)? = nil
    ) {
        self.localWords = localWords.map { $0.lowercased() }.filter { $0.count == 5 }
        self.calendar = calendar
        self.remoteCache = remoteCache
        self.remoteLoader = remoteLoader
    }

    func localWord(for date: Date = Date()) -> DailyWord {
        let words = localWords.isEmpty ? ["cider"] : localWords
        let start = calendar.startOfDay(for: date)
        let dayNumber = Int(start.timeIntervalSince1970 / 86_400)
        let index = abs(dayNumber) % words.count
        return DailyWord(
            answer: words[index],
            dateLabel: Self.dateLabel(for: date),
            source: .localDaily
        )
    }

    func remoteWord(from url: URL) async throws -> DailyWord {
        guard await AppSecurity.allowClientAction(.remoteContentFetch, scope: url.absoluteString) else {
            throw AppSecurityError.rateLimited
        }
        let word: DailyWord
        if let remoteLoader {
            word = try await remoteLoader(url)
        } else {
            let (data, _) = try await URLSession.shared.data(from: url)
            word = try Self.decodeRemotePayload(data)
        }

        try? remoteCache?.save(word, url: url)
        return word
    }

    func cachedRemoteWord(from url: URL, date: Date = Date()) -> DailyWord? {
        try? remoteCache?.load(url: url, dateLabel: Self.dateLabel(for: date))
    }

    /// A fresh random puzzle drawn from the local word bank.
    func randomWord() -> DailyWord {
        let words = localWords.isEmpty ? ["cider"] : localWords
        return DailyWord(answer: words.randomElement()!, dateLabel: "Random", source: .random)
    }

    static func decodeRemotePayload(_ data: Data) throws -> DailyWord {
        let payload = try JSONDecoder().decode(RemoteDailyWordPayload.self, from: data)
        let answer = payload.answer.lowercased().filter(\.isLetter)
        guard answer.count == 5 else {
            throw DailyWordProviderError.invalidRemoteAnswer
        }

        return DailyWord(
            answer: answer,
            dateLabel: payload.date,
            source: .remote(name: payload.sourceName ?? "Daily")
        )
    }

    private static func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum DailyWordProviderError: Error {
    case invalidRemoteAnswer
}
