import SwiftUI

// MARK: - Light Mode Color System
// App uses only light mode colors

extension Color {
    // MARK: - Helper for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - App Colors (Light Mode Only)
    
    /// Main background - Warm off-white
    static let appBackground = Color(hex: "#FFF8F0") // Pale peach - warm and energizing
    
    /// Primary accent - Gold
    static let appAccent = Color(red: 1.0, green: 0.84, blue: 0.0) // Gold

    /// Accent gradient - Orange to Gold (used for buttons, headings, highlights)
    static let appAccentGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.6, blue: 0.2),  // Warm orange
            Color(red: 1.0, green: 0.84, blue: 0.0)  // Gold
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Secondary background for cards
    static let appCardBackground = Color.white
    
    /// Card borders
    static let appCardBorder = Color(hex: "#E8E8E8")
    
    /// Text - Primary
    static let appTextPrimary = Color(hex: "#2B1E14") // Dark brown (warm, not stark black)
    
    /// Text - Secondary
    static let appTextSecondary = Color(hex: "#5A4A3A") // Medium brown
    
    /// Text - Tertiary
    static let appTextTertiary = Color(hex: "#8A7A6A") // Light brown
    
    /// Progress track (background)
    static let appProgressTrack = Color(hex: "#E8E8E8")
    
    /// Glass overlay for buttons
    static let appGlassOverlay = Color.black.opacity(0.05)
}
