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

struct RemoteDailyWordPayload: Decodable {
    let answer: String
    let date: String
    let sourceName: String?
}

struct DailyWordProvider {
    static let brokerDailyURL = URL(string: "https://cmufcjysgbiqhohozkrf.supabase.co/storage/v1/object/public/kaleidoscope-public/wordle/daily.json")!

    let localWords: [String]
    var calendar: Calendar

    init(localWords: [String], calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.localWords = localWords.map { $0.lowercased() }.filter { $0.count == 5 }
        self.calendar = calendar
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
        let (data, _) = try await URLSession.shared.data(from: url)
        return try Self.decodeRemotePayload(data)
    }

    /// A fresh random puzzle drawn from the local word bank.
    func randomWord() -> DailyWord {
        let words = localWords.isEmpty ? ["cider"] : localWords
        return DailyWord(answer: words.randomElement()!, dateLabel: "Random", source: .random)
    }

    func brokerDailyWord() async throws -> DailyWord {
        try await remoteWord(from: Self.brokerDailyURL)
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
            source: .remote(name: payload.sourceName ?? "Remote Daily")
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
