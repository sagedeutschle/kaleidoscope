import Foundation

// Uncle Scam: the receipt as rows of text, the same words and figures prismet.xyz/scam prints. The website builds
// its rows in `scam.js` (`receiptRows`); `UncleScamGoldenTests` holds these to them.

public struct UncleScamRow: Hashable, Sendable {
    public enum Kind: String, Sendable { case center, rule, row, total, head, note, stamp, barcode }
    public let kind: Kind
    /// Text of a centred line, heading, note or stamp; the left side of a row.
    public let text: String
    /// The right side of a row.
    public let value: String
    /// "title", "small", "red" or "".
    public let style: String

    public init(_ kind: Kind, _ text: String = "", _ value: String = "", style: String = "") {
        self.kind = kind; self.text = text; self.value = value; self.style = style
    }
}

public enum UncleScamFormat {
    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// JavaScript's `toFixed`: the nearest decimal with `digits` places to the double's exact value, halves going up.
    /// (`String(format:)` sends exact halves to the even digit, so "$1,240.50" would print as $1,240 here and
    /// $1,241 on the website.)
    static func fixed(_ x: Double, _ digits: Int) -> String {
        let exact = Array(String(format: "%.30f", abs(x)))            // printf prints the binary value's own digits
        guard let dot = exact.firstIndex(of: ".") else { return String(exact) }
        var kept = exact[..<dot].compactMap(\.wholeNumberValue) + exact[(dot + 1)...].prefix(digits).compactMap(\.wholeNumberValue)
        let rest = exact[(dot + 1 + digits)...]
        if let first = rest.first?.wholeNumberValue, first >= 5 {
            var i = kept.count - 1
            while i >= 0 { if kept[i] == 9 { kept[i] = 0; i -= 1 } else { kept[i] += 1; break } }
            if i < 0 { kept.insert(1, at: 0) }
        }
        let whole = kept.count - digits
        let text = kept.prefix(whole).map(String.init).joined() + (digits > 0 ? "." + kept.suffix(digits).map(String.init).joined() : "")
        return (x < 0 && kept.contains(where: { $0 != 0 }) ? "-" : "") + text
    }

    static func grouped(_ n: Double, decimals: Int) -> String {
        let text = fixed(n, decimals), negative = text.hasPrefix("-")
        let parts = (negative ? String(text.dropFirst()) : text).split(separator: ".", omittingEmptySubsequences: false)
        var whole = "", count = 0
        for ch in parts[0].reversed() {
            if count > 0, count % 3 == 0 { whole.append(",") }
            whole.append(ch); count += 1
        }
        return (negative ? "-$" : "$") + String(whole.reversed()) + (decimals > 0 ? "." + parts[1] : "")
    }

    /// "$60,000"
    public static func usd(_ n: Double) -> String { grouped(n, decimals: 0) }
    /// "$1.41"
    public static func usd2(_ n: Double) -> String { grouped(n, decimals: 2) }
    /// "17.5%"
    public static func pct(_ x: Double, digits: Int = 1) -> String { fixed(x * 100, digits) + "%" }

    /// "$16.43 trillion", "$309.6 million": sums too large to read digit by digit.
    public static func big(_ n: Double) -> String {
        let a = abs(n)
        if a >= 1e12 { return "$\(fixed(n / 1e12, 2)) trillion" }
        if a >= 1e9 { return "$\(fixed(n / 1e9, 1)) billion" }
        if a >= 1e6 { return "$\(fixed(n / 1e6, 1)) million" }
        return usd(n)
    }

    /// "2013-01-03" → "Jan 3, 2013"
    public static func day(_ iso: String) -> String {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...12).contains(p[1]) else { return iso }
        return "\(months[p[1] - 1]) \(p[2]), \(p[0])"
    }

    /// "65,000", "$65000", "65k", "1.2m" → dollars; nil for anything else.
    public static func parseSalary(_ text: String) -> Double? {
        var s = text.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("$") { s = String(s.dropFirst()).trimmingCharacters(in: .whitespaces) }
        var scale = 1.0
        if let last = s.last, "kKmM".contains(last) {
            scale = "kK".contains(last) ? 1e3 : 1e6
            s = String(s.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        guard !s.isEmpty, s.contains(where: \.isNumber), s.allSatisfy({ ($0.isASCII && $0.isNumber) || $0 == "," || $0 == "." }),
              s.filter({ $0 == "." }).count <= 1, let n = Double(s.replacingOccurrences(of: ",", with: "")) else { return nil }
        return UncleScam.jsRound(n * scale)
    }
}

extension UncleScam {
    /// Plain names for the budget's functions; anything not listed prints as the Treasury names it.
    static let plainNames: [String: String] = [
        "Net Interest": "Interest on the debt",
        "National Defense": "Defense",
        "Health": "Health (Medicaid, research)",
        "Income Security": "Income security",
        "Veterans Benefits and Services": "Veterans",
        "Administration of Justice": "Justice",
        "Education, Training, Employment, and Social Services": "Education and training",
        "Natural Resources and Environment": "Environment",
        "General Science, Space, and Technology": "Science and space",
        "Community and Regional Development": "Community development",
        "International Affairs": "Foreign affairs",
    ]

    /// The receipt. `percent` swaps dollars for shares of pay (for sharing without the amounts).
    public static func receiptRows(bill: UncleScamBill, statement st: UncleScamStatement, data: UncleScamTaxData, percent: Bool) -> [UncleScamRow] {
        typealias F = UncleScamFormat
        let stateName = data.state.states[bill.stateCode]?.name ?? bill.stateCode
        let taxed = data.state.states[bill.stateCode]?.taxesWages ?? false
        func money(_ n: Double) -> String { percent ? F.pct(bill.wages != 0 ? n / bill.wages : 0) : F.usd(n) }
        let t = timeUnits(rate: bill.rate, total: bill.total, year: data.federal.year)
        let day = t.freedomDay.split(separator: "-").compactMap { Int($0) }
        let mins = t.minutesPerWorkday
        let through = "\(F.months[(Int(st.date.dropFirst(5).prefix(2)) ?? 1) - 1]) \(st.date.prefix(4))"
        var rows: [UncleScamRow] = [
            .init(.center, "UNCLE SCAM", style: "title"),
            .init(.center, "INFERNAL REVENUE SERVICE"),
            .init(.center, "Branch: \(stateName) · Tax year \(data.federal.year)", style: "small"),
            .init(.rule),
            .init(.row, "GROSS PAY", percent ? "100.0%" : F.usd(bill.wages)),
            .init(.rule),
            .init(.head, "YOUR BILL"),
            .init(.row, "Federal income tax", money(bill.federalIncome)),
            .init(.row, "Social Security tax", money(bill.socialSecurity)),
            .init(.row, "Medicare tax", money(bill.medicare)),
            .init(.row, "\(stateName) income tax", taxed ? money(bill.state) : "\(money(0)) lucky you"),
            .init(.total, "TOTAL", money(bill.total)),
            .init(.row, "You keep", money(bill.takeHome)),
        ]
        if !percent { rows.append(.init(.row, "Share of your pay", F.pct(bill.rate))) }
        rows += [.init(.rule), .init(.head, "WHAT YOUR INCOME TAX BOUGHT")]
        rows += splitByFunction(bill.federalIncome, statement: st).map { .init(.row, $0.rest ? $0.name : (plainNames[$0.name] ?? $0.name), money($0.amount)) }
        rows += [
            .init(.note, "Your Social Security and Medicare taxes went to Social Security and Medicare."),
            .init(.rule),
            .init(.head, "PUT ON THE CARD", style: "red"),
            .init(.row, "Borrowed on top of your bill", money(borrowed(forFederalTotal: bill.federalTotal, statement: st)), style: "red"),
            .init(.note, "Washington spent \(F.usd2(1 + st.borrowedPerDollar)) for every $1.00 it collected (fiscal \(st.fiscalYear) through \(through)). You will be billed later."),
            .init(.rule),
            .init(.head, "TIME SERVED"),
            .init(.row, "Working for the government until", "\(F.months[day[1] - 1]) \(day[2])"),
            .init(.row, "Of every 8-hour day", "\(mins / 60) h \(String(format: "%02d", mins % 60)) min"),
        ]
        if !percent { rows.append(.init(.row, "Out of each paycheck (of 26)", F.usd(t.perPaycheck))) }
        rows += [
            .init(.rule),
            .init(.stamp, "NO REFUNDS"),
            .init(.center, "THANK YOU FOR YOUR CONTRIBUTION."),
            .init(.center, "IT WAS MANDATORY."),
            .init(.barcode),
            .init(.center, "prismet.xyz/scam · an estimate, not tax advice", style: "small"),
        ]
        return rows
    }
}
