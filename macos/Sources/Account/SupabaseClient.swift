import Foundation
import Supabase

enum Backend {
    static var configurationReadiness: AppSecurity.ValidationResult {
        guard Secrets.isConfigured else {
            return AppSecurity.ValidationResult(blockers: ["Supabase credentials are missing"])
        }
        return AppSecurity.validateSupabaseConfiguration(
            urlString: Secrets.supabaseURL,
            anonKey: Secrets.supabaseAnonKey
        )
    }

    static var isConfigured: Bool { configurationReadiness.isValid }

    static let client: SupabaseClient? = {
        guard Secrets.isConfigured, let url = URL(string: Secrets.supabaseURL) else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
    }()
}
