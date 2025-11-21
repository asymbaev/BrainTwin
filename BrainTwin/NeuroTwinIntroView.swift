import SwiftUI

// MARK: - Two-Part Intro: Domino Effect + Solution
struct NeuroTwinIntroView: View {
    var onGetStarted: () -> Void = {}
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    // Screen navigation
    @State private var currentScreen = 0 // 0 = domino problem, 1 = solution
    
    // ✅ Computed color scheme based on user preference
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // System
        }
    }

    var body: some View {
        ZStack {
            // ✅ Adaptive background
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
            
            TabView(selection: $currentScreen) {
                // Screen 1: The Problem (Dominoes Falling)
                DominoProblemScreen(
                    onContinue: {
                        withAnimation {
                            currentScreen = 1
                        }
                    },
                    colorScheme: colorScheme
                )
                .tag(0)
                
                // Screen 2: The Solution (Dominos Reversing)
                DominoSolutionScreen(
                    onGetStarted: onGetStarted,
                    colorScheme: colorScheme
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .preferredColorScheme(preferredColorScheme)
    }

    // Satoshi font helper (falls back to system if missing)
    private func ntSatoshi(_ size: CGFloat, weight: NTWeight) -> Font {
        let name: String
        switch weight {
        case .regular:  name = "Satoshi-Regular"
        case .medium:   name = "Satoshi-Medium"
        case .semibold: name = "Satoshi-SemiBold"
        case .bold:     name = "Satoshi-Bold"
        }
        return Font.custom(name, size: size, relativeTo: .body).weight(weight.swiftWeight)
    }

    private enum NTWeight {
        case regular, medium, semibold, bold
        var swiftWeight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }
}

// MARK: - Screen 1: Card Grid Problem (Cascade Falling)
struct DominoProblemScreen: View {
    var onContinue: () -> Void
    var colorScheme: ColorScheme
    
    @State private var cardStates: [[CardState]] = []
    @State private var showMessage = false
    
    let rows = 5
    let cols = 5
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 5x5 Card Grid (like the calendar layout)
            CardGridView(cardStates: cardStates, colorScheme: colorScheme)
                .padding(.horizontal, 40)
            
            Spacer().frame(height: 50)
            
            // Message below grid (psychological hook related to domino effect)
            if showMessage {
                VStack(spacing: 16) {
                    Text("One loose habit.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Everything falls.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            Spacer()
        }
        .onAppear {
            startCardCascade()
        }
    }
    
    private func startCardCascade() {
        // Initialize 5x5 grid of cards in standing position
        cardStates = (0..<rows).map { _ in
            (0..<cols).map { _ in CardState(isFallen: false, rotation: 0) }
        }
        
        // Start cascade after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Start from top-left card (0,0)
            triggerCardFall(row: 0, col: 0)
        }
    }
    
    private func triggerCardFall(row: Int, col: Int) {
        // Check bounds
        guard row < rows, col < cols else {
            // Check if we're completely done
            checkIfComplete()
            return
        }
        
        // Skip if already fallen
        guard !cardStates[row][col].isFallen else {
            // Move to next card
            moveToNextCard(row: row, col: col)
            return
        }
        
        // Fall this card with slower, more realistic physics
        withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) {
            cardStates[row][col].isFallen = true
            cardStates[row][col].rotation = 90
        }
        
        // Trigger next card after delay (slower for more realistic domino effect)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            moveToNextCard(row: row, col: col)
        }
    }
    
    private func moveToNextCard(row: Int, col: Int) {
        // Move left to right, then down (like reading)
        if col < cols - 1 {
            // Move to next column in same row
            triggerCardFall(row: row, col: col + 1)
        } else {
            // Move to first column of next row
            triggerCardFall(row: row + 1, col: 0)
        }
    }
    
    private func checkIfComplete() {
        // Check if all cards have fallen
        let allFallen = cardStates.allSatisfy { row in
            row.allSatisfy { $0.isFallen }
        }
        
        if allFallen {
            // Show message, then auto-transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6)) {
                    showMessage = true
                }
                
                // Auto-transition to solution screen after 1.5s
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onContinue()
                }
            }
        }
    }
    
    private func ntSatoshi(_ size: CGFloat, weight: NTWeight) -> Font {
        let name: String
        switch weight {
        case .regular:  name = "Satoshi-Regular"
        case .medium:   name = "Satoshi-Medium"
        case .semibold: name = "Satoshi-SemiBold"
        case .bold:     name = "Satoshi-Bold"
        }
        return Font.custom(name, size: size, relativeTo: .body).weight(weight.swiftWeight)
    }
    
    private enum NTWeight {
        case regular, medium, semibold, bold
        var swiftWeight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }
}

// MARK: - Screen 2: Card Grid Solution (Reversal)
struct DominoSolutionScreen: View {
    var onGetStarted: () -> Void
    var colorScheme: ColorScheme
    
    @State private var cardStates: [[CardState]] = []
    @State private var showTagline = false
    
    let rows = 5
    let cols = 5
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 5x5 Card Grid
            CardGridView(cardStates: cardStates, colorScheme: colorScheme)
                .padding(.horizontal, 40)
            
            Spacer().frame(height: 50)
            
            // Message (psychological hook - solution)
            if showTagline {
                VStack(spacing: 16) {
                    Text("One Daily Hack.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Everything rises.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            Spacer()
            
            // Get Started button (matching screenshot style)
            Button(action: onGetStarted) {
                Text("Get started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.appAccent)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
            }
            .buttonStyle(.plain)
            
            // Footer text (matching screenshot)
            Text("By continuing, you agree to our")
                .font(.system(size: 11))
                .foregroundStyle(Color.appTextTertiary)
                .padding(.top, 12)
            
            HStack(spacing: 4) {
                Text("Terms of Service")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.appAccent)
                
                Text("and")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appTextTertiary)
                
                Text("Privacy Policy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            .padding(.bottom, 36)
            }
            .onAppear {
            startSolutionAnimation()
        }
    }
    
    private func startSolutionAnimation() {
        // Start with all cards fallen
        cardStates = (0..<rows).map { _ in
            (0..<cols).map { _ in CardState(isFallen: true, rotation: 90) }
        }
        
        // Start standing cards back up after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            reverseCardFall(row: rows - 1, col: cols - 1)
        }
    }
    
    private func reverseCardFall(row: Int, col: Int) {
        // Check bounds
        guard row >= 0, col >= 0 else {
            // All cards standing - show tagline
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6)) {
                    showTagline = true
                }
            }
            return
        }
        
        // Stand this card back up with slower, more realistic physics
        withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) {
            cardStates[row][col].isFallen = false
            cardStates[row][col].rotation = 0
        }
        
        // Trigger previous card after delay (matching forward animation timing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            moveToPreviousCard(row: row, col: col)
        }
    }
    
    private func moveToPreviousCard(row: Int, col: Int) {
        // Move right to left, then up (reverse of falling)
        if col > 0 {
            // Move to previous column in same row
            reverseCardFall(row: row, col: col - 1)
        } else {
            // Move to last column of previous row
            reverseCardFall(row: row - 1, col: cols - 1)
        }
    }
    
    private func ntSatoshi(_ size: CGFloat, weight: NTWeight) -> Font {
        let name: String
        switch weight {
        case .regular:  name = "Satoshi-Regular"
        case .medium:   name = "Satoshi-Medium"
        case .semibold: name = "Satoshi-SemiBold"
        case .bold:     name = "Satoshi-Bold"
        }
        return Font.custom(name, size: size, relativeTo: .body).weight(weight.swiftWeight)
    }

    private enum NTWeight {
        case regular, medium, semibold, bold
        var swiftWeight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }
}

// MARK: - Card Grid View (5x5 Grid like calendar)
struct CardGridView: View {
    var cardStates: [[CardState]]
    var colorScheme: ColorScheme
    
    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 8
            let totalSpacing = spacing * 4 // 4 gaps between 5 cards
            let availableWidth = geometry.size.width - totalSpacing
            let cardSize = availableWidth / 5
            
            VStack(spacing: spacing) {
                ForEach(0..<cardStates.count, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<cardStates[row].count, id: \.self) { col in
                            CardView(
                                state: cardStates[row][col],
                                colorScheme: colorScheme,
                                size: cardSize
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit) // Keep it square
    }
}

// MARK: - Individual Card (with 3D Tipping Animation)
struct CardView: View {
    var state: CardState
    var colorScheme: ColorScheme
    var size: CGFloat
    
    var body: some View {
        ZStack {
            // Ground shadow (grows as card tips forward and to the right)
            Ellipse()
                .fill(Color.black.opacity(0.15))
                .frame(width: size * 0.65, height: size * 0.35)
                .blur(radius: 10)
                .offset(
                    x: (state.rotation / 90) * (size * 0.15),  // Moves right
                    y: (state.rotation / 90) * (size * 0.25)   // Moves down
                )
                .scaleEffect(1.0 + (state.rotation / 90) * 0.3)
                .opacity(state.rotation / 90 * 0.5) // Grows as card falls at angle
            
            // Card body (professional clean style)
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    state.isFallen
                        ? Color.appTextTertiary.opacity(0.25)
                        : Color.appAccent.opacity(0.12)
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            state.isFallen
                                ? Color.appTextTertiary.opacity(0.3)
                                : Color.appAccent.opacity(0.35),
                            lineWidth: 1.5
                        )
                )
                .overlay(
                    // Icon on card - cleaner, more subtle
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: size * 0.45, weight: .medium))
                        .foregroundColor(
                            state.isFallen
                                ? Color.appTextTertiary.opacity(0.5)
                                : Color.appAccent.opacity(0.8)
                        )
                        .opacity(state.isFallen ? 0.3 : 0.7)
                )
                .shadow(
                    color: Color.black.opacity(state.isFallen ? 0.12 : 0.08),
                    radius: 6 + (state.rotation / 90) * 4,              // Shadow spreads as card falls
                    x: (state.rotation / 90) * 4,                        // Shadow moves right
                    y: 3 + (state.rotation / 90) * 6                     // Shadow moves down
                )
                // ✨ 3D TIPPING EFFECT - Tips forward AND sideways at an angle like real dominoes!
                .rotation3DEffect(
                    .degrees(state.rotation),
                    axis: (x: 0.8, y: 0.6, z: 0),  // Rotate on BOTH X and Y axis (forward + right angle)
                    anchor: .bottomTrailing,        // Pivot on bottom-right corner
                    perspective: 0.6                // Add perspective depth
                )
        }
    }
}

// MARK: - Card State Model
struct CardState {
    var isFallen: Bool
    var rotation: Double
}

// MARK: - Daily Hack Card Preview Component
struct DailyHackCardPreview: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(.appAccent)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Hack")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appAccent)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text("The 2-Minute Rule")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appTextTertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appCardBackground)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview
#Preview {
    NeuroTwinIntroView()
}

