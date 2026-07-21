import UIKit

/// Languages Cicero can syntax-highlight. `.plain` is the fallback (no coloring).
enum Language: String {
    case swift, python, javascript, json, markdown, plain

    init(filename: String) {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": self = .swift
        case "py": self = .python
        case "js", "jsx", "ts", "tsx", "mjs", "cjs": self = .javascript
        case "json": self = .json
        case "md", "markdown", "mdown": self = .markdown
        default: self = .plain
        }
    }

    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .plain: return "Text"
        }
    }

    var keywords: Set<String> {
        switch self {
        case .swift:
            return ["func", "let", "var", "if", "else", "guard", "return", "for", "while",
                    "in", "switch", "case", "default", "struct", "class", "enum", "protocol",
                    "extension", "import", "self", "init", "throws", "try", "throw", "async",
                    "await", "nil", "true", "false", "public", "private", "internal", "static",
                    "some", "where", "do", "catch", "defer", "final", "override", "mutating"]
        case .python:
            return ["def", "class", "if", "elif", "else", "for", "while", "in", "return",
                    "import", "from", "as", "with", "try", "except", "finally", "raise",
                    "lambda", "yield", "async", "await", "None", "True", "False", "and",
                    "or", "not", "is", "pass", "break", "continue", "global", "nonlocal"]
        case .javascript:
            return ["function", "const", "let", "var", "if", "else", "for", "while", "return",
                    "class", "extends", "new", "import", "export", "from", "default", "async",
                    "await", "try", "catch", "finally", "throw", "switch", "case", "break",
                    "continue", "typeof", "instanceof", "null", "undefined", "true", "false", "this"]
        case .json, .markdown, .plain:
            return []
        }
    }
}

/// Turns source text into a colored `NSAttributedString`. Pure (no UI state), so
/// it's unit-testable and reusable by the UITextView-backed editor.
struct SyntaxHighlighter {
    let language: Language

    func attributed(for source: String, fontSize: CGFloat = 15) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let full = NSRange(source.startIndex..<source.endIndex, in: source)
        let result = NSMutableAttributedString(
            string: source,
            attributes: [.font: font, .foregroundColor: UIColor(hex: "E6EDF3")])

        guard language != .plain else { return result }

        func paint(_ pattern: String, _ color: UIColor) {
            guard let re = try? NSRegularExpression(pattern: pattern) else { return }
            re.enumerateMatches(in: source, range: full) { match, _, _ in
                if let r = match?.range { result.addAttribute(.foregroundColor, value: color, range: r) }
            }
        }

        // Order matters: strings and comments are painted last so they win over
        // keyword/number coloring that happens to fall inside them.
        paint(#"\b\d[\d_]*(?:\.[\d_]+)?\b"#, UIColor(hex: "FF9E64"))          // numbers

        if !language.keywords.isEmpty {
            let alt = language.keywords
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .joined(separator: "|")
            paint(#"\b(?:"# + alt + #")\b"#, UIColor(hex: "BB9AF7"))          // keywords
        }

        paint(#""(?:\\.|[^"\\])*""#, UIColor(hex: "9ECE6A"))                  // "double" strings
        if language == .python || language == .javascript {
            paint(#"'(?:\\.|[^'\\])*'"#, UIColor(hex: "9ECE6A"))             // 'single' strings
        }

        switch language {
        case .swift, .javascript:
            paint(#"//[^\n]*"#, UIColor(hex: "6B7681"))                       // line comments
            paint(#"/\*[\s\S]*?\*/"#, UIColor(hex: "6B7681"))                 // block comments
        case .python:
            paint(#"#[^\n]*"#, UIColor(hex: "6B7681"))
        default:
            break
        }

        return result
    }
}

extension UIColor {
    /// 6-digit "RRGGBB" hex (with or without leading '#').
    convenience init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
