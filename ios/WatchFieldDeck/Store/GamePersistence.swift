import Foundation

enum GamePersistence {
    static func load<Value: Decodable>(
        _ type: Value.Type,
        key: String,
        default defaultValue: @autoclosure () -> Value,
        defaults: UserDefaults = .standard
    ) -> Value {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(type, from: data)
        else { return defaultValue() }
        return value
    }

    static func save<Value: Encodable>(
        _ value: Value,
        key: String,
        defaults: UserDefaults = .standard
    ) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
