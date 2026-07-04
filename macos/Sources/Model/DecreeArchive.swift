import Foundation

/// The Oracle's Archives — a permanent, local, append-only record of every decree
/// the Court Historian has ever ruled on (vindicated or corrected), as seen by this
/// install. Once a reckoning is observed in a chronicle it is stored to disk and
/// **never forgotten**, even if a later chronicle drops it or the source database
/// is reset. Kept congruent with the iOS app.
@MainActor
final class DecreeArchive: ObservableObject {
    /// Every reckoned decree ever seen, newest ruling wins on conflict.
    @Published private(set) var decrees: [Decree] = []

    private let fileURL: URL

    init(filename: String = "oracle-archive.json") {
        let fm = FileManager.default
        // A permanent store must NOT live in a purgeable temp dir; prefer Application
        // Support, then Documents, and only fall to temp as an absolute last resort.
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent(filename)
        load()
    }

    /// Fold every vindicated/corrected decree from a chronicle into the archive.
    /// Append-only: existing entries are never removed, only updated in place if the
    /// same decree's ruling changed. Persists immediately when anything changes.
    func absorb(_ chronicle: DecreeChronicle) {
        var byID = Dictionary(decrees.map { ($0.id, $0) }, uniquingKeysWith: { _, newer in newer })
        var changed = false
        for decree in chronicle.decrees where decree.isReckoned {
            if byID[decree.id] != decree {
                byID[decree.id] = decree
                changed = true
            }
        }
        guard changed else { return }
        // Stable order for persistence; the view re-sorts for display.
        decrees = byID.values.sorted { $0.id > $1.id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        // Missing / unreadable file → clean first run, nothing to lose.
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let stored = try? JSONDecoder().decode([Decree].self, from: data) {
            decrees = stored
            return
        }
        // The file EXISTS but can't be decoded. Do NOT let the next save() silently
        // overwrite (and permanently lose) it — quarantine the bytes for recovery,
        // then start fresh so the archive rebuilds going forward.
        let stamp = Int(Date().timeIntervalSince1970)
        let quarantine = fileURL.deletingLastPathComponent()
            .appendingPathComponent("oracle-archive.corrupt-\(stamp).json")
        try? FileManager.default.moveItem(at: fileURL, to: quarantine)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(decrees) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
