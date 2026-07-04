// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — Moguls board model tests — macOS mirror (ports verbatim).
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
                  knownFor: "k", source: "s", council: [],
                  bench: nil, voteSummary: nil, consensus: nil, finalVerdict: .aight)
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
                          knownFor: "k", source: "s", council: [],
                          bench: nil, voteSummary: nil, consensus: nil, finalVerdict: .aight)
        XCTAssertEqual(mogul.payRatio, 2_000)
    }

    func testPayRatioNilWithoutWorkerFigureOrComp() {
        let noWorker = Mogul(id: "a", name: "a", title: "t", category: .ceo,
                             netWorthUSD: nil, annualCompUSD: 58_000_000, compYear: 2025,
                             medianWorkerPayUSD: nil,
                             knownFor: "k", source: "s", council: [],
                             bench: nil, voteSummary: nil, consensus: nil, finalVerdict: .aight)
        XCTAssertNil(noWorker.payRatio)
        let noComp = Mogul(id: "b", name: "b", title: "t", category: .billionaire,
                           netWorthUSD: 100_000_000_000, annualCompUSD: nil, compYear: nil,
                           medianWorkerPayUSD: 50_000,
                           knownFor: "k", source: "s", council: [],
                           bench: nil, voteSummary: nil, consensus: nil, finalVerdict: .aight)
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

    // MARK: - The bench (Council v2) voting system

    private func juror(_ persona: String, _ verdict: MogulVerdict) -> JurorVote {
        JurorVote(persona: persona, verdict: verdict, quip: "q")
    }

    private func justice(_ name: String, _ verdict: MogulVerdict) -> JusticeOpinion {
        JusticeOpinion(councilor: name, model: nil, verdict: verdict, opinion: "o")
    }

    private func jury(_ name: String, _ verdicts: [MogulVerdict]) -> MogulJury {
        let jurors = verdicts.enumerated().map { juror("J\($0.offset)", $0.element) }
        return MogulJury(name: name, model: nil, jurors: jurors,
                         juryVerdict: MogulJury.deliberate(jurors))
    }

    func testJuryDeliberationMajorityWins() {
        XCTAssertEqual(MogulJury.deliberate([juror("a", .gaming), juror("b", .gaming), juror("c", .fraud)]), .gaming)
        XCTAssertEqual(MogulJury.deliberate([juror("a", .fraud), juror("b", .fraud), juror("c", .fraud)]), .fraud)
    }

    func testJuryHangsOnFullSplit() {
        XCTAssertEqual(MogulJury.deliberate([juror("a", .fraud), juror("b", .aight), juror("c", .gaming)]), .aight)
    }

    func testEmptyJuryHangs() {
        XCTAssertEqual(MogulJury.deliberate([]), .aight)
    }

    func testBenchMajorityOfSeatsRules() {
        // 3 of 4 seats say gaming (justice + both juries) — gaming rules.
        let bench = MogulBench(
            justices: [justice("Opus", .gaming), justice("GPT-5.5", .fraud)],
            juries: [jury("Sonnet", [.gaming, .gaming, .fraud]),
                     jury("Mini", [.gaming, .aight, .gaming])])
        XCTAssertEqual(bench.ruling, .gaming)
    }

    func testBenchUnanimous() {
        let bench = MogulBench(
            justices: [justice("Opus", .fraud), justice("GPT-5.5", .fraud)],
            juries: [jury("Sonnet", [.fraud, .fraud, .aight]),
                     jury("Mini", [.fraud, .fraud, .fraud])])
        XCTAssertEqual(bench.ruling, .fraud)
    }

    func testBenchTieGoesToAgreeingJustices() {
        // 2-2 (justices gaming+gaming vs juries fraud+fraud) — justices agree → gaming.
        let bench = MogulBench(
            justices: [justice("Opus", .gaming), justice("GPT-5.5", .gaming)],
            juries: [jury("Sonnet", [.fraud, .fraud, .gaming]),
                     jury("Mini", [.fraud, .fraud, .aight])])
        XCTAssertEqual(bench.ruling, .gaming)
    }

    func testBenchTieWithSplitJusticesIsMid() {
        // 2-2 and the justices disagree with each other → officially mid.
        let bench = MogulBench(
            justices: [justice("Opus", .gaming), justice("GPT-5.5", .fraud)],
            juries: [jury("Sonnet", [.gaming, .gaming, .fraud]),
                     jury("Mini", [.fraud, .fraud, .gaming])])
        XCTAssertEqual(bench.ruling, .aight)
    }

    func testBenchPluralityWithoutMajorityFallsToJustices() {
        // Seats 2-1-1 (no strict majority): justices agree on the 2-block → theirs.
        let agree = MogulBench(
            justices: [justice("Opus", .gaming), justice("GPT-5.5", .gaming)],
            juries: [jury("Sonnet", [.fraud, .fraud, .aight]),
                     jury("Mini", [.aight, .aight, .fraud])])
        XCTAssertEqual(agree.ruling, .gaming)
        // Justices split → mid.
        let split = MogulBench(
            justices: [justice("Opus", .gaming), justice("GPT-5.5", .fraud)],
            juries: [jury("Sonnet", [.gaming, .aight, .fraud]),   // hung → aight
                     jury("Mini", [.aight, .aight, .gaming])])
        XCTAssertEqual(split.ruling, .aight)
    }

    func testDecodesBenchV2JSON() throws {
        let json = """
        {
          "asOf": "2026-07-04",
          "moguls": [
            {
              "id": "v2",
              "name": "V2 Mogul",
              "title": "BenchCorp — CEO",
              "category": "ceo",
              "netWorthUSD": null,
              "annualCompUSD": 50000000,
              "compYear": 2025,
              "medianWorkerPayUSD": 50000,
              "knownFor": "Being judged thoroughly",
              "source": "test",
              "council": [
                {"councilor": "Opus, J.", "model": "claude-opus", "verdict": "gaming", "quip": "flat fallback"}
              ],
              "bench": {
                "justices": [
                  {"councilor": "Opus", "model": "claude-opus", "verdict": "gaming", "opinion": "Two considered sentences."},
                  {"councilor": "GPT-5.5", "model": "gpt-5.5", "verdict": "gaming", "opinion": "Concurring at length."}
                ],
                "juries": [
                  {"name": "The Sonnet Jury", "model": "claude-sonnet",
                   "jurors": [
                     {"persona": "The Skeptic", "verdict": "fraud", "quip": "hm"},
                     {"persona": "The Builder", "verdict": "gaming", "quip": "ship"},
                     {"persona": "The Ledger Clerk", "verdict": "gaming", "quip": "math"}
                   ],
                   "juryVerdict": "gaming"},
                  {"name": "The Mini Jury", "model": "gpt-5.5-mini",
                   "jurors": [
                     {"persona": "The Quant", "verdict": "aight", "quip": "beta"},
                     {"persona": "The Populist", "verdict": "fraud", "quip": "boo"},
                     {"persona": "The Butler", "verdict": "fraud", "quip": "sigh"}
                   ],
                   "juryVerdict": "fraud"}
                ]
              },
              "voteSummary": "SEATS 3–1 · Sonnet Jury 2–1 gaming · Mini Jury 2–1 fraud",
              "consensus": "The bench leaned gaming over a spirited Mini Jury dissent.",
              "finalVerdict": "gaming"
            }
          ]
        }
        """
        let ledger = try JSONDecoder().decode(MogulLedger.self, from: Data(json.utf8))
        let mogul = try XCTUnwrap(ledger.moguls.first)
        let bench = try XCTUnwrap(mogul.bench)
        XCTAssertEqual(bench.justices.count, 2)
        XCTAssertEqual(bench.juries.count, 2)
        XCTAssertEqual(bench.juries[0].jurors.count, 3)
        XCTAssertEqual(bench.ruling, .gaming)          // reference logic agrees
        XCTAssertEqual(mogul.finalVerdict, .gaming)    // with the stored ruling
        XCTAssertEqual(mogul.consensus, "The bench leaned gaming over a spirited Mini Jury dissent.")
        XCTAssertNotNil(mogul.voteSummary)
    }

    func testV1BoardsDecodeWithNilBench() throws {
        // The already-shipped v1 shape (no bench/consensus/voteSummary) must keep decoding.
        let json = """
        {
          "asOf": "2026-07-04",
          "moguls": [
            {
              "id": "v1",
              "name": "V1 Mogul",
              "title": "OldCo — CEO",
              "category": "ceo",
              "netWorthUSD": null,
              "annualCompUSD": 10000000,
              "compYear": 2024,
              "knownFor": "Predating the bench",
              "source": "test",
              "council": [
                {"councilor": "Claude", "model": "c", "verdict": "aight", "quip": "mid"}
              ],
              "finalVerdict": "aight"
            }
          ]
        }
        """
        let ledger = try JSONDecoder().decode(MogulLedger.self, from: Data(json.utf8))
        let mogul = try XCTUnwrap(ledger.moguls.first)
        XCTAssertNil(mogul.bench)
        XCTAssertNil(mogul.consensus)
        XCTAssertNil(mogul.voteSummary)
        XCTAssertEqual(mogul.council.count, 1)
    }

    // MARK: - Stamps

    func testStampsReadCorrectly() {
        XCTAssertEqual(MogulVerdict.fraud.stamp, "FRAUD!")
        XCTAssertEqual(MogulVerdict.aight.stamp, "Aight...")
        XCTAssertEqual(MogulVerdict.gaming.stamp, "GAMING!!!!")
    }
}
