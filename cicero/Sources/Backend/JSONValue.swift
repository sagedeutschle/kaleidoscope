import Foundation

/// A minimal, fully `Codable` JSON value. Used for tool input schemas (which we
/// build by hand) and for decoding arbitrary tool-call `input` payloads from the
/// model without committing to a fixed Swift type per tool.
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            // Bool must be tried before Double: JSON `true`/`false` decode as Bool,
            // and a numeric literal will throw here and fall through to Double.
            self = .bool(b)
        } else if let d = try? c.decode(Double.self) {
            self = .number(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let d): try c.encode(d)
        case .bool(let b): try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        case .null: try c.encodeNil()
        }
    }
}

extension JSONValue {
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let d): return String(d)
        case .bool(let b): return String(b)
        default: return nil
        }
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Convenience for reading a field out of an object value.
    subscript(_ key: String) -> JSONValue? { objectValue?[key] }

    // Small builders that keep tool-schema construction readable.
    static func obj(_ pairs: [String: JSONValue]) -> JSONValue { .object(pairs) }
    static func str(_ s: String) -> JSONValue { .string(s) }
    static func arr(_ xs: [JSONValue]) -> JSONValue { .array(xs) }
}
