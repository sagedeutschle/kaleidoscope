import XCTest
@testable import PrismetShared

final class PrismetPracticeCasinoCatalogTests: XCTestCase {
    func testCatalogAndAllCasesLockExactlyElevenStableUniqueRawIDs() {
        let expected: [(id: PrismetPracticeCasinoGameID, rawValue: String)] = [
            (.blackjack, "blackjack"),
            (.fiveCardDraw, "five-card-draw"),
            (.redBlack, "red-black"),
            (.higherLower, "higher-lower"),
            (.highCard, "high-card"),
            (.coinCall, "coin-call"),
            (.diceDuel, "dice-duel"),
            (.overUnderSeven, "over-under-seven"),
            (.oddEven, "odd-even"),
            (.fairWheel, "fair-wheel"),
            (.numberDraw, "number-draw"),
        ]
        let expectedIDs = expected.map(\.id)
        let expectedRawValues = expected.map(\.rawValue)
        let allCases = PrismetPracticeCasinoGameID.allCases
        let catalogIDs = PrismetPracticeCasinoCatalog.all.map(\.id)

        XCTAssertEqual(allCases.count, 11)
        XCTAssertEqual(allCases, expectedIDs)
        XCTAssertEqual(allCases.map(\.rawValue), expectedRawValues)
        XCTAssertEqual(Set(allCases.map(\.rawValue)).count, 11)

        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.count, 11)
        XCTAssertEqual(catalogIDs, expectedIDs)
        XCTAssertEqual(catalogIDs, allCases)
        XCTAssertEqual(Set(catalogIDs), Set(allCases))
        XCTAssertEqual(Set(catalogIDs).count, 11)

        for id in allCases {
            XCTAssertEqual(PrismetPracticeCasinoCatalog[id].id, id)
        }
    }

    func testEveryEntryHasRulesFairnessAndAnExplicitAction() {
        for game in PrismetPracticeCasinoCatalog.all {
            XCTAssertFalse(game.rules.isEmpty)
            XCTAssertFalse(game.fairness.isEmpty)
            XCTAssertFalse(game.actionTitle.isEmpty)
            XCTAssertGreaterThan(game.rulesVersion, 0)
        }
    }

    func testSelectionRulesMatchTheElevenTableContract() {
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.redBlack].selectionRule, .exactly(1))
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.diceDuel].selectionRule, .none)
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.numberDraw].selectionRule, .exactly(3))
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.fiveCardDraw].kind, .poker)
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.blackjack].kind, .blackjack)
    }

    func testEveryTablePublishesItsCompleteExactFairnessDisclosure() {
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.blackjack].id.rawValue, PrismetBlackjackRulesV1.canonicalGameID)

        let expected: [PrismetPracticeCasinoGameID: String] = [
            .blackjack: "Hit bust odds are a dynamic exact visible-information count: unseen cards that would put this hand over 21 / all unseen cards. Only your cards and the dealer’s face-up card are treated as visible; the hole card and draw pile remain unseen. Dealer stands on every 17, including soft 17 (S17). Blackjack is not a 50/50 game.",
            .fiveCardDraw: "Each opening hand is one of 2,598,960 equally likely combinations. High card: 1,302,540; One pair: 1,098,240; Two pair: 123,552; Three of a kind: 54,912; Straight: 10,200; Flush: 5,108; Full house: 3,744; Four of a kind: 624. The standard straight-flush family total is 40: 36 non-royal straight flushes plus 4 royal flushes. Engine display categories remain mutually exclusive: Straight flush (non-royal): 36; Royal flush: 4; no hand is double-counted.",
            .redBlack: "Red: 26/52. Black: 26/52.",
            .higherLower: "Conditional on shown rank: Higher = (14-rank)*4/51. Lower = (rank-2)*4/51. Equal = 3/51 and neutral.",
            .highCard: "Higher: 8/17. Lower: 8/17. Equal rank: 1/17.",
            .coinCall: "Heads: 1/2. Tails: 1/2.",
            .diceDuel: "Higher: 15/36. Lower: 15/36. Tie: 6/36.",
            .overUnderSeven: "Below: 15/36. Above: 15/36. Seven: 6/36 and neutral.",
            .oddEven: "Odd: 18/36. Even: 18/36.",
            .fairWheel: "Six segments per color: 6/12. Each numbered segment: 1/12. No zero segment.",
            .numberDraw: "Matches: zero 84/220, one 108/220, two 27/220, three 1/220.",
        ]
        var actual: [PrismetPracticeCasinoGameID: String] = [:]
        for descriptor in PrismetPracticeCasinoCatalog.all {
            actual[descriptor.id] = descriptor.fairness
        }

        XCTAssertEqual(expected.count, 11)
        XCTAssertEqual(Set(expected.keys), Set(PrismetPracticeCasinoGameID.allCases))
        XCTAssertEqual(actual, expected)
    }
}
