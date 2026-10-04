import Foundation

// Uncle Scam: the arithmetic behind the tax receipt, and the shapes of the data it reads.
//
// This is a port of the website's `scam-calc.js` (prismet.xyz/scam). The two must agree to the cent:
// `scripts/uncle-scam-golden.mjs` runs the website's code over several hundred cases and
// `UncleScamGoldenTests` holds this file to those answers. Change the arithmetic on the website first,
// regenerate the answers, then change it here.
//
// What the estimate assumes: wages from one job are the only income, the standard deduction, no
// dependents, no credits, under 65. `.joint` treats the salary as the household's wages, earned by one
// person.

// MARK: - Data (scam-data/*.json on prismet.xyz)

public enum UncleScamFilingStatus: String, CaseIterable, Codable, Hashable, Sendable {
    case single, joint, head

    public var label: String {
        switch self {
        case .single: return "Single"
        case .joint: return "Married, joint"
        case .head: return "Head of household"
        }
    }
}

public struct UncleScamSource: Decodable, Hashable, Sendable {
    public let what: String?
    public let name: String
    public let url: String
}

public struct UncleScamTaxData: Decodable, Sendable {
    public struct Federal: Decodable, Sendable {
        public struct SocialSecurity: Decodable, Sendable { public let rate: Double; public let wageBase: Double }
        public struct Medicare: Decodable, Sendable {
            public let rate: Double
            public let additionalRate: Double
            public let additionalOver: [String: Double]
        }
        public let year: Int
        public let sources: [UncleScamSource]
        public let standardDeduction: [String: Double]
        /// Per filing status: `[[taxable income over, rate], …]`, ascending.
        public let brackets: [String: [[Double]]]
        public let socialSecurity: SocialSecurity
        public let medicare: Medicare
    }

    public struct StateTable: Decodable, Sendable {
        public let name: String
        /// "taxed" or "none".
        public let wages: String
        public let note: String?
        public let single: [[Double]]?
        public let joint: [[Double]]?
        public let deduct: [String: Double]?
        public let credit: [String: Double]?

        public var taxesWages: Bool { wages == "taxed" }
    }

    public struct States: Decodable, Sendable {
        public let year: Int
        public let source: UncleScamSource
        public let note: String
        public let states: [String: StateTable]
        public let territories: [String: String]
    }

    public struct Zip: Decodable, Sendable {
        public let source: UncleScamSource
        public let prefixes: [String: String]
        public let exceptions: [String: String]
    }

    public let built: String
    public let federal: Federal
    public let state: States
    public let zip: Zip
}

/// One line of the Monthly Treasury Statement, table 9. `t`: "F" outlays by function, "RSG" receipts by
/// source, "SL" the statement's own totals.
public struct UncleScamStatementRow: Decodable, Hashable, Sendable {
    public let d: String
    public let n: String
    public let a: Double
    public let t: String
    public let l: Int

    public init(d: String, n: String, a: Double, t: String, l: Int) {
        self.d = d; self.n = n; self.a = a; self.t = t; self.l = l
    }
}

public struct UncleScamSnapshot: Decodable, Sendable {
    public let built: String
    public let rows: [UncleScamStatementRow]
}

public struct UncleScamStatement: Hashable, Sendable {
    public struct Function: Hashable, Sendable { public let name: String; public let amount: Double }
    public let date: String
    public let fiscalYear: Int
    public let months: Int
    public let functions: [Function]
    public let outlays: Double
    public let receipts: Double
    public let borrowedPerDollar: Double
}

public struct UncleScamCongress: Decodable, Sendable {
    public struct Debt: Decodable, Hashable, Sendable {
        public let date: String
        public let amount: Double
        public let yearEnd: Bool?

        public init(date: String, amount: Double, yearEnd: Bool? = nil) {
            self.date = date; self.amount = amount; self.yearEnd = yearEnd
        }
    }
    public struct Member: Decodable, Hashable, Identifiable, Sendable {
        public let n: String
        public let p: String
        public let s: String
        /// "sen" or "rep".
        public let t: String
        public let d: Int?
        public let since: String
        public let end: String
        public let url: String?
        public let debt: Debt?

        public var id: String { "\(s)-\(t)-\(d ?? -1)-\(n)" }
    }
    public let built: String
    public let debtNow: Debt?
    public let members: [Member]
}

/// A ZIP's record in `scam-data/zip/<prefix>.json`: its county and the districts it touches, largest first.
public struct UncleScamZipEntry: Decodable, Hashable, Sendable {
    public let c: String
    public let d: [String]

    public init(c: String, d: [String]) { self.c = c; self.d = d }
}

// MARK: - Results

public struct UncleScamBill: Hashable, Sendable {
    public let wages: Double
    public let status: UncleScamFilingStatus
    public let stateCode: String
    public let federalIncome: Double
    public let federalTaxable: Double
    public let marginal: Double
    public let socialSecurity: Double
    public let medicare: Double
    public let state: Double
    public let federalTotal: Double
    public let total: Double
    public let takeHome: Double
    public let rate: Double
}

public struct UncleScamReceiptLine: Hashable, Sendable {
    public let name: String
    public let share: Double
    public let amount: Double
    public let rest: Bool
}

public struct UncleScamTime: Hashable, Sendable {
    public let dayOfYear: Int
    public let days: Int
    /// YYYY-MM-DD: the last day of the year whose pay goes to tax, counting from January 1.
    public let freedomDay: String
    public let minutesPerWorkday: Int
    public let perPaycheck: Double
    public let perDay: Double
}

public struct UncleScamPlace: Hashable, Sendable {
    public let code: String
    public let territory: Bool
}

public struct UncleScamSeat: Hashable, Sendable {
    public let state: String
    public let district: Int
    public let member: UncleScamCongress.Member?
}

public struct UncleScamDebtSince: Hashable, Sendable {
    public let then: Double
    public let thenDate: String
    public let yearEnd: Bool
    public let now: Double
    public let nowDate: String
    public let added: Double
}

public struct UncleScamRecipient: Hashable, Sendable {
    public let name: String
    public let amount: Double
}

// MARK: - Arithmetic

public enum UncleScam {
    /// JavaScript's `Math.round`: halves go up. The website rounds with it, so this does too.
    static func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
    static func cents(_ n: Double) -> Double { jsRound(n * 100) / 100 }

    /// `brackets`: `[[income over, rate], …]` ascending. Income under the first threshold is taxed at zero.
    public static func bracketTax(_ taxable: Double, _ brackets: [[Double]]) -> Double {
        var tax = 0.0
        for i in brackets.indices {
            let over = brackets[i][0], rate = brackets[i][1]
            if taxable <= over { break }
            let top = i + 1 < brackets.count ? min(taxable, brackets[i + 1][0]) : taxable
            tax += (top - over) * rate
        }
        return cents(tax)
    }

    public static func marginalRate(_ taxable: Double, _ brackets: [[Double]]) -> Double {
        var rate = 0.0
        for b in brackets where taxable > b[0] { rate = b[1] }
        return rate
    }

    public static func federalIncomeTax(wages: Double, status: UncleScamFilingStatus, federal: UncleScamTaxData.Federal) -> (taxable: Double, tax: Double, marginal: Double) {
        let brackets = federal.brackets[status.rawValue] ?? []
        let taxable = max(0, wages - (federal.standardDeduction[status.rawValue] ?? 0))
        return (taxable, bracketTax(taxable, brackets), marginalRate(taxable, brackets))
    }

    public static func payrollTax(wages: Double, status: UncleScamFilingStatus, federal: UncleScamTaxData.Federal) -> (socialSecurity: Double, medicare: Double) {
        let ss = federal.socialSecurity, mc = federal.medicare
        let over = max(0, wages - (mc.additionalOver[status.rawValue] ?? 0))
        return (cents(min(wages, ss.wageBase) * ss.rate), cents(wages * mc.rate + over * mc.additionalRate))
    }

    /// Head of household uses the single schedule (the source lists two).
    public static func stateIncomeTax(wages: Double, status: UncleScamFilingStatus, state: UncleScamTaxData.StateTable?) -> (taxable: Double, tax: Double) {
        guard let state, state.taxesWages else { return (0, 0) }
        let who = status == .joint ? "joint" : "single"
        let brackets = (status == .joint ? state.joint : state.single) ?? []
        let taxable = max(0, wages - (state.deduct?[who] ?? 0))
        return (taxable, max(0, cents(bracketTax(taxable, brackets) - (state.credit?[who] ?? 0))))
    }

    /// "43201" → OH; "00901" → PR, a territory; nil when the ZIP is not one this data knows.
    public static func place(forZip zip: String, data: UncleScamTaxData) -> UncleScamPlace? {
        let z = zip.trimmingCharacters(in: .whitespaces)
        guard z.count == 5, z.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        guard let code = data.zip.exceptions[z] ?? data.zip.prefixes[String(z.prefix(3))] else { return nil }
        return UncleScamPlace(code: code, territory: data.state.states[code] == nil)
    }

    public static func computeBill(wages: Double, status: UncleScamFilingStatus, stateCode: String, data: UncleScamTaxData) -> UncleScamBill {
        let fed = federalIncomeTax(wages: wages, status: status, federal: data.federal)
        let pay = payrollTax(wages: wages, status: status, federal: data.federal)
        let st = stateIncomeTax(wages: wages, status: status, state: data.state.states[stateCode])
        let federalTotal = cents(fed.tax + pay.socialSecurity + pay.medicare)
        let total = cents(federalTotal + st.tax)
        return UncleScamBill(wages: wages, status: status, stateCode: stateCode,
                             federalIncome: fed.tax, federalTaxable: fed.taxable, marginal: fed.marginal,
                             socialSecurity: pay.socialSecurity, medicare: pay.medicare,
                             state: st.tax, federalTotal: federalTotal, total: total,
                             takeHome: cents(wages - total), rate: wages > 0 ? total / wages : 0)
    }

    // MARK: The Monthly Treasury Statement, table 9

    /// The API's answer → rows. Lines without an amount (section headings) are dropped.
    public static func statementRows(fromAPI json: Data) -> [UncleScamStatementRow] {
        struct Answer: Decodable {
            struct Row: Decodable {
                let record_date: String?
                let classification_desc: String?
                let current_fytd_rcpt_outly_amt: String?
                let record_type_cd: String?
                let sequence_level_nbr: String?
            }
            let data: [Row]?
        }
        guard let answer = try? JSONDecoder().decode(Answer.self, from: json) else { return [] }
        return (answer.data ?? []).compactMap { r in
            guard let raw = r.current_fytd_rcpt_outly_amt, raw != "null", let amount = Double(raw), amount.isFinite,
                  let d = r.record_date, let n = r.classification_desc, let t = r.record_type_cd else { return nil }
            return UncleScamStatementRow(d: d, n: n, a: jsRound(amount), t: t, l: Int(r.sequence_level_nbr ?? "") ?? 0)
        }
    }

    /// The newest statement, unless its fiscal year (October to September) is under six months old: then
    /// the last full year (a September statement) when the rows hold one, so a single month never stands in
    /// for a budget. Nil when the table's shape is not what this expects.
    public static func pickStatement(_ rows: [UncleScamStatementRow]) -> UncleScamStatement? {
        let dates = Array(Set(rows.map(\.d))).sorted(by: >)
        guard var date = dates.first else { return nil }
        func month(_ d: String) -> Int { Int(d.dropFirst(5).prefix(2)) ?? 0 }
        func monthsIn(_ d: String) -> Int { ((month(d) - 10 + 12) % 12) + 1 }
        if monthsIn(date) < 6 { date = dates.first(where: { month($0) == 9 }) ?? date }
        let mine = rows.filter { $0.d == date }
        let functions = mine.filter { $0.t == "F" }.map { UncleScamStatement.Function(name: $0.n, amount: $0.a) }
        let outlays = functions.reduce(0) { $0 + $1.amount }
        let receipts = mine.filter { $0.t == "RSG" }.reduce(0) { $0 + $1.a }
        guard functions.count >= 10, outlays > 0, receipts > 0 else { return nil }
        // the statement's own "Total" lines must agree with the sums, or the table's shape has changed
        let totals = mine.filter { $0.t == "SL" && $0.n == "Total" }.reduce(0) { $0 + $1.a }
        if totals != 0, abs(totals - (outlays + receipts)) > totals * 0.001 { return nil }
        let fiscalYear = (Int(date.prefix(4)) ?? 0) + (month(date) >= 10 ? 1 : 0)
        return UncleScamStatement(date: date, fiscalYear: fiscalYear, months: monthsIn(date), functions: functions,
                                  outlays: outlays, receipts: receipts, borrowedPerDollar: (outlays - receipts) / receipts)
    }

    static let ownTax: Set<String> = ["Social Security", "Medicare"]   // paid for on the bill's payroll lines

    /// Spread an income tax bill over the budget's functions in proportion to outlays, leaving out the two
    /// programs the payroll lines already pay for. The `top` largest get their own line; the rest are
    /// netted into one. Lines add up to `amount` to the cent.
    public static func splitByFunction(_ amount: Double, statement: UncleScamStatement, top: Int = 8) -> [UncleScamReceiptLine] {
        let funcs = statement.functions.filter { !ownTax.contains($0.name) }
        let base = funcs.reduce(0) { $0 + $1.amount }
        // a stable sort, as JavaScript's is: equal amounts keep the statement's order
        var positive: [(offset: Int, function: UncleScamStatement.Function)] = []
        for (offset, function) in funcs.enumerated() where function.amount > 0 { positive.append((offset, function)) }
        positive.sort { a, b in a.function.amount != b.function.amount ? a.function.amount > b.function.amount : a.offset < b.offset }
        let big = positive.prefix(top).map { $0.function }
        var lines = big.map { UncleScamReceiptLine(name: $0.name, share: $0.amount / base, amount: cents(amount * $0.amount / base), rest: false) }
        let rest = cents(amount - lines.reduce(0) { $0 + $1.amount })
        lines.append(UncleScamReceiptLine(name: "Everything else", share: 1 - lines.reduce(0) { $0 + $1.share }, amount: rest, rest: true))
        return lines
    }

    /// What Washington borrowed on top of each dollar it collected, scaled to this bill.
    public static func borrowed(forFederalTotal federalTotal: Double, statement: UncleScamStatement) -> Double {
        cents(federalTotal * statement.borrowedPerDollar)
    }

    // MARK: The bill in units of time

    public static func timeUnits(rate: Double, total: Double, year: Int) -> UncleScamTime {
        let days = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 366 : 365
        let dayOfYear = min(days, max(1, Int((rate * Double(days)).rounded(.up))))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let freedom = calendar.date(byAdding: .day, value: dayOfYear - 1, to: jan1)!
        let c = calendar.dateComponents([.year, .month, .day], from: freedom)
        return UncleScamTime(dayOfYear: dayOfYear, days: days,
                             freedomDay: String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!),
                             minutesPerWorkday: Int(jsRound(rate * 480)),
                             perPaycheck: cents(total / 26), perDay: cents(total / Double(days)))
    }

    // MARK: Who signs off

    /// `entry` is nil when the ZIP is not in the Census list; then only the state's senators are known.
    public static func officials(entry: UncleScamZipEntry?, stateCode: String, congress: UncleScamCongress) -> (senators: [UncleScamCongress.Member], seats: [UncleScamSeat]) {
        let senators = congress.members.filter { $0.t == "sen" && $0.s == stateCode }.sorted { ($0.since, $0.n) < ($1.since, $1.n) }
        let seats = (entry?.d ?? []).map { key -> UncleScamSeat in
            let state = String(key.prefix(2)), district = Int(key.dropFirst(2)) ?? 0
            return UncleScamSeat(state: state, district: district,
                                 member: congress.members.first { $0.t == "rep" && $0.s == state && $0.d == district })
        }
        return (senators, seats)
    }

    public static func debtSince(_ member: UncleScamCongress.Member, now: UncleScamCongress.Debt?) -> UncleScamDebtSince? {
        guard let debt = member.debt, let now else { return nil }
        return UncleScamDebtSince(then: debt.amount, thenDate: debt.date, yearEnd: debt.yearEnd == true,
                                  now: now.amount, nowDate: now.date, added: now.amount - debt.amount)
    }

    // MARK: Federal awards landing in a place (USAspending)

    /// The last fiscal year that has ended (October 1 to September 30), as of `today` (YYYY-MM-DD).
    public static func lastFiscalYear(today: String) -> (fy: Int, start: String, end: String) {
        let y = Int(today.prefix(4)) ?? 0, fy = String(today.dropFirst(5)) >= "10-01" ? y : y - 1
        return (fy, "\(fy - 1)-10-01", "\(fy)-09-30")
    }

    static let keepUpper: Set<String> = ["LLC", "LLP", "LP", "PLLC", "USA", "US", "II", "III", "IV", "NA", "PC"]
    static let keepLower: Set<String> = ["of", "and", "the", "for", "in", "at", "on", "to"]
    static let placeholders = ["REDACTED DUE TO PII": "Individuals (names withheld)", "MULTIPLE RECIPIENTS": "Many recipients (reported together)"]
    static let capitalAfter: Set<Character> = ["-", "'", ".", "&", "/", "("]

    /// "OHIO STATE UNIVERSITY, THE" → "The Ohio State University"
    public static func tidyName(_ raw: String) -> String {
        var s = raw.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).joined(separator: " ")
        if let placeholder = placeholders[s.uppercased()] { return placeholder }
        if let comma = s.range(of: ",", options: .backwards),
           s[comma.upperBound...].trimmingCharacters(in: .whitespaces).uppercased() == "THE" {
            s = "THE " + s[..<comma.lowerBound]
        }
        return s.split(separator: " ", omittingEmptySubsequences: false).enumerated().map { i, word in
            let w = String(word), bare = w.filter { $0.isASCII && $0.isLetter }
            if keepUpper.contains(bare.uppercased()) { return w.uppercased() }
            if i > 0, keepLower.contains(w.lowercased()) { return w.lowercased() }
            var out = "", previous: Character?
            for ch in w.lowercased() {
                let starts = previous == nil || capitalAfter.contains(previous!)
                out.append(starts && ch.isASCII && ch.isLowercase ? Character(ch.uppercased()) : ch)
                previous = ch
            }
            return out
        }.joined(separator: " ")
    }

    /// USAspending lists one row per registration; fold rows that share a name, largest first.
    public static func topRecipients(_ results: [(name: String, amount: Double)], top: Int = 8) -> [UncleScamRecipient] {
        var sum: [String: Double] = [:], order: [String] = []
        for r in results where !r.name.isEmpty && r.amount.isFinite {
            let name = tidyName(r.name)
            if sum[name] == nil { order.append(name) }
            sum[name, default: 0] += r.amount
        }
        var ranked: [(offset: Int, recipient: UncleScamRecipient)] = []
        for (offset, name) in order.enumerated() {
            let amount = sum[name] ?? 0
            if amount > 0 { ranked.append((offset, UncleScamRecipient(name: name, amount: amount))) }
        }
        ranked.sort { a, b in a.recipient.amount != b.recipient.amount ? a.recipient.amount > b.recipient.amount : a.offset < b.offset }
        return ranked.prefix(top).map { $0.recipient }
    }
}
