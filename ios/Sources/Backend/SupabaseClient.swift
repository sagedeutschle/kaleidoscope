import Foundation
import Supabase

/// Single shared Supabase client, built from `Secrets`. Nil until the app is
/// configured (then the UI shows a setup screen instead of crashing).
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
        guard isConfigured, let url = URL(string: Secrets.supabaseURL) else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: Secrets.supabaseAnonKey)
    }()
}
