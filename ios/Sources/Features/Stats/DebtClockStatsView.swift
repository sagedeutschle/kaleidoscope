// PRISM: RELEASE Agent-Design(debtclock) 2026-07-03 - v10 design pass
import SwiftUI

/// US Debt Clock — a dark, glowing, color-coded counter board mirroring
/// usdebtclock.org (black field, category-colored LED figures) in the Kaleidoscope
/// app. DESIGN lane (Agent-Design): the dark theme, per-category color coordination,
/// the grouped grid, and the smooth per-tick animation. The STATISTICS
/// (`DebtClockStats.swift`: values, growth rate, accuracy, sources) are Agent-Ads/
/// Codex's lane — this view only reads a `DebtClockSnapshot`.
struct DebtClockStatsView: View {
    @StateObject private var store = DebtClockStatsStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The lens hosts two boards behind a top-bar switcher (Oracle-style):
    /// THE DEBT (the LED counter board) and THE MOGULS (the council-audited
    /// billionaire/CEO ledger — see `MogulsView.swift`, Agent-Design lane).
    private enum Board: String, CaseIterable {
        case debt = "THE DEBT"
        case moguls = "THE MOGULS"
    }
    @State private var board: Board = .debt

    // usdebtclock-style palette on a dark field.
    private enum Hue {
        static let debt     = Color(red: 1.00, green: 0.42, blue: 0.33)  // red — the debt
        static let ratio    = Color(red: 0.86, green: 0.52, blue: 1.00)  // violet — per-capita / ratios
        static let deficit  = Color(red: 1.00, green: 0.68, blue: 0.20)  // amber — deficit / interest
        static let revenue  = Color(red: 0.36, green: 0.90, blue: 0.52)  // green — revenue in
        static let economy  = Color(red: 0.44, green: 0.83, blue: 1.00)  // cyan — economy
        static let people   = Color(red: 0.92, green: 0.94, blue: 0.99)  // near-white — people
        static let label    = Color(white: 0.72)
        static let sublabel  = Color(white: 0.5)
    }

    private static func toneColor(_ tone: DebtClockMetricTone) -> Color {
        switch tone {
        case .debt: return Hue.debt
        case .revenue: return Hue.revenue
        case .reserve: return Hue.economy
        case .warning: return Hue.deficit
        case .labor: return Hue.economy
        case .neutral: return Hue.people
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            boardSwitcher
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 4)
            switch board {
            case .debt: debtBoard
            case .moguls: MogulBoardView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .navigationTitle(board == .debt ? "Debt Clock" : "The Moguls")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var debtBoard: some View {
        ScrollView {
            // Re-render ~8×/sec so live figures tick smoothly between the infrequent
            // official-source refreshes.
            TimelineView(.periodic(from: .now, by: 0.12)) { context in
                VStack(alignment: .leading, spacing: 20) {
                    header
                    trendBanner(now: context.date)
                    content(now: context.date)
                }
                .padding(18)
            }
        }
        .task { await store.load() }
        .refreshable { await store.load() }
    }

    /// LED segmented switcher between the lens's boards. The active segment glows
    /// in its board's signature hue — debt red, mogul gold. (Each segment is its
    /// own small view so the type-checker doesn't choke on the inline chain.)
    private var boardSwitcher: some View {
        HStack(spacing: 8) {
            BoardSegment(title: Board.debt.rawValue,
                         active: board == .debt,
                         hue: Hue.debt,
                         a11y: "The Debt board") { board = .debt }
            BoardSegment(title: Board.moguls.rawValue,
                         active: board == .moguls,
                         hue: MogulBoardView.Hue.gold,
                         a11y: "The Moguls board") { board = .moguls }
        }
    }

    private struct BoardSegment: View {
        let title: String
        let active: Bool
        let hue: Color
        let a11y: String
        let action: () -> Void

        private var fillColor: Color { active ? hue.opacity(0.16) : Color.white.opacity(0.04) }
        private var borderColor: Color { active ? hue.opacity(0.6) : Color.white.opacity(0.10) }
        private var textColor: Color { active ? hue : Color(white: 0.72) }
        private var glow: Color { active ? hue.opacity(0.35) : .clear }

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(Kaleido.rounded(12.5, .heavy))
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(segmentBackground)
                    .foregroundStyle(textColor)
                    .shadow(color: glow, radius: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(a11y)
            .accessibilityAddTraits(active ? [.isSelected] : [])
        }

        private var segmentBackground: some View {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.05, blue: 0.09),
                     Color(red: 0.02, green: 0.03, blue: 0.06)],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(alignment: .top) {
            // faint brand iris glow behind the hero
            RadialGradient(colors: [Hue.economy.opacity(0.10), .clear],
                           center: .top, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("U.S. DEBT CLOCK")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Live figures · free public sources")
                    .font(Kaleido.rounded(12, .semibold))
                    .foregroundStyle(Hue.sublabel)
            }
            Spacer()
            if let s = store.snapshot {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(s.metrics.count) metrics").foregroundStyle(Hue.label)
                    Text("\(sourceCount(s)) sources").foregroundStyle(Hue.sublabel)
                }
                .font(Kaleido.rounded(11, .semibold))
            }
        }
    }

    // MARK: - Live trend banner (the v10 signature)

    /// Direction of the national debt, read straight off the REAL two-row Treasury
    /// derivative. `nil` (metric absent / snapshot not loaded) is a distinct state —
    /// never coalesced to 0, so we never claim "down" before data arrives.
    private enum Trend {
        case up(Double)
        case down(Double)
        case unknown
    }

    private var currentTrend: Trend {
        guard let rate = store.snapshot?.metric(.debtGrowthPerSecond)?.value else { return .unknown }
        if rate > 0 { return .up(rate) }
        if rate < 0 { return .down(rate) }
        return .unknown // exact 0.0 means the derivative didn't resolve — treat as no reading
    }

    /// Full-width LED glass strip above the hero. Lives inside the TimelineView so the
    /// ~2s arrow blink rides the existing 8Hz tick for free — a phase computed from
    /// `now`, no Animation, no extra timers. Reduce Motion pins the arrows steady.
    private func trendBanner(now: Date) -> some View {
        let trend = currentTrend
        // 2s period: arrows dim on odd seconds. Pure arithmetic per tick — cheap.
        let blinkDim = !reduceMotion && Int(now.timeIntervalSinceReferenceDate) % 2 == 1

        let hue: Color
        let arrow: String?
        let headline: String
        let rateLine: String?
        let a11y: String
        switch trend {
        case .up(let rate):
            hue = Hue.debt
            arrow = "▲"
            headline = "IT'S GOING UP!"
            rateLine = "+\(currency(rate, fraction: 0)) PER SECOND"
            a11y = "National debt trend: going up, \(currency(rate, fraction: 0)) per second."
        case .down(let rate):
            hue = Hue.revenue
            arrow = "▼"
            headline = "IT'S GOING DOWN!"
            rateLine = "−\(currency(rate.magnitude, fraction: 0)) PER SECOND"
            a11y = "National debt trend: going down, \(currency(rate.magnitude, fraction: 0)) per second."
        case .unknown:
            hue = Hue.deficit
            arrow = nil
            headline = "— READING THE TAPE —"
            rateLine = nil
            a11y = "National debt trend: reading the tape, no data yet."
        }
        let dimmed = arrow == nil

        return HStack(spacing: 12) {
            if let arrow { blinkArrow(arrow, hue: hue, dim: blinkDim) }
            VStack(spacing: 3) {
                Text(headline)
                    .font(Kaleido.rounded(16, .heavy)).tracking(2.2)
                    .foregroundStyle(hue.opacity(dimmed ? 0.75 : 1))
                    .shadow(color: hue.opacity(dimmed ? 0.2 : 0.6), radius: 8)
                if let rateLine {
                    Text(rateLine)
                        .font(Kaleido.rounded(12, .bold)).tracking(1.2)
                        .monospacedDigit()
                        .foregroundStyle(hue.opacity(0.85))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            if let arrow { blinkArrow(arrow, hue: hue, dim: blinkDim) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.03, green: 0.03, blue: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [hue.opacity(dimmed ? 0.10 : 0.20),
                                                      hue.opacity(0.04)],
                                             startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(hue.opacity(dimmed ? 0.35 : 0.55), lineWidth: 1)
                )
        )
        .shadow(color: hue.opacity(dimmed ? 0.10 : 0.25), radius: 14, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }

    private func blinkArrow(_ glyph: String, hue: Color, dim: Bool) -> some View {
        Text(glyph)
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(hue)
            .opacity(dim ? 0.25 : 1)
            .shadow(color: hue.opacity(dim ? 0.15 : 0.8), radius: dim ? 2 : 8)
            .animation(.easeInOut(duration: 0.45), value: dim)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if store.isLoading && store.snapshot == nil {
            loadingCard(now: now)
        } else if let snapshot = store.snapshot {
            VStack(alignment: .leading, spacing: 20) {
                if let debt = snapshot.metric(.totalDebt) {
                    heroPanel(debt, snapshot: snapshot, now: now)
                }
                if !snapshot.errors.isEmpty { errorCard(snapshot.errors) }
                ForEach(Self.sections, id: \.title) { section in
                    let metrics = section.ids.compactMap { snapshot.metric($0) }
                    if !metrics.isEmpty {
                        sectionView(section, metrics: metrics, snapshot: snapshot, now: now)
                    }
                }
                disclaimer
            }
        } else if let error = store.lastError {
            errorCard([error])
        }
    }

    // MARK: - Hero LED panel (national debt)

    private func heroPanel(_ debt: DebtClockMetric, snapshot: DebtClockSnapshot, now: Date) -> some View {
        let live = liveValue(debt, snapshot: snapshot, now: now)
        let rate = snapshot.metric(.debtGrowthPerSecond)?.value  // nil = no reading; never coalesce
        let perCitizen = snapshot.metric(.debtPerCitizen).map { liveValue($0, snapshot: snapshot, now: now) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("U.S. NATIONAL DEBT")
                .font(Kaleido.rounded(13, .heavy)).tracking(3)
                .foregroundStyle(Hue.debt.opacity(0.95))
            Text(currency(live, fraction: 0))
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Hue.debt)
                .shadow(color: Hue.debt.opacity(0.7), radius: 16)
                .minimumScaleFactor(0.35)
                .lineLimit(1)
            HStack(spacing: 16) {
                // Signed rate — shown whenever a real reading exists, up OR down.
                if let rate {
                    HStack(spacing: 5) {
                        Text(rate >= 0 ? "▲" : "▼")
                            .font(Kaleido.rounded(10, .heavy))
                            .accessibilityHidden(true)
                        Text("\(signedCurrency(rate))/sec").monospacedDigit()
                    }
                    .foregroundStyle(rate >= 0 ? Hue.deficit : Hue.revenue)
                }
                if let perCitizen {
                    HStack(spacing: 5) {
                        Text("PER CITIZEN")
                            .font(Kaleido.rounded(9.5, .heavy)).tracking(1.2)
                            .foregroundStyle(Hue.ratio.opacity(0.7))
                        Text(currency(perCitizen, fraction: 0)).monospacedDigit()
                            .foregroundStyle(Hue.ratio)
                    }
                }
            }
            .font(Kaleido.rounded(12, .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.06, green: 0.02, blue: 0.03))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Hue.debt.opacity(0.5), lineWidth: 1))
        )
        .shadow(color: Hue.debt.opacity(0.22), radius: 20, y: 8)
    }

    // MARK: - Color-coded sections + counter tiles

    /// Full-digit flowing figures (e.g. "$1,234,567,890,123") span the FULL width in
    /// their own rows so digits never shrink to squint scale; compact figures keep the
    /// two-column counter grid.
    private func sectionView(_ section: Section, metrics: [DebtClockMetric],
                             snapshot: DebtClockSnapshot, now: Date) -> some View {
        let wide = metrics.filter { isFullDigit($0, snapshot: snapshot) }
        let compact = metrics.filter { !isFullDigit($0, snapshot: snapshot) }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(section.hue).frame(width: 8, height: 8)
                    .shadow(color: section.hue.opacity(0.8), radius: 4)
                Text(section.title.uppercased())
                    .font(Kaleido.rounded(13, .heavy)).tracking(1.8)
                    .foregroundStyle(section.hue)
            }
            if !wide.isEmpty {
                VStack(spacing: 10) {
                    ForEach(wide) { metric in
                        counterTile(metric, snapshot: snapshot, now: now, fullWidth: true)
                    }
                }
            }
            if !compact.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(compact) { metric in
                        counterTile(metric, snapshot: snapshot, now: now, fullWidth: false)
                    }
                }
            }
        }
    }

    /// True when the tile renders full grouped digits (a flowing dollar figure) —
    /// these get a full-width row of their own.
    private func isFullDigit(_ metric: DebtClockMetric, snapshot: DebtClockSnapshot) -> Bool {
        guard perSecondRate(metric, snapshot: snapshot) != 0 else { return false }
        switch metric.unit {
        case .dollars, .millionsOfDollars, .billionsOfDollars: return true
        default: return false
        }
    }

    private func counterTile(_ metric: DebtClockMetric,
                             snapshot: DebtClockSnapshot, now: Date,
                             fullWidth: Bool) -> some View {
        let live = liveValue(metric, snapshot: snapshot, now: now)
        let hue = Self.toneColor(metric.tone)
        let flowing = perSecondRate(metric, snapshot: snapshot) != 0
        let isLiveEstimated = metric.isEstimated || flowing
        return VStack(alignment: .leading, spacing: 7) {
            Text(metric.title)
                .font(Kaleido.rounded(11.5, .semibold))
                .foregroundStyle(Hue.label)
                .lineLimit(fullWidth ? 1 : 2, reservesSpace: !fullWidth)
                .fixedSize(horizontal: false, vertical: true)
            // Flowing figures render in FULL digits so the per-second tick is visible
            // (compact "$31.68T" would hide it); static figures keep the compact form.
            Text(tileValue(metric, live: live, flowing: flowing))
                .font(.system(size: fullWidth ? 24 : 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(hue)
                .shadow(color: hue.opacity(0.5), radius: 6)
                .minimumScaleFactor(fullWidth ? 0.6 : 0.45)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text("\(metric.source.name) · \(metric.asOf)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if isLiveEstimated { chip("EST", hue) }
                else if metric.isDerived { chip("DERIVED", hue) }
            }
            .font(Kaleido.rounded(10.5, .regular))
            .foregroundStyle(Hue.sublabel)
        }
        .frame(maxWidth: .infinity, minHeight: fullWidth ? 0 : 92, alignment: .leading)
        .padding(fullWidth ? 14 : 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(hue.opacity(0.22), lineWidth: 1))
        )
    }

    private func chip(_ text: String, _ hue: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Capsule().fill(hue.opacity(0.18)))
            .foregroundStyle(hue)
    }

    private var disclaimer: some View {
        Text("Figures from U.S. Treasury FiscalData, FRED, Census, and BLS public APIs. Ticking values are estimates between official source updates; fixed values show the latest official observation. Not investment advice.")
            .font(Kaleido.rounded(10.5, .regular))
            .foregroundStyle(Hue.sublabel)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    /// Loading state as dim, flickering LED digits — the board warming up, not a
    /// stock spinner. Flicker phase rides the existing 8Hz timeline tick (pure
    /// arithmetic); Reduce Motion holds the digits at a steady dim.
    private func loadingCard(now: Date) -> some View {
        // Semi-irregular flicker: 4Hz phase, dips one beat in three (~0.75s period).
        let flickerDip = !reduceMotion && Int(now.timeIntervalSinceReferenceDate * 4) % 3 == 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("U.S. NATIONAL DEBT")
                .font(Kaleido.rounded(13, .heavy)).tracking(3)
                .foregroundStyle(Hue.debt.opacity(0.45))
            Text("$--,---,---,---,---")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Hue.debt.opacity(flickerDip ? 0.20 : 0.38))
                .shadow(color: Hue.debt.opacity(flickerDip ? 0.10 : 0.28), radius: 12)
                .minimumScaleFactor(0.35)
                .lineLimit(1)
            Text("CONTACTING TREASURY · FRED · CENSUS · BLS")
                .font(Kaleido.rounded(10.5, .bold)).tracking(1.5)
                .foregroundStyle(Hue.sublabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.06, green: 0.02, blue: 0.03).opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Hue.debt.opacity(0.25), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading public fiscal sources.")
    }

    private func errorCard(_ errors: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(Hue.deficit).frame(width: 8, height: 8)
                    .shadow(color: Hue.deficit.opacity(0.8), radius: 4)
                Text("SIGNAL LOST — SOME SOURCES OFFLINE")
                    .font(Kaleido.rounded(12.5, .heavy)).tracking(1.6)
                    .foregroundStyle(Hue.deficit)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            ForEach(errors, id: \.self) { error in
                Text(error)
                    .font(Kaleido.rounded(11.5, .regular))
                    .foregroundStyle(Hue.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.07, green: 0.05, blue: 0.02))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Hue.deficit.opacity(0.35), lineWidth: 1))
        )
    }

    // MARK: - Live value + formatting

    /// Live-ticked value. Figures with a known real growth rate move — the national
    /// debt (from `debtGrowthPerSecond`) and `debtPerCitizen` (live debt ÷ population).
    /// Everything else shows its latest official value. (Codex can widen ticking by
    /// exposing per-metric rates in the model.)
    private func liveValue(_ metric: DebtClockMetric, snapshot: DebtClockSnapshot, now: Date) -> Double {
        let elapsed = max(0, now.timeIntervalSince(snapshot.loadedAt))
        // Debt-per-citizen stays exactly derived (live debt ÷ live population).
        if metric.id == .debtPerCitizen {
            let people = (snapshot.metric(.population)?.value ?? 0) * 1_000
            let debtRate = snapshot.metric(.debtGrowthPerSecond)?.value ?? 0
            if people > 0, let base = snapshot.metric(.totalDebt)?.value {
                return (base + debtRate * elapsed) / people
            }
            return metric.value
        }
        return metric.value + perSecondRate(metric, snapshot: snapshot) * elapsed
    }

    private static let secondsPerYear = 31_557_600.0

    /// Per-second drift used to animate a figure between official refreshes — this is
    /// how usdebtclock keeps counters moving. Debt figures ride the REAL Treasury
    /// growth rate (`debtGrowthPerSecond`), scaled to each figure's share of the total;
    /// other stocks/flows use a per-category nominal annual growth; ratios, indices,
    /// rates, gold reserves, and the cash balance stay put (they don't meaningfully
    /// move second-to-second). Values re-snap to the exact official figure on refresh.
    private func perSecondRate(_ metric: DebtClockMetric, snapshot: DebtClockSnapshot) -> Double {
        let debtRate = snapshot.metric(.debtGrowthPerSecond)?.value ?? 0
        let total = snapshot.metric(.totalDebt)?.value ?? 0
        func debtShare(_ v: Double) -> Double { total > 0 ? debtRate * (v / total) : 0 }

        switch metric.id {
        case .totalDebt:               return debtRate
        case .debtHeldByPublic,
             .intragovernmentalHoldings,
             .debtSubjectToLimit,
             .foreignHeldFederalDebt:  return debtShare(metric.value)
        case .federalDebtFRED:         return debtRate / 1_000_000        // unit: millions
        default: break
        }

        // Non-debt figures: base value × nominal annual growth ÷ seconds/year.
        let annualGrowth: Double
        switch metric.id {
        case .gdp, .personalIncome:                              annualGrowth = 0.045
        case .m2MoneyStock, .fedBalanceSheetAssets:              annualGrowth = 0.030
        case .federalSpending, .federalReceipts,
             .monthlyReceipts, .monthlyOutlays,
             .annualDeficit, .netInterestOutlays, .monthlyDeficit: annualGrowth = 0.050
        case .socialSecurityBenefits, .medicareBenefits:         annualGrowth = 0.055
        case .consumerCredit, .creditCardDebt, .studentLoanDebt,
             .autoLoanDebt, .mortgageDebt:                       annualGrowth = 0.045
        case .spendingPerCitizen, .receiptsPerCitizen, .deficitPerCitizen: annualGrowth = 0.045
        case .population:                                        annualGrowth = 0.005
        case .laborForce, .employedWorkers, .notInLaborForce:    annualGrowth = 0.008
        default:                                                 annualGrowth = 0.0  // ratios, indices, rates, gold, TGA, avg rate, unemployment
        }
        return metric.value * annualGrowth / Self.secondsPerYear
    }

    private func sourceCount(_ snapshot: DebtClockSnapshot) -> String {
        "\(Set(snapshot.metrics.map(\.source.name)).count)"
    }

    private func currency(_ value: Double, fraction: Int) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(fraction)))
    }

    /// Explicit-sign currency for the hero rate readout ("+$79,241" / "−$12,003").
    private func signedCurrency(_ value: Double) -> String {
        value >= 0
            ? "+" + currency(value, fraction: 0)
            : "−" + currency(value.magnitude, fraction: 0)
    }

    /// Value string for a counter tile. Flowing figures use full grouped digits (so
    /// the per-second tick is visible); static figures fall through to compact form.
    private func tileValue(_ metric: DebtClockMetric, live: Double, flowing: Bool) -> String {
        guard flowing else { return formatted(live, unit: metric.unit) }
        switch metric.unit {
        case .dollars:           return currency(live, fraction: 0)
        case .millionsOfDollars: return currency(live * 1_000_000, fraction: 0)
        case .billionsOfDollars: return currency(live * 1_000_000_000, fraction: 0)
        default:                 return formatted(live, unit: metric.unit)
        }
    }

    private func formatted(_ value: Double, unit: DebtClockMetricUnit) -> String {
        switch unit {
        case .dollars:            return compactDollars(value)
        case .dollarsPerSecond:   return currency(value, fraction: 0) + "/sec"
        case .dollarsPerPerson:   return currency(value, fraction: 0)
        case .percent:            return value.formatted(.number.precision(.fractionLength(2))) + "%"
        case .millionsOfDollars:  return compactDollars(value * 1_000_000)
        case .billionsOfDollars:  return compactDollars(value * 1_000_000_000)
        case .index:              return value.formatted(.number.precision(.fractionLength(3)))
        case .thousandsOfPeople:  return compactCount(value * 1_000)
        case .fineTroyOunces:     return compactCount(value) + " oz"
        }
    }

    private func compactDollars(_ dollars: Double) -> String {
        let absValue = dollars.magnitude
        let sign = dollars < 0 ? "-" : ""
        if absValue >= 1_000_000_000_000 {
            return "\(sign)$" + (absValue / 1_000_000_000_000).formatted(.number.precision(.fractionLength(2))) + "T"
        }
        if absValue >= 1_000_000_000 {
            return "\(sign)$" + (absValue / 1_000_000_000).formatted(.number.precision(.fractionLength(1))) + "B"
        }
        if absValue >= 1_000_000 {
            return "\(sign)$" + (absValue / 1_000_000).formatted(.number.precision(.fractionLength(1))) + "M"
        }
        return currency(dollars, fraction: 0)
    }

    private func compactCount(_ count: Double) -> String {
        let absValue = count.magnitude
        let sign = count < 0 ? "-" : ""
        if absValue >= 1_000_000 {
            return sign + (absValue / 1_000_000).formatted(.number.precision(.fractionLength(1))) + "M"
        }
        if absValue >= 1_000 {
            return sign + (absValue / 1_000).formatted(.number.precision(.fractionLength(0))) + "K"
        }
        return count.formatted(.number.precision(.fractionLength(0)))
    }

    // MARK: - Section layout + color coordination (design)

    private struct Section { let title: String; let hue: Color; let ids: [DebtClockMetricID] }
    private static let sections: [Section] = [
        Section(title: "National Debt", hue: Hue.debt,
                ids: [.debtHeldByPublic, .intragovernmentalHoldings, .federalDebtFRED, .debtSubjectToLimit, .foreignHeldFederalDebt]),
        Section(title: "Per Citizen & Ratios", hue: Hue.ratio,
                ids: [.debtPerCitizen, .debtToGDP, .federalDebtToGDP, .averageInterestRate]),
        Section(title: "Treasury & Reserves", hue: Hue.economy,
                ids: [.treasuryGeneralAccount, .goldReserveOunces, .goldReserveBookValue, .fedBalanceSheetAssets]),
        Section(title: "Revenue & Income", hue: Hue.revenue,
                ids: [.federalReceipts, .monthlyReceipts, .receiptsPerCitizen, .receiptsShareOfGDP, .personalIncome]),
        Section(title: "Spending & Deficit", hue: Hue.deficit,
                ids: [.federalSpending, .monthlyOutlays, .spendingPerCitizen, .annualDeficit, .monthlyDeficit, .deficitPerCitizen, .netInterestOutlays]),
        Section(title: "Consumer & Household Debt", hue: Hue.debt,
                ids: [.consumerCredit, .creditCardDebt, .studentLoanDebt, .autoLoanDebt, .mortgageDebt]),
        Section(title: "Benefits", hue: Hue.deficit,
                ids: [.socialSecurityBenefits, .medicareBenefits]),
        Section(title: "Economy & Money", hue: Hue.economy,
                ids: [.gdp, .m2MoneyStock, .cpi]),
        Section(title: "Labor & People", hue: Hue.people,
                ids: [.laborForce, .employedWorkers, .unemployedWorkers, .notInLaborForce, .unemploymentRate, .population])
    ]
}

@MainActor
final class DebtClockStatsStore: ObservableObject {
    @Published private(set) var snapshot: DebtClockSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let client: DebtClockStatsClient
    private let cache: DebtClockSnapshotCache

    init(
        client: DebtClockStatsClient = DebtClockStatsClient(),
        cache: DebtClockSnapshotCache = DebtClockSnapshotCache()
    ) {
        self.client = client
        self.cache = cache
        snapshot = try? cache.load()
    }

    func load() async {
        isLoading = true
        lastError = nil
        let loaded = await client.load()

        if loaded.metrics.isEmpty {
            if snapshot == nil {
                snapshot = loaded
            }
        } else {
            snapshot = loaded
            try? cache.save(loaded)
        }

        if loaded.metrics.isEmpty, !loaded.errors.isEmpty {
            lastError = loaded.errors.joined(separator: "\n")
        }
        isLoading = false
    }
}
