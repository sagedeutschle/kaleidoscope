import Foundation

enum WordPuzzleLetterScore: String, Hashable, Codable {
    case absent
    case present
    case correct
}

struct WordPuzzleGuessResult: Hashable, Identifiable, Codable {
    let id: Int
    let letter: Character
    let score: WordPuzzleLetterScore

    private enum CodingKeys: String, CodingKey { case id, letter, score }

    init(id: Int, letter: Character, score: WordPuzzleLetterScore) {
        self.id = id
        self.letter = letter
        self.score = score
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        let letterString = try container.decode(String.self, forKey: .letter)
        guard let character = letterString.first, letterString.count == 1 else {
            throw DecodingError.dataCorruptedError(forKey: .letter,
                                                   in: container,
                                                   debugDescription: "Expected a single-character string.")
        }
        letter = character
        score = try container.decode(WordPuzzleLetterScore.self, forKey: .score)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(String(letter), forKey: .letter)
        try container.encode(score, forKey: .score)
    }
}

struct WordPuzzleGame: Hashable, Codable {
    let answer: String
    let allowedWords: Set<String>
    let maxGuesses: Int
    private(set) var rows: [[WordPuzzleGuessResult]]

    init(answer: String, allowedWords: [String], maxGuesses: Int = 6) {
        self.answer = answer.lowercased()
        self.allowedWords = Set(allowedWords.map { $0.lowercased() })
        self.maxGuesses = maxGuesses
        self.rows = []
    }

    var isSolved: Bool {
        rows.last?.allSatisfy { $0.score == .correct } ?? false
    }

    var isComplete: Bool {
        isSolved || rows.count >= maxGuesses
    }

    mutating func submit(_ guess: String) -> Bool {
        let normalized = guess.lowercased()
        // Discord-style: accept any combination of letters of the right length —
        // no dictionary check. `allowedWords` is retained for the answer source
        // but no longer gates guesses.
        guard normalized.count == answer.count,
              normalized.allSatisfy({ $0.isLetter }),
              !isComplete else {
            return false
        }

        rows.append(Self.score(guess: normalized, answer: answer))
        return true
    }

    static func score(guess: String, answer: String) -> [WordPuzzleGuessResult] {
        let guessLetters = Array(guess.lowercased())
        let answerLetters = Array(answer.lowercased())
        var scores = Array(repeating: WordPuzzleLetterScore.absent, count: guessLetters.count)
        var remaining: [Character: Int] = [:]

        for index in answerLetters.indices {
            if index < guessLetters.count, guessLetters[index] == answerLetters[index] {
                scores[index] = .correct
            } else {
                remaining[answerLetters[index], default: 0] += 1
            }
        }

        for index in guessLetters.indices where scores[index] != .correct {
            let letter = guessLetters[index]
            if let count = remaining[letter], count > 0 {
                scores[index] = .present
                remaining[letter] = count - 1
            }
        }

        return guessLetters.enumerated().map { index, letter in
            WordPuzzleGuessResult(id: index, letter: letter, score: scores[index])
        }
    }
}
