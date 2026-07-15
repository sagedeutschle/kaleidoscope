import XCTest
@testable import PrismetShared

final class PrismetPracticeCasinoCatalogTests: XCTestCase {
    func testCatalogHasExactlyElevenStableUniqueIDs() {
        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.map(\.id), [
            .blackjack, .fiveCardDraw, .redBlack, .higherLower, .highCard,
            .coinCall, .diceDuel, .overUnderSeven, .oddEven, .fairWheel, .numberDraw,
        ])
        XCTAssertEqual(Set(PrismetPracticeCasinoCatalog.all.map(\.id)).count, 11)
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

    func testFairnessDisclosuresPublishPokerCountsHigherLowerFormulasAndBlackjackIdentity() {
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.blackjack].id.rawValue, PrismetBlackjackRulesV1.canonicalGameID)

        let poker = PrismetPracticeCasinoCatalog[.fiveCardDraw].fairness
        XCTAssertTrue(poker.contains("2,598,960"))
        XCTAssertTrue(poker.contains("Royal flush: 4"))
        XCTAssertTrue(poker.contains("Straight flush (non-royal): 36"))
        XCTAssertTrue(poker.contains("Four of a kind: 624"))
        XCTAssertTrue(poker.contains("Full house: 3,744"))
        XCTAssertTrue(poker.contains("Flush: 5,108"))
        XCTAssertTrue(poker.contains("Straight: 10,200"))
        XCTAssertTrue(poker.contains("Three of a kind: 54,912"))
        XCTAssertTrue(poker.contains("Two pair: 123,552"))
        XCTAssertTrue(poker.contains("One pair: 1,098,240"))
        XCTAssertTrue(poker.contains("High card: 1,302,540"))

        let higherLower = PrismetPracticeCasinoCatalog[.higherLower].fairness
        XCTAssertTrue(higherLower.contains("Higher = (14-rank)*4/51"))
        XCTAssertTrue(higherLower.contains("Lower = (rank-2)*4/51"))
        XCTAssertTrue(higherLower.contains("Equal = 3/51"))
    }
}
