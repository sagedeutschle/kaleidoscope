// PRISM: RELEASE Agent-Design/Fable 2026-07-04 — SteamRewind fold-in (Lens).
// Touch-first port of the SteamRewind Explorer: profile header + 11 playful lenses
// that re-rank a Steam library. Demo (fixture) library shows instantly with no key —
// that's what App Review sees; a user's own Steam Web API key (BYO, on-device only)
// lights up their real library. Engine lives in Sources/Core/Steam/.
import SwiftUI

// MARK: - Store

@MainActor
final class SteamRewindStore: ObservableObject {
    @Published private(set) var snapshot: SteamProfileSnapshot?
    @Published private(set) var isLiveData = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    static let lastQueryKey = "steam.lastQuery"

    /// Demo library immediately; refresh the saved profile live if a key exists.
    func bootstrap() async {
        if snapshot == nil { snapshot = Fixtures.sage }
        guard SteamCredentials.hasKey(),
              let saved = UserDefaults.standard.string(forKey: Self.lastQueryKey),
              !saved.isEmpty else { return }
        await load(query: saved)
    }

    func load(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let key = SteamCredentials.apiKey() else {
            errorMessage = "Add your free Steam Web API key first (the 🔑 button)."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let live = try await LiveSteamDataProvider(apiKey: key).snapshot(forQuery: trimmed)
            snapshot = live
            isLiveData = true
            UserDefaults.standard.set(trimmed, forKey: Self.lastQueryKey)
        } catch let error as SteamDataError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = SteamDataError.network.userMessage
        }
    }
}

// MARK: - The lens

struct SteamRewindView: View {
    @StateObject private var store = SteamRewindStore()
    @State private var query = ""
    @State private var lensID = "played"
    @State private var showKeySheet = false

    /// Steam-navy palette on the house dark field.
    enum Hue {
        static let steam   = Color(red: 0.40, green: 0.65, blue: 0.93)   // steam blue
        static let good    = Color(red: 0.36, green: 0.90, blue: 0.52)
        static let bad     = Color(red: 1.00, green: 0.52, blue: 0.40)
        static let gold    = Color(red: 1.00, green: 0.80, blue: 0.32)
        static let label   = Color(white: 0.72)
        static let sublabel = Color(white: 0.5)
    }

    static func toneColor(_ tone: Tone) -> Color {
        switch tone {
        case .good: return Hue.good
        case .bad: return Hue.bad
        case .neutral: return Hue.steam
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot = store.snapshot {
                    ProfileHeaderCard(snapshot: snapshot, isLive: store.isLiveData)
                }
                searchRow
                if let message = store.errorMessage {
                    errorCard(message)
                }
                if let snapshot = store.snapshot {
                    LensChipsRow(lensID: $lensID)
                    LensResultSection(lens: LensCatalog.lens(id: lensID), snapshot: snapshot)
                }
                disclaimer
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .preferredColorScheme(.dark)
        .navigationTitle("Steam Rewind")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await store.bootstrap() }
        .refreshable {
            if !query.isEmpty { await store.load(query: query) }
            else { await store.bootstrap() }
        }
        .sheet(isPresented: $showKeySheet) { SteamKeySheet() }
    }

    private var background: some View {
        LinearGradient(colors: [Color(red: 0.06, green: 0.09, blue: 0.13),
                                Color(red: 0.03, green: 0.05, blue: 0.08)],
                       startPoint: .top, endPoint: .bottom)
        .overlay(alignment: .top) {
            RadialGradient(colors: [Hue.steam.opacity(0.10), .clear],
                           center: .top, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            TextField("Steam ID, vanity, or profile URL", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(Kaleido.rounded(14, .semibold))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.06)))
                .onSubmit { Task { await store.load(query: query) } }
            Button {
                Task { await store.load(query: query) }
            } label: {
                if store.isLoading {
                    ProgressView().tint(Hue.steam)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Hue.steam)
                }
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)
            .accessibilityLabel("Load profile")
            Button {
                showKeySheet = true
            } label: {
                Image(systemName: SteamCredentials.hasKey() ? "key.fill" : "key")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(SteamCredentials.hasKey() ? Hue.good : Hue.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Steam API key settings")
        }
    }

    private func errorCard(_ message: String) -> some View {
        Text(message)
            .font(Kaleido.rounded(12.5, .semibold))
            .foregroundStyle(Hue.bad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Hue.bad.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Hue.bad.opacity(0.35), lineWidth: 1)))
    }

    private var disclaimer: some View {
        Text("Reads your own library via your free Steam Web API key (steamcommunity.com/dev/apikey) — the key stays on this device. Prices are current full-price estimates, not what you paid; Steam never discloses purchase history to apps. Demo library shown until you load a profile.")
            .font(Kaleido.rounded(10.5, .regular))
            .foregroundStyle(Hue.sublabel)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }
}

// MARK: - Header

private struct ProfileHeaderCard: View {
    let snapshot: SteamProfileSnapshot
    let isLive: Bool
    private typealias Hue = SteamRewindView.Hue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Hue.steam.opacity(0.18))
                    Text(snapshot.player.avatarInitials)
                        .font(Kaleido.rounded(16, .heavy))
                        .foregroundStyle(Hue.steam)
                }
                .frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(Hue.steam.opacity(0.5), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(snapshot.player.personaName)
                            .font(Kaleido.rounded(18, .heavy))
                            .foregroundStyle(.white)
                        if !isLive { demoBadge }
                    }
                    Text(memberLine)
                        .font(Kaleido.rounded(11.5, .semibold))
                        .foregroundStyle(Hue.sublabel)
                }
                Spacer()
                if let level = snapshot.steamLevel {
                    VStack(spacing: 1) {
                        Text("LVL").font(Kaleido.rounded(9, .heavy)).tracking(1.4)
                            .foregroundStyle(Hue.sublabel)
                        Text("\(level)").font(Kaleido.rounded(17, .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Hue.gold)
                    }
                }
            }
            HStack(spacing: 14) {
                statPair("\(snapshot.ownedGames.count)", "games")
                statPair(Fmt.hours(SteamMetrics.totalHours(snapshot)), "played")
                statPair(Fmt.money(SteamMetrics.estLibraryValue(snapshot)), "est. value")
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.05, green: 0.08, blue: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Hue.steam.opacity(0.4), lineWidth: 1))
        )
        .shadow(color: Hue.steam.opacity(0.18), radius: 16, y: 6)
    }

    private var memberLine: String {
        var parts: [String] = []
        if let year = snapshot.player.memberSinceYear { parts.append("member since \(year)") }
        if let country = snapshot.player.country { parts.append(country) }
        return parts.isEmpty ? "Steam profile" : parts.joined(separator: " · ")
    }

    private var demoBadge: some View {
        Text("DEMO")
            .font(.system(size: 9, weight: .heavy))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Hue.gold.opacity(0.2)))
            .foregroundStyle(Hue.gold)
            .accessibilityLabel("Demo library")
    }

    private func statPair(_ big: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(big).font(Kaleido.rounded(15, .heavy)).monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased()).font(Kaleido.rounded(9, .heavy)).tracking(1.2)
                .foregroundStyle(Hue.sublabel)
        }
    }
}

// MARK: - Lens chips

private struct LensChipsRow: View {
    @Binding var lensID: String
    private typealias Hue = SteamRewindView.Hue

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LensCatalog.all) { lens in
                    chip(lens)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ lens: Lens) -> some View {
        let active = lensID == lens.id
        return Button {
            lensID = lens.id
        } label: {
            HStack(spacing: 5) {
                Image(systemName: lens.symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(lens.title.uppercased())
                    .font(Kaleido.rounded(10.5, .heavy)).tracking(1.1)
            }
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Capsule().fill(active ? Hue.steam.opacity(0.2) : Color.white.opacity(0.05)))
            .overlay(Capsule().strokeBorder(active ? Hue.steam.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1))
            .foregroundStyle(active ? Hue.steam : Hue.label)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

// MARK: - Lens result

private struct LensResultSection: View {
    let lens: Lens
    let snapshot: SteamProfileSnapshot
    private typealias Hue = SteamRewindView.Hue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lens.blurb(snapshot))
                .font(Kaleido.rounded(13.5, .regular))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            switch LensCatalog.evaluate(lens, snapshot) {
            case .list(let rows):
                if rows.isEmpty {
                    emptyCard
                } else {
                    VStack(spacing: 8) {
                        ForEach(rows) { row in LensListRow(row: row) }
                    }
                }
            case .bars(let bars):
                VStack(spacing: 9) {
                    ForEach(bars) { bar in LensBarRow(bar: bar) }
                }
            }
            if let note = lens.note {
                Text(note)
                    .font(Kaleido.rounded(10.5, .regular))
                    .foregroundStyle(Hue.sublabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyCard: some View {
        Text("Nothing qualifies for this lens yet — which is its own kind of achievement.")
            .font(Kaleido.rounded(12.5, .regular))
            .foregroundStyle(Hue.sublabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04)))
    }
}

private struct LensListRow: View {
    let row: LensRowData
    private typealias Hue = SteamRewindView.Hue

    var body: some View {
        let hue = SteamRewindView.toneColor(row.stat.tone)
        HStack(spacing: 11) {
            Text("\(row.rank)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(row.rank <= 3 ? Hue.gold : Hue.sublabel)
                .frame(width: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.name)
                        .font(Kaleido.rounded(14, .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength: 8)
                    Text(row.stat.big)
                        .font(Kaleido.rounded(13.5, .heavy))
                        .monospacedDigit()
                        .foregroundStyle(hue)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule().fill(hue.opacity(0.55))
                                .frame(width: max(3, geo.size.width * row.fraction))
                        }
                    }
                    .frame(height: 4)
                    Text(row.stat.sub)
                        .font(Kaleido.rounded(10.5, .semibold))
                        .foregroundStyle(Hue.sublabel)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .layoutPriority(1)
                }
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(hue.opacity(0.18), lineWidth: 1)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(row.rank), \(row.name), \(row.stat.big), \(row.stat.sub)")
    }
}

private struct LensBarRow: View {
    let bar: BarDatum
    private typealias Hue = SteamRewindView.Hue

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                if let symbol = bar.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Hue.steam)
                }
                Text(bar.label)
                    .font(Kaleido.rounded(13, .bold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text(bar.detail)
                    .font(Kaleido.rounded(11.5, .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Hue.steam)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(Hue.steam.opacity(0.6))
                        .frame(width: max(3, geo.size.width * bar.fraction))
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.04)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bar.label): \(bar.detail)")
    }
}

// MARK: - Key sheet

private struct SteamKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var keyText = ""
    @State private var saved = false
    private typealias Hue = SteamRewindView.Hue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Steam Rewind reads your library with your own free Steam Web API key. Grab it at steamcommunity.com/dev/apikey (any domain value works, e.g. \"localhost\"), paste it below, done.")
                        .font(Kaleido.rounded(13.5, .regular))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    SecureField("Steam Web API key", text: $keyText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.white.opacity(0.06)))
                    Button {
                        try? SteamCredentials.saveAPIKey(keyText)
                        saved = true
                        dismiss()
                    } label: {
                        Text("Save key")
                            .font(Kaleido.rounded(14, .heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Hue.steam.opacity(keyText.isEmpty ? 0.15 : 0.3)))
                            .foregroundStyle(keyText.isEmpty ? Hue.sublabel : Hue.steam)
                    }
                    .buttonStyle(.plain)
                    .disabled(keyText.isEmpty)
                    if SteamCredentials.hasKey() {
                        Button {
                            SteamCredentials.clear()
                            keyText = ""
                            dismiss()
                        } label: {
                            Text("Remove saved key")
                                .font(Kaleido.rounded(12.5, .semibold))
                                .foregroundStyle(Hue.bad)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("The key is stored only on this device and only ever sent to Steam. It never touches Kaleidoscope's servers, the app bundle, or git.")
                        .font(Kaleido.rounded(11, .regular))
                        .foregroundStyle(Hue.sublabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
            }
            .background(Color(red: 0.04, green: 0.06, blue: 0.10).ignoresSafeArea())
            .navigationTitle("Steam API key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
