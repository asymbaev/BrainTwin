import SwiftUI
import UIKit

// MARK: - Thank You Screen (Post-Purchase)
struct ThankYouView: View {
    var onContinue: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    // Typewriter animation state
    @State private var animatedLine1 = ""
    @State private var animatedLine2 = ""
    @State private var animatedLine3 = ""
    @State private var showButton = false
    
    // Full text to animate
    private let line1 = "Thank you"
    private let line2 = "You made the right choice"
    private let line3 = "Let's begin your rewiring journey"
    
    // Animation config
    private let typingSpeed: TimeInterval = 0.08
    
    // Computed color scheme
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        ZStack {
            // ✅ Adaptive background (same as other screens)
            Color.appBackground.ignoresSafeArea()
            
            // ✅ Subtle depth gradient (only in dark mode)
            if colorScheme == .dark {
                RadialGradient(
                    colors: [
                        Color(white: 0.04),
                        Color.black
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 24) {
                Spacer()
                
                // Thank you icon
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appAccent)
                        .shadow(color: colorScheme == .dark ? Color.appAccent.opacity(0.4) : .clear, radius: 12)
                }
                .padding(.bottom, 16)
                
                // Line 1: "Thank you" (Hero text)
                Text(line1)
                    .font(.system(size: 44, weight: .bold))
                    .kerning(0.5)
                    .foregroundColor(.clear)
                    .overlay(
                        Text(animatedLine1)
                            .font(.system(size: 44, weight: .bold))
                            .kerning(0.5)
                            .foregroundColor(.appTextPrimary)
                            .animation(nil, value: animatedLine1)
                    )
                
                // Line 2: "You made the right choice"
                Text(line2)
                    .font(.system(size: 20, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.clear)
                    .padding(.horizontal, 32)
                    .overlay(
                        Text(animatedLine2)
                            .font(.system(size: 20, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, 32)
                            .animation(nil, value: animatedLine2)
                    )
                
                // Line 3: "Let's begin your rewiring journey"
                Text(line3)
                    .font(.system(size: 18, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.clear)
                    .padding(.horizontal, 40)
                    .overlay(
                        Text(animatedLine3)
                            .font(.system(size: 18, weight: .regular))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.appTextSecondary.opacity(0.8))
                            .padding(.horizontal, 40)
                            .animation(nil, value: animatedLine3)
                    )
                
                Spacer()
                
                // Continue button (appears after animation)
                if showButton {
                    Button(action: onContinue) {
                        Text("Begin")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.appAccent)
                            .cornerRadius(16)
                            .shadow(color: Color.appAccent.opacity(0.3), radius: 12)
                            .padding(.horizontal, 28)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                    .frame(height: 60)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            startTypewriterAnimation()
        }
    }
    
    // MARK: - Typewriter Animation
    
    private func startTypewriterAnimation() {
        // Reset state
        animatedLine1 = ""
        animatedLine2 = ""
        animatedLine3 = ""
        showButton = false
        
        // Start animating line 1
        animateLine(line: line1, currentIndex: 0, lineNumber: 1)
    }
    
    private func animateLine(line: String, currentIndex: Int, lineNumber: Int) {
        guard currentIndex < line.count else {
            // Finished this line, start next
            switch lineNumber {
            case 1:
                // Wait a bit, then start line 2
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateLine(line: line2, currentIndex: 0, lineNumber: 2)
                }
            case 2:
                // Wait a bit, then start line 3
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateLine(line: line3, currentIndex: 0, lineNumber: 3)
                }
            case 3:
                // All lines done, show button
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showButton = true
                    }
                }
            default:
                break
            }
            return
        }
        
        // Get substring up to current index
        let endIndex = line.index(line.startIndex, offsetBy: currentIndex + 1)
        let substring = String(line[..<endIndex])
        
        // Update the appropriate line
        switch lineNumber {
        case 1:
            animatedLine1 = substring
        case 2:
            animatedLine2 = substring
        case 3:
            animatedLine3 = substring
        default:
            break
        }
        
        // Haptic feedback (same pattern as welcome page)
        if lineNumber == 1 {
            // Hero text: every 3 characters
            if currentIndex % 3 == 0 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            // Secondary text: every 2 characters for snappier feel
            if currentIndex % 2 == 0 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        
        // Schedule next character
        DispatchQueue.main.asyncAfter(deadline: .now() + typingSpeed) {
            animateLine(line: line, currentIndex: currentIndex + 1, lineNumber: lineNumber)
        }
    }
}

#Preview {
    ThankYouView {
        print("Continue tapped")
    }
}

