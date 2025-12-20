import Foundation
import os

/// Centralized logging for BrainTwin using Apple's OSLog framework.
///
/// Usage:
/// - Logger.auth.info("User signed in: \(userId, privacy: .private)")
/// - Logger.networking.error("API failed: \(error)")
/// - Logger.ui.debug("Button tapped")
///
/// Privacy levels:
/// - .public: Safe to log (non-sensitive data like counts, states)
/// - .private: Redacted in production (default - user IDs, emails, tokens)
/// - .sensitive: Never logged even in debug
///
/// Note: OSLog automatically respects Debug/Release builds and only logs in debug mode by default.

extension Logger {
    private static let subsystem = "com.braintwin.app"

    /// Authentication and user session events
    static let auth = Logger(subsystem: subsystem, category: "🔐 Auth")

    /// Network requests, API calls, backend communication
    static let networking = Logger(subsystem: subsystem, category: "🌐 Network")

    /// UI events, view lifecycle, user interactions
    static let ui = Logger(subsystem: subsystem, category: "🎨 UI")

    /// Data persistence, caching, database operations
    static let data = Logger(subsystem: subsystem, category: "💾 Data")

    /// Audio playback, caching, TTS operations
    static let audio = Logger(subsystem: subsystem, category: "🎵 Audio")

    /// In-app purchases, subscriptions, receipts
    static let purchase = Logger(subsystem: subsystem, category: "💳 Purchase")

    /// App lifecycle, state transitions, initialization
    static let lifecycle = Logger(subsystem: subsystem, category: "⚙️ Lifecycle")
}
