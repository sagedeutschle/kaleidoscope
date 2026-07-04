# Debt Clock Stats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a U.S. debt-clock statistics data layer and routeable Kaleidoscope facet using safe public data sources.

**Architecture:** The stats layer normalizes official/public source payloads into source-labelled metric rows. A minimal SwiftUI view displays those rows while Claude owns the final visual treatment.

**Tech Stack:** Swift 5, SwiftUI, XCTest, URLSession, Treasury FiscalData JSON, FRED no-key CSV, BLS public API JSON.

## Global Constraints

- Do not scrape usdebtclock.org.
- Do not touch ads, entitlements, or monetization files.
- Respect PRISM coordination for `Sources/Features/Home/HomeView.swift`.
- Run `xcodegen generate` after adding Swift files.
- Use iOS simulator builds with DerivedData under `~/Library/Caches`.

---

### Task 1: Stats Contracts And Parsers

**Files:**
- Create: `Sources/Core/Stats/DebtClockStats.swift`
- Test: `Tests/DebtClockStatsTests.swift`

**Interfaces:**
- Produces: `DebtClockSource`, `DebtClockMetricID`, `DebtClockMetric`, `DebtClockSnapshot`, `DebtClockStatsAssembler`, `TreasuryDebtSnapshot`, `FREDCSVParser`, `BLSSeriesParser`.
- Consumes: Fixture strings in unit tests.

- [ ] **Step 1: Write failing parser tests**

```swift
func testTreasuryDebtParserDerivesPerSecondGrowthFromTrailingRows() throws {
    let json = #"{"data":[{"record_date":"2026-06-29","tot_pub_debt_out_amt":"39345340787969.72","intragov_hold_amt":"7724010982621.53","debt_held_public_amt":"31621329805348.19"},{"record_date":"2026-06-26","tot_pub_debt_out_amt":"39337503706976.53","intragov_hold_amt":"7716631313714.13","debt_held_public_amt":"31620872393262.40"}]}"#
    let snapshot = try TreasuryDebtSnapshot.parse(Data(json.utf8))
    XCTAssertEqual(snapshot.asOf, "2026-06-29")
    XCTAssertEqual(snapshot.totalDebt, 39_345_340_787_969.72, accuracy: 0.01)
    XCTAssertEqual(snapshot.debtHeldByPublic, 31_621_329_805_348.19, accuracy: 0.01)
    XCTAssertEqual(snapshot.intragovernmentalHoldings, 7_724_010_982_621.53, accuracy: 0.01)
    XCTAssertEqual(snapshot.estimatedGrowthPerSecond, 30_247.9984, accuracy: 0.01)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath "$HOME/Library/Caches/Kaleidoscope-debtclock-dd" -only-testing:KaleidoscopeTests/DebtClockStatsTests test`
Expected: fails because `TreasuryDebtSnapshot` is not defined.

- [ ] **Step 3: Implement contracts and parsers**

Create `DebtClockStats.swift` with focused parser types and no UI dependencies.

- [ ] **Step 4: Run focused parser tests**

Run the same `xcodebuild ... -only-testing:KaleidoscopeTests/DebtClockStatsTests test`.
Expected: all `DebtClockStatsTests` pass.

### Task 2: Public Source Fetcher And Minimal View

**Files:**
- Modify: `Sources/Core/Stats/DebtClockStats.swift`
- Create: `Sources/Features/Stats/DebtClockStatsView.swift`
- Test: `Tests/DebtClockStatsTests.swift`

**Interfaces:**
- Consumes: parser contracts from Task 1.
- Produces: `DebtClockStatsStore.load()` and `DebtClockStatsView`.

- [ ] **Step 1: Write failing assembly test**

```swift
func testAssemblerBuildsDebtPerCitizenAndSourceLabels() {
    let snapshot = DebtClockStatsAssembler.assemble(
        treasury: TreasuryDebtSnapshot(asOf: "2026-06-29", totalDebt: 39_345_340_787_969.72, debtHeldByPublic: 31_621_329_805_348.19, intragovernmentalHoldings: 7_724_010_982_621.53, estimatedGrowthPerSecond: 30_247.9984),
        fred: [.population: FREDObservation(seriesID: "POPTHM", asOf: "2026-05-01", value: 342_746)],
        bls: [:]
    )
    let perCitizen = snapshot.metric(.debtPerCitizen)
    XCTAssertEqual(perCitizen?.value, 114_797.42, accuracy: 0.5)
    XCTAssertEqual(perCitizen?.source.name, "Treasury FiscalData + FRED")
    XCTAssertTrue(perCitizen?.isDerived == true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run focused test command. Expected: fails because `DebtClockStatsAssembler` is incomplete.

- [ ] **Step 3: Implement assembler, fetcher, and simple view**

Fetcher uses Treasury FiscalData with HTTP/1.1-friendly request headers, FRED CSV URLs, and BLS public API v2 JSON. View renders metric rows and error summaries only.

- [ ] **Step 4: Run focused tests**

Expected: `DebtClockStatsTests` pass.

### Task 3: Home Routing

**Files:**
- Modify: `Sources/Features/Home/HomeView.swift`
- Test: build verification

**Interfaces:**
- Consumes: `DebtClockStatsView`.
- Produces: a `Debt Clock` card in the Oracle category and route for `debtclock`.

- [ ] **Step 1: Claim and re-read `HomeView.swift`**

Add `// PRISM: CLAIM Codex 2026-07-01 — debt clock stats route` at line 1, then re-read the file before editing route code.

- [ ] **Step 2: Add card and route**

Add `GameCard.debtClockID = "debtclock"`, insert the card in the Oracle category next to Oracle, and route `debtclock` to `DebtClockStatsView()`.

- [ ] **Step 3: Release claim**

Remove or convert the claim comment after build verification.

### Task 4: Verification

**Files:**
- Generated: `Kaleidoscope.xcodeproj`

- [ ] **Step 1: Regenerate project**

Run: `xcodegen generate`
Expected: project regenerates without errors.

- [ ] **Step 2: Focused tests**

Run: `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath "$HOME/Library/Caches/Kaleidoscope-debtclock-dd" -only-testing:KaleidoscopeTests/DebtClockStatsTests test`
Expected: tests pass.

- [ ] **Step 3: Simulator build**

Run: `xcodebuild -project Kaleidoscope.xcodeproj -scheme Kaleidoscope -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath "$HOME/Library/Caches/Kaleidoscope-debtclock-dd" -configuration Debug build`
Expected: build succeeds.
