import Foundation
import XCTest
@testable import PrismetShared

final class PrismetPaiGowSplitLabTests: XCTestCase {
    func testDealIsDeterministicAndPublishesTheUnique53CardModel() throws {
        let first = try PrismetPaiGowSplitLab.dealSeven(seed: 0xCA51_0021)
        let replay = try PrismetPaiGowSplitLab.dealSeven(seed: 0xCA51_0021)

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.phase, .dealt)
        XCTAssertNil(first.lowCardIndices)
        XCTAssertNil(first.analysis)
        XCTAssertEqual(first.cards.count, 7)
        XCTAssertEqual(Set(first.cards).count, 7)
        XCTAssertEqual(PrismetPaiGowSplitLab.totalUnorderedDealCount, 154_143_080)
        XCTAssertEqual(PrismetPaiGowSplitLab.possibleLowAllocationCount, 21)
        XCTAssertEqual(PrismetPaiGowSplitLab.uniqueDeck.count, 53)
        XCTAssertEqual(Set(PrismetPaiGowSplitLab.uniqueDeck).count, 53)
        XCTAssertEqual(PrismetPaiGowSplitLab.uniqueDeck.filter { $0 == .joker }.count, 1)
    }

    func testEveryUnorderedTwoCardAllocationIsAnalyzedAndConservesSevenCards() throws {
        // Every five-card remainder is a flush or straight flush, so every one of C(7, 2)
        // allocations is a legal high-over-low split.
        let cards = [
            paiGowCard(.two, .hearts), paiGowCard(.three, .hearts), paiGowCard(.four, .hearts),
            paiGowCard(.five, .hearts), paiGowCard(.six, .hearts), paiGowCard(.seven, .hearts),
            paiGowCard(.eight, .hearts),
        ]
        var analyses: [PrismetPaiGowSplitAnalysis] = []

        for first in 0..<6 {
            for second in (first + 1)..<7 {
                let analysis = try PrismetPaiGowSplitLab.analyze(cards: cards, lowCardIndices: [second, first])
                analyses.append(analysis)
                XCTAssertEqual(analysis.lowCardIndices, [first, second])
                XCTAssertEqual(analysis.lowCards.count, 2)
                XCTAssertEqual(analysis.highCards.count, 5)
                XCTAssertGreaterThan(analysis.highComparableValue, analysis.lowComparableValue)
                XCTAssertEqual(Set(analysis.lowCards + analysis.highCards), Set(cards))
                XCTAssertEqual(analysis.lowCards.count + analysis.highCards.count, cards.count)
            }
        }

        XCTAssertEqual(analyses.count, PrismetPaiGowSplitLab.possibleLowAllocationCount)
        XCTAssertEqual(Set(analyses.map(\ .lowCardIndices)).count, 21)
    }

    func testSplitSelectionRejectsDuplicateAndOutOfRangeIndices() throws {
        let dealt = try PrismetPaiGowSplitLab.dealSeven(seed: 12)

        XCTAssertThrowsError(try PrismetPaiGowSplitLab.selectLowCards(at: [0], in: dealt)) {
            XCTAssertEqual($0 as? PrismetPaiGowSplitLabError, .invalidLowCardCount(1))
        }
        XCTAssertThrowsError(try PrismetPaiGowSplitLab.selectLowCards(at: [0, 0], in: dealt)) {
            XCTAssertEqual($0 as? PrismetPaiGowSplitLabError, .duplicateLowCardIndex(0))
        }
        XCTAssertThrowsError(try PrismetPaiGowSplitLab.selectLowCards(at: [-1, 1], in: dealt)) {
            XCTAssertEqual($0 as? PrismetPaiGowSplitLabError, .invalidLowCardIndex(-1))
        }
        XCTAssertThrowsError(try PrismetPaiGowSplitLab.selectLowCards(at: [1, 7], in: dealt)) {
            XCTAssertEqual($0 as? PrismetPaiGowSplitLabError, .invalidLowCardIndex(7))
        }
    }

    func testSelectedSplitReplaysExactlyAndConservesTheOriginalDeal() throws {
        let dealt = try PrismetPaiGowSplitLab.dealSeven(seed: 0xD37E_7A11)
        let indices = try legalIndices(in: dealt)
        let selected = try PrismetPaiGowSplitLab.selectLowCards(at: indices.reversed(), in: dealt)
        let replay = try PrismetPaiGowSplitLab.selectLowCards(at: indices, in: try PrismetPaiGowSplitLab.dealSeven(seed: 0xD37E_7A11))
        let analysis = try XCTUnwrap(selected.analysis)

        XCTAssertEqual(selected, replay)
        XCTAssertEqual(selected.phase, .splitSelected)
        XCTAssertEqual(selected.lowCardIndices, indices)
        XCTAssertEqual(Set(analysis.lowCards + analysis.highCards), Set(dealt.cards))
        XCTAssertEqual(analysis.lowCards.count + analysis.highCards.count, dealt.cards.count)
        XCTAssertEqual(try PrismetPaiGowSplitLab.changingSplit(to: indices.reversed(), in: selected), selected)
    }

    func testWheelRanksBelowSixHighAndAceHighStraights() throws {
        let wheel = try PrismetPaiGowSplitLab.evaluateHighHand([
            paiGowCard(.ace, .clubs), paiGowCard(.two, .diamonds), paiGowCard(.three, .hearts),
            paiGowCard(.four, .spades), paiGowCard(.five, .clubs),
        ])
        let sixHigh = try PrismetPaiGowSplitLab.evaluateHighHand([
            paiGowCard(.two, .clubs), paiGowCard(.three, .diamonds), paiGowCard(.four, .hearts),
            paiGowCard(.five, .spades), paiGowCard(.six, .clubs),
        ])
        let aceHigh = try PrismetPaiGowSplitLab.evaluateHighHand([
            paiGowCard(.ten, .clubs), paiGowCard(.jack, .diamonds), paiGowCard(.queen, .hearts),
            paiGowCard(.king, .spades), paiGowCard(.ace, .clubs),
        ])

        XCTAssertEqual(wheel.category, .straight)
        XCTAssertLessThan(wheel, sixHigh)
        XCTAssertLessThan(wheel, aceHigh)
        XCTAssertLessThan(sixHigh, aceHigh)
    }

    func testJokerAsAceCompletesFiveAcesAndDefaultsToAceWhenNoSpecialHandExists() throws {
        let defaultAce = try PrismetPaiGowSplitLab.evaluateHighHand([
            .joker, paiGowCard(.king, .clubs), paiGowCard(.nine, .diamonds),
            paiGowCard(.six, .hearts), paiGowCard(.three, .spades),
        ])
        let fiveAces = try PrismetPaiGowSplitLab.evaluateHighHand([
            .joker, paiGowCard(.ace, .clubs), paiGowCard(.ace, .diamonds),
            paiGowCard(.ace, .hearts), paiGowCard(.ace, .spades),
        ])

        XCTAssertEqual(defaultAce.jokerSubstitution, .ace)
        XCTAssertEqual(defaultAce.tieBreakRanks, [14, 13, 9, 6, 3])
        XCTAssertEqual(fiveAces.category, .fiveAces)
        XCTAssertEqual(fiveAces.jokerSubstitution, .ace)
    }

    func testJokerCompletesStraightAndFlushIncludingStraightFlushWithoutDuplicatingNaturalCards() throws {
        let straight = try PrismetPaiGowSplitLab.evaluateHighHand([
            .joker, paiGowCard(.two, .clubs), paiGowCard(.three, .diamonds),
            paiGowCard(.four, .hearts), paiGowCard(.five, .spades),
        ])
        let flush = try PrismetPaiGowSplitLab.evaluateHighHand([
            .joker, paiGowCard(.ace, .hearts), paiGowCard(.king, .hearts),
            paiGowCard(.nine, .hearts), paiGowCard(.six, .hearts),
        ])
        let straightFlush = try PrismetPaiGowSplitLab.evaluateHighHand([
            .joker, paiGowCard(.ten, .spades), paiGowCard(.jack, .spades),
            paiGowCard(.queen, .spades), paiGowCard(.king, .spades),
        ])

        XCTAssertEqual(straight.category, .straight)
        XCTAssertEqual(straight.tieBreakRanks, [PrismetCardRank.six.rawValue])
        XCTAssertEqual(straight.jokerSubstitution, .straight(rank: .six))
        XCTAssertEqual(flush.category, .flush)
        XCTAssertEqual(flush.jokerSubstitution, .flush(suit: .hearts, rank: .queen))
        XCTAssertEqual(flush.tieBreakRanks, [14, 13, 12, 9, 6])
        XCTAssertEqual(straightFlush.category, .royalFlush)
        XCTAssertEqual(straightFlush.jokerSubstitution, .straightFlush(suit: .spades, rank: .ace))
    }

    func testJokerChoosesTheStrongestLegalSubstitution() throws {
        let value = try PrismetPaiGowSplitLab.evaluateHighHand([
            .joker, paiGowCard(.nine, .clubs), paiGowCard(.ten, .clubs),
            paiGowCard(.jack, .clubs), paiGowCard(.queen, .clubs),
        ])

        XCTAssertEqual(value.category, .straightFlush)
        XCTAssertEqual(value.tieBreakRanks, [13])
        XCTAssertEqual(value.jokerSubstitution, .straightFlush(suit: .clubs, rank: .king))
    }

    func testCodableRejectsPhaseAndAnalysisTampering() throws {
        let dealt = try PrismetPaiGowSplitLab.dealSeven(seed: 0xC0DE)
        let selected = try PrismetPaiGowSplitLab.selectLowCards(at: try legalIndices(in: dealt), in: dealt)
        let encoded = try JSONEncoder().encode(selected)
        let original = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        var phaseTampered = original
        phaseTampered["phase"] = PrismetPaiGowSplitLabPhase.dealt.rawValue
        XCTAssertDecodeFailure(phaseTampered, equals: .invalidPhase)

        var analysisTampered = original
        var analysis = try XCTUnwrap(analysisTampered["analysis"] as? [String: Any])
        var highHand = try XCTUnwrap(analysis["highHand"] as? [String: Any])
        highHand["tieBreakRanks"] = [0]
        analysis["highHand"] = highHand
        analysisTampered["analysis"] = analysis
        XCTAssertDecodeFailure(analysisTampered, equals: .invalidAnalysis)
    }

    private func XCTAssertDecodeFailure(
        _ object: [String: Any],
        equals expected: PrismetPaiGowSplitLabStateValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                PrismetPaiGowSplitLabState.self,
                from: JSONSerialization.data(withJSONObject: object)
            ),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(error as? PrismetPaiGowSplitLabStateValidationError, expected, file: file, line: line)
        }
    }

    private func paiGowCard(_ rank: PrismetCardRank, _ suit: PrismetCardSuit) -> PrismetPaiGowCard {
        .standard(PrismetPlayingCard(rank: rank, suit: suit))
    }

    private func legalIndices(in state: PrismetPaiGowSplitLabState) throws -> [Int] {
        for first in 0..<6 {
            for second in (first + 1)..<7 where (try? PrismetPaiGowSplitLab.analyze(cards: state.cards, lowCardIndices: [first, second])) != nil {
                return [first, second]
            }
        }
        throw NSError(domain: "PrismetPaiGowSplitLabTests", code: 1)
    }
}
