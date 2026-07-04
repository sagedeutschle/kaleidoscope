import SwiftUI

// PRISM: RELEASE Agent-A 2026-06-27 — Oracle now on real parchment texture (CC-BY, see docs/ASSET_ATTRIBUTIONS.md)

/// The Wizard King's Decree — a native chronicle of a model council's no-hedge
/// prophecies and their self-graded reckonings. Starts from a bundled snapshot
/// (`decrees.json`) and can live-refresh from archbox via `DecreeStore`. Self-
/// contained royal/parchment styling, independent of the chess `Theme`.
struct DecreeView: View {
    @StateObject private var store = DecreeStore()
    @StateObject private var archive = DecreeArchive()
    private var chronicle: DecreeChronicle { store.chronicle }
    @State private var selectedDecree: Decree?
    @State private var tab: OracleTab = .standing
    @State private var searchText = ""
    @State private var sort: DecreeSort = .expirationSoon

    private let parchment = Color(red: 0.96, green: 0.93, blue: 0.85)
    private let ink = Color(red: 0.20, green: 0.16, blue: 0.12)
    private let gold = Color(red: 0.72, green: 0.56, blue: 0.20)

    /// The Oracle's three ledgers. Kept congruent with the iOS app.
    private enum OracleTab: String, CaseIterable, Identifiable {
        case standing = "Standing"
        case archives = "Archives"
        case divided = "Divided"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                tabPicker
                if tab != .divided { searchSortBar }
                tabContent
                footer
            }
            .padding(22)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(parchmentBackground)
        .environment(\.colorScheme, .light)
        .sheet(item: $selectedDecree) { DecreeDetailView(decree: $0) }
        .task { await store.refreshIfNeeded() }
        // Fold every ruling seen into the permanent Archives (never forgotten).
        .onChange(of: store.chronicle, initial: true) { _, fresh in archive.absorb(fresh) }
    }

    // MARK: - Tabs

    // Book-cover leather for unselected ledger tabs (mirrors iOS OracleTheme).
    private let leather = Color(red: 0.27, green: 0.20, blue: 0.13)
    private let leatherEdge = Color(red: 0.42, green: 0.33, blue: 0.21)
    private let leatherInk = Color(red: 0.85, green: 0.77, blue: 0.62)

    private var bookTabShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 0,
                               bottomTrailingRadius: 0, topTrailingRadius: 9,
                               style: .continuous)
    }

    /// Three book-tab chips over a gilt spine rule — the illuminated-ledger look
    /// mirrored from iOS (replaces the plain segmented picker).
    private var tabPicker: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(OracleTab.allCases) { t in
                let selected = tab == t
                Button {
                    guard tab != t else { return }
                    withAnimation(.snappy(duration: 0.22)) { tab = t }
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 14, weight: selected ? .bold : .semibold, design: .serif))
                        .tracking(0.6)
                        .foregroundStyle(selected ? ink : leatherInk)
                        .frame(maxWidth: .infinity)
                        .padding(.top, selected ? 10 : 8)
                        .padding(.bottom, selected ? 11 : 8)
                        .background(
                            bookTabShape.fill(
                                selected
                                ? AnyShapeStyle(LinearGradient(colors: [parchment, parchment.opacity(0.82)],
                                                               startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(leather)
                            )
                        )
                        .overlay(
                            bookTabShape.strokeBorder(selected ? gold.opacity(0.55) : leatherEdge, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(t.rawValue) ledger")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(gold.opacity(0.55))
                .frame(height: 1.5)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 2)
    }

    /// Free-text search + a sort menu (default: soonest expiration first).
    private var searchSortBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(ink.opacity(0.5))
                TextField("Search decrees", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(ink.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(gold.opacity(0.4), lineWidth: 1))

            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(DecreeSort.allCases) { option in
                        Label(option.label, systemImage: option.systemImage).tag(option)
                    }
                }
            } label: {
                Label(sort.label, systemImage: "arrow.up.arrow.down")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(gold)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    @ViewBuilder private var tabContent: some View {
        switch tab {
        case .standing:  standingList
        case .archives:  archivesList
        case .divided:   dividedTab
        }
    }

    /// Live prophecies the Court Historian hasn't ruled on yet.
    @ViewBuilder private var standingList: some View {
        let items = chronicle.decrees.filter { $0.isStanding }
            .searchedAndSorted(query: searchText, by: sort)
        if items.isEmpty {
            if searchText.isEmpty {
                tabEmpty("No prophecies stand", "The King has no open decrees right now. Refresh the chronicle from the court.")
            } else {
                tabEmpty("No matches", "No standing decree matches “\(searchText)”.")
            }
        } else {
            ForEach(items) { decreeCard($0) }
        }
    }

    /// The Oracle's Archives — the PERMANENT record of every decree the Court
    /// Historian has ever ruled on, kept locally forever even if the live chronicle
    /// drops it. Split into the King's vindications and the record he had to correct.
    @ViewBuilder private var archivesList: some View {
        let vindicated = archive.decrees.filter { $0.isVindicated }
            .searchedAndSorted(query: searchText, by: sort)
        let corrected  = archive.decrees.filter { $0.isCorrected }
            .searchedAndSorted(query: searchText, by: sort)
        if vindicated.isEmpty && corrected.isEmpty {
            if searchText.isEmpty {
                tabEmpty("The archives are empty",
                         "No decree has been ruled yet. Once the Court Historian speaks, every vindication and correction is kept here forever.")
            } else {
                tabEmpty("No matches", "No archived decree matches “\(searchText)”.")
            }
        } else {
            if !vindicated.isEmpty {
                reckoningHeading("⚜︎ Vindicated", "The King was right.", .green)
                ForEach(vindicated) { decreeCard($0) }
            }
            if !corrected.isEmpty {
                reckoningHeading("🙇 Corrected", "The King had to walk it back.", .red)
                ForEach(corrected) { decreeCard($0) }
            }
        }
    }

    /// Matters on which the council could not agree.
    @ViewBuilder private var dividedTab: some View {
        if chronicle.divided.isEmpty {
            tabEmpty("The council was never divided", "Every matter reached a verdict worth decreeing.")
        } else {
            dividedLedger
        }
    }

    private func reckoningHeading(_ title: String, _ subtitle: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline.weight(.bold)).foregroundStyle(color)
            Text(subtitle).font(.caption).foregroundStyle(ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func tabEmpty(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.headline).foregroundStyle(ink.opacity(0.75))
            Text(subtitle).font(.callout).foregroundStyle(ink.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    // MARK: - Parchment page

    /// A real photographed parchment sheet (public-domain/CC-BY) washed with the
    /// warm parchment tone so the King's chronicle reads on genuine vellum.
    private var parchmentBackground: some View {
        Image("oracle_parchment")
            .resizable()
            .scaledToFill()
            .overlay(parchment.opacity(0.24))
            .clipped()
            .ignoresSafeArea()
    }

    // MARK: - Header & record

    private var header: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Text("👑 The Wizard King's Decree")
                    .font(.system(.largeTitle, design: .serif).weight(.bold))
                    .foregroundStyle(ink)
                    .frame(maxWidth: .infinity)
                refreshControl
            }
            Text("A council of chat models, forced to commit. Every prophecy is graded against reality — vindication, or a groveling royal apology.")
                .font(.callout)
                .foregroundStyle(ink.opacity(0.7))
                .multilineTextAlignment(.center)
            recordStrip
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(parchment)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(gold.opacity(0.55), lineWidth: 1.5))
        )
    }

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
                        .foregroundStyle(gold)
                }
                .buttonStyle(.plain)
                .help("Refresh the chronicle from the King's court.")
            }
        }
    }

    private var recordStrip: some View {
        let r = chronicle.record
        // Standing / Divided are inherently "current" (the live chronicle). Vindicated,
        // Corrected and Hit rate are the ALL-TIME record, sourced from the permanent
        // Archives so this summary can never contradict the Archives tab.
        let av = archive.decrees.filter { $0.isVindicated }.count
        let ac = archive.decrees.filter { $0.isCorrected }.count
        let hit: Double? = (av + ac) > 0 ? Double(av) / Double(av + ac) : nil
        return HStack(spacing: 14) {
            stat("\(r.standing)", "Standing", .blue)
            stat("\(av)", "Vindicated", .green)
            stat("\(ac)", "Corrected", .red)
            stat("\(r.divided)", "Divided", .gray)
            stat(hit.map { String(format: "%.0f%%", $0 * 100) } ?? "—", "Hit rate", gold)
        }
        .padding(.top, 4)
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(ink.opacity(0.6))
        }
        .frame(minWidth: 62)
    }

    // MARK: - Decree card

    private func decreeCard(_ d: Decree) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                tierBadge(d.tier)
                Spacer()
                Text(domainLabel(d.domain))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ink.opacity(0.55))
            }
            Text(d.regal.isEmpty ? d.claim : d.regal)
                .font(.system(.body, design: .serif).italic())
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            if let correction = d.correction, !correction.isEmpty {
                Text(correction)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
            }
            HStack(spacing: 14) {
                Label("Resolves \(d.resolves)", systemImage: "calendar")
                if d.isAwaitingRuling() {
                    Label("awaiting ruling", systemImage: "hourglass")
                        .foregroundStyle(.orange)
                        .help("The resolution date has passed; the Court Historian hasn't graded it yet.")
                } else {
                    Label(String(format: "privately %.0f%%", d.confidence * 100), systemImage: "lock")
                        .help("The council's true private probability — the public decree is absolute regardless.")
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ink.opacity(0.4))
            }
            .font(.caption)
            .foregroundStyle(ink.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color.white.opacity(0.60),
                                              parchment.opacity(0.55)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tierColor(d.tier).opacity(0.35), lineWidth: 1))
                // Illuminated-manuscript double rule: a gilt hairline inset inside
                // the tier border (mirrors the iOS Oracle proclamation frame).
                .overlay(RoundedRectangle(cornerRadius: 11)
                    .inset(by: 4)
                    .strokeBorder(gold.opacity(0.45), lineWidth: 0.75))
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedDecree = d }
    }

    // MARK: - Divided ledger

    private var dividedLedger: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⚖️ The Divided Ledger")
                .font(.headline.weight(.bold))
                .foregroundStyle(ink.opacity(0.8))
            Text("Matters on which the council could not agree — the King held his tongue.")
                .font(.caption).foregroundStyle(ink.opacity(0.6))
            ForEach(chronicle.divided) { m in
                HStack {
                    Image(systemName: "circle.dotted")
                    Text(m.title)
                    Spacer()
                    Text(m.resolves).foregroundStyle(ink.opacity(0.5))
                }
                .font(.callout)
                .foregroundStyle(ink.opacity(0.75))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08)))
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if let status = store.statusMessage {
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            Text("Snapshot generated \(chronicle.generated) · self-grades via the Court Historian")
                .font(.caption2)
                .foregroundStyle(ink.opacity(0.45))
        }
        .padding(.top, 4)
    }

    // MARK: - Tier styling

    private func tierBadge(_ tier: String) -> some View {
        Text(tierLabel(tier))
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(tierColor(tier)))
    }

    private func tierLabel(_ tier: String) -> String {
        switch tier {
        case "standing": return "⚖︎ STANDING"
        case "vindicated": return "⚜︎ VINDICATED"
        case "cliffnotes": return "✎ CLIFFNOTES"
        case "apology": return "🙇 APOLOGY"
        case "cancellation", "cancelled": return "🚫 CANCELLED"
        default: return tier.uppercased()
        }
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "vindicated": return .green
        case "apology": return .red
        case "cliffnotes": return .orange
        case "cancellation", "cancelled": return .gray
        default: return .blue  // standing
        }
    }

    private func domainLabel(_ d: String) -> String {
        d.replacingOccurrences(of: "-", with: " ").uppercased()
    }
}

#Preview {
    DecreeView().frame(width: 760, height: 740)
}
