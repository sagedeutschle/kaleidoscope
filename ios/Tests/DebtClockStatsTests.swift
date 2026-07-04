import XCTest
@testable import Kaleidoscope

final class DebtClockStatsTests: XCTestCase {
    func testTreasuryDebtParserDerivesPerSecondGrowthFromTrailingRows() throws {
        let json = #"{"data":[{"record_date":"2026-06-29","tot_pub_debt_out_amt":"39345340787969.72","intragov_hold_amt":"7724010982621.53","debt_held_public_amt":"31621329805348.19"},{"record_date":"2026-06-26","tot_pub_debt_out_amt":"39337503706976.53","intragov_hold_amt":"7716631313714.13","debt_held_public_amt":"31620872393262.40"}]}"#

        let snapshot = try TreasuryDebtSnapshot.parse(Data(json.utf8))

        XCTAssertEqual(snapshot.asOf, "2026-06-29")
        XCTAssertEqual(snapshot.totalDebt, 39_345_340_787_969.72, accuracy: 0.01)
        XCTAssertEqual(snapshot.debtHeldByPublic, 31_621_329_805_348.19, accuracy: 0.01)
        XCTAssertEqual(snapshot.intragovernmentalHoldings, 7_724_010_982_621.53, accuracy: 0.01)
        let growth = try XCTUnwrap(snapshot.estimatedGrowthPerSecond)
        XCTAssertEqual(growth, 30_235.6519, accuracy: 0.01)
    }

    func testTreasuryDebtParserUsesWindowDeltaForGrowthSign() throws {
        let json = #"{"data":[{"record_date":"2026-06-30","tot_pub_debt_out_amt":"1000","intragov_hold_amt":"400","debt_held_public_amt":"600"},{"record_date":"2026-06-29","tot_pub_debt_out_amt":"900","intragov_hold_amt":"360","debt_held_public_amt":"540"},{"record_date":"2026-06-01","tot_pub_debt_out_amt":"1100","intragov_hold_amt":"440","debt_held_public_amt":"660"}]}"#

        let snapshot = try TreasuryDebtSnapshot.parse(Data(json.utf8))

        let growth = try XCTUnwrap(snapshot.estimatedGrowthPerSecond)
        XCTAssertLessThan(growth, 0)
        XCTAssertEqual(growth, -100.0 / Double(29 * 86_400), accuracy: 0.000_001)
    }

    func testTreasuryDebtParserReturnsNilGrowthForSingleRow() throws {
        let json = #"{"data":[{"record_date":"2026-06-30","tot_pub_debt_out_amt":"1000","intragov_hold_amt":"400","debt_held_public_amt":"600"}]}"#

        let snapshot = try TreasuryDebtSnapshot.parse(Data(json.utf8))

        XCTAssertNil(snapshot.estimatedGrowthPerSecond)
    }

    func testFREDCSVParserUsesLatestNumericObservation() throws {
        let csv = """
        observation_date,GDP
        2025-10-01,31422.526
        2026-01-01,.
        2026-04-01,31865.721
        """

        let observation = try FREDCSVParser.latestObservation(seriesID: "GDP", csv: csv)

        XCTAssertEqual(observation.seriesID, "GDP")
        XCTAssertEqual(observation.asOf, "2026-04-01")
        XCTAssertEqual(observation.value, 31_865.721, accuracy: 0.001)
    }

    func testBLSSeriesParserSkipsMissingValuesAndUsesLatestUsableData() throws {
        let json = #"{"Results":{"series":[{"seriesID":"LNS14000000","data":[{"year":"2026","period":"M06","periodName":"June","latest":"true","value":"-","footnotes":[{}]},{"year":"2026","period":"M05","periodName":"May","value":"4.3","footnotes":[{}]}]}]}}"#

        let observations = try BLSSeriesParser.parseLatestObservations(Data(json.utf8))

        let unemployment = try XCTUnwrap(observations["LNS14000000"])
        XCTAssertEqual(unemployment.asOf, "2026-M05")
        XCTAssertEqual(unemployment.value, 4.3, accuracy: 0.001)
    }

    func testAssemblerBuildsDebtPerCitizenAndSourceLabels() {
        let snapshot = DebtClockStatsAssembler.assemble(
            treasury: TreasuryDebtSnapshot(
                asOf: "2026-06-29",
                totalDebt: 39_345_340_787_969.72,
                debtHeldByPublic: 31_621_329_805_348.19,
                intragovernmentalHoldings: 7_724_010_982_621.53,
                estimatedGrowthPerSecond: 30_235.6519
            ),
            fred: [
                .population: FREDObservation(seriesID: "POPTHM", asOf: "2026-05-01", value: 342_746),
                .gdp: FREDObservation(seriesID: "GDP", asOf: "2026-01-01", value: 31_865.721)
            ],
            bls: [:]
        )

        let perCitizen = snapshot.metric(.debtPerCitizen)
        XCTAssertEqual(perCitizen?.value ?? 0, 114_794.46, accuracy: 0.5)
        XCTAssertEqual(perCitizen?.source.name, "Treasury FiscalData + FRED")
        XCTAssertTrue(perCitizen?.isDerived == true)

        let debtToGDP = snapshot.metric(.debtToGDP)
        XCTAssertEqual(debtToGDP?.value ?? 0, 123.47, accuracy: 0.05)
        XCTAssertEqual(debtToGDP?.unit, .percent)
    }

    func testAssemblerBuildsRevenueSpendingAndPerCitizenClockLines() {
        let snapshot = DebtClockStatsAssembler.assemble(
            treasury: TreasuryDebtSnapshot(
                asOf: "2026-06-29",
                totalDebt: 39_345_340_787_969.72,
                debtHeldByPublic: 31_621_329_805_348.19,
                intragovernmentalHoldings: 7_724_010_982_621.53,
                estimatedGrowthPerSecond: 30_235.6519
            ),
            fred: [
                .population: FREDObservation(seriesID: "POPTHM", asOf: "2026-05-01", value: 342_746),
                .federalReceipts: FREDObservation(seriesID: "FGRECPT", asOf: "2026-01-01", value: 5_872.497),
                .federalSpending: FREDObservation(seriesID: "FGEXPND", asOf: "2026-01-01", value: 7_679.660)
            ],
            bls: [:]
        )

        let receipts = snapshot.metric(.federalReceipts)
        XCTAssertEqual(receipts?.value ?? 0, 5_872.497, accuracy: 0.001)
        XCTAssertEqual(receipts?.unit, .billionsOfDollars)
        XCTAssertEqual(receipts?.tone, .revenue)

        let spending = snapshot.metric(.federalSpending)
        XCTAssertEqual(spending?.value ?? 0, 7_679.660, accuracy: 0.001)
        XCTAssertEqual(spending?.unit, .billionsOfDollars)
        XCTAssertEqual(spending?.tone, .warning)

        let receiptsPerCitizen = snapshot.metric(.receiptsPerCitizen)
        XCTAssertEqual(receiptsPerCitizen?.value ?? 0, 17_133.67, accuracy: 0.05)
        XCTAssertEqual(receiptsPerCitizen?.unit, .dollarsPerPerson)
        XCTAssertTrue(receiptsPerCitizen?.isDerived == true)
        XCTAssertTrue(receiptsPerCitizen?.isEstimated == true)
        XCTAssertEqual(receiptsPerCitizen?.tone, .revenue)

        let spendingPerCitizen = snapshot.metric(.spendingPerCitizen)
        XCTAssertEqual(spendingPerCitizen?.value ?? 0, 22_406.27, accuracy: 0.05)
        XCTAssertEqual(spendingPerCitizen?.tone, .warning)

        let deficitPerCitizen = snapshot.metric(.deficitPerCitizen)
        XCTAssertEqual(deficitPerCitizen?.value ?? 0, 5_272.60, accuracy: 0.05)
        XCTAssertEqual(deficitPerCitizen?.tone, .debt)
    }

    func testAssemblerIncludesConsumerDebtAndLaborCountersWithClockTones() {
        let snapshot = DebtClockStatsAssembler.assemble(
            treasury: nil,
            fred: [
                .consumerCredit: FREDObservation(seriesID: "TOTALSL", asOf: "2026-04-01", value: 5_153_090.64),
                .creditCardDebt: FREDObservation(seriesID: "REVOLSL", asOf: "2026-04-01", value: 1_348_688.30),
                .studentLoanDebt: FREDObservation(seriesID: "SLOAS", asOf: "2024-10-01", value: 1_777_101.97),
                .autoLoanDebt: FREDObservation(seriesID: "MVLOAS", asOf: "2024-10-01", value: 1_568_619.45),
                .personalIncome: FREDObservation(seriesID: "PI", asOf: "2026-05-01", value: 26_916.4)
            ],
            bls: [
                .laborForce: BLSObservation(seriesID: "LNS11000000", asOf: "2026-M05", value: 170_078),
                .employedWorkers: BLSObservation(seriesID: "LNS12000000", asOf: "2026-M05", value: 162_705),
                .unemployedWorkers: BLSObservation(seriesID: "LNS13000000", asOf: "2026-M05", value: 7_373),
                .notInLaborForce: BLSObservation(seriesID: "LNS15000000", asOf: "2026-M05", value: 101_363)
            ]
        )

        XCTAssertEqual(snapshot.metric(.consumerCredit)?.unit, .millionsOfDollars)
        XCTAssertEqual(snapshot.metric(.consumerCredit)?.tone, .debt)
        XCTAssertEqual(snapshot.metric(.creditCardDebt)?.tone, .debt)
        XCTAssertEqual(snapshot.metric(.studentLoanDebt)?.tone, .debt)
        XCTAssertEqual(snapshot.metric(.autoLoanDebt)?.tone, .debt)
        XCTAssertEqual(snapshot.metric(.personalIncome)?.unit, .billionsOfDollars)
        XCTAssertEqual(snapshot.metric(.personalIncome)?.tone, .revenue)

        XCTAssertEqual(snapshot.metric(.laborForce)?.unit, .thousandsOfPeople)
        XCTAssertEqual(snapshot.metric(.laborForce)?.tone, .labor)
        XCTAssertEqual(snapshot.metric(.employedWorkers)?.tone, .labor)
        XCTAssertEqual(snapshot.metric(.unemployedWorkers)?.tone, .warning)
        XCTAssertEqual(snapshot.metric(.notInLaborForce)?.tone, .neutral)
    }

    func testAssemblerIncludesCurrentFREDFiscalAndEconomyMetricsWithClockTones() throws {
        let snapshot = DebtClockStatsAssembler.assemble(
            treasury: nil,
            fred: [
                .federalDebt: FREDObservation(seriesID: "GFDEBTN", asOf: "2026-01-01", value: 36_214_000),
                .annualDeficit: FREDObservation(seriesID: "FYFSD", asOf: "2025-10-01", value: -1_775_123),
                .debtToGDP: FREDObservation(seriesID: "GFDEGDQ188S", asOf: "2026-01-01", value: 121.6),
                .netInterestOutlays: FREDObservation(seriesID: "FYOINT", asOf: "2025-10-01", value: 881_000),
                .receiptsShareOfGDP: FREDObservation(seriesID: "FYFRGDA188S", asOf: "2025-10-01", value: 17.1),
                .monthlyDeficit: FREDObservation(seriesID: "MTSDS133FMS", asOf: "2026-05-01", value: -316_987),
                .m2MoneyStock: FREDObservation(seriesID: "M2SL", asOf: "2026-05-01", value: 21_946.4)
            ],
            bls: [:]
        )

        let federalDebt = try XCTUnwrap(snapshot.metric(.federalDebtFRED))
        XCTAssertEqual(federalDebt.value, 36_214_000, accuracy: 0.001)
        XCTAssertEqual(federalDebt.unit, .millionsOfDollars)
        XCTAssertEqual(federalDebt.tone, .debt)

        XCTAssertEqual(snapshot.metric(.annualDeficit)?.unit, .millionsOfDollars)
        XCTAssertEqual(snapshot.metric(.annualDeficit)?.tone, .debt)
        XCTAssertEqual(snapshot.metric(.federalDebtToGDP)?.unit, .percent)
        XCTAssertEqual(snapshot.metric(.federalDebtToGDP)?.tone, .warning)
        XCTAssertEqual(snapshot.metric(.netInterestOutlays)?.tone, .warning)
        XCTAssertEqual(snapshot.metric(.receiptsShareOfGDP)?.tone, .revenue)
        XCTAssertEqual(snapshot.metric(.monthlyDeficit)?.tone, .debt)
        XCTAssertEqual(snapshot.metric(.m2MoneyStock)?.unit, .billionsOfDollars)
        XCTAssertEqual(snapshot.metric(.m2MoneyStock)?.tone, .reserve)
    }

    func testTreasurySupplementalParserBuildsReserveAndDebtLimitMetrics() throws {
        let avgInterestJSON = #"{"data":[{"record_date":"2026-05-31","security_desc":"Total Interest-bearing Debt","avg_interest_rate_amt":"3.353"}]}"#
        let cashJSON = #"{"data":[{"record_date":"2026-06-30","account_type":"Treasury General Account (TGA) Closing Balance","close_today_bal":"null","open_today_bal":"919145"}]}"#
        let goldJSON = #"{"data":[{"record_date":"2026-05-31","fine_troy_ounce_qty":"43853707.279","book_value_amt":"1851599995.81"},{"record_date":"2026-05-31","fine_troy_ounce_qty":"147341858.382","book_value_amt":"6219360711.55"},{"record_date":"2026-04-30","fine_troy_ounce_qty":"1","book_value_amt":"1"}]}"#
        let debtLimitJSON = #"{"data":[{"record_date":"2026-06-30","debt_catg":"Debt Held by the Public","close_today_bal":"31681308","open_today_bal":"31621330"},{"record_date":"2026-06-30","debt_catg":"Intragovernmental Holdings","close_today_bal":"7781090","open_today_bal":"7724011"},{"record_date":"2026-06-30","debt_catg":"Debt Not Subject to Limit","close_today_bal":"474","open_today_bal":"474"}]}"#

        let supplemental = try TreasurySupplementalSnapshot(
            averageInterest: TreasurySupplementalSnapshot.parseAverageInterest(Data(avgInterestJSON.utf8)),
            treasuryGeneralAccount: TreasurySupplementalSnapshot.parseTreasuryGeneralAccount(Data(cashJSON.utf8)),
            goldReserve: TreasurySupplementalSnapshot.parseGoldReserve(Data(goldJSON.utf8)),
            debtSubjectToLimit: TreasurySupplementalSnapshot.parseDebtSubjectToLimit(Data(debtLimitJSON.utf8))
        )

        XCTAssertEqual(supplemental.averageInterest?.value ?? 0, 3.353, accuracy: 0.001)
        XCTAssertEqual(supplemental.treasuryGeneralAccount?.value ?? 0, 919_145, accuracy: 0.001)
        XCTAssertEqual(supplemental.goldReserve?.fineTroyOunces ?? 0, 191_195_565.661, accuracy: 0.001)
        XCTAssertEqual(supplemental.goldReserve?.bookValue ?? 0, 8_070_960_707.36, accuracy: 0.01)
        XCTAssertEqual(supplemental.debtSubjectToLimit?.value ?? 0, 39_462_398, accuracy: 0.001)
    }

    func testAssemblerIncludesSupplementalTreasuryAndAdditionalFREDMetrics() throws {
        let supplemental = TreasurySupplementalSnapshot(
            averageInterest: .init(asOf: "2026-05-31", value: 3.353),
            treasuryGeneralAccount: .init(asOf: "2026-06-30", value: 919_145),
            goldReserve: .init(asOf: "2026-05-31", fineTroyOunces: 191_195_565.661, bookValue: 8_070_960_707.36),
            debtSubjectToLimit: .init(asOf: "2026-06-30", value: 39_462_398)
        )

        let snapshot = DebtClockStatsAssembler.assemble(
            treasury: nil,
            treasurySupplemental: supplemental,
            fred: [
                .monthlyReceipts: FREDObservation(seriesID: "MTSR133FMS", asOf: "2026-05-01", value: 371_123),
                .monthlyOutlays: FREDObservation(seriesID: "MTSO133FMS", asOf: "2026-05-01", value: 688_207),
                .fedBalanceSheetAssets: FREDObservation(seriesID: "WALCL", asOf: "2026-06-24", value: 6_612_990),
                .foreignHeldFederalDebt: FREDObservation(seriesID: "FDHBFIN", asOf: "2026-01-01", value: 8_837.2),
                .socialSecurityBenefits: FREDObservation(seriesID: "W823RC1", asOf: "2026-05-01", value: 1_679.0),
                .medicareBenefits: FREDObservation(seriesID: "W824RC1", asOf: "2026-05-01", value: 1_062.5),
                .mortgageDebt: FREDObservation(seriesID: "HHMSDODNS", asOf: "2026-01-01", value: 14_234_500)
            ],
            bls: [:]
        )

        XCTAssertEqual(snapshot.metric(.averageInterestRate)?.unit, .percent)
        XCTAssertEqual(snapshot.metric(.averageInterestRate)?.tone, .warning)
        XCTAssertEqual(snapshot.metric(.treasuryGeneralAccount)?.unit, .millionsOfDollars)
        XCTAssertEqual(snapshot.metric(.treasuryGeneralAccount)?.tone, .reserve)
        XCTAssertEqual(snapshot.metric(.goldReserveOunces)?.unit, .fineTroyOunces)
        XCTAssertEqual(snapshot.metric(.goldReserveBookValue)?.unit, .dollars)
        XCTAssertEqual(snapshot.metric(.debtSubjectToLimit)?.tone, .debt)
        XCTAssertEqual(snapshot.metric(.monthlyReceipts)?.tone, .revenue)
        XCTAssertEqual(snapshot.metric(.monthlyOutlays)?.tone, .warning)
        XCTAssertEqual(snapshot.metric(.fedBalanceSheetAssets)?.tone, .reserve)
        XCTAssertEqual(snapshot.metric(.foreignHeldFederalDebt)?.tone, .debt)
        XCTAssertEqual(snapshot.metric(.socialSecurityBenefits)?.tone, .warning)
        XCTAssertEqual(snapshot.metric(.medicareBenefits)?.tone, .warning)
        XCTAssertEqual(snapshot.metric(.mortgageDebt)?.unit, .millionsOfDollars)
    }

    func testDebtClockSnapshotCacheRoundTripsSnapshot() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("debt-clock-cache-\(UUID().uuidString).json")
        let cache = DebtClockSnapshotCache(fileURL: fileURL)
        let snapshot = DebtClockSnapshot(
            loadedAt: Date(timeIntervalSince1970: 100),
            metrics: [
                DebtClockMetric(
                    id: .totalDebt,
                    title: "U.S. National Debt",
                    value: 39_345_340_787_969,
                    unit: .dollars,
                    asOf: "2026-06-29",
                    source: .treasury,
                    isDerived: false,
                    isEstimated: true,
                    tone: .debt
                )
            ],
            errors: []
        )

        try cache.save(snapshot)

        XCTAssertEqual(try cache.load(), snapshot)
    }

    @MainActor
    func testDebtClockStoreSeedsSnapshotFromCacheBeforeRefresh() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("debt-clock-cache-\(UUID().uuidString).json")
        let cache = DebtClockSnapshotCache(fileURL: fileURL)
        let cached = DebtClockSnapshot(
            loadedAt: Date(timeIntervalSince1970: 100),
            metrics: [
                DebtClockMetric(
                    id: .totalDebt,
                    title: "U.S. National Debt",
                    value: 39_345_340_787_969,
                    unit: .dollars,
                    asOf: "2026-06-29",
                    source: .treasury,
                    isDerived: false,
                    isEstimated: true,
                    tone: .debt
                )
            ],
            errors: []
        )
        try cache.save(cached)

        let store = DebtClockStatsStore(
            client: DebtClockStatsClient(loader: {
                DebtClockSnapshot(loadedAt: Date(), metrics: [], errors: ["offline"])
            }),
            cache: cache
        )

        XCTAssertEqual(store.snapshot, cached)
        XCTAssertFalse(store.isLoading)
    }
}
