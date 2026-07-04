import Foundation

// TEMPLATE — copy to Sources/Backend/Secrets.swift and fill in real values.
// Sources/Backend/Secrets.swift is gitignored so your keys never get committed.
// Get these from Supabase → Project Settings → API.
enum Secrets {
    static let supabaseURL = "https://YOUR-PROJECT.supabase.co"
    static let supabaseAnonKey = "YOUR-ANON-PUBLIC-KEY"

    static var isConfigured: Bool {
        !supabaseURL.contains("YOUR-") && !supabaseAnonKey.contains("YOUR-")
    }
}
