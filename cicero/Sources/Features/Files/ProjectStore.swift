import Foundation
import Combine

/// A file in the on-device project, addressed by its path relative to the
/// project root.
struct CodeFile: Identifiable, Hashable {
    var id: String { relativePath }
    let name: String
    let relativePath: String
    let isDirectory: Bool

    var language: Language { Language(filename: name) }
}

/// Owns Cicero's sandboxed on-device workspace: a single project directory under
/// the app's Documents folder. Both the file browser/editor and the agent's file
/// tools go through this store, so the model edits exactly what the user sees.
@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var files: [CodeFile] = []
    @Published var errorMessage: String?

    let rootURL: URL
    private var didSeed = false

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        rootURL = docs.appendingPathComponent("CiceroProjects/Playground", isDirectory: true)
    }

    // MARK: Lifecycle

    func reloadIfNeeded() {
        if !didSeed {
            seedIfEmpty()
            didSeed = true
        }
        reload()
    }

    func reload() {
        let fm = FileManager.default
        var out: [CodeFile] = []
        if let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let rel = relativePath(of: url)
                out.append(CodeFile(name: url.lastPathComponent, relativePath: rel, isDirectory: isDir))
            }
        }
        files = out.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
    }

    // MARK: File ops (also used by the agent's tools)

    func read(_ relativePath: String) throws -> String {
        guard let url = resolve(relativePath) else { throw ProjectError.badPath(relativePath) }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func write(_ relativePath: String, contents: String) throws {
        guard let url = resolve(relativePath) else { throw ProjectError.badPath(relativePath) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        reload()
    }

    func delete(_ relativePath: String) throws {
        guard let url = resolve(relativePath) else { throw ProjectError.badPath(relativePath) }
        try FileManager.default.removeItem(at: url)
        reload()
    }

    /// Lists relative file paths (files only), for the agent's `list_files` tool.
    func allFilePaths() -> [String] {
        files.filter { !$0.isDirectory }.map { $0.relativePath }
    }

    // MARK: Path safety

    /// Resolves a relative path, confined to the project root. Returns nil for any
    /// path that escapes the root (e.g. via `..`).
    func resolve(_ relativePath: String) -> URL? {
        let trimmed = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        guard !trimmed.isEmpty else { return nil }
        let candidate = rootURL.appendingPathComponent(trimmed).standardizedFileURL
        let root = rootURL.standardizedFileURL
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/") else {
            return nil
        }
        return candidate
    }

    private func relativePath(of url: URL) -> String {
        let root = rootURL.standardizedFileURL.path
        let full = url.standardizedFileURL.path
        if full.hasPrefix(root + "/") {
            return String(full.dropFirst(root.count + 1))
        }
        return url.lastPathComponent
    }

    private func seedIfEmpty() {
        let fm = FileManager.default
        try? fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let existing = (try? fm.contentsOfDirectory(atPath: rootURL.path)) ?? []
        guard existing.isEmpty else { return }
        let welcome = """
        # Welcome to Cicero

        This is your pocket coding studio. Edit files here in the **Code** tab, then
        head to the **Agent** tab and ask Claude to read, explain, or change them.

        Try: "Add a `greet(name:)` function to hello.swift and call it."
        """
        let hello = """
        import Foundation

        func greet(_ name: String) -> String {
            "Hello, \\(name)! Welcome to Cicero."
        }

        print(greet("world"))
        """
        try? welcome.write(to: rootURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try? hello.write(to: rootURL.appendingPathComponent("hello.swift"), atomically: true, encoding: .utf8)
    }
}

enum ProjectError: LocalizedError {
    case badPath(String)
    var errorDescription: String? {
        switch self {
        case .badPath(let p): return "Path is outside the project or invalid: \(p)"
        }
    }
}
