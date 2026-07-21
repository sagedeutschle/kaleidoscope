import Foundation
import Combine

/// App-wide, persisted configuration: which model/effort the agent uses, whether
/// an API key is stored, and the list of remote dev hosts (for the future
/// remote-execution path). The API key itself lives in the Keychain, not here.
@MainActor
final class CiceroSettings: ObservableObject {
    static let apiKeyAccount = "anthropic_api_key"

    @Published var modelID: String { didSet { defaults.set(modelID, forKey: Keys.model) } }
    @Published var effort: String { didSet { defaults.set(effort, forKey: Keys.effort) } }
    @Published var hosts: [RemoteHost] { didSet { persistHosts() } }
    @Published private(set) var hasAPIKey: Bool

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let model = "cicero.model"
        static let effort = "cicero.effort"
        static let hosts = "cicero.hosts"
    }

    init() {
        // Property observers do not fire for these initial assignments, so this
        // does not write defaults back on every launch.
        modelID = defaults.string(forKey: Keys.model) ?? AgentModel.default.id
        effort = defaults.string(forKey: Keys.effort) ?? AgentEffort.high.rawValue
        hasAPIKey = (Keychain.get(CiceroSettings.apiKeyAccount)?.isEmpty == false)
        if let data = defaults.data(forKey: Keys.hosts),
           let decoded = try? JSONDecoder().decode([RemoteHost].self, from: data) {
            hosts = decoded
        } else {
            hosts = []
        }
    }

    /// Reads the raw key out of the Keychain (nil when unset).
    func apiKey() -> String? { Keychain.get(Self.apiKeyAccount) }

    func setAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Keychain.set(trimmed, for: Self.apiKeyAccount)
        hasAPIKey = true
    }

    func clearAPIKey() {
        Keychain.delete(Self.apiKeyAccount)
        hasAPIKey = false
    }

    func addHost(_ host: RemoteHost) { hosts.append(host) }
    func removeHosts(at offsets: IndexSet) { hosts.remove(atOffsets: offsets) }

    private func persistHosts() {
        if let data = try? JSONEncoder().encode(hosts) {
            defaults.set(data, forKey: Keys.hosts)
        }
    }
}
