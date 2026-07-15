import XCTest
@testable import PrismetShared

final class PrismetFairChanceEngineTests: XCTestCase {
    func testProbabilityFractionReducesAndRejectsInvalidValues() throws {
        XCTAssertEqual(try PrismetProbabilityFraction(26, 52), try PrismetProbabilityFraction(1, 2))
        XCTAssertEqual(try PrismetProbabilityFraction(15, 36), try PrismetProbabilityFraction(5, 12))
        XCTAssertEqual(try PrismetProbabilityFraction(84, 220), try PrismetProbabilityFraction(21, 55))
        assertThrowsFairChanceError(.invalidFraction, try PrismetProbabilityFraction(1, 0))
        assertThrowsFairChanceError(.invalidFraction, try PrismetProbabilityFraction(-1, 2))
    }

    func testProbabilityFractionDecodingValidatesAndReduces() throws {
        let decoder = JSONDecoder()

        XCTAssertEqual(
            try decoder.decode(
                PrismetProbabilityFraction.self,
                from: Data(#"{"numerator":26,"denominator":52}"#.utf8)
            ),
            try PrismetProbabilityFraction(1, 2)
        )
        assertThrowsFairChanceError(
            .invalidFraction,
            try decoder.decode(
                PrismetProbabilityFraction.self,
                from: Data(#"{"numerator":1,"denominator":0}"#.utf8)
            )
        )
        assertThrowsFairChanceError(
            .invalidFraction,
            try decoder.decode(
                PrismetProbabilityFraction.self,
                from: Data(#"{"numerator":-1,"denominator":2}"#.utf8)
            )
        )
    }

    func testProbabilityFractionPercentTextHandlesIntMaxScaleValues() throws {
        XCTAssertEqual(
            try PrismetProbabilityFraction(Int.max, 1).percentText,
            "922337203685477580800%"
        )
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
        let shownCard = try XCTUnwrap(
            PrismetDeckFactory.standard52().first { $0.id == higherLower.shownCard.id }
        )
        let shownRank = shownCard.rank.rawValue
        XCTAssertEqual(higherLower.shownCard.primary, shownCard.rank.displayName)
        XCTAssertEqual(higherLower.shownCard.secondary, shownCard.suit.displayName)
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
        try assertCardTokenMetadata(preview.shownCard)

        let cardRound = try PrismetFairChanceEngine.play(.init(gameID: .higherLower, choiceIDs: ["higher"]), seed: 8)
        XCTAssertEqual(cardRound.tokens.count, 2)
        XCTAssertEqual(cardRound.tokens[0], preview.shownCard)
        XCTAssertEqual(Set(cardRound.tokens.map(\.id)).count, 2)
        XCTAssertTrue(Set(cardRound.tokens.map(\.id)).isSubset(of: Set(PrismetDeckFactory.standard52().map(\.id))))
        for token in cardRound.tokens {
            try assertCardTokenMetadata(token)
        }

        let typedRound = try PrismetFairChanceEngine.resolveHigherLower(preview, choice: .higher)
        XCTAssertEqual(typedRound, cardRound)

        let numberRound = try PrismetFairChanceEngine.play(.init(gameID: .numberDraw, choiceIDs: ["1", "2", "3"]), seed: 9)
        XCTAssertEqual(numberRound.tokens.count, 3)
        XCTAssertEqual(Set(numberRound.tokens.map(\.id)).count, 3)
    }

    func testCardRevealTokensCarryRankSuitAndSingularSuitSymbols() throws {
        var tokensBySuit: [PrismetCardSuit: PrismetPracticeRevealToken] = [:]

        for seed in UInt64(0)..<256 where tokensBySuit.count < PrismetCardSuit.allCases.count {
            let round = try PrismetFairChanceEngine.play(
                .init(gameID: .redBlack, choiceIDs: ["red"]),
                seed: seed
            )
            let token = try XCTUnwrap(round.tokens.first)
            let card = try canonicalCard(for: token)
            tokensBySuit[card.suit] = token
        }

        XCTAssertEqual(Set(tokensBySuit.keys), Set(PrismetCardSuit.allCases))
        for token in tokensBySuit.values {
            try assertCardTokenMetadata(token)
            XCTAssertFalse(token.symbol.contains("clubs"))
            XCTAssertFalse(token.symbol.contains("diamonds"))
            XCTAssertFalse(token.symbol.contains("hearts"))
            XCTAssertFalse(token.symbol.contains("spades"))
        }
    }

    func testGoldenDeterministicOutcomesMapTitlesAndTokensForEveryCompactGame() throws {
        let fixtures: [GoldenFixture] = [
            .init(
                gameID: .redBlack,
                choiceIDs: ["red"],
                seed: 17,
                title: "Other color revealed",
                tokens: [
                    revealToken("queen-of-spades", "Queen", "spades", "suit.spade.fill", false),
                ]
            ),
            .init(
                gameID: .higherLower,
                choiceIDs: ["higher"],
                seed: 17,
                title: "Lower revealed",
                tokens: [
                    revealToken("queen-of-spades", "Queen", "spades", "suit.spade.fill", false),
                    revealToken("four-of-spades", "Four", "spades", "suit.spade.fill", false),
                ]
            ),
            .init(
                gameID: .highCard,
                choiceIDs: [],
                seed: 17,
                title: "First card higher",
                tokens: [
                    revealToken("queen-of-spades", "Queen", "spades", "suit.spade.fill", true),
                    revealToken("four-of-spades", "Four", "spades", "suit.spade.fill", false),
                ]
            ),
            .init(
                gameID: .coinCall,
                choiceIDs: ["heads"],
                seed: 17,
                title: "Other side revealed",
                tokens: [
                    revealToken("tails", "Tails", nil, "circle.lefthalf.filled", false),
                ]
            ),
            .init(
                gameID: .diceDuel,
                choiceIDs: [],
                seed: 17,
                title: "First die higher",
                tokens: [
                    revealToken("first-die", "4", nil, "die.face.4", true),
                    revealToken("second-die", "2", nil, "die.face.2", false),
                ]
            ),
            .init(
                gameID: .overUnderSeven,
                choiceIDs: ["below"],
                seed: 17,
                title: "Selected range revealed",
                tokens: [
                    revealToken("die-one", "4", nil, "die.face.4", false),
                    revealToken("die-two", "2", nil, "die.face.2", false),
                ]
            ),
            .init(
                gameID: .oddEven,
                choiceIDs: ["odd"],
                seed: 17,
                title: "Other parity revealed",
                tokens: [
                    revealToken("die-one", "4", nil, "die.face.4", false),
                    revealToken("die-two", "2", nil, "die.face.2", false),
                ]
            ),
            .init(
                gameID: .fairWheel,
                choiceIDs: ["ivory"],
                seed: 1,
                title: "Selected color revealed",
                tokens: [
                    revealToken("wheel-segment-6", "6", "Ivory", "circle.dotted", true),
                ]
            ),
            .init(
                gameID: .fairWheel,
                choiceIDs: ["ivory"],
                seed: 31,
                title: "Other color revealed",
                tokens: [
                    revealToken("wheel-segment-7", "7", "Emerald", "circle.dotted", false),
                ]
            ),
            .init(
                gameID: .numberDraw,
                choiceIDs: ["1", "2", "3"],
                seed: 17,
                title: "1 match",
                tokens: [
                    revealToken("number-11", "11", nil, "number.square", false),
                    revealToken("number-1", "1", nil, "number.square", true),
                    revealToken("number-8", "8", nil, "number.square", false),
                ]
            ),
        ]
        let compactGames: Set<PrismetPracticeCasinoGameID> = [
            .redBlack, .higherLower, .highCard, .coinCall, .diceDuel,
            .overUnderSeven, .oddEven, .fairWheel, .numberDraw,
        ]

        XCTAssertEqual(Set(fixtures.map(\.gameID)), compactGames)
        for fixture in fixtures {
            let result = try PrismetFairChanceEngine.play(
                .init(gameID: fixture.gameID, choiceIDs: fixture.choiceIDs),
                seed: fixture.seed
            )
            XCTAssertEqual(result.gameID, fixture.gameID)
            XCTAssertEqual(result.seed, fixture.seed)
            XCTAssertEqual(result.randomizerVersion, 1)
            XCTAssertEqual(result.title, fixture.title)
            XCTAssertEqual(result.tokens, fixture.tokens)
        }
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

    func testInvalidRequestsThrowExactTypedErrorsBeforeAResultExists() {
        assertThrowsFairChanceError(
            .duplicateChoice("1"),
            try PrismetFairChanceEngine.play(.init(gameID: .numberDraw, choiceIDs: ["1", "1", "2"]), seed: 7)
        )
        assertThrowsFairChanceError(
            .invalidChoice("13"),
            try PrismetFairChanceEngine.play(.init(gameID: .numberDraw, choiceIDs: ["1", "2", "13"]), seed: 7)
        )
        assertThrowsFairChanceError(
            .invalidChoiceCount(expected: 1, actual: 0),
            try PrismetFairChanceEngine.play(.init(gameID: .coinCall, choiceIDs: []), seed: 7)
        )
        assertThrowsFairChanceError(
            .unsupportedGame(.blackjack),
            try PrismetFairChanceEngine.play(.init(gameID: .blackjack, choiceIDs: []), seed: 7)
        )
        assertThrowsFairChanceError(
            .unsupportedGame(.fiveCardDraw),
            try PrismetFairChanceEngine.play(.init(gameID: .fiveCardDraw, choiceIDs: []), seed: 7)
        )
    }

    func testTamperedHigherLowerPreviewsThrowExactTypedErrors() throws {
        let preview = try PrismetFairChanceEngine.previewHigherLower(seed: 8)
        let invalidVersion = PrismetHigherLowerPreview(
            seed: preview.seed,
            randomizerVersion: preview.randomizerVersion + 1,
            shownCard: preview.shownCard,
            probabilities: preview.probabilities
        )
        let invalidCard = PrismetHigherLowerPreview(
            seed: preview.seed,
            randomizerVersion: preview.randomizerVersion,
            shownCard: PrismetPracticeRevealToken(
                id: "tampered-card",
                primary: preview.shownCard.primary,
                secondary: preview.shownCard.secondary,
                symbol: preview.shownCard.symbol,
                isSelected: preview.shownCard.isSelected
            ),
            probabilities: preview.probabilities
        )
        let invalidProbabilities = PrismetHigherLowerPreview(
            seed: preview.seed,
            randomizerVersion: preview.randomizerVersion,
            shownCard: preview.shownCard,
            probabilities: []
        )

        for tamperedPreview in [invalidVersion, invalidCard, invalidProbabilities] {
            assertThrowsFairChanceError(
                .invalidHigherLowerPreview,
                try PrismetFairChanceEngine.resolveHigherLower(tamperedPreview, choice: .higher)
            )
        }
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

    private func canonicalCard(
        for token: PrismetPracticeRevealToken,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> PrismetPlayingCard {
        try XCTUnwrap(
            PrismetDeckFactory.standard52().first { $0.id == token.id },
            "Reveal token must use a canonical card identity.",
            file: file,
            line: line
        )
    }

    private func assertCardTokenMetadata(
        _ token: PrismetPracticeRevealToken,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let card = try canonicalCard(for: token, file: file, line: line)
        XCTAssertEqual(token.primary, card.rank.displayName, file: file, line: line)
        XCTAssertEqual(token.secondary, card.suit.displayName, file: file, line: line)
        XCTAssertEqual(token.symbol, singularSuitSymbol(for: card.suit), file: file, line: line)
    }

    private func singularSuitSymbol(for suit: PrismetCardSuit) -> String {
        switch suit {
        case .clubs: return "suit.club.fill"
        case .diamonds: return "suit.diamond.fill"
        case .hearts: return "suit.heart.fill"
        case .spades: return "suit.spade.fill"
        }
    }

    private func revealToken(
        _ id: String,
        _ primary: String,
        _ secondary: String?,
        _ symbol: String,
        _ isSelected: Bool
    ) -> PrismetPracticeRevealToken {
        PrismetPracticeRevealToken(
            id: id,
            primary: primary,
            secondary: secondary,
            symbol: symbol,
            isSelected: isSelected
        )
    }

    private func assertThrowsFairChanceError<T>(
        _ expected: PrismetFairChanceEngineError,
        _ expression: @autoclosure () throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard let actual = error as? PrismetFairChanceEngineError else {
                XCTFail("Expected PrismetFairChanceEngineError, got \(error)", file: file, line: line)
                return
            }
            XCTAssertEqual(actual, expected, file: file, line: line)
        }
    }

    private struct GoldenFixture {
        let gameID: PrismetPracticeCasinoGameID
        let choiceIDs: [String]
        let seed: UInt64
        let title: String
        let tokens: [PrismetPracticeRevealToken]
    }
}
