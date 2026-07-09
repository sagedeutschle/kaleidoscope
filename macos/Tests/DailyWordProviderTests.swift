import XCTest
@testable import Kaleidoscope

final class DailyWordProviderTests: XCTestCase {
    func testLocalFallbackIsStableForSameDate() throws {
        let provider = DailyWordProvider(localWords: ["cider", "brick", "plane"])
        let date = Date(timeIntervalSince1970: 1_783_468_800)

        let first = provider.localWord(for: date)
        let second = provider.localWord(for: date)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.source, .localDaily)
        XCTAssertTrue(["cider", "brick", "plane"].contains(first.answer))
    }

    func testDecodesBrokerPayload() throws {
        let data = """
        {"answer":"acute","date":"2026-06-26","sourceName":"Daily"}
        """.data(using: .utf8)!

        let word = try DailyWordProvider.decodeRemotePayload(data)

        XCTAssertEqual(word.answer, "acute")
        XCTAssertEqual(word.dateLabel, "2026-06-26")
        XCTAssertEqual(word.source, .remote(name: "Daily"))
    }

    func testBrokerPayloadRejectsNonFiveLetterAnswer() {
        let data = #"{"answer":"toolong","date":"2026-06-26","sourceName":"Daily"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try DailyWordProvider.decodeRemotePayload(data))
    }

    func testBrokerDailyURLUsesPublicStorageEndpoint() {
        XCTAssertEqual(DailyWordProvider.brokerDailyURL.absoluteString,
                       "https://prismet.xyz/api/wordle")
    }

    func testRandomWordIsFiveLettersFromBank() {
        let bank = ["cider", "brick", "plane", "crane"]
        let provider = DailyWordProvider(localWords: bank)

        let word = provider.randomWord()

        XCTAssertEqual(word.answer.count, 5)
        XCTAssertTrue(bank.contains(word.answer))
        XCTAssertEqual(word.source, .random)
    }

    func testRemotePayloadDecodesAuthorizedDailyWord() throws {
        let data = """
        {
          "answer": "crane",
          "date": "2026-06-26",
          "sourceName": "Authorized Daily"
        }
        """.data(using: .utf8)!

        let word = try DailyWordProvider.decodeRemotePayload(data)

        XCTAssertEqual(word.answer, "crane")
        XCTAssertEqual(word.dateLabel, "2026-06-26")
        XCTAssertEqual(word.source, .remote(name: "Authorized Daily"))
    }
}
