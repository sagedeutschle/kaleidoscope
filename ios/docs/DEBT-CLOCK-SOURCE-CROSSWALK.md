# Debt Clock Source Crosswalk

Date: 2026-07-01

## Policy

USDebtClock.org was reviewed for layout, density, and category color language only. Kaleidoscope does not scrape USDebtClock.org, copy its image assets, or depend on its private formulas. The tab uses official or no-key public feeds and labels derived/ticking values as estimates.

## Color Roles

- `debt`: red counters for debt burdens and private credit balances.
- `revenue`: green counters for receipts and income.
- `warning`: amber counters for deficit, spending, unemployment, and interest pressure.
- `reserve`: cyan/blue counters for broad economy and money-stock values.
- `labor`: cyan/blue counters for labor-market participation.
- `neutral`: white/gray counters for people counts and neutral index values.

## Implemented Sources

| Metric area | Source | Endpoint or series | Unit/frequency | Notes |
| --- | --- | --- | --- | --- |
| National debt, public debt, intragovernmental holdings | Treasury FiscalData | `debt_to_penny` API | Dollars, daily business-day records | Official Treasury values. Debt growth per second is derived from the latest two records. |
| Average interest rate | Treasury FiscalData | `avg_interest_rates`, `security_desc=Total Interest-bearing Debt` | Percent, monthly | Step value only. |
| Treasury General Account | Treasury FiscalData Daily Treasury Statement | `operating_cash_balance`, TGA closing balance row | Millions of dollars, daily business-day records | The current DTS row can store closing value in `open_today_bal`; parser accepts the first numeric close/open value. |
| Gold reserve | Treasury FiscalData | `gold_reserve` API | Fine troy ounces and statutory book dollars, monthly | The parser sums all latest-date rows. Book value is statutory, not market value. |
| Debt subject to limit | Treasury FiscalData Daily Treasury Statement | `debt_subject_to_limit` API | Millions of dollars, daily business-day records | Sums latest Debt Held by the Public and Intragovernmental Holdings rows; statutory definition differs from total public debt. |
| GDP | FRED | `GDP` | Billions of dollars, quarterly | Used directly and for derived debt-to-GDP. |
| Population | FRED | `POPTHM` | Thousands of people, monthly | Used for per-citizen derived counters. |
| Federal debt | FRED | `GFDEBTN` | Millions of dollars, quarterly | Secondary cross-check against Treasury. |
| Federal receipts | FRED | `FGRECPT` | Billions of dollars, quarterly annual rate | Green revenue counter. |
| Federal spending | FRED | `FGEXPND` | Billions of dollars, quarterly annual rate | Amber spending counter. |
| Monthly receipts/outlays | FRED | `MTSR133FMS`, `MTSO133FMS` | Millions of dollars, monthly | More current Treasury monthly flow lines. |
| Federal deficit/surplus | FRED | `FYFSD`, `MTSDS133FMS` | Millions of dollars, annual/monthly | Annual and monthly deficit/surplus lines. |
| Debt-to-GDP | FRED + derived | `GFDEGDQ188S`, Treasury + `GDP` | Percent | One official FRED ratio plus one Treasury-derived ratio. |
| Net interest | FRED | `FYOINT` | Millions of dollars, annual | Amber interest-pressure counter. |
| Receipts share of GDP | FRED | `FYFRGDA188S` | Percent, annual | Revenue ratio. |
| Consumer credit | FRED | `TOTALSL` | Millions of dollars, monthly | Public/private debt-style line. |
| Credit card debt | FRED | `REVOLSL` | Millions of dollars, monthly | Mirrors the common credit-card counter category. |
| Student loans | FRED | `SLOAS` | Millions of dollars, quarterly | Can lag more than monthly series. |
| Auto loans | FRED | `MVLOAS` | Millions of dollars, quarterly | Can lag more than monthly series. |
| Mortgage debt | FRED | `HHMSDODNS` | Millions of dollars, quarterly | Household and nonprofit mortgage liability. |
| M2 money stock | FRED | `M2SL` | Billions of dollars, monthly | Reserve/economy counter. |
| Fed balance-sheet assets | FRED | `WALCL` | Millions of dollars, weekly | Reserve/monetary-system category. |
| Foreign-held federal debt | FRED | `FDHBFIN` | Billions of dollars, quarterly | Lagged holder breakdown. |
| Social Security benefits | FRED | `W823RC1` | Billions of dollars, monthly | Transfer flow, not an unfunded liability counter. |
| Medicare benefits | FRED | `W824RC1` | Billions of dollars, monthly | Transfer flow, not an unfunded liability counter. |
| Personal income | FRED | `PI` | Billions of dollars, monthly | Green income counter. |
| Unemployment rate | BLS Public Data API | `LNS14000000` | Percent, monthly | Public no-key BLS series. |
| Labor force | BLS Public Data API | `LNS11000000` | Thousands of people, monthly | Labor counter. |
| Employed workers | BLS Public Data API | `LNS12000000` | Thousands of people, monthly | Labor counter. |
| Unemployed workers | BLS Public Data API | `LNS13000000` | Thousands of people, monthly | Amber labor-pressure counter. |
| Not in labor force | BLS Public Data API | `LNS15000000` | Thousands of people, monthly | Neutral people counter. |
| CPI | BLS Public Data API | `CUUR0000SA0` | Index, monthly | Neutral price index. |

## Derived Counters

- Debt per citizen: Treasury total debt divided by FRED population.
- Debt to GDP: Treasury total debt divided by FRED GDP.
- Receipts per citizen: FRED `FGRECPT` divided by FRED population.
- Spending per citizen: FRED `FGEXPND` divided by FRED population.
- Deficit per citizen: FRED `FGEXPND - FGRECPT` divided by FRED population.

## Live Ticking

National debt and debt per citizen tick from the recent Treasury daily growth estimate. Some stock/flow counters also use a nominal soft-drift rate between official refreshes to preserve the debt-clock feel; those rows are marked `EST` in the UI. Ratios, indices, interest rates, gold reserve, and Treasury cash values stay fixed until the next official observation.
