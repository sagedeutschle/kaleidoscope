import XCTest
@testable import PrismetShared

final class PrismetPracticeCasinoCatalogTests: XCTestCase {
    func testCatalogAndAllCasesLockExactlyTwentyOneStableUniqueRawIDs() {
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
            (.threeCardPokerLab, "three-card-poker-lab"),
            (.texasHoldemLab, "texas-holdem-lab"),
            (.caribbeanStudQualificationLab, "caribbean-stud-qualification-lab"),
            (.paiGowSplitLab, "pai-gow-split-lab"),
            (.omahaHandLab, "omaha-hand-lab"),
            (.miniBaccaratPractice, "mini-baccarat-practice"),
            (.casinoWarPractice, "casino-war-practice"),
            (.crapsPointLab, "craps-point-lab"),
            (.sicBoOutcomeLab, "sic-bo-outcome-lab"),
            (.europeanRouletteLab, "european-roulette-lab"),
        ]
        let expectedIDs = expected.map(\.id)
        let expectedRawValues = expected.map(\.rawValue)
        let allCases = PrismetPracticeCasinoGameID.allCases
        let catalogIDs = PrismetPracticeCasinoCatalog.all.map(\.id)

        XCTAssertEqual(allCases.count, 21)
        XCTAssertEqual(allCases, expectedIDs)
        XCTAssertEqual(allCases.map(\.rawValue), expectedRawValues)
        XCTAssertEqual(Set(allCases.map(\.rawValue)).count, 21)

        XCTAssertEqual(PrismetPracticeCasinoCatalog.all.count, 21)
        XCTAssertEqual(catalogIDs, expectedIDs)
        XCTAssertEqual(catalogIDs, allCases)
        XCTAssertEqual(Set(catalogIDs), Set(allCases))
        XCTAssertEqual(Set(catalogIDs).count, 21)

        for id in allCases {
            XCTAssertEqual(PrismetPracticeCasinoCatalog[id].id, id)
        }
    }

    func testStudyLabsHaveCompleteRendererMetadata() {
        let expected: [PrismetPracticeCasinoGameID: PrismetPracticeCasinoRenderer] = [
            .threeCardPokerLab: .cards,
            .texasHoldemLab: .cards,
            .caribbeanStudQualificationLab: .cards,
            .paiGowSplitLab: .cards,
            .omahaHandLab: .cards,
            .miniBaccaratPractice: .cards,
            .casinoWarPractice: .cards,
            .crapsPointLab: .dice,
            .sicBoOutcomeLab: .dice,
            .europeanRouletteLab: .wheel,
        ]

        XCTAssertEqual(expected.count, 10)
        for (id, renderer) in expected {
            let descriptor = PrismetPracticeCasinoCatalog[id]
            XCTAssertEqual(descriptor.kind, .studyLab)
            XCTAssertEqual(descriptor.renderer, renderer)
            XCTAssertFalse(descriptor.title.isEmpty)
            XCTAssertFalse(descriptor.subtitle.isEmpty)
            XCTAssertFalse(descriptor.symbol.isEmpty)
            XCTAssertFalse(descriptor.rules.isEmpty)
            XCTAssertFalse(descriptor.fairness.isEmpty)
            XCTAssertFalse(descriptor.actionTitle.isEmpty)
        }
    }

    func testAddingRendererMetadataRemainsDecodableForLegacyDescriptors() throws {
        let legacy = #"{"id":"red-black","title":"Red or Black","subtitle":"Choose a color and reveal one card.","symbol":"suit.heart.fill","kind":"fairChance","selectionRule":{"exactly":{"_0":1}},"choices":[{"id":"red","title":"Red","symbol":"suit.heart.fill"}],"rulesVersion":1,"rules":"Choose a color, then reveal one card.","fairness":"Red: 26/52. Black: 26/52.","actionTitle":"Reveal Card"}"#.data(using: .utf8)!
        let descriptor = try JSONDecoder().decode(PrismetPracticeCasinoGameDescriptor.self, from: legacy)
        XCTAssertEqual(descriptor.id, .redBlack)
        XCTAssertEqual(descriptor.renderer, .cards)
    }

    func testEveryEntryHasRulesFairnessAndAnExplicitAction() {
        for game in PrismetPracticeCasinoCatalog.all {
            XCTAssertFalse(game.rules.isEmpty)
            XCTAssertFalse(game.fairness.isEmpty)
            XCTAssertFalse(game.actionTitle.isEmpty)
            XCTAssertGreaterThan(game.rulesVersion, 0)
        }
    }

    func testSelectionRulesMatchTheTwentyOneTableContract() {
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.redBlack].selectionRule, .exactly(1))
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.diceDuel].selectionRule, .none)
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.numberDraw].selectionRule, .exactly(3))
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.fiveCardDraw].kind, .poker)
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.blackjack].kind, .blackjack)
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.threeCardPokerLab].selectionRule, .none)
        XCTAssertEqual(PrismetPracticeCasinoCatalog[.europeanRouletteLab].selectionRule, .none)
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
            .threeCardPokerLab: "Three-card combinations: 22,100 total. High card: 16,440; pair: 3,744; flush: 1,096; straight: 720; three of a kind: 52; straight flush: 48. Categories are mutually exclusive and sum to 22,100.",
            .texasHoldemLab: "Seven-card combinations: 133,784,560 total. High card: 23,294,460; one pair: 58,627,800; two pair: 31,433,400; three of a kind: 6,461,620; straight: 6,180,020; flush: 4,047,644; full house: 3,473,184; four of a kind: 224,848; straight flush: 37,260; royal flush: 4,324. These mutually exclusive categories sum to 133,784,560.",
            .caribbeanStudQualificationLab: "Five-card hand categories use 2,598,960 equally likely combinations; qualification follows a fixed reference-hand comparison.",
            .paiGowSplitLab: "A seven-card deal from the 53-card deck has C(53,7)=154143080 unordered combinations. Each deal has 21 two-card/five-card splits.",
            .omahaHandLab: "A four-hole-card deal and five-card board are evaluated with exactly two hole cards and three board cards. Exactly 60 legal two-plus-three combinations are checked.",
            .miniBaccaratPractice: "Across 4998398275503360 eight-deck deals: banker 2292252566437888; player 2230518282592256; tie 475627426473216. The stated draw rules classify each outcome.",
            .casinoWarPractice: "Learner higher: 10376/20825. Reference higher: 10376/20825. Neutral: 73/20825. The three outcomes are not 50/50.",
            .crapsPointLab: "Across 36 ordered two-dice outcomes, come-out natural: 8/36, craps: 4/36, point: 24/36. Point resolution uses point counts 3, 4, 5, 5, 4, 3 for 4, 5, 6, 8, 9, 10; seven has 6/36.",
            .sicBoOutcomeLab: "Three dice have 216 ordered outcomes. Totals 3 through 18 occur 1, 3, 6, 10, 15, 21, 25, 27, 27, 25, 21, 15, 10, 6, 3, 1 times; all same: 6/216, exactly one pair: 90/216, all distinct: 120/216.",
            .europeanRouletteLab: "A single-zero wheel has 37 pockets: red 18/37, black 18/37, zero 1/37. Red and black are not 50/50 because zero is neither.",
        ]
        var actual: [PrismetPracticeCasinoGameID: String] = [:]
        for descriptor in PrismetPracticeCasinoCatalog.all {
            actual[descriptor.id] = descriptor.fairness
        }

        XCTAssertEqual(expected.count, 21)
        XCTAssertEqual(Set(expected.keys), Set(PrismetPracticeCasinoGameID.allCases))
        XCTAssertEqual(actual, expected)
    }

    func testPermanentCopyGuardrailsRejectValueAndPressureMechanics() {
        let prohibited = ["money", "wager", "bet", "stake", "payout", "prize", "reward", "wallet", "cash", "purchase", "deposit", "streak", "timer", "urgency", "pressure"]
        for descriptor in PrismetPracticeCasinoCatalog.all {
            let copy = [descriptor.title, descriptor.subtitle, descriptor.rules, descriptor.fairness, descriptor.actionTitle].joined(separator: " ").lowercased()
            for term in prohibited {
                XCTAssertFalse(copy.contains(term), "\(descriptor.id.rawValue) contains prohibited term \(term)")
            }
        }

        for id in [PrismetPracticeCasinoGameID.miniBaccaratPractice, .casinoWarPractice, .crapsPointLab, .europeanRouletteLab] {
            let fairness = PrismetPracticeCasinoCatalog[id].fairness
            XCTAssertFalse(fairness.contains(" is a 50/50") || fairness.contains(" are 50/50"), "\(id.rawValue) must not be called 50/50")
        }
    }

    func testStudyLabDescriptorsPublishNonemptyHumanReadableCopy() {
        let labs = PrismetPracticeCasinoGameID.allCases.suffix(10)
        XCTAssertEqual(labs.count, 10)
        for id in labs {
            let descriptor = PrismetPracticeCasinoCatalog[id]
            XCTAssertFalse(descriptor.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(descriptor.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(descriptor.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(descriptor.rules.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(descriptor.fairness.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(descriptor.actionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
