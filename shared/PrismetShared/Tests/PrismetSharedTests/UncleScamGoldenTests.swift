import XCTest
@testable import PrismetShared

/// The apps' Uncle Scam must give the answers prismet.xyz/scam gives. `Golden/uncle-scam-golden.json` holds
/// those answers (`scripts/uncle-scam-golden.mjs` writes it from the website's `scam-calc.js`); the data the
/// website used is the data bundled in the package, so every figure here is compared to the cent.
final class UncleScamGoldenTests: XCTestCase {
    struct Golden: Decodable {
        struct Statement: Decodable { let date: String; let fiscalYear: Int; let months: Int; let outlays: Double; let receipts: Double; let borrowedPerDollar: Double }
        struct Bill: Decodable {
            let wages: Double; let status: String; let state: String
            let federalIncome: Double; let socialSecurity: Double; let medicare: Double; let stateTax: Double
            let federalTotal: Double; let total: Double; let takeHome: Double; let marginal: Double; let borrowed: Double
            let dayOfYear: Int; let freedomDay: String; let minutesPerWorkday: Int; let perPaycheck: Double
        }
        struct Split: Decodable { struct Line: Decodable { let name: String; let amount: Double; let rest: Bool }; let amount: Double; let lines: [Line] }
        struct Zip: Decodable { struct Place: Decodable { let code: String; let territory: Bool? }; let zip: String; let place: Place? }
        struct Officials: Decodable {
            struct Seat: Decodable { let state: String; let district: Int; let member: String? }
            let zip: String; let entry: UncleScamZipEntry?; let state: String; let senators: [String]; let seats: [Seat]
        }
        struct FiscalYear: Decodable { let today: String; let fy: Int; let start: String; let end: String }
        struct Name: Decodable { let raw: String; let tidy: String }
        struct Receipt: Decodable {
            struct Row: Decodable { let kind: String; let text: String; let value: String; let style: String }
            let wages: Double; let status: String; let state: String; let percent: Bool; let rows: [Row]
        }
        struct Pair<Input: Decodable, Output: Decodable>: Decodable {
            let input: Input; let output: Output
            init(from decoder: Decoder) throws { var c = try decoder.unkeyedContainer(); input = try c.decode(Input.self); output = try c.decode(Output.self) }
        }
        struct Formats: Decodable {
            let usd: [Pair<Double, String>]; let usd2: [Pair<Double, String>]; let pct: [Pair<Double, String>]
            let big: [Pair<Double, String>]; let salary: [Pair<String, Double?>]
        }
        let receipts: [Receipt]; let formats: Formats
        let site: String; let taxDataBuilt: String
        let statement: Statement; let bills: [Bill]; let splits: [Split]; let zips: [Zip]
        let officials: [Officials]; let fiscalYears: [FiscalYear]; let names: [Name]
    }

    static func resource(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Golden"))
        return try Data(contentsOf: url)
    }

    lazy var golden: Golden = try! JSONDecoder().decode(Golden.self, from: Self.resource("uncle-scam-golden"))
    lazy var tax: UncleScamTaxData = try! UncleScamBundled.taxData()
    lazy var statement: UncleScamStatement = UncleScam.pickStatement(try! UncleScamBundled.snapshot().rows)!

    func testBundledDataIsTheDataTheAnswersWereMadeFrom() {
        XCTAssertEqual(tax.built, golden.taxDataBuilt, "run scripts/uncle-scam-golden.mjs: the bundled tax data and the answers are from different builds")
        XCTAssertEqual(tax.federal.year, 2026)
        XCTAssertEqual(tax.state.states.count, 51)
    }

    func testStatementMatchesTheWebsite() {
        XCTAssertEqual(statement.date, golden.statement.date)
        XCTAssertEqual(statement.fiscalYear, golden.statement.fiscalYear)
        XCTAssertEqual(statement.months, golden.statement.months)
        XCTAssertEqual(statement.outlays, golden.statement.outlays)
        XCTAssertEqual(statement.receipts, golden.statement.receipts)
        XCTAssertEqual(statement.borrowedPerDollar, golden.statement.borrowedPerDollar, accuracy: 1e-12)
    }

    func testEveryBillMatchesTheWebsiteToTheCent() throws {
        XCTAssertGreaterThan(golden.bills.count, 600)
        for g in golden.bills {
            let status = try XCTUnwrap(UncleScamFilingStatus(rawValue: g.status))
            let b = UncleScam.computeBill(wages: g.wages, status: status, stateCode: g.state, data: tax)
            let what = "\(g.wages) \(g.status) \(g.state)"
            XCTAssertEqual(b.federalIncome, g.federalIncome, "federal income tax, \(what)")
            XCTAssertEqual(b.socialSecurity, g.socialSecurity, "social security, \(what)")
            XCTAssertEqual(b.medicare, g.medicare, "medicare, \(what)")
            XCTAssertEqual(b.state, g.stateTax, "state tax, \(what)")
            XCTAssertEqual(b.federalTotal, g.federalTotal, "federal total, \(what)")
            XCTAssertEqual(b.total, g.total, "total, \(what)")
            XCTAssertEqual(b.takeHome, g.takeHome, "take-home, \(what)")
            XCTAssertEqual(b.marginal, g.marginal, "marginal rate, \(what)")
            XCTAssertEqual(UncleScam.borrowed(forFederalTotal: b.federalTotal, statement: statement), g.borrowed, "borrowed, \(what)")
            let t = UncleScam.timeUnits(rate: b.rate, total: b.total, year: tax.federal.year)
            XCTAssertEqual(t.dayOfYear, g.dayOfYear, "day of year, \(what)")
            XCTAssertEqual(t.freedomDay, g.freedomDay, "freedom day, \(what)")
            XCTAssertEqual(t.minutesPerWorkday, g.minutesPerWorkday, "minutes per workday, \(what)")
            XCTAssertEqual(t.perPaycheck, g.perPaycheck, "per paycheck, \(what)")
        }
    }

    func testSplitsMatchTheWebsiteAndAddUp() {
        for g in golden.splits {
            let lines = UncleScam.splitByFunction(g.amount, statement: statement)
            XCTAssertEqual(lines.map(\.name), g.lines.map(\.name), "line order for \(g.amount)")
            XCTAssertEqual(lines.map(\.amount), g.lines.map(\.amount), "line amounts for \(g.amount)")
            XCTAssertEqual(lines.map(\.rest), g.lines.map(\.rest))
            XCTAssertEqual(lines.reduce(0) { $0 + $1.amount }, g.amount, accuracy: 0.005)
        }
    }

    func testZipsResolveAsOnTheWebsite() {
        for g in golden.zips {
            let place = UncleScam.place(forZip: g.zip, data: tax)
            XCTAssertEqual(place?.code, g.place?.code, "ZIP \(g.zip)")
            XCTAssertEqual(place?.territory ?? false, g.place?.territory ?? false, "ZIP \(g.zip) territory")
        }
    }

    func testOfficialsResolveAsOnTheWebsite() throws {
        let congress = try JSONDecoder().decode(UncleScamCongress.self, from: Self.resource("uncle-scam-congress"))
        XCTAssertGreaterThan(congress.members.count, 530)
        for g in golden.officials {
            let o = UncleScam.officials(entry: g.entry, stateCode: g.state, congress: congress)
            XCTAssertEqual(Set(o.senators.map(\.n)), Set(g.senators), "senators for \(g.zip)")
            XCTAssertEqual(o.seats.map(\.state), g.seats.map(\.state), "seat states for \(g.zip)")
            XCTAssertEqual(o.seats.map(\.district), g.seats.map(\.district), "districts for \(g.zip)")
            XCTAssertEqual(o.seats.map { $0.member?.n }, g.seats.map(\.member), "representatives for \(g.zip)")
        }
        let member = try XCTUnwrap(congress.members.first { $0.t == "rep" && $0.s == "OH" && $0.d == 3 })
        let d = try XCTUnwrap(UncleScam.debtSince(member, now: congress.debtNow))
        XCTAssertEqual(d.then + d.added, d.now)
        XCTAssertGreaterThan(d.added, 0)
    }

    func testFiscalYearsAndNamesMatchTheWebsite() {
        for g in golden.fiscalYears {
            let fy = UncleScam.lastFiscalYear(today: g.today)
            XCTAssertEqual(fy.fy, g.fy); XCTAssertEqual(fy.start, g.start); XCTAssertEqual(fy.end, g.end)
        }
        for g in golden.names { XCTAssertEqual(UncleScam.tidyName(g.raw), g.tidy) }
        let top = UncleScam.topRecipients([("OHIO STATE UNIVERSITY, THE", 90), ("BATTELLE", 300), ("OHIO STATE UNIVERSITY, THE", 7), ("REFUND CO", -5), ("", 9)])
        XCTAssertEqual(top, [UncleScamRecipient(name: "Battelle", amount: 300), UncleScamRecipient(name: "The Ohio State University", amount: 97)])
    }

    func testReceiptsReadAsOnTheWebsite() throws {
        XCTAssertEqual(golden.receipts.count, 8)
        for g in golden.receipts {
            let bill = UncleScam.computeBill(wages: g.wages, status: try XCTUnwrap(UncleScamFilingStatus(rawValue: g.status)), stateCode: g.state, data: tax)
            let rows = UncleScam.receiptRows(bill: bill, statement: statement, data: tax, percent: g.percent)
            let what = "\(g.wages) \(g.status) \(g.state) percent=\(g.percent)"
            XCTAssertEqual(rows.map(\.kind.rawValue), g.rows.map(\.kind), "row kinds, \(what)")
            XCTAssertEqual(rows.map(\.text), g.rows.map(\.text), "row text, \(what)")
            XCTAssertEqual(rows.map(\.value), g.rows.map(\.value), "row figures, \(what)")
            XCTAssertEqual(rows.map(\.style), g.rows.map(\.style), "row styles, \(what)")
        }
    }

    func testFiguresPrintAsOnTheWebsite() {
        for g in golden.formats.usd { XCTAssertEqual(UncleScamFormat.usd(g.input), g.output, "usd \(g.input)") }
        for g in golden.formats.usd2 { XCTAssertEqual(UncleScamFormat.usd2(g.input), g.output, "usd2 \(g.input)") }
        for g in golden.formats.pct { XCTAssertEqual(UncleScamFormat.pct(g.input), g.output, "pct \(g.input)") }
        for g in golden.formats.big { XCTAssertEqual(UncleScamFormat.big(g.input), g.output, "big \(g.input)") }
        for g in golden.formats.salary { XCTAssertEqual(UncleScamFormat.parseSalary(g.input), g.output, "salary \"\(g.input)\"") }
        XCTAssertEqual(UncleScamFormat.day("2013-01-03"), "Jan 3, 2013")
    }

    func testStatementSelection() {
        let rows = try! UncleScamBundled.snapshot().rows
        func month(_ d: String, scale: Double = 1) -> [UncleScamStatementRow] { rows.map { UncleScamStatementRow(d: d, n: $0.n, a: ($0.a * scale).rounded(), t: $0.t, l: $0.l) } }
        XCTAssertEqual(UncleScam.pickStatement(month("2026-11-30", scale: 0.2) + month("2026-09-30"))?.date, "2026-09-30", "a young fiscal year yields to the last full one")
        XCTAssertEqual(UncleScam.pickStatement(month("2026-11-30", scale: 0.2))?.date, "2026-11-30")
        XCTAssertEqual(UncleScam.pickStatement(month("2027-04-30") + month("2026-09-30"))?.date, "2027-04-30")
        XCTAssertEqual(UncleScam.pickStatement(month("2026-11-30"))?.fiscalYear, 2027)
        XCTAssertNil(UncleScam.pickStatement(rows.filter { $0.n != "National Defense" }), "a missing function fails the totals check")
        XCTAssertNil(UncleScam.pickStatement([]))
        let api = #"{"data":[{"record_date":"2026-08-31","classification_desc":"Receipts","current_fytd_rcpt_outly_amt":"null","record_type_cd":"SL","sequence_level_nbr":"1"},{"record_date":"2026-08-31","classification_desc":"Net Interest","current_fytd_rcpt_outly_amt":"1016966437408.25","record_type_cd":"F","sequence_level_nbr":"2"}]}"#
        XCTAssertEqual(UncleScam.statementRows(fromAPI: Data(api.utf8)), [UncleScamStatementRow(d: "2026-08-31", n: "Net Interest", a: 1016966437408, t: "F", l: 2)])
    }
}
