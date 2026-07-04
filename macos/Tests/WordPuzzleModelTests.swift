import XCTest
@testable import Kaleidoscope

final class WordPuzzleModelTests: XCTestCase {
    func testRepeatedLettersScoreWithoutOvercounting() {
        let result = WordPuzzleGame.score(guess: "array", answer: "cigar")

        XCTAssertEqual(result.map(\.score), [.absent, .present, .absent, .correct, .absent])
    }

    func testWinningGuessMarksGameComplete() {
        var game = WordPuzzleGame(answer: "cider", allowedWords: ["cider"])

        let accepted = game.submit("cider")

        XCTAssertTrue(accepted)
        XCTAssertTrue(game.isSolved)
        XCTAssertEqual(game.rows.last?.map(\.score), Array(repeating: .correct, count: 5))
    }

    func testAcceptsAnyFiveLetterGuessEvenIfNotARealWord() {
        // Discord-style: no dictionary gate — any 5 letters is a valid guess.
        var game = WordPuzzleGame(answer: "cider", allowedWords: ["cider"])

        XCTAssertTrue(game.submit("zzzzz"))
        XCTAssertEqual(game.rows.count, 1)
    }

    func testRejectsGuessOfWrongLength() {
        var game = WordPuzzleGame(answer: "cider", allowedWords: ["cider"])
        XCTAssertFalse(game.submit("cide"))
        XCTAssertFalse(game.submit("ciders"))
    }

    func testRejectsGuessWithNonLetters() {
        var game = WordPuzzleGame(answer: "cider", allowedWords: ["cider"])
        XCTAssertFalse(game.submit("cid3r"))
        XCTAssertFalse(game.submit("ci er"))
    }
}
