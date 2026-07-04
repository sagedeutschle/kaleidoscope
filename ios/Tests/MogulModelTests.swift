// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — Moguls board model tests.
import XCTest
@testable import Kaleidoscope

final class MogulModelTests: XCTestCase {
    private func opinion(_ councilor: String, _ verdict: MogulVerdict) -> CouncilOpinion {
        CouncilOpinion(councilor: councilor, model: nil, verdict: verdict, quip: "test quip")
    }

    // MARK: - Majority rulings

    func testUnanimousCouncilRules() {
        let council = [opinion("Claude", .gaming), opinion("Codex", .gaming), opinion("DeepSeek", .gaming)]
        XCTAssertEqual(Mogul.majority(of: council), .gaming)
    }

    func testTwoToOneMajorityRules() {
        let council = [opinion("Claude", .fraud), opinion("Codex", .fraud), opinion("DeepSeek", .gaming)]
        XCTAssertEqual(Mogul.majority(of: council), .fraud)
    }

    func testThreeWaySplitIsOfficiallyMid() {
        let council = [opinion("Claude", .fraud), opinion("Codex", .aight), opinion("DeepSeek", .gaming)]
        XCTAssertEqual(Mogul.majority(of: council), .aight)
    }

    func testTwoCouncilorTieIsMid() {
        let council = [opinion("Claude", .fraud), opinion("Codex", .gaming)]
        XCTAssertEqual(Mogul.majority(of: council), .aight)
    }

    func testEmptyCouncilIsMid() {
        XCTAssertEqual(Mogul.majority(of: []), .aight)
    }

    // MARK: - Decoding the published shape

    func testDecodesLedgerJSON() throws {
        let json = """
        {
          "asOf": "2026-07-04",
          "moguls": [
            {
              "id": "test-mogul",
              "name": "Test Mogul",
              "title": "TestCorp — CEO",
              "category": "both",
              "netWorthUSD": 250000000000,
              "annualCompUSD": 50000000,
              "compYear": 2025,
              "knownFor": "Testing at scale",
              "source": "Forbes Real-Time 2026-07-04",
              "council": [
                {"councilor": "Claude", "model": "claude", "verdict": "gaming", "quip": "Ship it."},
                {"councilor": "Codex", "model": "gpt", "verdict": "fraud", "quip": "Audit says no."},
                {"councilor": "DeepSeek", "model": "deepseek-chat", "verdict": "gaming", "quip": "Deep respect."}
              ],
              "finalVerdict": "gaming"
            }
          ]
        }
        """
        let ledger = try JSONDecoder().decode(MogulLedger.self, from: Data(json.utf8))
        XCTAssertEqual(ledger.asOf, "2026-07-04")
        XCTAssertEqual(ledger.moguls.count, 1)
        let mogul = try XCTUnwrap(ledger.moguls.first)
        XCTAssertEqual(mogul.category, .both)
        XCTAssertEqual(mogul.finalVerdict, .gaming)
        XCTAssertEqual(mogul.council.count, 3)
        XCTAssertEqual(Mogul.majority(of: mogul.council), .gaming)
    }

    func testNullMoneyFieldsDecode() throws {
        let json = """
        {
          "asOf": "2026-07-04",
          "moguls": [
            {
              "id": "salary-only",
              "name": "Salary Person",
              "title": "BigCo — CEO",
              "category": "ceo",
              "netWorthUSD": null,
              "annualCompUSD": 30000000,
              "compYear": 2025,
              "knownFor": "Compensation",
              "source": "Proxy filing 2025",
              "council": [],
              "finalVerdict": "aight"
            }
          ]
        }
        """
        let ledger = try JSONDecoder().decode(MogulLedger.self, from: Data(json.utf8))
        let mogul = try XCTUnwrap(ledger.moguls.first)
        XCTAssertNil(mogul.netWorthUSD)
        XCTAssertEqual(mogul.annualCompUSD, 30_000_000)
    }

    // MARK: - Ranking

    func testRankedSortsNetWorthDescendingWithCompFallback() throws {
        func mogul(_ id: String, worth: Double?, comp: Double?) -> Mogul {
            Mogul(id: id, name: id, title: "t", category: .billionaire,
                  netWorthUSD: worth, annualCompUSD: comp, compYear: nil,
                  medianWorkerPayUSD: nil,
                  knownFor: "k", source: "s", council: [], finalVerdict: .aight)
        }
        let ledger = MogulLedger(asOf: "2026-07-04", moguls: [
            mogul("small", worth: 5_000_000_000, comp: nil),
            mogul("salary", worth: nil, comp: 60_000_000),
            mogul("big", worth: 400_000_000_000, comp: nil),
        ])
        XCTAssertEqual(ledger.ranked.map(\.id), ["big", "small", "salary"])
    }

    // MARK: - The pay ratio (boss vs. median worker)

    func testPayRatioComputesFromDisclosedFigures() {
        let mogul = Mogul(id: "r", name: "r", title: "t", category: .ceo,
                          netWorthUSD: nil, annualCompUSD: 58_000_000, compYear: 2025,
                          medianWorkerPayUSD: 29_000,
                          knownFor: "k", source: "s", council: [], finalVerdict: .aight)
        XCTAssertEqual(mogul.payRatio, 2_000)
    }

    func testPayRatioNilWithoutWorkerFigureOrComp() {
        let noWorker = Mogul(id: "a", name: "a", title: "t", category: .ceo,
                             netWorthUSD: nil, annualCompUSD: 58_000_000, compYear: 2025,
                             medianWorkerPayUSD: nil,
                             knownFor: "k", source: "s", council: [], finalVerdict: .aight)
        XCTAssertNil(noWorker.payRatio)
        let noComp = Mogul(id: "b", name: "b", title: "t", category: .billionaire,
                           netWorthUSD: 100_000_000_000, annualCompUSD: nil, compYear: nil,
                           medianWorkerPayUSD: 50_000,
                           knownFor: "k", source: "s", council: [], finalVerdict: .aight)
        XCTAssertNil(noComp.payRatio)
    }

    func testDecodingToleratesMissingMedianWorkerKey() throws {
        // Older published boards predate the field — must decode as nil, not throw.
        let json = """
        {
          "asOf": "2026-07-04",
          "moguls": [
            {
              "id": "legacy",
              "name": "Legacy Entry",
              "title": "OldCo — CEO",
              "category": "ceo",
              "netWorthUSD": null,
              "annualCompUSD": 10000000,
              "compYear": 2024,
              "knownFor": "Predating schema fields",
              "source": "test",
              "council": [],
              "finalVerdict": "aight"
            }
          ]
        }
        """
        let ledger = try JSONDecoder().decode(MogulLedger.self, from: Data(json.utf8))
        XCTAssertNil(try XCTUnwrap(ledger.moguls.first).medianWorkerPayUSD)
    }

    // MARK: - Stamps

    func testStampsReadCorrectly() {
        XCTAssertEqual(MogulVerdict.fraud.stamp, "FRAUD!")
        XCTAssertEqual(MogulVerdict.aight.stamp, "Aight...")
        XCTAssertEqual(MogulVerdict.gaming.stamp, "GAMING!!!!")
    }
}
