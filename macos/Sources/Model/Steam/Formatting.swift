import Foundation

// Small display formatters. Every number that reaches the screen goes through one of these so we
// never leak float artifacts.
enum Fmt {
    static func hours(_ h: Double) -> String {
        h >= 10 ? "\(Int(h.rounded()))h" : String(format: "%.1fh", h)
    }

    static func days(_ h: Double) -> String {
        "\(Int((h / 24).rounded())) days"
    }

    static func money(_ v: Double) -> String {
        "$" + Int(v.rounded()).formatted()
    }

    static func integer(_ v: Double) -> String {
        Int(v.rounded()).formatted()
    }

    static func percent(_ p: Double) -> String {
        String(format: "%.1f%%", p)
    }

    static func minutes(_ h: Double) -> String {
        "\(Int((h * 60).rounded())) min"
    }

    static func ownedFor(days: Int?) -> String {
        guard let d = days else { return "" }
        if d >= 365 { return "owned \(Int((Double(d) / 365).rounded())) yrs" }
        return "owned \(d) days"
    }
}
