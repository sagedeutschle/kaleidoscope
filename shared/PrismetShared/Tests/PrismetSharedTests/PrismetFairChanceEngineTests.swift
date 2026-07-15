import XCTest
@testable import PrismetShared

final class PrismetFairChanceEngineTests: XCTestCase {
    func testProbabilityFractionReducesAndRejectsInvalidValues() throws {
        XCTAssertEqual(try PrismetProbabilityFraction(26, 52), try PrismetProbabilityFraction(1, 2))
        XCTAssertEqual(try PrismetProbabilityFraction(15, 36), try PrismetProbabilityFraction(5, 12))
        XCTAssertEqual(try PrismetProbabilityFraction(84, 220), try PrismetProbabilityFraction(21, 55))
        XCTAssertThrowsError(try PrismetProbabilityFraction(1, 0))
        XCTAssertThrowsError(try PrismetProbabilityFraction(-1, 2))
    }

    func testSameRequestAndSeedProduceIdenticalResult() throws {
        let request = PrismetPracticeRoundRequest(gameID: .coinCall, choiceIDs: ["heads"])
        XCTAssertEqual(
            try PrismetFairChanceEngine.play(request, seed: 42),
            try PrismetFairChanceEngine.play(request, seed: 42)
        )
    }

    func testCompactGamesPublishTheirExactFractions() throws {
        try assertFractions(game: .redBlack, choices: ["red"], expected: ["Red": (1, 2), "Black": (1, 2)])
        let higherLower = try PrismetFairChanceEngine.previewHigherLower(seed: 17)
        let shownRank = Int(higherLower.shownCard.secondary ?? "")!
        let conditional = Dictionary(uniqueKeysWithValues: higherLower.probabilities.map { ($0.label, ($0.fraction.numerator, $0.fraction.denominator)) })
        XCTAssertEqual(conditional["Higher"]?.0, (14 - shownRank) * 4)
        XCTAssertEqual(conditional["Higher"]?.1, 51)
        XCTAssertEqual(conditional["Lower"]?.0, (shownRank - 2) * 4)
        XCTAssertEqual(conditional["Lower"]?.1, 51)
        XCTAssertEqual(conditional["Equal rank"]?.0, 1)
        XCTAssertEqual(conditional["Equal rank"]?.1, 17)
        try assertFractions(game: .highCard, choices: [], expected: ["Higher": (8, 17), "Lower": (8, 17), "Equal rank": (1, 17)])
        try assertFractions(game: .coinCall, choices: ["tails"], expected: ["Heads": (1, 2), "Tails": (1, 2)])
        try assertFractions(game: .diceDuel, choices: [], expected: ["Higher": (5, 12), "Lower": (5, 12), "Tie": (1, 6)])
        try assertFractions(game: .overUnderSeven, choices: ["below"], expected: ["Below seven": (5, 12), "Above seven": (5, 12), "Seven": (1, 6)])
        try assertFractions(game: .oddEven, choices: ["odd"], expected: ["Odd": (1, 2), "Even": (1, 2)])
        try assertFractions(game: .fairWheel, choices: ["ivory"], expected: ["Ivory": (1, 2), "Emerald": (1, 2), "Each segment": (1, 12)])
        try assertFractions(game: .numberDraw, choices: ["1", "2", "3"], expected: ["Zero matches": (21, 55), "One match": (27, 55), "Two matches": (27, 220), "Three matches": (1, 220)])
    }

    func testCardAndNumberDrawRoundsConserveUniqueCardsAndNumbers() throws {
        let preview = try PrismetFairChanceEngine.previewHigherLower(seed: 8)
        XCTAssertEqual(try PrismetFairChanceEngine.previewHigherLower(seed: 8), preview)

        let cardRound = try PrismetFairChanceEngine.play(.init(gameID: .higherLower, choiceIDs: ["higher"]), seed: 8)
        XCTAssertEqual(cardRound.tokens.count, 2)
        XCTAssertEqual(cardRound.tokens[0], preview.shownCard)
        XCTAssertEqual(Set(cardRound.tokens.map(\.id)).count, 2)
        XCTAssertTrue(Set(cardRound.tokens.map(\.id)).isSubset(of: Set(PrismetDeckFactory.standard52().map(\.id))))

        let typedRound = try PrismetFairChanceEngine.resolveHigherLower(preview, choice: .higher)
        XCTAssertEqual(typedRound, cardRound)

        let numberRound = try PrismetFairChanceEngine.play(.init(gameID: .numberDraw, choiceIDs: ["1", "2", "3"]), seed: 9)
        XCTAssertEqual(numberRound.tokens.count, 3)
        XCTAssertEqual(Set(numberRound.tokens.map(\.id)).count, 3)
    }

    func testDicePairMathematicsExhaustivelyEnumeratesAllThirtySixOrderedOutcomes() {
        let pairs = [(1...6).flatMap { first in (1...6).map { second in (first, second) } }]
        XCTAssertEqual(pairs[0].count, 36)
        XCTAssertEqual(pairs[0].filter { $0.0 > $0.1 }.count, 15)
        XCTAssertEqual(pairs[0].filter { $0.0 < $0.1 }.count, 15)
        XCTAssertEqual(pairs[0].filter { $0.0 == $0.1 }.count, 6)
        XCTAssertEqual(pairs[0].filter { $0.0 + $0.1 < 7 }.count, 15)
        XCTAssertEqual(pairs[0].filter { $0.0 + $0.1 > 7 }.count, 15)
        XCTAssertEqual(pairs[0].filter { $0.0 + $0.1 == 7 }.count, 6)
        XCTAssertEqual(pairs[0].filter { ($0.0 + $0.1).isMultiple(of: 2) }.count, 18)
    }

    func testWheelMathematicsExhaustivelyEnumeratesAllTwelveSegments() {
        let segments = Array(1...12)
        XCTAssertEqual(segments.count, 12)
        XCTAssertEqual(segments.filter { $0 <= 6 }.count, 6)
        XCTAssertEqual(segments.filter { $0 >= 7 }.count, 6)
        XCTAssertEqual(Set(segments).count, 12)
    }

    func testNumberDrawMathematicsExhaustivelyEnumeratesAllCombinations() {
        let selected = Set([1, 2, 3])
        var matchCounts = Array(repeating: 0, count: 4)
        for first in 1...10 {
            for second in (first + 1)...11 {
                for third in (second + 1)...12 {
                    matchCounts[[first, second, third].filter { selected.contains($0) }.count] += 1
                }
            }
        }
        XCTAssertEqual(matchCounts, [84, 108, 27, 1])
        XCTAssertEqual(matchCounts.reduce(0, +), 220)
    }

    func testInvalidChoicesFailBeforeAResultExists() {
        XCTAssertThrowsError(try PrismetFairChanceEngine.play(.init(gameID: .numberDraw, choiceIDs: ["1", "1", "2"]), seed: 7))
        XCTAssertThrowsError(try PrismetFairChanceEngine.play(.init(gameID: .numberDraw, choiceIDs: ["1", "2", "13"]), seed: 7))
        XCTAssertThrowsError(try PrismetFairChanceEngine.play(.init(gameID: .coinCall, choiceIDs: []), seed: 7))
        XCTAssertThrowsError(try PrismetFairChanceEngine.play(.init(gameID: .blackjack, choiceIDs: []), seed: 7))
        XCTAssertThrowsError(try PrismetFairChanceEngine.play(.init(gameID: .fiveCardDraw, choiceIDs: []), seed: 7))
    }

    private func assertFractions(
        game: PrismetPracticeCasinoGameID,
        choices: [String],
        expected: [String: (Int, Int)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let result = try PrismetFairChanceEngine.play(.init(gameID: game, choiceIDs: choices), seed: 17)
        let actual = Dictionary(uniqueKeysWithValues: result.probabilities.map { ($0.label, ($0.fraction.numerator, $0.fraction.denominator)) })
        for (label, fraction) in expected {
            XCTAssertEqual(actual[label]?.0, fraction.0, file: file, line: line)
            XCTAssertEqual(actual[label]?.1, fraction.1, file: file, line: line)
        }
    }
}
