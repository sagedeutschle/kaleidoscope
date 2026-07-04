import SwiftUI

/// Global leaderboards browser — pick a game, see the top players. The signed-in
/// player's row is highlighted.
struct LeaderboardView: View {
    let accountID: UUID?
    let gcAccountID: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var selected: CanonicalGameID
    @State private var rows: [LeaderboardRow] = []
    @State private var loading = true
    @State private var friendsOnly = true
    /// The local player's Game Center id as reported by GameKit itself — covers
    /// callers that don't pass `gcAccountID` (e.g. in-game result sheets).
    @State private var resolvedGCID: UUID?
    private let accent = Kaleido.gold
    private var rankedGames: [CanonicalGameID] {
        LeaderboardCatalog.ranked(friendsOnly: friendsOnly)
    }

    init(accountID: UUID? = nil, gcAccountID: UUID? = nil, initialSelection: CanonicalGameID = .game2048) {
        self.accountID = accountID
        self.gcAccountID = gcAccountID
        _selected = State(initialValue: initialSelection)
    }

    private var myGCID: UUID? { gcAccountID ?? resolvedGCID }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("Game", selection: $selected) {
                    ForEach(rankedGames, id: \.self) { g in
                        Text(LeaderboardCatalog.title(for: g)).tag(g)
                    }
                }
                .pickerStyle(.menu)
                .tint(accent)

                Picker("Scope", selection: $friendsOnly) {
                    Text("Friends").tag(true)
                    Text("Global").tag(false)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    if let metric = LeaderboardCatalog.metric(for: selected) {
                        Text(metric.blurb.uppercased())
                            .font(.caption2.weight(.bold)).tracking(1.4)
                            .foregroundStyle(Kaleido.ink3)
                    }
                    periodBadge
                }

                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FacetBackdrop(accent: accent, multiHue: true))
            .navigationTitle("Leaderboards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: "\(selected.rawValue)-\(friendsOnly)") { await load() }
            .onChange(of: friendsOnly) { _, _ in
                let games = rankedGames
                if !games.contains(selected), let first = games.first {
                    selected = first
                }
            }
        }
        .tint(accent)
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if rows.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "trophy")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.6))
                Text("No scores yet")
                    .font(Kaleido.rounded(18)).foregroundStyle(Kaleido.ink)
                Text(emptyStateDetail)
                    .font(.caption).foregroundStyle(Kaleido.ink3)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                        rowView(rank: index + 1, row: row)
                    }
                }
            }
        }
    }

    private func rowView(rank: Int, row: LeaderboardRow) -> some View {
        let isMe = (accountID != nil && row.userID == accountID)
            || (row.gcAccountID != nil && row.gcAccountID == myGCID)
        let unit = LeaderboardCatalog.metric(for: selected)?.unit ?? ""
        return HStack(spacing: 12) {
            Text("#\(rank)")
                .font(Kaleido.rounded(16)).monospacedDigit()
                .foregroundStyle(rank <= 3 ? accent : Kaleido.ink3)
                .frame(width: 40, alignment: .leading)
            Text(row.avatarEmoji).font(.system(size: 22))
            Text(row.displayName + (isMe ? " (you)" : ""))
                .font(.headline).foregroundStyle(Kaleido.ink).lineLimit(1)
            Spacer(minLength: 8)
            Text("\(row.score) \(unit)")
                .font(Kaleido.rounded(18)).monospacedDigit()
                .foregroundStyle(Kaleido.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isMe ? accent.opacity(0.16) : Kaleido.panel)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isMe ? accent : Kaleido.outline, lineWidth: isMe ? 2 : 1))
        )
    }

    /// Daily vs All-Time badge for the selected game.
    private var periodBadge: some View {
        Text(LeaderboardCatalog.period(for: selected).label.uppercased())
            .font(.caption2.weight(.heavy)).tracking(1.2)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(accent.opacity(0.18)))
            .foregroundStyle(accent)
    }

    /// Friendlier empty-state copy. In the friends scope the player may simply have
    /// no round on the board yet (or no Game Center friends to compare against);
    /// the global scope keeps the original "be the first" framing.
    private var emptyStateDetail: String {
        if friendsOnly {
            return "Play a round to put yourself on the board — add Game Center friends to compare."
        }
        return "Play \(LeaderboardCatalog.title(for: selected)) to be the first."
    }

    private func load() async {
        loading = true
        var ids: [UUID]? = nil
        if friendsOnly {
            // The player's own ids (device account + Game Center) plus their Game
            // Center friends' ids. Rows match on either user_id or gc_account_id.
            var set = accountID.map { [$0] } ?? []
            if let gcAccountID { set.append(gcAccountID) }
            let references = await GameCenterFriends.loadFriendReferences()
            set += references.map(\.accountID)
            if resolvedGCID == nil {
                resolvedGCID = references.first(where: \.isLocalPlayer)?.accountID
            }
            ids = set.isEmpty ? nil : Array(Set(set))
        }
        var fetched: [LeaderboardRow]
        do { fetched = try await LeaderboardStore.shared.top(game: selected, friendIDs: ids, limit: 30) }
        catch { fetched = [] }
        // Union the player's own row so their best always shows, even offline or
        // right after a score that hasn't synced yet.
        if let accountID {
            let myRow = try? await LeaderboardStore.shared.myRow(accountID: accountID, gcAccountID: myGCID, game: selected)
            fetched = Self.merged(fetched, ownRow: myRow, game: selected)
        }
        rows = fetched
        loading = false
    }

    /// Union the player's own best into the fetched rows: dedupe by the canonical
    /// player id (keeping the better score per the game's metric) and re-sort so
    /// the merged row lands at its true rank. Pure so it can be unit-tested.
    static func merged(
        _ rows: [LeaderboardRow],
        ownRow: LeaderboardRow?,
        game: CanonicalGameID
    ) -> [LeaderboardRow] {
        var bestByPlayer: [UUID: LeaderboardRow] = [:]
        var order: [UUID] = []
        for row in rows + (ownRow.map { [$0] } ?? []) {
            if let existing = bestByPlayer[row.canonicalPlayerID] {
                if isBetterScore(row.score, than: existing.score, game: game) {
                    bestByPlayer[row.canonicalPlayerID] = row
                }
            } else {
                bestByPlayer[row.canonicalPlayerID] = row
                order.append(row.canonicalPlayerID)
            }
        }
        return order.compactMap { bestByPlayer[$0] }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return isBetterScore(lhs.score, than: rhs.score, game: game)
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    /// Mirrors `LeaderboardStore`'s metric comparison (that one is fileprivate):
    /// higher wins for high-score games, lower wins for fewest-moves / fastest-time.
    static func isBetterScore(_ candidate: Int, than existing: Int, game: CanonicalGameID) -> Bool {
        guard let metric = LeaderboardCatalog.metric(for: game) else { return false }
        return metric.higherIsBetter ? candidate > existing : candidate < existing
    }
}
