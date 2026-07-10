import SwiftUI

// macOS Prismet "Steam Rewind" lens — desktop sibling of the iOS lens. Reuses the shared engine
// (Sources/Model/Steam/) and renders with PrismetDesign design tokens so it sits in the shell as an own-world
// facet (like Debt Clock). Fixture demo shows instantly; a Steam Web API key (config.json on disk, same
// as the standalone app) lights up real profiles.
struct SteamRewindLensView: View {
    @StateObject private var model = ExplorerModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                searchBar
                if model.showingSettings { keyCard }

                if let snap = model.snapshot, !model.isPrivate {
                    if model.isDemo { demoBanner }
                    profileHeader(snap)
                    kpiRow(snap)
                    valueNote
                    lensChips
                    blurbBlock(snap)
                    resultBlock(snap)
                    footer(snap)
                } else if let snap = model.snapshot, model.isPrivate {
                    profileHeader(snap)
                    privateState
                } else if model.isLoading {
                    loadingState
                } else if let err = model.errorText {
                    errorState(err)
                } else if !model.showingSettings {
                    emptyPrompt
                }
            }
            .padding(20)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(PrismetDesign.ground)
        .task { await model.loadInitial() }
    }

    // MARK: search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(PrismetDesign.ink3)
            TextField("Steam ID, vanity name, or profile URL", text: $model.query)
                .textFieldStyle(.plain)
                .font(PrismetDesign.rounded(14, .regular))
                .onSubmit { Task { await model.load() } }
            if model.isLoading { ProgressView().controlSize(.small) }
            Button("Unwrap") { Task { await model.load() } }
                .buttonStyle(.borderedProminent)
            Button { model.showingSettings.toggle() } label: {
                Image(systemName: "key").foregroundStyle(model.hasKey ? RewindStyle.good : PrismetDesign.ink3)
            }
            .buttonStyle(.plain)
            .help(model.hasKey ? "Steam API key connected" : "Add your Steam API key")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(PrismetDesign.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PrismetDesign.hairline))
    }

    // MARK: key entry

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.hasKey ? "Steam API key" : "Connect Steam").font(PrismetDesign.rounded(16))
                    .foregroundStyle(PrismetDesign.ink)
                Spacer()
                Button { model.showingSettings = false } label: { Image(systemName: "xmark").foregroundStyle(PrismetDesign.ink3) }
                    .buttonStyle(.plain)
            }
            Text("Real profiles need a free Steam Web API key. It's stored only on this Mac — never bundled or committed.")
                .font(PrismetDesign.rounded(13, .regular)).foregroundStyle(PrismetDesign.ink2).fixedSize(horizontal: false, vertical: true)
            Link(destination: URL(string: "https://steamcommunity.com/dev/apikey")!) {
                HStack(spacing: 5) { Text("Get a free key"); Image(systemName: "arrow.up.right") }.font(PrismetDesign.rounded(13, .regular))
            }
            HStack(spacing: 8) {
                TextField("Paste your key here", text: $model.keyDraft)
                    .textFieldStyle(.roundedBorder).font(.system(size: 13, design: .monospaced))
                    .onSubmit { model.saveKey() }
                Button("Save") { model.saveKey() }.buttonStyle(.borderedProminent)
            }
            if model.hasKey {
                Text("Key connected — type any public profile above and Unwrap.")
                    .font(PrismetDesign.rounded(12, .regular)).foregroundStyle(RewindStyle.good)
            }
        }
        .padding(16)
        .background(PrismetDesign.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PrismetDesign.hairline))
    }

    private var demoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(RewindStyle.accent)
            Text(model.hasKey
                 ? "Demo library — type any Steam ID, vanity name, or profile URL above and Unwrap it."
                 : "This is the demo library. Add your Steam key to unwrap real profiles.")
                .font(PrismetDesign.rounded(13, .regular)).foregroundStyle(PrismetDesign.ink2)
            Spacer()
            if !model.hasKey {
                Button("Add key") { model.showingSettings = true }.buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RewindStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: profile

    private func profileHeader(_ s: SteamProfileSnapshot) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14).fill(RewindStyle.accent.opacity(0.18))
                .frame(width: 52, height: 52)
                .overlay(Text(s.player.avatarInitials).font(PrismetDesign.rounded(20)).foregroundStyle(RewindStyle.accent))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(s.player.personaName).font(PrismetDesign.title(20)).foregroundStyle(PrismetDesign.ink)
                    if let level = s.steamLevel {
                        Text("level \(level)").font(PrismetDesign.rounded(12))
                            .foregroundStyle(RewindStyle.accent)
                            .padding(.horizontal, 9).padding(.vertical, 2)
                            .background(RewindStyle.accent.opacity(0.16), in: Capsule())
                    }
                }
                Text(subtitle(s)).font(PrismetDesign.rounded(13, .regular)).foregroundStyle(PrismetDesign.ink3)
            }
            Spacer()
        }
    }

    private func subtitle(_ s: SteamProfileSnapshot) -> String {
        var parts: [String] = []
        if let year = s.player.memberSinceYear { parts.append("on Steam since \(year)") }
        parts.append(s.visibility == .publicProfile ? "public profile" : (s.visibility == .privateProfile ? "private profile" : "partial data"))
        if !s.ownedGames.isEmpty { parts.append("\(s.ownedGames.count) games") }
        return parts.joined(separator: " · ")
    }

    // MARK: KPI tiles

    private func kpiRow(_ s: SteamProfileSnapshot) -> some View {
        let rare = SteamMetrics.rarestUnlockPercent(s)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            kpiTile("lifetime hours", Fmt.integer(SteamMetrics.totalHours(s)), PrismetDesign.ink)
            kpiTile("full-price value", Fmt.money(SteamMetrics.estLibraryValue(s)), PrismetDesign.ink)
            kpiTile("pile of shame", Fmt.money(SteamMetrics.pileOfShameValue(s)), RewindStyle.bad)
            kpiTile("rarest unlock", rare.map { Fmt.percent($0) } ?? "—", RewindStyle.accent)
        }
    }

    private func kpiTile(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(PrismetDesign.rounded(12, .regular)).foregroundStyle(PrismetDesign.ink3)
            Text(value).font(PrismetDesign.rounded(22)).foregroundStyle(color).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(PrismetDesign.panel, in: RoundedRectangle(cornerRadius: 10))
    }

    private var valueNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "tag").font(.system(size: 11))
            Text("Full-price value is today's store price. Steam never reveals what you actually paid, so real sale-savings can't be shown here.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(PrismetDesign.rounded(11.5, .regular)).foregroundStyle(PrismetDesign.ink3)
    }

    // MARK: lens chips

    private var lensChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LensCatalog.all) { lens in lensChip(lens) }
            }
            .padding(.vertical, 2)
        }
    }

    private func lensChip(_ lens: Lens) -> some View {
        let selected = lens.id == model.selectedLensID
        return Button {
            withAnimation(.easeOut(duration: 0.16)) { model.selectedLensID = lens.id }
        } label: {
            HStack(spacing: 6) { Image(systemName: lens.symbol); Text(lens.title) }
                .font(PrismetDesign.rounded(13, selected ? .semibold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? PrismetDesign.ink : PrismetDesign.panel, in: Capsule())
                .foregroundStyle(selected ? PrismetDesign.ground : PrismetDesign.ink2)
                .overlay(Capsule().stroke(PrismetDesign.hairline, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: blurb + results

    private func blurbBlock(_ s: SteamProfileSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.selectedLens.blurb(s))
                .font(PrismetDesign.rounded(14, .regular)).foregroundStyle(PrismetDesign.ink).fixedSize(horizontal: false, vertical: true)
            if let note = model.selectedLens.note {
                Text(note).font(PrismetDesign.rounded(12, .regular)).foregroundStyle(PrismetDesign.ink3).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func resultBlock(_ s: SteamProfileSnapshot) -> some View {
        switch LensCatalog.evaluate(model.selectedLens, s) {
        case .list(let rows):
            if rows.isEmpty {
                Text("Nothing here yet — which is its own kind of achievement.")
                    .font(PrismetDesign.rounded(13, .regular)).foregroundStyle(PrismetDesign.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            } else {
                VStack(spacing: 8) { ForEach(rows) { RewindLensRow(row: $0) } }
            }
        case .bars(let bars):
            VStack(spacing: 8) { ForEach(bars) { RewindBarRow(bar: $0) } }
        }
    }

    private func footer(_ s: SteamProfileSnapshot) -> some View {
        let enriched = s.ownedGames.filter { $0.genre != nil || $0.priceEstimateCents != nil }.count
        let text: String = model.isDemo
            ? "Demo data · value figures are estimates from current store price · hours are lifetime, not monthly."
            : ((enriched < s.ownedGames.count ? "store data covers your \(enriched) most-played games · " : "") + "prices are today's store data · hours are lifetime, not monthly.")
        return HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle").font(.system(size: 11))
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(PrismetDesign.rounded(11.5, .regular)).foregroundStyle(PrismetDesign.ink3).padding(.top, 6)
    }

    // MARK: states

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Resolving the profile and pulling the library…").font(PrismetDesign.rounded(13, .regular)).foregroundStyle(PrismetDesign.ink3)
        }
        .frame(maxWidth: .infinity).padding(.top, 48)
    }

    private var privateState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.fill").font(.system(size: 24)).foregroundStyle(PrismetDesign.ink3)
            Text("This profile's game details are private.").font(PrismetDesign.rounded(15))
                .foregroundStyle(PrismetDesign.ink)
            Text("In Steam → Profile → Edit Profile → Privacy Settings, set “Game details” to Public, then Unwrap again.")
                .font(PrismetDesign.rounded(13, .regular)).foregroundStyle(PrismetDesign.ink2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 24)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 24)).foregroundStyle(RewindStyle.bad)
            Text(message).font(PrismetDesign.rounded(14, .regular)).foregroundStyle(PrismetDesign.ink2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 32)
    }

    private var emptyPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Unwrap a Steam library").font(PrismetDesign.title(18)).foregroundStyle(PrismetDesign.ink)
            Text("Type a SteamID, a vanity name, or a full profile URL and hit Unwrap.")
                .font(PrismetDesign.rounded(14, .regular)).foregroundStyle(PrismetDesign.ink2)
            Button("Load the demo library") { Task { await model.loadDemo() } }.buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 28)
    }
}

private enum RewindStyle {
    static let accent = Color(red: 0.36, green: 0.60, blue: 0.92)
    static let good = Color(red: 0.29, green: 0.72, blue: 0.45)
    static let bad = Color(red: 0.90, green: 0.40, blue: 0.37)
    static func bar(_ tone: Tone) -> Color {
        switch tone { case .good: return good; case .bad: return bad; case .neutral: return accent }
    }
    static func text(_ tone: Tone) -> Color {
        switch tone { case .good: return good; case .bad: return bad; case .neutral: return PrismetDesign.ink }
    }
}

private struct RewindStatBar: View {
    var fraction: Double
    var color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PrismetDesign.hairline)
                Capsule().fill(color).frame(width: max(4, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 6)
    }
}

private struct RewindLensRow: View {
    let row: LensRowData
    var body: some View {
        HStack(spacing: 12) {
            Text("\(row.rank)").font(PrismetDesign.rounded(12, .regular)).foregroundStyle(PrismetDesign.ink3)
                .frame(width: 20, alignment: .trailing).monospacedDigit()
            VStack(alignment: .leading, spacing: 6) {
                Text(row.name).font(PrismetDesign.rounded(14, .regular)).foregroundStyle(PrismetDesign.ink).lineLimit(1)
                RewindStatBar(fraction: row.fraction, color: RewindStyle.bar(row.stat.tone))
            }
            VStack(alignment: .trailing, spacing: 1) {
                Text(row.stat.big).font(PrismetDesign.rounded(15)).foregroundStyle(RewindStyle.text(row.stat.tone)).monospacedDigit()
                Text(row.stat.sub).font(PrismetDesign.rounded(11.5, .regular)).foregroundStyle(PrismetDesign.ink3)
            }
            .frame(width: 116, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(PrismetDesign.panel, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct RewindBarRow: View {
    let bar: BarDatum
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                if let symbol = bar.symbol { Image(systemName: symbol).foregroundStyle(PrismetDesign.ink2) }
                Text(bar.label).font(PrismetDesign.rounded(14, .regular)).foregroundStyle(PrismetDesign.ink)
            }
            .frame(width: 150, alignment: .leading)
            RewindStatBar(fraction: bar.fraction, color: RewindStyle.accent)
            Text(bar.detail).font(PrismetDesign.rounded(12, .regular)).foregroundStyle(PrismetDesign.ink2)
                .frame(width: 104, alignment: .trailing).monospacedDigit()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(PrismetDesign.panel, in: RoundedRectangle(cornerRadius: 10))
    }
}
