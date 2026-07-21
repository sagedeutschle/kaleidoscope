import Foundation

/// A dev machine Cicero can (eventually) drive remotely — one of Sage's homelab
/// boxes (archbox / topaz / iMac) reachable over the LAN or Tailnet. Stored in
/// Settings and persisted via `CiceroSettings`.
struct RemoteHost: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String        // friendly label, e.g. "archbox"
    var hostname: String    // LAN IP, Tailscale IP, or DNS name
    var username: String
    var port: Int

    init(id: UUID = UUID(), name: String, hostname: String, username: String, port: Int = 22) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.username = username
        self.port = port
    }
}
