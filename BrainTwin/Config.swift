import Foundation

/// App Configuration
/// SECURITY NOTE: This file contains API keys. In production:
/// 1. Add Config.swift to .gitignore
/// 2. Create Config.swift.template with placeholder values for version control
/// 3. Or use xcconfig files for better security
enum Config {
    // MARK: - Superwall
    /// Superwall SDK API Key (Public Key - safe for client apps)
    static let superwallAPIKey = "pk_Ned_vvu1JG8DJn_kq2HS5"

    // MARK: - Supabase
    /// Supabase URL (Public)
    static let supabaseURL = "https://yykxwlioounydxjikbjs.supabase.co"

    /// Supabase Anon Key (Public - protected by Row Level Security)
    /// This key is designed to be used in client apps and is protected by RLS policies
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5a3h3bGlvb3VueWR4amlrYmpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk3NzU4NjYsImV4cCI6MjA3NTM1MTg2Nn0.u2U6xApU-ViMe1FO5TtRa31-y76nEgohsF1jJ63rk0Q"
}
