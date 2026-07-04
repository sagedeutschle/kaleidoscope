// PRISM: RELEASE Agent-Design(oracle) 2026-07-03 - v10 design pass
import SwiftUI

// MARK: - Oracle — The Illuminated Ledger

/// FACET Oracle — the Wizard King's Decree.
/// A lore/curio facet (not a scored game): consult a kaleidoscope Oracle and
/// receive a random royal decree on a parchment proclamation, wax-sealed.
/// The parchment is its own world: deliberately light paper regardless of the
/// global theme, so the ledger glows against the dark shell.
struct OracleView: View {
    private let accent = Kaleido.gold
    private let accountID: UUID?
    @StateObject private var persistence = PersistedGameSession<OracleSnapshot>(gameID: .oracle)
    @StateObject private var archive = DecreeArchive()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The view owns its model.
    @State private var chronicle = DecreeChronicle.empty
    @State private var loaded = false
    @State private var hasRefreshed = false     // fetched the live chronicle once this appearance
    @State private var gotLiveChronicle = false // a live fetch won — don't let a stale snapshot clobber it

    @State private var current: Decree?
    @State private var consultCount: Int = 0
    @State private var spin: Double = 0
    @State private var showDraw = false   // presents the drawn decree, exitable to the list
    @State private var readerRevealed = false

    @State private var rng = SeededGenerator(seed: 0xACE_0F_DEC_4EE)

    /// The Oracle's three ledgers. Kept congruent with the macOS app.
    private enum OracleTab: String, CaseIterable, Identifiable {
        case standing = "Standing"
        case archives = "Archives"
        case divided = "Divided"
        var id: String { rawValue }
    }
    @State private var tab: OracleTab = .standing
    @State private var searchText = ""
    @State private var sort: DecreeSort = .expirationSoon

    private var standingDecrees: [Decree] {
        chronicle.decrees.filter { $0.isStanding }.searchedAndSorted(query: searchText, by: sort)
    }
    // Archives read from the PERMANENT local store, not the live chronicle, so a
    // ruling is never forgotten once seen.
    private var vindicatedDecrees: [Decree] {
        archive.decrees.filter { $0.isVindicated }.searchedAndSorted(query: searchText, by: sort)
    }
    private var correctedDecrees: [Decree] {
        archive.decrees.filter { $0.isCorrected }.searchedAndSorted(query: searchText, by: sort)
    }

    /// All-time hit rate from the permanent archive: vindicated ÷ ruled.
    private var archiveHitRate: Double? {
        let v = archive.decrees.filter { $0.isVindicated }.count
        let ruled = v + archive.decrees.filter { $0.isCorrected }.count
        return ruled > 0 ? Double(v) / Double(ruled) : nil
    }

    /// The pool the "Consult" draw pulls from — whatever prophecies are on view.
    private var drawPool: [Decree] {
        switch tab {
        case .standing:  return standingDecrees
        case .archives:  return vindicatedDecrees + correctedDecrees
        case .divided:   return []
        }
    }

    init(accountID: UUID? = nil) {
        self.accountID = accountID
    }

    var body: some View {
        VStack(spacing: 16) {
            GameHeader(
                title: "Oracle",
                systemImage: "sparkles",
                accent: accent,
                subtitle: "The Wizard King's Decree"
            ) {
                StatBadge(
                    label: "Hit Rate",
                    value: "\(Int((archiveHitRate ?? 0) * 100))%",
                    accent: accent
                )
                StatBadge(
                    label: "Decrees",
                    value: "\(chronicle.record.total)",
                    accent: accent
                )
            }

            // Consult control — a compact iris + a button that draws a random decree
            // from the ledger on view and presents it in an exitable reader.
            HStack(spacing: 16) {
                oracleIris(diameter: 66)
                Button {
                    consult()
                } label: {
                    Text("Consult the Oracle")
                }
                .buttonStyle(OracleConsultStyle())
                .disabled(drawPool.isEmpty)
            }

            // Three ledgers: live prophecies, the reckoning, and the divided matters.
            VStack(spacing: 10) {
                ledgerTabs
                if tab != .divided { searchSortBar }

                // Tap any card to read it; the random draw opens the same reader, which
                // is dismissible back to whichever ledger is on view.
                tabContent
            }
        }
        .padding(20)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .facetBackground(accent, multiHue: true)
        .navigationTitle("Oracle")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refreshFromCloud() }
        .sheet(isPresented: $showDraw) { drawReader }
        .sensoryFeedback(.impact(weight: .light), trigger: consultCount)
        .sensoryFeedback(.success, trigger: current?.id)
        .onAppear {
            persistence.configure(accountID: accountID, cloudStore: .shared) { restore($0) }
            guard !loaded else { return }
            chronicle = DecreeChronicle.loadBundled()
            loaded = true
            save()
        }
        // Pull the live chronicle once per appearance (published daily from the
        // source laptop). Runs after first paint, so the bundled snapshot shows
        // instantly and the live copy folds in when it arrives.
        .task {
            guard !hasRefreshed else { return }
            hasRefreshed = true
            await refreshFromCloud()
        }
        // Fold every ruling seen into the permanent Archives (never forgotten).
        .onChange(of: chronicle, initial: true) { _, fresh in archive.absorb(fresh) }
        .onDisappear { save(forceCloud: true) }
    }

    // MARK: Ledger tabs

    /// Three book-tab chips over a gilt spine rule — same selection binding the
    /// segmented picker drove, restyled as tabs on the ledger itself.
    private var ledgerTabs: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(OracleTab.allCases) { t in
                let selected = tab == t
                Button {
                    guard tab != t else { return }
                    if reduceMotion {
                        tab = t
                    } else {
                        withAnimation(.snappy(duration: 0.22)) { tab = t }
                    }
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 14, weight: selected ? .bold : .semibold, design: .serif))
                        .tracking(0.6)
                        .foregroundStyle(selected ? OracleTheme.ink : OracleTheme.leatherInk)
                        .frame(maxWidth: .infinity)
                        .padding(.top, selected ? 10 : 8)
                        .padding(.bottom, selected ? 11 : 8)
                        .background(
                            bookTabShape.fill(
                                selected
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [OracleTheme.paper, OracleTheme.paperAged],
                                    startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(OracleTheme.leather)
                            )
                        )
                        .overlay(
                            bookTabShape.strokeBorder(
                                selected ? OracleTheme.paperEdge : OracleTheme.leatherEdge,
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(t.rawValue) ledger")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(OracleTheme.gilt.opacity(0.55))
                .frame(height: 1.5)
                .accessibilityHidden(true)
        }
    }

    private var bookTabShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 9, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: 9,
            style: .continuous
        )
    }

    // MARK: Search + sort (inset-paper chrome)

    /// Free-text search + a sort menu (default: soonest expiration first).
    private var searchSortBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OracleTheme.ink3)
                TextField("Search decrees", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(OracleTheme.ink)
                    .tint(OracleTheme.gilt)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(OracleTheme.ink3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(insetPaper(cornerRadius: 10))

            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(DecreeSort.allCases) { option in
                        Label(option.label, systemImage: option.systemImage).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OracleTheme.ink2)
                    .frame(width: 44, height: 44)
                    .background(insetPaper(cornerRadius: 10))
            }
            .accessibilityLabel("Sort decrees")
        }
    }

    /// A field pressed into the paper — inner shadow, aged fill, paper edge.
    private func insetPaper(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(OracleTheme.paperAged.shadow(.inner(
                color: OracleTheme.ink.opacity(0.22), radius: 2, x: 0, y: 1.2)))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(OracleTheme.paperEdge, lineWidth: 1)
            )
    }

    // MARK: Ledgers (tab content)

    @ViewBuilder private var tabContent: some View {
        switch tab {
        case .standing:
            decreeScroll(standingDecrees,
                         emptyTitle: searchText.isEmpty ? "No prophecies stand" : "No matches",
                         emptyBody: searchText.isEmpty
                            ? "The Oracle has no open decrees right now."
                            : "No standing decree matches “\(searchText)”.")
        case .archives:
            archivesScroll
        case .divided:
            dividedScroll
        }
    }

    @ViewBuilder private func decreeScroll(_ items: [Decree],
                                           emptyTitle: String, emptyBody: String) -> some View {
        if items.isEmpty {
            emptyState(emptyTitle, emptyBody)
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(items, id: \.id) { decree in
                        Button { present(decree) } label: { decreeCard(decree) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .kaleidoCard()
        }
    }

    /// The Oracle's Archives — the PERMANENT record of every ruling ever seen, kept
    /// locally forever, split into vindications and corrections.
    @ViewBuilder private var archivesScroll: some View {
        if vindicatedDecrees.isEmpty && correctedDecrees.isEmpty {
            emptyState(searchText.isEmpty ? "The archives are empty" : "No matches",
                       searchText.isEmpty
                        ? "No decree has been ruled yet. Once the Oracle's word is graded it is kept here forever — vindicated, or corrected."
                        : "No archived decree matches “\(searchText)”.")
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !vindicatedDecrees.isEmpty {
                        reckoningHeading("Vindicated", "The Oracle was right.",
                                         OracleTheme.laurelOnShell)
                        ForEach(vindicatedDecrees, id: \.id) { decree in
                            Button { present(decree) } label: { decreeCard(decree) }
                                .buttonStyle(.plain)
                        }
                    }
                    if !correctedDecrees.isEmpty {
                        reckoningHeading("Corrected", "The Oracle had to walk it back.",
                                         OracleTheme.ochreOnShell)
                        ForEach(correctedDecrees, id: \.id) { decree in
                            Button { present(decree) } label: { decreeCard(decree) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .kaleidoCard()
        }
    }

    @ViewBuilder private var dividedScroll: some View {
        if chronicle.divided.isEmpty {
            emptyState("The council was never divided",
                       "Every matter reached a verdict worth decreeing.")
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chronicle.divided) { dividedCard($0) }
                }
                .padding(.vertical, 4)
            }
            .kaleidoCard()
        }
    }

    /// Section header as an ink stamp (replaces the emoji headings).
    /// Sits on the shell panel, so it takes the paper-aware ink shades.
    private func reckoningHeading(_ title: String, _ subtitle: String, _ inkColor: Color) -> some View {
        HStack(alignment: .center, spacing: 10) {
            stamp(title, ink: inkColor)
            Text(subtitle)
                .font(.system(size: 12, design: .serif).italic())
                .foregroundStyle(Kaleido.ink2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }

    private func dividedCard(_ matter: DividedMatter) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(OracleTheme.gilt)
                .accessibilityHidden(true)
            Text(matter.title)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(OracleTheme.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(matter.resolves)
                .font(.system(size: 12, design: .serif))
                .monospacedDigit()
                .foregroundStyle(OracleTheme.ink3)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [OracleTheme.paper, OracleTheme.paperAged],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(OracleTheme.paperEdge, lineWidth: 1)
                )
        )
        .padding(.horizontal, 2)
    }

    // MARK: Oracle iris

    private func oracleIris(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: Kaleido.wheel + [Kaleido.wheel.first ?? accent],
                        center: .center
                    )
                )
                .rotationEffect(.degrees(spin))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Kaleido.ground.opacity(0.0), Kaleido.ground.opacity(0.55)],
                        center: .center,
                        startRadius: diameter * 0.05,
                        endRadius: diameter * 0.5
                    )
                )

            Circle()
                .fill(Kaleido.panel.opacity(0.85))
                .frame(width: diameter * 0.34, height: diameter * 0.34)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: diameter * 0.14, weight: .bold))
                        .foregroundStyle(accent)
                )

            Circle()
                .strokeBorder(accent, lineWidth: 3)

            Circle()
                .strokeBorder(accent.opacity(0.35), lineWidth: 8)
                .blur(radius: 4)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: accent.opacity(0.4), radius: 18)
        .accessibilityHidden(true)
    }

    // MARK: Empty state

    private func emptyState(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 12) {
            waxSeal(diameter: 38)
                .opacity(0.9)
            Text(title)
                .font(Kaleido.title(20))
                .foregroundStyle(Kaleido.ink)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(Kaleido.ink2)
                .multilineTextAlignment(.center)
            ornamentalRule
                .frame(width: 140)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
    }

    // MARK: The proclamation (decree card)

    /// The signature: a wax-sealed parchment proclamation. Own-world light paper
    /// regardless of the global theme — it must glow against the dark shell.
    private func decreeCard(_ decree: Decree) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Scribe's reference line — trailing padding leaves room for the seal.
            Text(decree.title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .tracking(1.6)
                .foregroundStyle(OracleTheme.ink3)
                .lineLimit(1)
                .padding(.trailing, 48)

            // The proclamation itself.
            Text(decree.regal)
                .font(Kaleido.title(20))
                .foregroundStyle(OracleTheme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 40)

            ornamentalRule

            // The falsifiable claim — readable body, generous leading.
            Text(decree.claim)
                .font(.system(size: 17, design: .serif))
                .lineSpacing(4)
                .foregroundStyle(OracleTheme.ink2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // The Court Historian's ruling, in the appropriate ink.
            if let verdict = decree.verdict, !verdict.isEmpty {
                Text(verdict)
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundStyle(decree.isVindicated ? OracleTheme.laurel
                                     : decree.isCorrected ? OracleTheme.ochre
                                     : OracleTheme.gilt)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if decree.isVindicated {
                stamp("Vindicated", ink: OracleTheme.laurel)
            } else if decree.isCorrected {
                stamp(decree.tier.capitalized, ink: OracleTheme.ochre)
            } else if decree.isAwaitingRuling() {
                stamp("Awaiting Ruling", ink: OracleTheme.gilt)
            }

            // Meta row: domain · resolves-by · confidence sigil.
            HStack(spacing: 7) {
                metaLabel(decree.domain)
                metaDot
                metaLabel(resolveLabel(decree))
                metaDot
                confidenceSigil(decree.confidence)
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(parchmentBackground)
        .overlay(alignment: .topTrailing) {
            waxSeal(diameter: 40)
                .padding(.top, 12)
                .padding(.trailing, 14)
        }
        .padding(.horizontal, 2)
    }

    private var parchmentBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [OracleTheme.paper, OracleTheme.paperAged],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(OracleTheme.paperEdge, lineWidth: 1)
            )
            .overlay(
                // Inner hairline frame — the illuminated-manuscript double rule.
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(OracleTheme.ink.opacity(0.10), lineWidth: 1)
                    .padding(5)
            )
            .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
    }

    /// Deep-crimson wax seal with an embossed crown — the card's signature mark.
    private func waxSeal(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [OracleTheme.sealHighlight, OracleTheme.sealCrimson, OracleTheme.sealDeep],
                        center: UnitPoint(x: 0.38, y: 0.34),
                        startRadius: 1,
                        endRadius: diameter * 0.62
                    )
                )
            Circle()
                .strokeBorder(OracleTheme.sealDeep.opacity(0.8), lineWidth: 1)
            Circle()
                .strokeBorder(OracleTheme.sealHighlight.opacity(0.35), lineWidth: 1.2)
                .padding(diameter * 0.14)
            Image(systemName: "crown.fill")
                .font(.system(size: diameter * 0.32, weight: .bold))
                .foregroundStyle(OracleTheme.sealEmboss)
                .shadow(color: OracleTheme.sealDeep.opacity(0.9), radius: 0.5, y: 0.8)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.30), radius: 3, y: 2)
        .accessibilityHidden(true)
    }

    /// Gilt hairline rule with a small diamond at center.
    private var ornamentalRule: some View {
        HStack(spacing: 8) {
            LinearGradient(colors: [OracleTheme.gilt.opacity(0.05), OracleTheme.gilt.opacity(0.75)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            Image(systemName: "diamond.fill")
                .font(.system(size: 5, weight: .bold))
                .foregroundStyle(OracleTheme.gilt)
            LinearGradient(colors: [OracleTheme.gilt.opacity(0.75), OracleTheme.gilt.opacity(0.05)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    /// Rubber-stamp verdict treatment — bordered small caps, faintly askew.
    private func stamp(_ text: String, ink: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .bold, design: .serif))
            .tracking(2)
            .foregroundStyle(ink)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(ink.opacity(0.65), lineWidth: 1.2)
            )
            .rotationEffect(.degrees(-1.5))
    }

    private func metaLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold, design: .serif))
            .tracking(1.1)
            .foregroundStyle(OracleTheme.ink3)
    }

    private var metaDot: some View {
        Circle()
            .fill(OracleTheme.gilt.opacity(0.8))
            .frame(width: 3, height: 3)
            .accessibilityHidden(true)
    }

    private func resolveLabel(_ decree: Decree) -> String {
        if let date = decree.resolveDate {
            return "Resolves \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Resolves \(decree.resolves)"
    }

    /// The council's private confidence as one-to-three gilt diamonds.
    private func confidenceSigil(_ confidence: Double) -> some View {
        let pips = confidence >= 0.85 ? 3 : (confidence >= 0.65 ? 2 : 1)
        return HStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < pips ? "diamond.fill" : "diamond")
                    .font(.system(size: 6.5, weight: .bold))
            }
        }
        .foregroundStyle(OracleTheme.gilt)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Council confidence \(Int((confidence * 100).rounded())) percent")
    }

    // MARK: Actions

    private func consult() {
        let pool = drawPool
        guard !pool.isEmpty else { return }
        let pick = pool[rng.nextInt(upperBound: pool.count)]
        consultCount += 1
        if reduceMotion {
            spin += 360
            current = pick
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                spin += 360
                current = pick
            }
        }
        showDraw = true
        save()
    }

    private func present(_ decree: Decree) {
        current = decree
        showDraw = true
    }

    /// The drawn-decree reader — a sheet dismissible back to the decree list.
    /// The proclamation settles in (scale + fade) unless reduce-motion is on.
    private var drawReader: some View {
        NavigationStack {
            ScrollView {
                if let decree = current {
                    decreeCard(decree)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .scaleEffect(readerRevealed ? 1 : 0.92)
                        .opacity(readerRevealed ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FacetBackdrop(accent: accent, multiHue: true))
            .navigationTitle("Decree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { consult() } label: { Label("Draw Again", systemImage: "arrow.clockwise") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showDraw = false }
                }
            }
            .onAppear {
                if reduceMotion {
                    readerRevealed = true
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                        readerRevealed = true
                    }
                }
            }
            .onDisappear { readerRevealed = false }
        }
    }

    private func snapshot() -> OracleSnapshot {
        OracleSnapshot(
            chronicle: chronicle,
            loaded: loaded,
            current: current,
            consultCount: consultCount,
            rng: rng
        )
    }

    /// Fetch the live chronicle from the public endpoint and swap it in on success.
    /// On failure the current (bundled/cached) chronicle is left untouched.
    private func refreshFromCloud() async {
        if let fresh = await DecreeSource.fetchLatest() {
            chronicle = fresh
            gotLiveChronicle = true
            save()
        }
    }

    private func restore(_ snapshot: OracleSnapshot) {
        // A successful live fetch is authoritative — never let a late (possibly
        // stale) persisted snapshot overwrite it.
        if !gotLiveChronicle { chronicle = snapshot.chronicle }
        loaded = snapshot.loaded
        current = snapshot.current
        consultCount = snapshot.consultCount
        rng = snapshot.rng
    }

    private func save(forceCloud: Bool = false) {
        persistence.save(snapshot: snapshot(), score: consultCount, forceCloud: forceCloud)
    }
}

// MARK: - Oracle theme (own-world parchment)

/// The Illuminated Ledger palette. The parchment values are deliberately fixed
/// (not theme-derived) so decree cards read as lit paper against the dark shell;
/// only the shades that sit on shell panels adapt to the global paper.
private enum OracleTheme {
    // Parchment stock (light regardless of global theme) + its inks.
    static let paper = Color(red: 0.968, green: 0.940, blue: 0.872)
    static let paperAged = Color(red: 0.934, green: 0.896, blue: 0.792)
    static let paperEdge = Color(red: 0.72, green: 0.63, blue: 0.46)
    static let ink = Color(red: 0.16, green: 0.11, blue: 0.05)
    static let ink2 = Color(red: 0.16, green: 0.11, blue: 0.05).opacity(0.78)
    static let ink3 = Color(red: 0.16, green: 0.11, blue: 0.05).opacity(0.55)

    // Gilt flourishes.
    static let gilt = Kaleido.gold

    // Wax seal.
    static let sealCrimson = Color(red: 0.55, green: 0.11, blue: 0.13)
    static let sealDeep = Color(red: 0.34, green: 0.05, blue: 0.08)
    static let sealHighlight = Color(red: 0.78, green: 0.30, blue: 0.28)
    static let sealEmboss = Color(red: 0.80, green: 0.42, blue: 0.40)

    // Verdict inks ON PARCHMENT (fixed, paper is always light).
    static let laurel = Color(red: 0.23, green: 0.38, blue: 0.19)
    static let ochre = Color(red: 0.60, green: 0.24, blue: 0.11)

    // Verdict inks ON SHELL PANELS (paper-aware: brighter on the dark ground).
    static var laurelOnShell: Color {
        Kaleido.isDark ? Color(red: 0.56, green: 0.74, blue: 0.46)
                       : Color(red: 0.24, green: 0.40, blue: 0.20)
    }
    static var ochreOnShell: Color {
        Kaleido.isDark ? Color(red: 0.90, green: 0.55, blue: 0.38)
                       : Color(red: 0.62, green: 0.26, blue: 0.13)
    }

    // Book-cover leather for unselected ledger tabs.
    static let leather = Color(red: 0.27, green: 0.20, blue: 0.13)
    static let leatherEdge = Color(red: 0.42, green: 0.33, blue: 0.21)
    static let leatherInk = Color(red: 0.85, green: 0.77, blue: 0.62)
}

/// Consult button — parchment plate with a double gilt rule, serif small caps.
private struct OracleConsultStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .serif))
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(OracleTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [OracleTheme.paper, OracleTheme.paperAged],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(OracleTheme.gilt.opacity(0.9), lineWidth: 1.2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(OracleTheme.gilt.opacity(0.45), lineWidth: 1)
                    .padding(3)
            )
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .saturation(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

#Preview {
    NavigationStack {
        OracleView()
    }
}
