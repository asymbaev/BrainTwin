import SwiftUI

// MARK: - Adaptive Color System
// Automatically switches between Light and Dark mode based on iOS system appearance

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
    
    // MARK: - Adaptive Colors
    
    /// Main background - Warm off-white in light, pure black in dark
    static let appBackground = Color(
        light: Color(hex: "#FFF8F0"), // Pale peach - warm and energizing
        dark: Color.black
    )
    
    /// Primary accent - Electric Yellow in BOTH modes (energetic consistency)
    static let appAccent = Color(hex: "#FFD60A") // Electric Yellow
    
    /// Secondary background for cards
    static let appCardBackground = Color(
        light: Color.white,
        dark: Color.white.opacity(0.03)
    )
    
    /// Card borders
    static let appCardBorder = Color(
        light: Color(hex: "#E8E8E8"),
        dark: Color.white.opacity(0.08)
    )
    
    /// Text - Primary
    static let appTextPrimary = Color(
        light: Color(hex: "#2B1E14"), // Dark brown (warm, not stark black)
        dark: Color.white
    )
    
    /// Text - Secondary
    static let appTextSecondary = Color(
        light: Color(hex: "#5A4A3A"), // Medium brown
        dark: Color.white.opacity(0.7)
    )
    
    /// Text - Tertiary
    static let appTextTertiary = Color(
        light: Color(hex: "#8A7A6A"), // Light brown
        dark: Color.white.opacity(0.4)
    )
    
    /// Progress track (background)
    static let appProgressTrack = Color(
        light: Color(hex: "#E8E8E8"),
        dark: Color.white.opacity(0.08)
    )
    
    /// Glass overlay for buttons
    static let appGlassOverlay = Color(
        light: Color.black.opacity(0.05),
        dark: Color.white.opacity(0.1)
    )
    
    // MARK: - Helper initializer for light/dark variants
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .light:
                return UIColor(light)
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(dark)
            }
        })
    }
}
