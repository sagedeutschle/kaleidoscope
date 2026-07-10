import SwiftUI

/// App-wide typeface choice. String-backed so it drops straight into `@AppStorage`.
///
/// The persisted key is ``AppFont/storageKey`` (`"app.fontChoice"`). Read the current
/// choice anywhere with `@AppStorage(AppFont.storageKey) var raw = AppFont.default.rawValue`
/// and resolve it via `AppFont(stored: raw)`.
enum AppFont: String, CaseIterable, Identifiable {
    /// Refined serif — the app's default. Reads more editorial/professional than the
    /// plain system face and matches the existing `PrismetDesign.title(_:)` serif headings.
    case serif
    /// Apple's default UI face (San Francisco).
    case system
    /// Soft, friendly rounded variant.
    case rounded
    /// Fixed-width — utilitarian, good for a "technical" look.
    case monospaced

    /// `@AppStorage` key the whole app agrees on for the font choice.
    static let storageKey = "app.fontChoice"

    /// Professional default. Serif is the most polished/editorial of the system faces
    /// and is already the app's headline voice, so it unifies the typography.
    static let `default`: AppFont = .serif

    var id: String { rawValue }

    /// Tolerant lookup for a persisted raw value; falls back to the default.
    init(stored raw: String?) {
        self = raw.flatMap(AppFont.init(rawValue:)) ?? .default
    }

    /// Human-facing label for the picker.
    var displayName: String {
        switch self {
        case .serif:      return "Serif"
        case .system:     return "System"
        case .rounded:    return "Rounded"
        case .monospaced: return "Monospaced"
        }
    }

    /// One-line description of the vibe, shown under the picker row.
    var blurb: String {
        switch self {
        case .serif:      return "Refined, editorial — the Prismet default."
        case .system:     return "Clean and familiar (San Francisco)."
        case .rounded:    return "Soft and friendly."
        case .monospaced: return "Fixed-width, technical."
        }
    }

    /// SwiftUI `Font.Design` this case maps to. Distinct per case.
    var design: Font.Design {
        switch self {
        case .serif:      return .serif
        case .system:     return .default
        case .rounded:    return .rounded
        case .monospaced: return .monospaced
        }
    }

    /// SF Symbol used to preview each option in the picker.
    var symbol: String {
        switch self {
        case .serif:      return "textformat.abc"
        case .system:     return "textformat"
        case .rounded:    return "textformat.size"
        case .monospaced: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
