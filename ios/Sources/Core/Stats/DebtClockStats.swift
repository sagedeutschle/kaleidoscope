// PRISM: RELEASE Agent-Ads/Codex 2026-07-03 — Debt Clock growth-rate smoothing data lane
import Foundation

struct DebtClockSource: Codable, Equatable, Hashable {
    var name: String
    var url: URL

    static let treasury = DebtClockSource(
        name: "Treasury FiscalData",
        url: URL(string: "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v2/accounting/od/debt_to_penny")!
    )

    static let fred = DebtClockSource(
        name: "FRED",
        url: URL(string: "https://fred.stlouisfed.org")!
    )

    static let bls = DebtClockSource(
        name: "BLS Public Data API",
        url: URL(string: "https://api.bls.gov/publicAPI/v2/timeseries/data/")!
    )

    static let treasuryPlusFRED = DebtClockSource(
        name: "Treasury FiscalData + FRED",
        url: URL(string: "https://fiscaldata.treasury.gov/datasets/debt-to-the-penny/")!
    )
}

enum DebtClockMetricID: String, Codable, CaseIterable, Hashable {
    case totalDebt
    case debtHeldByPublic
    case intragovernmentalHoldings
    case debtGrowthPerSecond
    case debtPerCitizen
    case debtToGDP
    case averageInterestRate
    case treasuryGeneralAccount
    case goldReserveOunces
    case goldReserveBookValue
    case debtSubjectToLimit
    case federalDebtToGDP
    case gdp
    case federalDebtFRED
    case federalReceipts
    case federalSpending
    case monthlyReceipts
    case monthlyOutlays
    case receiptsPerCitizen
    case spendingPerCitizen
    case deficitPerCitizen
    case annualDeficit
    case netInterestOutlays
    case receiptsShareOfGDP
    case monthlyDeficit
    case consumerCredit
    case creditCardDebt
    case studentLoanDebt
    case autoLoanDebt
    case mortgageDebt
    case m2MoneyStock
    case fedBalanceSheetAssets
    case foreignHeldFederalDebt
    case socialSecurityBenefits
    case medicareBenefits
    case personalIncome
    case population
    case laborForce
    case employedWorkers
    case unemployedWorkers
    case notInLaborForce
    case unemploymentRate
    case cpi
}

enum DebtClockMetricUnit: String, Codable, Hashable {
    case dollars
    case dollarsPerSecond
    case dollarsPerPerson
    case percent
    case millionsOfDollars
    case billionsOfDollars
    case index
    case thousandsOfPeople
    case fineTroyOunces
}

enum DebtClockMetricTone: String, Codable, CaseIterable, Hashable {
    case debt
    case revenue
    case reserve
    case warning
    case labor
    case neutral
}

struct DebtClockMetric: Identifiable, Codable, Equatable {
    var id: DebtClockMetricID
    var title: String
    var value: Double
    var unit: DebtClockMetricUnit
    var asOf: String
    var source: DebtClockSource
    var isDerived: Bool
    var isEstimated: Bool
    var tone: DebtClockMetricTone = .neutral
}

struct DebtClockSnapshot: Codable, Equatable {
    var loadedAt: Date
    var metrics: [DebtClockMetric]
    var errors: [String]

    func metric(_ id: DebtClockMetricID) -> DebtClockMetric? {
        metrics.first { $0.id == id }
    }
}

struct DebtClockSnapshotCache {
    var fileURL: URL

    init(fileURL: URL = Self.defaultFileURL()) {
        self.fileURL = fileURL
    }

    func load() throws -> DebtClockSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(DebtClockSnapshot.self, from: Data(contentsOf: fileURL))
    }

    func save(_ snapshot: DebtClockSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Kaleidoscope", isDirectory: true)
            .appendingPathComponent("DebtClockSnapshot.json", isDirectory: false)
    }
}

struct TreasuryDebtSnapshot: Codable, Equatable {
    var asOf: String
    var totalDebt: Double
    var debtHeldByPublic: Double
    var intragovernmentalHoldings: Double
    var estimatedGrowthPerSecond: Double?

    static func parse(_ data: Data, calendar: Calendar = Calendar(identifier: .gregorian)) throws -> TreasuryDebtSnapshot {
        let response = try JSONDecoder().decode(TreasuryDebtResponse.self, from: data)
        guard let latest = response.data.first else {
            throw DebtClockParseError.missingTreasuryRows
        }

        let latestTotal = try latest.totalDebt()
        var growth: Double?
        if let latestDate = Self.date(latest.recordDate) {
            for olderRow in response.data.dropFirst().reversed() {
                guard let olderDate = Self.date(olderRow.recordDate) else { continue }
                let components = calendar.dateComponents([.day], from: olderDate, to: latestDate)
                guard let elapsedDays = components.day, elapsedDays > 0 else { continue }
                let olderTotal = try olderRow.totalDebt()
                growth = (latestTotal - olderTotal) / Double(elapsedDays * 86_400)
                break
            }
        }

        return TreasuryDebtSnapshot(
            asOf: latest.recordDate,
            totalDebt: latestTotal,
            debtHeldByPublic: try latest.debtHeldByPublic(),
            intragovernmentalHoldings: try latest.intragovernmentalHoldings(),
            estimatedGrowthPerSecond: growth
        )
    }

    private static func date(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }
}

struct TreasuryValuePoint: Codable, Equatable {
    var asOf: String
    var value: Double
}

struct TreasuryGoldReservePoint: Codable, Equatable {
    var asOf: String
    var fineTroyOunces: Double
    var bookValue: Double
}

struct TreasurySupplementalSnapshot: Codable, Equatable {
    var averageInterest: TreasuryValuePoint?
    var treasuryGeneralAccount: TreasuryValuePoint?
    var goldReserve: TreasuryGoldReservePoint?
    var debtSubjectToLimit: TreasuryValuePoint?

    static func parseAverageInterest(_ data: Data) throws -> TreasuryValuePoint {
        let response = try JSONDecoder().decode(TreasuryAverageInterestResponse.self, from: data)
        guard let row = response.data.first else {
            throw DebtClockParseError.missingTreasuryRows
        }
        return TreasuryValuePoint(asOf: row.recordDate, value: try parseNumber(row.averageInterestRateAmount))
    }

    static func parseTreasuryGeneralAccount(_ data: Data) throws -> TreasuryValuePoint {
        let response = try JSONDecoder().decode(TreasuryCashBalanceResponse.self, from: data)
        guard let row = response.data.first,
              let value = parseFirstNumber(row.closeTodayBalance, row.openTodayBalance) else {
            throw DebtClockParseError.missingTreasuryRows
        }
        return TreasuryValuePoint(asOf: row.recordDate, value: value)
    }

    static func parseGoldReserve(_ data: Data) throws -> TreasuryGoldReservePoint {
        let response = try JSONDecoder().decode(TreasuryGoldReserveResponse.self, from: data)
        guard let latestDate = response.data.first?.recordDate else {
            throw DebtClockParseError.missingTreasuryRows
        }

        var ounces = 0.0
        var bookValue = 0.0
        for row in response.data where row.recordDate == latestDate {
            ounces += try parseNumber(row.fineTroyOunceQuantity)
            bookValue += try parseNumber(row.bookValueAmount)
        }

        return TreasuryGoldReservePoint(asOf: latestDate, fineTroyOunces: ounces, bookValue: bookValue)
    }

    static func parseDebtSubjectToLimit(_ data: Data) throws -> TreasuryValuePoint {
        let response = try JSONDecoder().decode(TreasuryDebtLimitResponse.self, from: data)
        guard let latestDate = response.data.first?.recordDate else {
            throw DebtClockParseError.missingTreasuryRows
        }

        let includedCategories = Set(["Debt Held by the Public", "Intragovernmental Holdings"])
        var total = 0.0
        for row in response.data where row.recordDate == latestDate && includedCategories.contains(row.debtCategory) {
            guard let value = parseFirstNumber(row.closeTodayBalance, row.openTodayBalance) else {
                throw DebtClockParseError.invalidNumber(row.closeTodayBalance)
            }
            total += value
        }

        guard total > 0 else {
            throw DebtClockParseError.missingTreasuryRows
        }
        return TreasuryValuePoint(asOf: latestDate, value: total)
    }

    private static func parseFirstNumber(_ rawValues: String...) -> Double? {
        rawValues.lazy.compactMap { Double($0) }.first
    }

    private static func parseNumber(_ raw: String) throws -> Double {
        guard let value = Double(raw) else {
            throw DebtClockParseError.invalidNumber(raw)
        }
        return value
    }
}

enum FREDSeries: String, Codable, CaseIterable, Hashable {
    case gdp = "GDP"
    case population = "POPTHM"
    case federalDebt = "GFDEBTN"
    case federalReceipts = "FGRECPT"
    case federalSpending = "FGEXPND"
    case monthlyReceipts = "MTSR133FMS"
    case monthlyOutlays = "MTSO133FMS"
    case annualDeficit = "FYFSD"
    case debtToGDP = "GFDEGDQ188S"
    case netInterestOutlays = "FYOINT"
    case receiptsShareOfGDP = "FYFRGDA188S"
    case monthlyDeficit = "MTSDS133FMS"
    case consumerCredit = "TOTALSL"
    case creditCardDebt = "REVOLSL"
    case studentLoanDebt = "SLOAS"
    case autoLoanDebt = "MVLOAS"
    case mortgageDebt = "HHMSDODNS"
    case m2MoneyStock = "M2SL"
    case fedBalanceSheetAssets = "WALCL"
    case foreignHeldFederalDebt = "FDHBFIN"
    case socialSecurityBenefits = "W823RC1"
    case medicareBenefits = "W824RC1"
    case personalIncome = "PI"
}

struct FREDObservation: Codable, Equatable {
    var seriesID: String
    var asOf: String
    var value: Double
}

enum FREDCSVParser {
    static func latestObservation(seriesID: String, csv: String) throws -> FREDObservation {
        let rows = csv
            .split(whereSeparator: \.isNewline)
            .dropFirst()

        for row in rows.reversed() {
            let columns = row.split(separator: ",", omittingEmptySubsequences: false)
            guard columns.count >= 2 else { continue }
            let date = String(columns[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let valueRaw = String(columns[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Double(valueRaw) {
                return FREDObservation(seriesID: seriesID, asOf: date, value: value)
            }
        }

        throw DebtClockParseError.missingFREDObservation(seriesID)
    }
}

enum BLSSeries: String, Codable, CaseIterable, Hashable {
    case unemploymentRate = "LNS14000000"
    case laborForce = "LNS11000000"
    case employedWorkers = "LNS12000000"
    case unemployedWorkers = "LNS13000000"
    case notInLaborForce = "LNS15000000"
    case cpi = "CUUR0000SA0"
}

struct BLSObservation: Codable, Equatable {
    var seriesID: String
    var asOf: String
    var value: Double
}

enum BLSSeriesParser {
    static func parseLatestObservations(_ data: Data) throws -> [String: BLSObservation] {
        let response = try JSONDecoder().decode(BLSResponse.self, from: data)
        var observations: [String: BLSObservation] = [:]

        for series in response.results.series {
            guard let point = series.data.first(where: { Double($0.value) != nil }),
                  let value = Double(point.value) else {
                continue
            }
            observations[series.seriesID] = BLSObservation(
                seriesID: series.seriesID,
                asOf: "\(point.year)-\(point.period)",
                value: value
            )
        }

        return observations
    }
}

enum DebtClockStatsAssembler {
    static func assemble(
        treasury: TreasuryDebtSnapshot?,
        treasurySupplemental: TreasurySupplementalSnapshot? = nil,
        fred: [FREDSeries: FREDObservation],
        bls: [BLSSeries: BLSObservation],
        errors: [String] = [],
        loadedAt: Date = Date()
    ) -> DebtClockSnapshot {
        var metrics: [DebtClockMetric] = []

        if let treasury {
            metrics.append(DebtClockMetric(
                id: .totalDebt,
                title: "U.S. National Debt",
                value: treasury.totalDebt,
                unit: .dollars,
                asOf: treasury.asOf,
                source: .treasury,
                isDerived: false,
                isEstimated: false,
                tone: .debt
            ))
            metrics.append(DebtClockMetric(
                id: .debtHeldByPublic,
                title: "Debt Held by the Public",
                value: treasury.debtHeldByPublic,
                unit: .dollars,
                asOf: treasury.asOf,
                source: .treasury,
                isDerived: false,
                isEstimated: false,
                tone: .debt
            ))
            metrics.append(DebtClockMetric(
                id: .intragovernmentalHoldings,
                title: "Intragovernmental Holdings",
                value: treasury.intragovernmentalHoldings,
                unit: .dollars,
                asOf: treasury.asOf,
                source: .treasury,
                isDerived: false,
                isEstimated: false,
                tone: .debt
            ))
            if let estimatedGrowthPerSecond = treasury.estimatedGrowthPerSecond {
                metrics.append(DebtClockMetric(
                    id: .debtGrowthPerSecond,
                    title: "Debt Growth",
                    value: estimatedGrowthPerSecond,
                    unit: .dollarsPerSecond,
                    asOf: treasury.asOf,
                    source: .treasury,
                    isDerived: true,
                    isEstimated: true,
                    tone: .warning
                ))
            }
        }

        appendTreasurySupplementalMetrics(treasurySupplemental, to: &metrics)
        appendFREDMetrics(fred, to: &metrics)
        appendBLSMetrics(bls, to: &metrics)

        if let treasury,
           let population = fred[.population] {
            let people = population.value * 1_000
            if people > 0 {
                metrics.append(DebtClockMetric(
                    id: .debtPerCitizen,
                    title: "Debt per Citizen",
                    value: treasury.totalDebt / people,
                    unit: .dollarsPerPerson,
                    asOf: "\(treasury.asOf) / \(population.asOf)",
                    source: .treasuryPlusFRED,
                    isDerived: true,
                    isEstimated: true,
                    tone: .debt
                ))
            }
        }

        if let treasury,
           let gdp = fred[.gdp],
           gdp.value > 0 {
            let gdpDollars = gdp.value * 1_000_000_000
            metrics.append(DebtClockMetric(
                id: .debtToGDP,
                title: "Debt to GDP",
                value: (treasury.totalDebt / gdpDollars) * 100,
                unit: .percent,
                asOf: "\(treasury.asOf) / \(gdp.asOf)",
                source: .treasuryPlusFRED,
                isDerived: true,
                isEstimated: true,
                tone: .warning
            ))
        }

        if let population = fred[.population] {
            let people = population.value * 1_000
            if people > 0 {
                appendFiscalPerCitizenMetrics(fred, population: population, people: people, to: &metrics)
            }
        }

        return DebtClockSnapshot(loadedAt: loadedAt, metrics: metrics, errors: errors)
    }

    private static func appendTreasurySupplementalMetrics(
        _ supplemental: TreasurySupplementalSnapshot?,
        to metrics: inout [DebtClockMetric]
    ) {
        guard let supplemental else { return }

        if let averageInterest = supplemental.averageInterest {
            metrics.append(DebtClockMetric(
                id: .averageInterestRate,
                title: "Average Interest Rate",
                value: averageInterest.value,
                unit: .percent,
                asOf: averageInterest.asOf,
                source: .treasury,
                isDerived: false,
                isEstimated: false,
                tone: .warning
            ))
        }

        if let treasuryGeneralAccount = supplemental.treasuryGeneralAccount {
            metrics.append(DebtClockMetric(
                id: .treasuryGeneralAccount,
                title: "Treasury General Account",
                value: treasuryGeneralAccount.value,
                unit: .millionsOfDollars,
                asOf: treasuryGeneralAccount.asOf,
                source: .treasury,
                isDerived: false,
                isEstimated: false,
                tone: .reserve
            ))
        }

        if let goldReserve = supplemental.goldReserve {
            metrics.append(DebtClockMetric(
                id: .goldReserveOunces,
                title: "U.S. Gold Reserve",
                value: goldReserve.fineTroyOunces,
                unit: .fineTroyOunces,
                asOf: goldReserve.asOf,
                source: .treasury,
                isDerived: true,
                isEstimated: false,
                tone: .reserve
            ))
            metrics.append(DebtClockMetric(
                id: .goldReserveBookValue,
                title: "Gold Reserve Book Value",
                value: goldReserve.bookValue,
                unit: .dollars,
                asOf: goldReserve.asOf,
                source: .treasury,
                isDerived: true,
                isEstimated: false,
                tone: .reserve
            ))
        }

        if let debtSubjectToLimit = supplemental.debtSubjectToLimit {
            metrics.append(DebtClockMetric(
                id: .debtSubjectToLimit,
                title: "Debt Subject to Limit",
                value: debtSubjectToLimit.value,
                unit: .millionsOfDollars,
                asOf: debtSubjectToLimit.asOf,
                source: .treasury,
                isDerived: true,
                isEstimated: false,
                tone: .debt
            ))
        }
    }

    private static func appendFREDMetrics(_ fred: [FREDSeries: FREDObservation], to metrics: inout [DebtClockMetric]) {
        let definitions: [(FREDSeries, DebtClockMetricID, String, DebtClockMetricUnit, DebtClockMetricTone)] = [
            (.gdp, .gdp, "Gross Domestic Product", .billionsOfDollars, .reserve),
            (.population, .population, "U.S. Population", .thousandsOfPeople, .neutral),
            (.federalDebt, .federalDebtFRED, "Federal Debt", .millionsOfDollars, .debt),
            (.federalReceipts, .federalReceipts, "Federal Receipts", .billionsOfDollars, .revenue),
            (.federalSpending, .federalSpending, "Federal Spending", .billionsOfDollars, .warning),
            (.monthlyReceipts, .monthlyReceipts, "Monthly Federal Receipts", .millionsOfDollars, .revenue),
            (.monthlyOutlays, .monthlyOutlays, "Monthly Federal Outlays", .millionsOfDollars, .warning),
            (.annualDeficit, .annualDeficit, "Annual Deficit / Surplus", .millionsOfDollars, .debt),
            (.debtToGDP, .federalDebtToGDP, "Federal Debt to GDP", .percent, .warning),
            (.netInterestOutlays, .netInterestOutlays, "Net Interest Outlays", .millionsOfDollars, .warning),
            (.receiptsShareOfGDP, .receiptsShareOfGDP, "Federal Receipts to GDP", .percent, .revenue),
            (.monthlyDeficit, .monthlyDeficit, "Monthly Deficit / Surplus", .millionsOfDollars, .debt),
            (.consumerCredit, .consumerCredit, "Total Consumer Credit", .millionsOfDollars, .debt),
            (.creditCardDebt, .creditCardDebt, "Credit Card Debt Proxy", .millionsOfDollars, .debt),
            (.studentLoanDebt, .studentLoanDebt, "Student Loan Debt", .millionsOfDollars, .debt),
            (.autoLoanDebt, .autoLoanDebt, "Auto Loan Debt", .millionsOfDollars, .debt),
            (.mortgageDebt, .mortgageDebt, "Mortgage Debt", .millionsOfDollars, .debt),
            (.m2MoneyStock, .m2MoneyStock, "M2 Money Stock", .billionsOfDollars, .reserve),
            (.fedBalanceSheetAssets, .fedBalanceSheetAssets, "Fed Balance Sheet Assets", .millionsOfDollars, .reserve),
            (.foreignHeldFederalDebt, .foreignHeldFederalDebt, "Foreign-Held Federal Debt", .billionsOfDollars, .debt),
            (.socialSecurityBenefits, .socialSecurityBenefits, "Social Security Benefits", .billionsOfDollars, .warning),
            (.medicareBenefits, .medicareBenefits, "Medicare Benefits", .billionsOfDollars, .warning),
            (.personalIncome, .personalIncome, "Personal Income", .billionsOfDollars, .revenue)
        ]

        for (series, id, title, unit, tone) in definitions {
            guard let observation = fred[series] else { continue }
            metrics.append(DebtClockMetric(
                id: id,
                title: title,
                value: observation.value,
                unit: unit,
                asOf: observation.asOf,
                source: .fred,
                isDerived: false,
                isEstimated: false,
                tone: tone
            ))
        }
    }

    private static func appendFiscalPerCitizenMetrics(
        _ fred: [FREDSeries: FREDObservation],
        population: FREDObservation,
        people: Double,
        to metrics: inout [DebtClockMetric]
    ) {
        let receiptsDollars = fred[.federalReceipts].map { $0.value * 1_000_000_000 }
        let spendingDollars = fred[.federalSpending].map { $0.value * 1_000_000_000 }

        if let receiptsDollars,
           let receipts = fred[.federalReceipts] {
            metrics.append(DebtClockMetric(
                id: .receiptsPerCitizen,
                title: "Revenue per Citizen",
                value: receiptsDollars / people,
                unit: .dollarsPerPerson,
                asOf: "\(receipts.asOf) / \(population.asOf)",
                source: .fred,
                isDerived: true,
                isEstimated: true,
                tone: .revenue
            ))
        }

        if let spendingDollars,
           let spending = fred[.federalSpending] {
            metrics.append(DebtClockMetric(
                id: .spendingPerCitizen,
                title: "Spending per Citizen",
                value: spendingDollars / people,
                unit: .dollarsPerPerson,
                asOf: "\(spending.asOf) / \(population.asOf)",
                source: .fred,
                isDerived: true,
                isEstimated: true,
                tone: .warning
            ))
        }

        if let receiptsDollars,
           let spendingDollars,
           let receipts = fred[.federalReceipts],
           let spending = fred[.federalSpending] {
            metrics.append(DebtClockMetric(
                id: .deficitPerCitizen,
                title: "Deficit per Citizen",
                value: (spendingDollars - receiptsDollars) / people,
                unit: .dollarsPerPerson,
                asOf: "\(spending.asOf) / \(receipts.asOf) / \(population.asOf)",
                source: .fred,
                isDerived: true,
                isEstimated: true,
                tone: spendingDollars >= receiptsDollars ? .debt : .revenue
            ))
        }
    }

    private static func appendBLSMetrics(_ bls: [BLSSeries: BLSObservation], to metrics: inout [DebtClockMetric]) {
        let definitions: [(BLSSeries, DebtClockMetricID, String, DebtClockMetricUnit, DebtClockMetricTone)] = [
            (.unemploymentRate, .unemploymentRate, "Unemployment Rate", .percent, .warning),
            (.laborForce, .laborForce, "Labor Force", .thousandsOfPeople, .labor),
            (.employedWorkers, .employedWorkers, "Employed Workers", .thousandsOfPeople, .labor),
            (.unemployedWorkers, .unemployedWorkers, "Unemployed Workers", .thousandsOfPeople, .warning),
            (.notInLaborForce, .notInLaborForce, "Not in Labor Force", .thousandsOfPeople, .neutral),
            (.cpi, .cpi, "Consumer Price Index", .index, .neutral)
        ]

        for (series, id, title, unit, tone) in definitions {
            guard let observation = bls[series] else { continue }
            metrics.append(DebtClockMetric(
                id: id,
                title: title,
                value: observation.value,
                unit: unit,
                asOf: observation.asOf,
                source: .bls,
                isDerived: false,
                isEstimated: false,
                tone: tone
            ))
        }
    }
}

struct DebtClockStatsClient {
    var session: URLSession = .shared
    var loader: (() async -> DebtClockSnapshot)?

    init(session: URLSession = .shared, loader: (() async -> DebtClockSnapshot)? = nil) {
        self.session = session
        self.loader = loader
    }

    func load() async -> DebtClockSnapshot {
        if let loader {
            return await loader()
        }

        async let treasuryResult = result { try await loadTreasuryDebt() }
        async let treasurySupplemental = loadTreasurySupplemental()
        async let fredResult = result { try await loadFREDObservations() }
        async let blsResult = result { try await loadBLSObservations() }

        var errors: [String] = []
        let treasury: TreasuryDebtSnapshot?
        switch await treasuryResult {
        case .success(let snapshot):
            treasury = snapshot
        case .failure(let error):
            treasury = nil
            errors.append("Treasury: \(error.localizedDescription)")
        }

        let fred: [FREDSeries: FREDObservation]
        switch await fredResult {
        case .success(let observations):
            fred = observations
        case .failure(let error):
            fred = [:]
            errors.append("FRED: \(error.localizedDescription)")
        }

        let bls: [BLSSeries: BLSObservation]
        switch await blsResult {
        case .success(let observations):
            bls = observations
        case .failure(let error):
            bls = [:]
            errors.append("BLS: \(error.localizedDescription)")
        }

        let supplemental = await treasurySupplemental
        return DebtClockStatsAssembler.assemble(
            treasury: treasury,
            treasurySupplemental: supplemental,
            fred: fred,
            bls: bls,
            errors: errors
        )
    }

    func loadTreasuryDebt() async throws -> TreasuryDebtSnapshot {
        var request = URLRequest(url: URL(string: "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v2/accounting/od/debt_to_penny?fields=record_date,tot_pub_debt_out_amt,intragov_hold_amt,debt_held_public_amt&sort=-record_date&page%5Bsize%5D=31")!)
        request.setValue("Kaleidoscope/1.0 debt-clock-stats", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await validatedData(for: request)
        return try TreasuryDebtSnapshot.parse(data)
    }

    func loadTreasurySupplemental() async -> TreasurySupplementalSnapshot {
        async let averageInterest = optionalResult {
            try TreasurySupplementalSnapshot.parseAverageInterest(try await loadTreasuryData(
                "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v2/accounting/od/avg_interest_rates?filter=security_desc:eq:Total%20Interest-bearing%20Debt&sort=-record_date&page%5Bsize%5D=1"
            ))
        }
        async let treasuryGeneralAccount = optionalResult {
            try TreasurySupplementalSnapshot.parseTreasuryGeneralAccount(try await loadTreasuryData(
                "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/accounting/dts/operating_cash_balance?filter=account_type:eq:Treasury%20General%20Account%20%28TGA%29%20Closing%20Balance&sort=-record_date&page%5Bsize%5D=1"
            ))
        }
        async let goldReserve = optionalResult {
            try TreasurySupplementalSnapshot.parseGoldReserve(try await loadTreasuryData(
                "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v2/accounting/od/gold_reserve?sort=-record_date&page%5Bsize%5D=100"
            ))
        }
        async let debtSubjectToLimit = optionalResult {
            try TreasurySupplementalSnapshot.parseDebtSubjectToLimit(try await loadTreasuryData(
                "https://api.fiscaldata.treasury.gov/services/api/fiscal_service/v1/accounting/dts/debt_subject_to_limit?sort=-record_date&page%5Bsize%5D=25"
            ))
        }

        return await TreasurySupplementalSnapshot(
            averageInterest: averageInterest,
            treasuryGeneralAccount: treasuryGeneralAccount,
            goldReserve: goldReserve,
            debtSubjectToLimit: debtSubjectToLimit
        )
    }

    private func loadTreasuryData(_ urlString: String) async throws -> Data {
        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Kaleidoscope/1.0 debt-clock-stats", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await validatedData(for: request)
    }

    func loadFREDObservations() async throws -> [FREDSeries: FREDObservation] {
        var observations: [FREDSeries: FREDObservation] = [:]
        for series in FREDSeries.allCases {
            let url = URL(string: "https://fred.stlouisfed.org/graph/fredgraph.csv?id=\(series.rawValue)")!
            let data = try await validatedData(for: URLRequest(url: url))
            guard let csv = String(data: data, encoding: .utf8) else {
                throw DebtClockParseError.invalidUTF8(series.rawValue)
            }
            observations[series] = try FREDCSVParser.latestObservation(seriesID: series.rawValue, csv: csv)
        }
        return observations
    }

    func loadBLSObservations() async throws -> [BLSSeries: BLSObservation] {
        let now = Calendar(identifier: .gregorian).component(.year, from: Date())
        var request = URLRequest(url: DebtClockSource.bls.url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(BLSRequest(
            seriesid: BLSSeries.allCases.map(\.rawValue),
            startyear: "\(max(now - 1, 2000))",
            endyear: "\(now)"
        ))
        let data = try await validatedData(for: request)
        let keyedByString = try BLSSeriesParser.parseLatestObservations(data)
        var keyedBySeries: [BLSSeries: BLSObservation] = [:]
        for series in BLSSeries.allCases {
            keyedBySeries[series] = keyedByString[series.rawValue]
        }
        return keyedBySeries
    }

    private func validatedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw DebtClockNetworkError.badResponse
        }
        return data
    }
}

private func result<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
    do {
        return .success(try await operation())
    } catch {
        return .failure(error)
    }
}

private func optionalResult<T>(_ operation: () async throws -> T) async -> T? {
    do {
        return try await operation()
    } catch {
        return nil
    }
}

enum DebtClockParseError: LocalizedError, Equatable {
    case missingTreasuryRows
    case invalidNumber(String)
    case missingFREDObservation(String)
    case invalidUTF8(String)

    var errorDescription: String? {
        switch self {
        case .missingTreasuryRows:
            return "Treasury response did not include debt rows."
        case .invalidNumber(let raw):
            return "Could not parse numeric value: \(raw)."
        case .missingFREDObservation(let series):
            return "FRED series \(series) did not include a numeric observation."
        case .invalidUTF8(let label):
            return "\(label) response was not valid UTF-8."
        }
    }
}

enum DebtClockNetworkError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        "Source returned a non-success HTTP response."
    }
}

private struct TreasuryDebtResponse: Decodable {
    var data: [TreasuryDebtRow]
}

private struct TreasuryDebtRow: Decodable {
    var recordDate: String
    var totalPublicDebtOutstandingAmount: String
    var intragovernmentalHoldingsAmount: String
    var debtHeldByPublicAmount: String

    enum CodingKeys: String, CodingKey {
        case recordDate = "record_date"
        case totalPublicDebtOutstandingAmount = "tot_pub_debt_out_amt"
        case intragovernmentalHoldingsAmount = "intragov_hold_amt"
        case debtHeldByPublicAmount = "debt_held_public_amt"
    }

    func totalDebt() throws -> Double {
        try parse(totalPublicDebtOutstandingAmount)
    }

    func intragovernmentalHoldings() throws -> Double {
        try parse(intragovernmentalHoldingsAmount)
    }

    func debtHeldByPublic() throws -> Double {
        try parse(debtHeldByPublicAmount)
    }

    private func parse(_ raw: String) throws -> Double {
        guard let value = Double(raw) else {
            throw DebtClockParseError.invalidNumber(raw)
        }
        return value
    }
}

private struct TreasuryAverageInterestResponse: Decodable {
    var data: [TreasuryAverageInterestRow]
}

private struct TreasuryAverageInterestRow: Decodable {
    var recordDate: String
    var averageInterestRateAmount: String

    enum CodingKeys: String, CodingKey {
        case recordDate = "record_date"
        case averageInterestRateAmount = "avg_interest_rate_amt"
    }
}

private struct TreasuryCashBalanceResponse: Decodable {
    var data: [TreasuryCashBalanceRow]
}

private struct TreasuryCashBalanceRow: Decodable {
    var recordDate: String
    var closeTodayBalance: String
    var openTodayBalance: String

    enum CodingKeys: String, CodingKey {
        case recordDate = "record_date"
        case closeTodayBalance = "close_today_bal"
        case openTodayBalance = "open_today_bal"
    }
}

private struct TreasuryGoldReserveResponse: Decodable {
    var data: [TreasuryGoldReserveRow]
}

private struct TreasuryGoldReserveRow: Decodable {
    var recordDate: String
    var fineTroyOunceQuantity: String
    var bookValueAmount: String

    enum CodingKeys: String, CodingKey {
        case recordDate = "record_date"
        case fineTroyOunceQuantity = "fine_troy_ounce_qty"
        case bookValueAmount = "book_value_amt"
    }
}

private struct TreasuryDebtLimitResponse: Decodable {
    var data: [TreasuryDebtLimitRow]
}

private struct TreasuryDebtLimitRow: Decodable {
    var recordDate: String
    var debtCategory: String
    var closeTodayBalance: String
    var openTodayBalance: String

    enum CodingKeys: String, CodingKey {
        case recordDate = "record_date"
        case debtCategory = "debt_catg"
        case closeTodayBalance = "close_today_bal"
        case openTodayBalance = "open_today_bal"
    }
}

private struct BLSResponse: Decodable {
    var results: BLSResults

    enum CodingKeys: String, CodingKey {
        case results = "Results"
    }
}

private struct BLSResults: Decodable {
    var series: [BLSSeriesResponse]
}

private struct BLSSeriesResponse: Decodable {
    var seriesID: String
    var data: [BLSDataPoint]
}

private struct BLSDataPoint: Decodable {
    var year: String
    var period: String
    var value: String
}

private struct BLSRequest: Encodable {
    var seriesid: [String]
    var startyear: String
    var endyear: String
}
