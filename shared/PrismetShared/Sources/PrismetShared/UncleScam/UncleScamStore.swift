import Foundation

// Uncle Scam: where the numbers come from.
//
// Privacy, the same promise the website makes: the salary never leaves the device. The ZIP code's first
// three digits fetch a public data file from prismet.xyz; the full ZIP goes to USAspending.gov only when
// the person asks for the local lookup.

/// The website's own data files, bundled as the offline fallback (`scripts/uncle-scam-golden.mjs` copies them).
public enum UncleScamBundled {
    static func data(_ name: String, _ ext: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
    public static func taxData() throws -> UncleScamTaxData { try JSONDecoder().decode(UncleScamTaxData.self, from: data("tax-2026", "json")) }
    public static func snapshot() throws -> UncleScamSnapshot { try JSONDecoder().decode(UncleScamSnapshot.self, from: data("mts-snapshot", "json")) }
    public static func sealPNG() -> Data? { try? data("uncle-scam-seal", "png") }
}

public struct UncleScamLocalAwards: Hashable, Sendable {
    public let fiscalYear: Int
    public let countyName: String?
    public let countyTotal: Double?
    public let countyPerCapita: Double?
    public let recipients: [UncleScamRecipient]
}

/// Fetches the public data. Every method is safe to call offline: the receipt falls back to the bundled files.
public struct UncleScamService: Sendable {
    public static let site = URL(string: "https://prismet.xyz/scam-data/")!
    static let statementURL = URL(string: "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/accounting/mts/mts_table_9"
        + "?fields=record_date,classification_desc,current_fytd_rcpt_outly_amt,record_type_cd,sequence_level_nbr"
        + "&sort=-record_date&page%5Bsize%5D=300")!
    static let debtURL = URL(string: "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v2/accounting/od/debt_to_penny"
        + "?fields=record_date,tot_pub_debt_out_amt&sort=-record_date&page%5Bsize%5D=1")!
    static let spending = URL(string: "https://api.usaspending.gov/api/v2/search/")!

    let session: URLSession

    public init(session: URLSession = .shared) { self.session = session }

    func get(_ url: URL, timeout: TimeInterval = 8) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    func post(_ url: URL, body: [String: Any], timeout: TimeInterval = 20) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    /// The site's tax tables when it answers, the bundled copy when it does not.
    public func taxData(year: Int = 2026) async -> UncleScamTaxData? {
        if let data = try? await get(Self.site.appendingPathComponent("tax-\(year).json"), timeout: 6),
           let tax = try? JSONDecoder().decode(UncleScamTaxData.self, from: data) { return tax }
        return try? UncleScamBundled.taxData()
    }

    /// The Treasury's live statement; else the site's snapshot; else the bundled one. `live` says which.
    public func statement() async -> (statement: UncleScamStatement, live: Bool)? {
        if let data = try? await get(Self.statementURL, timeout: 6), let picked = UncleScam.pickStatement(UncleScam.statementRows(fromAPI: data)) {
            return (picked, true)
        }
        if let data = try? await get(Self.site.appendingPathComponent("mts-snapshot.json"), timeout: 6),
           let snapshot = try? JSONDecoder().decode(UncleScamSnapshot.self, from: data), let picked = UncleScam.pickStatement(snapshot.rows) {
            return (picked, false)
        }
        if let snapshot = try? UncleScamBundled.snapshot(), let picked = UncleScam.pickStatement(snapshot.rows) { return (picked, false) }
        return nil
    }

    public func congress() async -> UncleScamCongress? {
        guard let data = try? await get(Self.site.appendingPathComponent("congress.json")) else { return nil }
        return try? JSONDecoder().decode(UncleScamCongress.self, from: data)
    }

    /// Today's total public debt, from the Treasury.
    public func debtNow() async -> UncleScamCongress.Debt? {
        struct Answer: Decodable { struct Row: Decodable { let record_date: String; let tot_pub_debt_out_amt: String }; let data: [Row] }
        guard let data = try? await get(Self.debtURL, timeout: 6), let row = (try? JSONDecoder().decode(Answer.self, from: data))?.data.first,
              let amount = Double(row.tot_pub_debt_out_amt), amount > 0 else { return nil }
        return UncleScamCongress.Debt(date: row.record_date, amount: amount.rounded(), yearEnd: nil)
    }

    /// Only the first three digits of the ZIP go to prismet.xyz.
    public func zipEntry(_ zip: String) async -> UncleScamZipEntry? {
        guard zip.count == 5, let data = try? await get(Self.site.appendingPathComponent("zip/\(zip.prefix(3)).json")) else { return nil }
        return (try? JSONDecoder().decode([String: UncleScamZipEntry].self, from: data))?[zip]
    }

    /// Sends the ZIP (never the salary) to USAspending.gov. Call only when the person asks.
    public func localAwards(zip: String, countyFIPS: String?, today: String) async throws -> UncleScamLocalAwards {
        let fy = UncleScam.lastFiscalYear(today: today)
        let period = [["start_date": fy.start, "end_date": fy.end]]
        struct Recipients: Decodable { struct Row: Decodable { let name: String?; let amount: Double? }; let results: [Row] }
        struct Geography: Decodable { struct Row: Decodable { let display_name: String?; let aggregated_amount: Double?; let per_capita: Double? }; let results: [Row] }
        async let recipientsData = post(Self.spending.appendingPathComponent("spending_by_category/recipient/"), body: [
            "filters": ["time_period": period, "place_of_performance_locations": [["country": "USA", "zip": zip]]], "limit": 30,
        ])
        var county: Geography.Row?
        if let countyFIPS, let data = try? await post(Self.spending.appendingPathComponent("spending_by_geography/"), body: [
            "scope": "place_of_performance", "geo_layer": "county", "geo_layer_filters": [countyFIPS], "filters": ["time_period": period],
        ]) {
            county = (try? JSONDecoder().decode(Geography.self, from: data))?.results.first
        }
        let rows = try JSONDecoder().decode(Recipients.self, from: try await recipientsData).results
        return UncleScamLocalAwards(fiscalYear: fy.fy, countyName: county?.display_name, countyTotal: county?.aggregated_amount,
                                    countyPerCapita: county?.per_capita,
                                    recipients: UncleScam.topRecipients(rows.map { ($0.name ?? "", $0.amount ?? .nan) }))
    }
}
