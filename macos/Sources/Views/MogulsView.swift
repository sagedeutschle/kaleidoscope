// PRISM: RELEASE Agent-MacParity/Fable 2026-07-04 — Moguls board macOS mirror of
// ios/Sources/Features/Stats/MogulsView.swift (v2 bench discourse: consensus panel,
// justice cards, jury boxes, voting-rules footnote). macOS adaptations: sheet loses
// presentationDetents/DragIndicator and gains a Done bar + window frame (DecreeDetailView
// house pattern); .preferredColorScheme(.dark) → .environment(\.colorScheme, .dark)
// (DecreeView house pattern); header gains an explicit refresh button (no pull-to-refresh
// on macOS). Store gains isRefreshing for the spinner.
//
// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — "The Moguls" board (Debt Clock lens).
// A live wealth board for the top billionaires + highest-paid CEOs, each vibe-checked
// by the Council of Bots (Claude · Codex · DeepSeek) with a comedic ruling:
// FRAUD! / Aight... / GAMING!!!!  — satire, and labeled as such on the board.
// Serve pattern mirrors the Oracle: bundled snapshot → gist refresh, never blocks.
import SwiftUI

// MARK: - Store

@MainActor
final class MogulStore: ObservableObject {
    @Published private(set) var ledger: MogulLedger?
    @Published private(set) var isRefreshing = false
    /// Once a live board lands, a late bundled/persisted snapshot can't clobber it
    /// (same guard the Oracle uses for its chronicle).
    private var gotLiveBoard = false

    func bootstrap() {
        guard ledger == nil else { return }
        ledger = MogulSource.loadBundled()
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let live = await MogulSource.fetchLatest() {
            gotLiveBoard = true
            ledger = live
        } else if !gotLiveBoard, ledger == nil {
            ledger = MogulSource.loadBundled()
        }
    }
}

// MARK: - Board

/// The Moguls board content. Hosted by `DebtClockStatsView` inside its dark field —
/// this view brings its own scroll + sections but shares the lens's background.
struct MogulBoardView: View {
    @StateObject private var store = MogulStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: Filter = .all
    @State private var selected: Mogul?

    /// Gold-ledger palette on the same dark field as the debt board.
    enum Hue {
        static let gold    = Color(red: 1.00, green: 0.80, blue: 0.32)   // headline gilt
        static let money   = Color(red: 0.36, green: 0.90, blue: 0.52)   // green — net worth
        static let comp    = Color(red: 0.44, green: 0.83, blue: 1.00)   // cyan — salary/comp
        static let fraud   = Color(red: 1.00, green: 0.42, blue: 0.33)   // red — FRAUD!
        static let aight   = Color(red: 1.00, green: 0.68, blue: 0.20)   // amber — Aight...
        static let gaming  = Color(red: 0.36, green: 0.90, blue: 0.52)   // green — GAMING!!!!
        static let label   = Color(white: 0.72)
        static let sublabel = Color(white: 0.5)
    }

    static func verdictColor(_ verdict: MogulVerdict) -> Color {
        switch verdict {
        case .fraud: return Hue.fraud
        case .aight: return Hue.aight
        case .gaming: return Hue.gaming
        }
    }

    enum Filter: String, CaseIterable {
        case all = "ALL"
        case billionaires = "BILLIONAIRES"
        case ceos = "CEOS"

        func admits(_ mogul: Mogul) -> Bool {
            switch self {
            case .all: return true
            case .billionaires: return mogul.category != .ceo
            case .ceos: return mogul.category != .billionaire
            }
        }
    }

    /// Nominal annual drift for the estimated live tick — same trick the debt board
    /// uses for figures without a real per-second source, and labeled EST the same way.
    static let estimatedAnnualGrowth = 0.06
    private static let secondsPerYear = 31_557_600.0

    static func perSecondDrift(_ netWorth: Double) -> Double {
        netWorth * estimatedAnnualGrowth / secondsPerYear
    }

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: 0.12)) { context in
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let ledger = store.ledger, !ledger.moguls.isEmpty {
                        combinedHero(ledger, now: context.date)
                        filterBar
                        boardRows(ledger, now: context.date)
                        disclaimer(ledger)
                    } else {
                        conveningCard(now: context.date)
                    }
                }
                .padding(18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Self-contained dark field: the DebtClock host paints the same gradient,
        // but the board must stay legible anywhere it's rendered (ShotHarness
        // proved white-on-light names vanish without this).
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.05, blue: 0.09),
                         Color(red: 0.02, green: 0.03, blue: 0.06)],
                startPoint: .top, endPoint: .bottom
            )
            .overlay(alignment: .top) {
                RadialGradient(colors: [Hue.gold.opacity(0.08), .clear],
                               center: .top, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
        )
        .environment(\.colorScheme, .dark)
        .task {
            store.bootstrap()
            await store.refresh()
        }
        .sheet(item: $selected) { mogul in
            MogulDetailSheet(mogul: mogul)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("THE MOGULS")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Audited by the Council of Bots · satire")
                    .font(Kaleido.rounded(12, .semibold))
                    .foregroundStyle(Hue.sublabel)
            }
            Spacer()
            if let ledger = store.ledger, !ledger.moguls.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(ledger.moguls.count) moguls").foregroundStyle(Hue.label)
                    Text("as of \(ledger.asOf)").foregroundStyle(Hue.sublabel)
                }
                .font(Kaleido.rounded(11, .semibold))
            }
            refreshControl
        }
    }

    /// Explicit refresh affordance — macOS has no pull-to-refresh gesture, so the
    /// board mirrors the Oracle's refresh button (DecreeView house pattern).
    private var refreshControl: some View {
        Group {
            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Hue.gold)
                }
                .buttonStyle(.plain)
                .help("Reconvene the council — fetch the latest board.")
            }
        }
        .padding(.leading, 6)
    }

    // MARK: Combined ticker hero — the board's one big flowing counter.

    private func combinedHero(_ ledger: MogulLedger, now: Date) -> some View {
        let base = ledger.moguls.compactMap(\.netWorthUSD).reduce(0, +)
        let loaded = loadReference
        let elapsed = max(0, now.timeIntervalSince(loaded))
        let live = reduceMotion ? base : base + Self.perSecondDrift(base) * elapsed
        let gamingCount = ledger.moguls.filter { $0.finalVerdict == .gaming }.count
        let fraudCount = ledger.moguls.filter { $0.finalVerdict == .fraud }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("COMBINED AUDITED FORTUNE")
                .font(Kaleido.rounded(13, .heavy)).tracking(3)
                .foregroundStyle(Hue.gold.opacity(0.95))
            Text(currency(live))
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Hue.gold)
                .shadow(color: Hue.gold.opacity(0.65), radius: 16)
                .minimumScaleFactor(0.35)
                .lineLimit(1)
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Text("▲").font(Kaleido.rounded(10, .heavy)).accessibilityHidden(true)
                    Text("+\(currency(Self.perSecondDrift(base)))/sec").monospacedDigit()
                }
                .foregroundStyle(Hue.money)
                chip("EST", Hue.gold)
                Spacer(minLength: 0)
                Text("\(gamingCount) GAMING · \(fraudCount) FRAUD")
                    .foregroundStyle(Hue.sublabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(Kaleido.rounded(12, .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.06, green: 0.05, blue: 0.02))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Hue.gold.opacity(0.5), lineWidth: 1))
        )
        .shadow(color: Hue.gold.opacity(0.22), radius: 20, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Combined audited fortune, estimated \(currency(live)).")
    }

    /// Stable reference date for the estimated drift (per board appearance).
    @State private var loadReference = Date()

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases, id: \.self) { candidate in
                Button {
                    filter = candidate
                } label: {
                    Text(candidate.rawValue)
                        .font(Kaleido.rounded(11, .heavy)).tracking(1.4)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(
                            Capsule().fill(filter == candidate
                                           ? Hue.gold.opacity(0.20)
                                           : Color.white.opacity(0.05))
                        )
                        .overlay(Capsule().strokeBorder(
                            filter == candidate ? Hue.gold.opacity(0.6) : Color.white.opacity(0.12),
                            lineWidth: 1))
                        .foregroundStyle(filter == candidate ? Hue.gold : Hue.label)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private func boardRows(_ ledger: MogulLedger, now: Date) -> some View {
        let roster = ledger.ranked.filter { filter.admits($0) }
        return VStack(spacing: 10) {
            ForEach(Array(roster.enumerated()), id: \.element.id) { index, mogul in
                Button {
                    selected = mogul
                } label: {
                    MogulRow(rank: index + 1, mogul: mogul)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func conveningCard(now: Date) -> some View {
        let flickerDip = !reduceMotion && Int(now.timeIntervalSinceReferenceDate * 4) % 3 == 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("THE COUNCIL IS CONVENING")
                .font(Kaleido.rounded(13, .heavy)).tracking(3)
                .foregroundStyle(Hue.gold.opacity(0.45))
            Text("$--,---,---,---,---")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Hue.gold.opacity(flickerDip ? 0.20 : 0.38))
                .shadow(color: Hue.gold.opacity(flickerDip ? 0.10 : 0.28), radius: 12)
                .minimumScaleFactor(0.35)
                .lineLimit(1)
            Text("CLAUDE · CODEX · DEEPSEEK — REVIEWING THE LEDGERS")
                .font(Kaleido.rounded(10.5, .bold)).tracking(1.5)
                .foregroundStyle(Hue.sublabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.06, green: 0.05, blue: 0.02).opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Hue.gold.opacity(0.25), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The council is convening. Refresh to try again.")
    }

    private func disclaimer(_ ledger: MogulLedger) -> some View {
        Text("Council verdicts are satire — comedy bits written by AI bots (Claude, Codex, DeepSeek), not factual claims or accusations. Net worth and compensation are public estimates (Forbes, Bloomberg, SEC proxy filings); ticking figures are estimated drift, not live market data.")
            .font(Kaleido.rounded(10.5, .regular))
            .foregroundStyle(Hue.sublabel)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    private func chip(_ text: String, _ hue: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Capsule().fill(hue.opacity(0.18)))
            .foregroundStyle(hue)
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

// MARK: - Row

struct MogulRow: View {
    let rank: Int
    let mogul: Mogul
    private typealias Hue = MogulBoardView.Hue

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rank <= 3 ? Hue.gold : Hue.sublabel)
                .frame(width: 26, alignment: .trailing)

            VStack(alignment: .leading, spacing: 3) {
                Text(mogul.name)
                    .font(Kaleido.rounded(15, .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(mogul.title)
                    .font(Kaleido.rounded(11, .semibold))
                    .foregroundStyle(Hue.sublabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 10) {
                    if let worth = mogul.netWorthUSD {
                        Text(Self.compactDollars(worth))
                            .foregroundStyle(Hue.money)
                    }
                    if let comp = mogul.annualCompUSD {
                        Text("\(Self.compactDollars(comp))/yr")
                            .foregroundStyle(Hue.comp)
                    }
                    // The absurdity chip: boss pay as a multiple of their company's
                    // median worker (Dodd-Frank pay-ratio disclosure).
                    if let ratio = mogul.payRatio {
                        Text("×\(Int(ratio.rounded()).formatted()) their median worker")
                            .font(Kaleido.rounded(10, .heavy))
                            .foregroundStyle(Hue.aight)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Hue.aight.opacity(0.14)))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .font(Kaleido.rounded(13, .heavy))
                .monospacedDigit()
            }

            Spacer(minLength: 8)

            VerdictStamp(verdict: mogul.finalVerdict, compact: true)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(MogulBoardView.verdictColor(mogul.finalVerdict).opacity(0.22), lineWidth: 1))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Shows the council's full audit.")
    }

    private var accessibilitySummary: String {
        var parts = ["Rank \(rank).", mogul.name + ",", mogul.title + "."]
        if let worth = mogul.netWorthUSD { parts.append("Net worth about \(Self.compactDollars(worth)).") }
        if let comp = mogul.annualCompUSD { parts.append("Pay about \(Self.compactDollars(comp)) a year.") }
        parts.append("Council ruling: \(mogul.finalVerdict.stamp)")
        return parts.joined(separator: " ")
    }

    static func compactDollars(_ dollars: Double) -> String {
        let magnitude = dollars.magnitude
        if magnitude >= 1_000_000_000_000 {
            return "$" + (magnitude / 1_000_000_000_000).formatted(.number.precision(.fractionLength(2))) + "T"
        }
        if magnitude >= 1_000_000_000 {
            return "$" + (magnitude / 1_000_000_000).formatted(.number.precision(.fractionLength(1))) + "B"
        }
        if magnitude >= 1_000_000 {
            return "$" + (magnitude / 1_000_000).formatted(.number.precision(.fractionLength(1))) + "M"
        }
        return "$" + magnitude.formatted(.number.precision(.fractionLength(0)))
    }
}

// MARK: - Stamp

/// The council's ruling as a rubber stamp — slight tilt, inked border, all attitude.
struct VerdictStamp: View {
    let verdict: MogulVerdict
    var compact = false

    var body: some View {
        let hue = MogulBoardView.verdictColor(verdict)
        Text(verdict.stamp)
            .font(.system(size: compact ? 12 : 22, weight: .heavy, design: .rounded))
            .tracking(compact ? 0.5 : 1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(hue)
            .padding(.horizontal, compact ? 8 : 16)
            .padding(.vertical, compact ? 4 : 8)
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 6 : 10, style: .continuous)
                    .strokeBorder(hue.opacity(0.8), lineWidth: compact ? 1.5 : 2.5)
            )
            .rotationEffect(.degrees(compact ? -4 : -7))
            .shadow(color: hue.opacity(0.45), radius: compact ? 4 : 10)
            .accessibilityLabel("Council ruling: \(verdict.stamp)")
    }
}

// MARK: - Detail

struct MogulDetailSheet: View {
    let mogul: Mogul
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var opened = Date()
    private typealias Hue = MogulBoardView.Hue

    var body: some View {
        VStack(spacing: 0) {
            // macOS sheets have no drag-to-dismiss — house pattern is an explicit
            // Done bar up top (see DecreeDetailView).
            HStack {
                Text(mogul.category.label.uppercased())
                    .font(Kaleido.rounded(10, .heavy)).tracking(1.6)
                    .foregroundStyle(Hue.gold.opacity(0.8))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            Divider().overlay(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mogul.name)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text(mogul.title)
                                .font(Kaleido.rounded(13, .semibold))
                                .foregroundStyle(Hue.label)
                        }
                        Spacer()
                        VerdictStamp(verdict: mogul.finalVerdict)
                    }

                    if let worth = mogul.netWorthUSD {
                        liveWorthPanel(worth)
                    }
                    if let comp = mogul.annualCompUSD {
                        compRow(comp)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("KNOWN FOR")
                            .font(Kaleido.rounded(11, .heavy)).tracking(2)
                            .foregroundStyle(Hue.sublabel)
                        Text(mogul.knownFor)
                            .font(Kaleido.rounded(14, .regular))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    councilSection

                    Text("Satire: the council's verdicts and quips are comedy written by AI bots, not factual claims. Figures: \(mogul.source).")
                        .font(Kaleido.rounded(10.5, .regular))
                        .foregroundStyle(Hue.sublabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 480, idealHeight: 660)
        .background(
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.09),
                                    Color(red: 0.02, green: 0.03, blue: 0.06)],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
        .environment(\.colorScheme, .dark)
    }

    /// The full-digit flowing counter — the wealth ticking in real time (estimated).
    private func liveWorthPanel(_ worth: Double) -> some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(opened))
            let drift = MogulBoardView.perSecondDrift(worth)
            let live = reduceMotion ? worth : worth + drift * elapsed
            VStack(alignment: .leading, spacing: 10) {
                Text("ESTIMATED NET WORTH")
                    .font(Kaleido.rounded(12, .heavy)).tracking(2.6)
                    .foregroundStyle(Hue.money.opacity(0.9))
                Text(live.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Hue.money)
                    .shadow(color: Hue.money.opacity(0.6), radius: 14)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("▲ +\(drift.formatted(.currency(code: "USD").precision(.fractionLength(0))))/sec")
                        .font(Kaleido.rounded(12, .bold))
                        .monospacedDigit()
                        .foregroundStyle(Hue.money.opacity(0.85))
                    Text("EST")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Hue.money.opacity(0.18)))
                        .foregroundStyle(Hue.money)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.02, green: 0.06, blue: 0.03))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Hue.money.opacity(0.45), lineWidth: 1))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Estimated net worth \(MogulRow.compactDollars(worth)), drifting up an estimated \(MogulRow.compactDollars(drift)) per second.")
        }
    }

    /// Comp panel. With a disclosed median-worker figure it becomes the absurdity
    /// exhibit: boss pay vs. their median worker, multiplier front and center.
    private func compRow(_ comp: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("ANNUAL COMP")
                    .font(Kaleido.rounded(11, .heavy)).tracking(2)
                    .foregroundStyle(Hue.comp.opacity(0.8))
                Spacer()
                Text(MogulRow.compactDollars(comp) + (mogul.compYear.map { " (\($0))" } ?? ""))
                    .font(Kaleido.rounded(16, .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Hue.comp)
            }
            if let worker = mogul.medianWorkerPayUSD, let ratio = mogul.payRatio {
                Divider().overlay(Color.white.opacity(0.1))
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("THEIR MEDIAN WORKER")
                            .font(Kaleido.rounded(9.5, .heavy)).tracking(1.4)
                            .foregroundStyle(Hue.sublabel)
                        Text(MogulRow.compactDollars(worker) + "/yr")
                            .font(Kaleido.rounded(15, .heavy))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("×\(Int(ratio.rounded()).formatted())")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Hue.aight)
                            .shadow(color: Hue.aight.opacity(0.55), radius: 10)
                        Text("THE RATIO")
                            .font(Kaleido.rounded(9.5, .heavy)).tracking(1.6)
                            .foregroundStyle(Hue.aight.opacity(0.7))
                    }
                }
                Text("A median employee would need \(Int(ratio.rounded()).formatted()) years on the job to earn the boss's \(mogul.compYear.map(String.init) ?? "annual") package.")
                    .font(Kaleido.rounded(12, .regular))
                    .italic()
                    .foregroundStyle(Hue.sublabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Hue.comp.opacity(0.25), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var councilSection: some View {
        if let bench = mogul.bench {
            benchSection(bench)
        } else {
            flatCouncilSection
        }
    }

    // MARK: The bench (Council v2) — full discourse

    private func benchSection(_ bench: MogulBench) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let consensus = mogul.consensus {
                consensusPanel(consensus)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("THE JUSTICES")
                    .font(Kaleido.rounded(11, .heavy)).tracking(2)
                    .foregroundStyle(Hue.gold.opacity(0.85))
                ForEach(bench.justices, id: \.self) { justice in
                    justiceCard(justice)
                }
            }

            ForEach(bench.juries, id: \.self) { jury in
                juryBox(jury)
            }

            Text("How the bench votes: two Justices and two juries hold one seat each — a jury's seat goes to the majority of its three jurors (a full split hangs the jury). Three of four seats rule; on a tie, Justices who agree prevail; if the Justices split too, the vibe is officially mid.")
                .font(Kaleido.rounded(10.5, .regular))
                .foregroundStyle(Hue.sublabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The court reporter's synthesis — the headline of the discourse.
    private func consensusPanel(_ consensus: String) -> some View {
        let hue = MogulBoardView.verdictColor(mogul.finalVerdict)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Hue.gold)
                    .accessibilityHidden(true)
                Text("THE COUNCIL'S CONSENSUS")
                    .font(Kaleido.rounded(11, .heavy)).tracking(2)
                    .foregroundStyle(Hue.gold.opacity(0.9))
            }
            Text(consensus)
                .font(Kaleido.rounded(14, .regular))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            if let summary = mogul.voteSummary {
                Text(summary.uppercased())
                    .font(Kaleido.rounded(10, .heavy)).tracking(1.2)
                    .foregroundStyle(hue.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Hue.gold.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Hue.gold.opacity(0.4), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }

    /// A Justice's seat: bigger card, written opinion.
    private func justiceCard(_ justice: JusticeOpinion) -> some View {
        let hue = MogulBoardView.verdictColor(justice.verdict)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: Self.icon(for: justice.councilor))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(hue)
                    .accessibilityHidden(true)
                Text("\(justice.councilor.uppercased()), J.")
                    .font(Kaleido.rounded(13, .heavy)).tracking(1.4)
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(justice.verdict.stamp)
                    .font(Kaleido.rounded(12, .heavy))
                    .foregroundStyle(hue)
            }
            Text(justice.opinion)
                .font(Kaleido.rounded(13.5, .regular))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(hue.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(hue.opacity(0.35), lineWidth: 1.2))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Justice \(justice.councilor) rules \(justice.verdict.stamp): \(justice.opinion)")
    }

    /// A mini-jury's box: three persona rows + the seat it returns.
    private func juryBox(_ jury: MogulJury) -> some View {
        let hue = MogulBoardView.verdictColor(jury.juryVerdict)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(hue.opacity(0.9))
                    .accessibilityHidden(true)
                Text(jury.name.uppercased())
                    .font(Kaleido.rounded(11.5, .heavy)).tracking(1.6)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("RETURNS: \(jury.juryVerdict.stamp)")
                    .font(Kaleido.rounded(10.5, .heavy))
                    .foregroundStyle(hue)
            }
            ForEach(jury.jurors, id: \.self) { juror in
                jurorRow(juror)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(hue.opacity(0.25), lineWidth: 1))
        )
    }

    private func jurorRow(_ juror: JurorVote) -> some View {
        let hue = MogulBoardView.verdictColor(juror.verdict)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(juror.persona)
                    .font(Kaleido.rounded(12, .heavy))
                    .foregroundStyle(hue.opacity(0.95))
                Spacer()
                Text(juror.verdict.stamp)
                    .font(Kaleido.rounded(10, .heavy))
                    .foregroundStyle(hue.opacity(0.85))
            }
            Text("“\(juror.quip)”")
                .font(Kaleido.rounded(12.5, .regular))
                .italic()
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(juror.persona) votes \(juror.verdict.stamp): \(juror.quip)")
    }

    // MARK: v1 fallback — flat council list

    private var flatCouncilSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THE COUNCIL'S AUDIT")
                .font(Kaleido.rounded(11, .heavy)).tracking(2)
                .foregroundStyle(Hue.gold.opacity(0.85))
            if mogul.council.isEmpty {
                Text("The council abstained. Suspicious… or shy.")
                    .font(Kaleido.rounded(13, .regular))
                    .foregroundStyle(Hue.sublabel)
            } else {
                ForEach(mogul.council, id: \.self) { opinion in
                    councilCard(opinion)
                }
            }
        }
    }

    private func councilCard(_ opinion: CouncilOpinion) -> some View {
        let hue = MogulBoardView.verdictColor(opinion.verdict)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: Self.icon(for: opinion.councilor))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(hue)
                    .accessibilityHidden(true)
                Text(opinion.councilor.uppercased())
                    .font(Kaleido.rounded(12, .heavy)).tracking(1.4)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(opinion.verdict.stamp)
                    .font(Kaleido.rounded(11, .heavy))
                    .foregroundStyle(hue)
            }
            Text("“\(opinion.quip)”")
                .font(Kaleido.rounded(13.5, .regular))
                .italic()
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(hue.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(hue.opacity(0.3), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(opinion.councilor) rules \(opinion.verdict.stamp): \(opinion.quip)")
    }

    static func icon(for councilor: String) -> String {
        switch councilor.lowercased() {
        case "claude", "opus": return "sparkle"
        case "codex", "gpt-5.5": return "chevron.left.forwardslash.chevron.right"
        case "deepseek": return "water.waves"
        default: return "cpu"
        }
    }
}

#Preview {
    MogulBoardView().frame(width: 760, height: 740)
}
