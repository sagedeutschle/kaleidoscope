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
    private static let requestTimeout: TimeInterval = 8
    private static let maxPayloadBytes = 32 * 1024

    static let brokerDailyURL = URL(string: "https://prismet.xyz/api/wordle")!

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
        guard await AppSecurity.allowClientAction(.remoteContentFetch, scope: url.absoluteString) else {
            throw AppSecurityError.rateLimited
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = Self.requestTimeout
        let (data, response) = try await URLSession.shared.data(for: req)
        if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            throw DailyWordProviderError.network
        }
        guard data.count <= Self.maxPayloadBytes else {
            throw DailyWordProviderError.network
        }
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
    case network
}
