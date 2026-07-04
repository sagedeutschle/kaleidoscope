import Foundation
import Supabase

enum Backend {
    static let client: SupabaseClient? = {
        guard Secrets.isConfigured, let url = URL(string: Secrets.supabaseURL) else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
    }()

    static var isConfigured: Bool { client != nil }
}
