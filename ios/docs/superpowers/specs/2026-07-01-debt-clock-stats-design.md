# Debt Clock Stats Design

Date: 2026-07-01
Status: Approved by user for implementation

## Purpose

Fold a U.S. debt-clock statistics facet into Kaleidoscope without scraping usdebtclock.org or depending on private data. Claude owns the visual design. This work owns the accurate, sourced, free/public data layer and a minimal handoff surface so the tab can run inside the app.

## Source Policy

- Use official or broadly public feeds only.
- Do not scrape usdebtclock.org or copy opaque formulas.
- Mark derived/ticking values as estimates.
- Preserve each metric's source name, URL, and as-of date for UI disclosure.
- Prefer no-key endpoints. Free API-key sources are allowed only as future adapters, not required for v1.

## V1 Metrics

- Treasury FiscalData: Debt to the Penny, average interest rate on interest-bearing debt, Treasury General Account cash balance, gold reserve rows, and Debt Subject to Limit rows.
- FRED no-key CSV feeds: GDP, federal debt, debt-to-GDP, population, federal receipts, federal spending, monthly federal receipts/outlays, annual deficit/surplus, net interest outlays, receipts share of GDP, monthly federal surplus/deficit, total consumer credit, credit card debt proxy, student loan debt, auto loan debt, mortgage debt, M2 money stock, Fed balance-sheet assets, foreign-held federal debt, Social Security benefits, Medicare benefits, and personal income.
- BLS public API v2 without registration key: unemployment rate, labor force, employed workers, unemployed workers, not in labor force, and CPI index.
- Derived metrics: debt per citizen, debt-to-GDP, daily increase, per-second growth, receipts per citizen, spending per citizen, and deficit per citizen when the required source values exist.

## Visual Review Notes

- USDebtClock.org is used only as a visual/category reference, not as a data source.
- The site reads as a dense dark counter wall with category-colored LED figures: red for debt burdens, green for revenue/income, amber for deficit/interest pressure, cyan/blue for economy/labor/reserve-style values, and white/gray for neutral people counts.
- Kaleidoscope stores that color role on each `DebtClockMetric` as `DebtClockMetricTone`, so the UI and data layer stay aligned as more counters are added.

## Architecture

- `Sources/Core/Stats/DebtClockStats.swift` defines source metadata, metric IDs, normalized metric rows, parser adapters, and snapshot assembly.
- `Sources/Features/Stats/DebtClockStatsView.swift` provides a simple SwiftUI list that fetches the stats. Claude can replace the layout without changing the data contracts.
- `HomeView.swift` adds a Debt Clock card in the same bottom-area category as Oracle and routes it outside `CanonicalGameID`, because this is a stats facet, not a saved game.

## Error Handling

Each adapter is independent. If a source fails, the assembled snapshot returns the metrics that did load and an error summary for the failed source. UI should show stale/missing states instead of invented values.

## Testing

Unit tests cover Treasury JSON parsing and rate derivation, FRED CSV parsing, BLS response parsing with missing-value skips, derived debt-per-citizen math, and snapshot assembly. Live network is not required in tests.
