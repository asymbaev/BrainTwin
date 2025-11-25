import SwiftUI
import SuperwallKit
import UIKit

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Binding var isOnboardingComplete: Bool
    @State private var showProfileSetup = false
    @State private var setupComplete = false
    @State private var isProcessingPurchase = false  // ✅ NEW: Show loading after purchase
    
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
//    @AppStorage("welcomeTypewriterCompleted") private var welcomeTypewriterCompleted = false
    
    @State private var welcomeTypewriterCompleted = false
    @State private var valuePropTypewriterCompleted = false
    
    // MARK: - Typewriter config
    private let typewriterCharacterDelay: TimeInterval = 0.065   // slightly slower



    
    @Environment(\.colorScheme) var colorScheme
    
    @FocusState private var isAgeFieldFocused: Bool
    
    // MARK: - Typewriter state 👇
    @State private var animatedWelcomeText = ""
    @State private var animatedQuoteText = ""
    @State private var isAnimatingWelcome = false
    @State private var isAnimatingQuote = false
    
    // Value prop screen typewriter state
    @State private var animatedValueHeadline = ""
    @State private var animatedValueSubtext = ""
    @State private var isAnimatingValueHeadline = false
    @State private var isAnimatingValueSubtext = false
    @State private var showValueIcon = false
    
    @State private var hasAnimatedStep0 = false
    
    // MARK: - Typewriter config
    private let welcomeTypingDelay: TimeInterval = 0.10   // slower, premium
    private let quoteTypingDelay: TimeInterval = 0.065    // slightly faster
    private let valueTypingDelay: TimeInterval = 0.08     // medium speed

    // MARK: - NeuroMeter State (for mood slider)
    @State private var moodLevel: Double = 0.5  // 0.0 to 1.0
    @State private var hasInteractedWithSlider = false
    @State private var showContinuePulse = false

    
    private let fullWelcomeText = "Welcome"
    private let fullQuoteText = "If you don't program your mind, someone else will."
    private let fullValueHeadline = "Your personalized brain rewiring plan"
    private let fullValueSubtext = "Daily neuroscience-backed hacks tailored to you. Plus 24/7 AI coaching."
    // -----------------------------------
    
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
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
            
            AdaptiveStarfieldView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator - NOW 8 STEPS
                HStack(spacing: 8) {
                    ForEach(0..<8, id: \.self) { index in
                        Capsule()
                            .fill(index <= viewModel.currentStep ? Color.appAccent : Color.appTextTertiary)
                            .frame(height: 4)
                    }
                }
                .padding()
                
                // Content
                TabView(selection: $viewModel.currentStep) {
                    screen0_WelcomeIntro.tag(0)
                    screen0_5_ValueProp.tag(1)         // Value proposition
                    screen0_75_MoodCheck.tag(2)        // NEW: Mood check (NeuroMeter Slider)
                    screen1_NameCollection.tag(3)
                    screen1_AgeCollection.tag(4)
                    screen2_GoalSelection.tag(5)
                    screen3_StruggleSelection.tag(6)
                    screen4_TimeSelection.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .fullScreenCover(isPresented: $showProfileSetup) {
                ProfileSetupAnimationView(isComplete: $setupComplete)
                    .onChange(of: setupComplete) { done in
                        if done {
                            print("🎉 Animation complete! Showing paywall next...")
                            
                            // ❌ Do NOT mark onboarding complete here anymore
                            // isOnboardingComplete stays false until user actually subscribes

                            showProfileSetup = false

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showPaywall()
                            }
                        }
                    }
                    .interactiveDismissDisabled(true)
            }

        }
        .preferredColorScheme(preferredColorScheme)
        .overlay {
            // ✅ NEW: Show loading overlay immediately after purchase
            if isProcessingPurchase {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.appAccent)
                        
                        Text("Setting up your account...")
                            .font(.headline)
                            .foregroundColor(.appTextPrimary)
                        
                        Text("This will only take a moment")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .purchaseCompleted)) { _ in
            // Purchase completed! Show loading immediately, then process
            print("🎉 Purchase notification received!")
            
            // ✅ IMMEDIATELY show loading state (no delay)
            withAnimation(.easeInOut(duration: 0.3)) {
                isProcessingPurchase = true
            }
            
            // Process in background
            Task {
                await checkIfUserSubscribed()
                
                // Loading will disappear when ContentView shows ThankYouView
            }
        }
    }
    
    // MARK: - Typewriter helpers 👇

    private func startWelcomeAnimation() {
        if welcomeTypewriterCompleted ||
            (animatedWelcomeText == fullWelcomeText &&
             animatedQuoteText == fullQuoteText) {
            return
        }

        if isAnimatingWelcome || isAnimatingQuote {
            return
        }

        animatedWelcomeText = ""
        animatedQuoteText = ""
        isAnimatingWelcome = true
        isAnimatingQuote = false
        typeNextCharacter(isWelcome: true, index: 0)
    }

    
    private func typeNextCharacter(isWelcome: Bool, index: Int) {
        let fullText = isWelcome ? fullWelcomeText : fullQuoteText
        guard !fullText.isEmpty else { return }

        // If we've reached the end of this text
        if index >= fullText.count {
            if isWelcome {
                // Finished WELCOME → start quote
                isAnimatingWelcome = false
                isAnimatingQuote = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.typeNextCharacter(isWelcome: false, index: 0)
                }
            } else {
                // Finished QUOTE → mark as completed
                isAnimatingQuote = false
                welcomeTypewriterCompleted = true
            }
            return
        }

        // Take characters from start up to index+1
        let endIndex = fullText.index(fullText.startIndex, offsetBy: index + 1)
        let substring = String(fullText[..<endIndex])

        if isWelcome {
            animatedWelcomeText = substring
        } else {
            animatedQuoteText = substring
        }

        // Haptic every 2 characters so it feels smoother, not "machine gun"
        if isWelcome {
            if index % 3 == 0 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            // keep quote at every 2
            if index % 2 == 0 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }


        // Schedule next character with a slightly slower delay
        let delay = isWelcome ? welcomeTypingDelay : quoteTypingDelay

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.typeNextCharacter(isWelcome: isWelcome, index: index + 1)
        }

    }
    
    // MARK: - Value Prop Animation
    
    private func startValuePropAnimation() {
        if valuePropTypewriterCompleted ||
            (animatedValueHeadline == fullValueHeadline &&
             animatedValueSubtext == fullValueSubtext) {
            return
        }
        
        if isAnimatingValueHeadline || isAnimatingValueSubtext {
            return
        }
        
        // Show icon first
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showValueIcon = true
        }
        
        // Start headline animation after icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.animatedValueHeadline = ""
            self.animatedValueSubtext = ""
            self.isAnimatingValueHeadline = true
            self.isAnimatingValueSubtext = false
            self.typeValuePropCharacter(isHeadline: true, index: 0)
        }
    }
    
    private func typeValuePropCharacter(isHeadline: Bool, index: Int) {
        let fullText = isHeadline ? fullValueHeadline : fullValueSubtext
        guard !fullText.isEmpty else { return }
        
        // If we've reached the end of this text
        if index >= fullText.count {
            if isHeadline {
                // Finished HEADLINE → start subtext
                isAnimatingValueHeadline = false
                isAnimatingValueSubtext = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.typeValuePropCharacter(isHeadline: false, index: 0)
                }
            } else {
                // Finished SUBTEXT → mark as completed
                isAnimatingValueSubtext = false
                valuePropTypewriterCompleted = true
            }
            return
        }
        
        // Take characters from start up to index+1
        let endIndex = fullText.index(fullText.startIndex, offsetBy: index + 1)
        let substring = String(fullText[..<endIndex])
        
        if isHeadline {
            animatedValueHeadline = substring
        } else {
            animatedValueSubtext = substring
        }
        
        // Haptic feedback
        if index % 3 == 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        // Schedule next character
        DispatchQueue.main.asyncAfter(deadline: .now() + valueTypingDelay) {
            self.typeValuePropCharacter(isHeadline: isHeadline, index: index + 1)
        }
    }


    
    // MARK: - Paywall (Age-based routing)
    @State private var paywallAttempts = 0
    
    private func showPaywall() {
        paywallAttempts += 1
        
        // Prevent infinite loop - max 3 attempts
        if paywallAttempts > 3 {
            print("⚠️ Paywall failed to show after 3 attempts - allowing user through")
            isOnboardingComplete = true
            return
        }
        let campaign = determineCampaignByAge(age: viewModel.ageInt ?? 25)
        
        print("🎯 Triggering Superwall campaign: \(campaign) for age: \(viewModel.ageInt ?? 25)")
        print("   Attempt: \(paywallAttempts)/3")
        print("   Current subscriptionStatus: \(Superwall.shared.subscriptionStatus)")
        
        Superwall.shared.register(placement: campaign)
        
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await checkIfUserSubscribed()
        }
    }
    
    /// Determines which Superwall campaign to trigger based on user's age
    private func determineCampaignByAge(age: Int) -> String {
        switch age {
        case 0..<18:
            return "Under 18"
        case 18...22:
            return "18-22"
        case 23...28:
            return "23-28"
        case 29...40:
            return "29-40"
        default: // 41+
            return "Over 40"
        }
    }

    private func checkIfUserSubscribed() async {
        print("🔍 [OnboardingView] Starting subscription check...")
        
        await SubscriptionManager.shared.refreshSubscription()
        
        // CRITICAL: Only complete onboarding if BOTH subscription AND account exist
        let isSubscribed = SubscriptionManager.shared.isSubscribed
        let hasUserId = SupabaseManager.shared.userId != nil
        let userId = SupabaseManager.shared.userId ?? "nil"
        
        print("📊 [OnboardingView] First check:")
        print("   isSubscribed: \(isSubscribed)")
        print("   hasUserId: \(hasUserId)")
        print("   userId: \(userId)")
        
        if isSubscribed && hasUserId {
            // User has BOTH subscription AND account created from receipt
            print("✅ [OnboardingView] Both conditions met! Completing onboarding...")
            await MainActor.run {
                completeOnboarding()
            }
        } else {
            // Wait longer for account creation to complete
            print("⏳ [OnboardingView] Conditions not met, waiting 3 seconds...")
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            await MainActor.run {
                let stillSubscribed = SubscriptionManager.shared.isSubscribed
                let nowHasUserId = SupabaseManager.shared.userId != nil
                let nowUserId = SupabaseManager.shared.userId ?? "nil"
                
                print("📊 [OnboardingView] Recheck after 3s:")
                print("   isSubscribed: \(stillSubscribed)")
                print("   hasUserId: \(nowHasUserId)")
                print("   userId: \(nowUserId)")
                
                if stillSubscribed && nowHasUserId {
                    // Account created successfully
                    print("✅ [OnboardingView] Both conditions met on recheck! Completing onboarding...")
                    completeOnboarding()
                } else {
                    print("⚠️ [OnboardingView] Conditions still not met after recheck")
                    print("   → Showing paywall again...")
                    
                    // Show paywall again
                    showPaywall()
                }
            }
        }
    }

    private func completeOnboarding() {
        isOnboardingComplete = true
        UserDefaults.standard.set(true, forKey: "justCompletedOnboarding")
        paywallAttempts = 0 // Reset counter for next time
        print("✅ Onboarding complete - user is subscribed!")
    }
    
    private var screen0_WelcomeIntro: some View {
        VStack(spacing: 0) {
            // App name - cleaner, smaller
            Text("NeuroHack")
                .font(.system(size: 22, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(.appTextPrimary)
                .padding(.top, 32)

            Spacer()

            VStack(spacing: 24) {
                // --- WELCOME TEXT --- More premium styling
                Text(fullWelcomeText)
                    .font(.system(size: 42, weight: .bold))   // placeholder space
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.clear)
                    .overlay(
                        Text(animatedWelcomeText)
                            .font(.system(size: 42, weight: .bold))   // animated hero text
                            .tracking(0.5)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.appTextPrimary)
                            .animation(nil, value: animatedWelcomeText)
                    )

                // --- QUOTE TEXT --- Clean, professional, NO italics
                Text(fullQuoteText)
                    .font(.system(size: 18, weight: .regular))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.clear)
                    .overlay(
                        Text(animatedQuoteText)
                            .font(.system(size: 18, weight: .regular))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, 40)
                            .animation(nil, value: animatedQuoteText)
                    )
                    .padding(.top, 4)


                // --- STARS --- More subtle, refined
                HStack(spacing: 6) {
                    Image(systemName: "laurel.leading")
                        .font(.system(size: 14))
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                    }
                    Image(systemName: "laurel.trailing")
                        .font(.system(size: 14))
                }
                .foregroundColor(.appAccent)
                .padding(.top, 20)
                // Make sure stars never inherit weird animations from the text changes
                .animation(nil, value: animatedQuoteText)
                .animation(nil, value: animatedWelcomeText)
            }

            Spacer()

            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 1
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
        .padding(.horizontal, 20)
        .onAppear {
            if welcomeTypewriterCompleted {
                // already ran → show final static text
                animatedWelcomeText = fullWelcomeText
                animatedQuoteText  = fullQuoteText
                isAnimatingWelcome = false
                isAnimatingQuote   = false
            } else {
                startWelcomeAnimation()
            }
        }
    }
    
    // MARK: - Screen 0.5: Value Proposition (NEW)
    
    private var screen0_5_ValueProp: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)
            
            // Lightning icon - animated entrance
            if showValueIcon {
                Text("⚡")
                    .font(.system(size: 64))
                    .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
                .frame(height: 40)
            
            VStack(spacing: 24) {
                // --- HEADLINE --- Typewriter
                Text(fullValueHeadline)
                    .font(.system(size: 36, weight: .bold))
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.clear)
                    .overlay(
                        Text(animatedValueHeadline)
                            .font(.system(size: 36, weight: .bold))
                            .tracking(0.5)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.appTextPrimary)
                            .animation(nil, value: animatedValueHeadline)
                    )
                    .padding(.horizontal, 32)
                
                // --- SUBTEXT --- Typewriter
                Text(fullValueSubtext)
                    .font(.system(size: 17, weight: .regular))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.clear)
                    .overlay(
                        Text(animatedValueSubtext)
                            .font(.system(size: 17, weight: .regular))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, 36)
                            .animation(nil, value: animatedValueSubtext)
                    )
                    .padding(.top, 4)
            }
            
            Spacer()
            
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 2
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
        .onAppear {
            if valuePropTypewriterCompleted {
                // Already completed - show final state
                showValueIcon = true
                animatedValueHeadline = fullValueHeadline
                animatedValueSubtext = fullValueSubtext
                isAnimatingValueHeadline = false
                isAnimatingValueSubtext = false
            } else {
                startValuePropAnimation()
            }
        }
    }
    
    // MARK: - Screen 0.75: Mood Check (NeuroMeter Slider)
    
    private var screen0_75_MoodCheck: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.appTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
            
            Spacer()
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("How's your mental state right now?")
                        .font(.title2.bold())
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Text("Drag the slider to match your energy")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                    .frame(height: 20)
                
                // Lightning Icon - Animated based on mood level
                Image(systemName: "bolt.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.appAccent)
                    .shadow(
                        color: .appAccent.opacity(moodLevel * 0.6),
                        radius: 16 + (moodLevel * 24),
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(0.9 + (moodLevel * 0.15))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: moodLevel)
                
                // Mood Label - Shows current mood text
                Text(currentMoodLabel)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.appTextPrimary)
                    .animation(.easeOut(duration: 0.2), value: currentMoodLabel)
                    .frame(height: 32)
                
                Spacer()
                    .frame(height: 40)
                
                // NeuroMeter Slider
                VStack(spacing: 16) {
                    // Custom Slider Track
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 12)
                            
                            // Active track (yellow fill)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.appAccent.opacity(0.8),
                                            Color.appAccent
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * moodLevel, height: 12)
                            
                            // Slider thumb
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                .offset(x: (geometry.size.width - 32) * moodLevel)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            // Calculate new mood level based on drag position
                                            let newLevel = min(max(0, value.location.x / geometry.size.width), 1)
                                            moodLevel = newLevel
                                            
                                            // Mark as interacted on first drag
                                            if !hasInteractedWithSlider {
                                                hasInteractedWithSlider = true
                                                
                                                // Pulse animation for continue button
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                        showContinuePulse = true
                                                    }
                                                }
                                            }
                                            
                                            // Update ViewModel's selectedMood based on slider position
                                            viewModel.selectMood(currentMoodValue)
                                            
                                            // Haptic feedback
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                )
                        }
                        .frame(height: 32)
                    }
                    .frame(height: 32)
                    .padding(.horizontal, 40)
                    
                    // Slider labels
                    HStack {
                        Text("Low Energy")
                            .font(.caption)
                            .foregroundColor(.appTextTertiary)
                        
                        Spacer()
                        
                        Text("High Energy")
                            .font(.caption)
                            .foregroundColor(.appTextTertiary)
                    }
                    .padding(.horizontal, 40)
                }
            }
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 3
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!hasInteractedWithSlider)
            .opacity(hasInteractedWithSlider ? 1 : 0.5)
            .scaleEffect(showContinuePulse ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showContinuePulse)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .onAppear {
                // Reset pulse after animation completes
                if showContinuePulse {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            showContinuePulse = false
                        }
                    }
                }
            }
        }
        .onAppear {
            // Initialize slider to middle position on first appear
            if !hasInteractedWithSlider {
                moodLevel = 0.5
            }
        }
    }
    
    // MARK: - NeuroMeter Mood Mapping
    
    /// Maps slider position (0.0-1.0) to mood label text
    /// Adjust these thresholds to fine-tune the mood ranges
    private var currentMoodLabel: String {
        switch moodLevel {
        case 0.0..<0.125:
            return "Overwhelmed"
        case 0.125..<0.25:
            return "Anxious"
        case 0.25..<0.375:
            return "Low energy"
        case 0.375..<0.5:
            return "Neutral"
        case 0.5..<0.625:
            return "Calm"
        case 0.625..<0.75:
            return "Good"
        case 0.75..<0.875:
            return "Motivated"
        default: // 0.875...1.0
            return "Inspired"
        }
    }
    
    /// Maps slider position to the mood value used by ViewModel
    /// These match the internal mood identifiers in your existing system
    private var currentMoodValue: String {
        switch moodLevel {
        case 0.0..<0.125:
            return "overwhelmed"
        case 0.125..<0.25:
            return "anxious"
        case 0.25..<0.375:
            return "low_energy"
        case 0.375..<0.5:
            return "neutral"
        case 0.5..<0.625:
            return "calm"
        case 0.625..<0.75:
            return "good"
        case 0.75..<0.875:
            return "motivated"
        default: // 0.875...1.0
            return "inspired"
        }
    }
    
    // MARK: - Screen 1: Name Collection
    
    private var screen1_NameCollection: some View {
        VStack(spacing: 24) {
            // 🔙 Back button
                HStack {
                    Button {
                        withAnimation {
                            viewModel.currentStep = 2
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.appTextPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text("What's your name?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Let's personalize your experience")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            // Name Input
            VStack(alignment: .leading, spacing: 12) {
                TextField("Enter your first name", text: $viewModel.userName)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .foregroundColor(.appTextPrimary)
                    .accentColor(.appAccent)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                viewModel.userName.isEmpty ? Color.appCardBorder : Color.appAccent,
                                lineWidth: viewModel.userName.isEmpty ? 1 : 2
                            )
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                
                if !viewModel.userName.isEmpty && !viewModel.isNameValid {
                    Text("Please enter at least 2 characters")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 4
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isNameValid)
            .opacity(viewModel.isNameValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 2: Age Collection
    
    private var screen1_AgeCollection: some View {
        VStack(spacing: 24) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 3
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.appTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text("How old are you?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text("This helps us personalize your journey")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            // Age Input
            VStack(alignment: .leading, spacing: 12) {
                TextField("Enter your age", text: $viewModel.userAge)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .foregroundColor(.appTextPrimary)
                    .accentColor(.appAccent)
                    .keyboardType(.numberPad)
                    .focused($isAgeFieldFocused)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                viewModel.userAge.isEmpty ? Color.appCardBorder : Color.appAccent,
                                lineWidth: viewModel.userAge.isEmpty ? 1 : 2
                            )
                    )
                
                if !viewModel.userAge.isEmpty && !viewModel.isAgeValid {
                    Text("Please enter a valid age (13-120)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
                
                Text("We use this to personalize content and track demographics")
                    .font(.caption)
                    .foregroundColor(.appTextTertiary)
                    .padding(.leading, 4)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                isAgeFieldFocused = false
                withAnimation {
                    viewModel.currentStep = 5
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isAgeValid)
            .opacity(viewModel.isAgeValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 3: Goal Selection
    
    private var screen2_GoalSelection: some View {
        VStack(spacing: 24) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 4
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.appTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text("What's your main goal?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Choose one or describe your own")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            // Goal Options
            VStack(spacing: 16) {
                GoalOptionButton(
                    title: "Build better habits",
                    isSelected: viewModel.selectedGoal == "Build better habits",
                    action: { viewModel.selectGoal("Build better habits") }
                )
                
                GoalOptionButton(
                    title: "Overcome procrastination",
                    isSelected: viewModel.selectedGoal == "Overcome procrastination",
                    action: { viewModel.selectGoal("Overcome procrastination") }
                )
                
                GoalOptionButton(
                    title: "Reduce anxiety/stress",
                    isSelected: viewModel.selectedGoal == "Reduce anxiety/stress",
                    action: { viewModel.selectGoal("Reduce anxiety/stress") }
                )
                
                // Custom Goal Option
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        viewModel.selectGoal("custom")
                    } label: {
                        HStack {
                            Text("Other - Set your own goal")
                                .font(.body)
                                .foregroundColor(.appTextPrimary)
                            
                            Spacer()
                            
                            Circle()
                                .strokeBorder(Color.appCardBorder, lineWidth: 2)
                                .background(
                                    Circle()
                                        .fill(viewModel.selectedGoal == "custom" ? Color.appAccent : Color.clear)
                                )
                                .frame(width: 24, height: 24)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.appCardBorder, lineWidth: 1)
                        )
                    }
                    
                    if viewModel.selectedGoal == "custom" {
                        TextField("e.g., Build discipline to finish my startup tasks", text: $viewModel.customGoalText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .foregroundColor(.appTextPrimary)
                            .accentColor(.appAccent)
                            .placeholder(when: viewModel.customGoalText.isEmpty) {
                                Text("e.g., Build discipline to finish my startup tasks")
                                    .foregroundColor(.appTextTertiary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appCardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
                            )
                            .lineLimit(2...4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 6
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isGoalValid)
            .opacity(viewModel.isGoalValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 4: Struggle Selection
    
    private var screen3_StruggleSelection: some View {
        VStack(spacing: 24) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 5
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.appTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Text("What's your biggest struggle?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                
                Text("This helps us personalize your journey")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            
            Spacer()
            
            // Struggle Options
            VStack(spacing: 12) {
                StruggleOptionButton(
                    title: "I get distracted easily",
                    isSelected: viewModel.selectedStruggle == "I get distracted easily",
                    action: { viewModel.selectStruggle("I get distracted easily") }
                )
                
                StruggleOptionButton(
                    title: "I keep falling back to old habits",
                    isSelected: viewModel.selectedStruggle == "I keep falling back to old habits",
                    action: { viewModel.selectStruggle("I keep falling back to old habits") }
                )
                
                StruggleOptionButton(
                    title: "I start strong but lose motivation",
                    isSelected: viewModel.selectedStruggle == "I start strong but lose motivation",
                    action: { viewModel.selectStruggle("I start strong but lose motivation") }
                )
                
                StruggleOptionButton(
                    title: "I feel overwhelmed",
                    isSelected: viewModel.selectedStruggle == "I feel overwhelmed",
                    action: { viewModel.selectStruggle("I feel overwhelmed") }
                )
                
                // Custom Struggle Option
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        viewModel.selectStruggle("other")
                    } label: {
                        HStack {
                            Text("Other")
                                .font(.body)
                                .foregroundColor(.appTextPrimary)
                            
                            Spacer()
                            
                            Circle()
                                .strokeBorder(Color.appCardBorder, lineWidth: 2)
                                .background(
                                    Circle()
                                        .fill(viewModel.selectedStruggle == "other" ? Color.appAccent : Color.clear)
                                )
                                .frame(width: 24, height: 24)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.appCardBorder, lineWidth: 1)
                        )
                    }
                    
                    if viewModel.selectedStruggle == "other" {
                        TextField("Describe your biggest challenge...", text: $viewModel.customStruggleText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .foregroundColor(.appTextPrimary)
                            .accentColor(.appAccent)
                            .placeholder(when: viewModel.customStruggleText.isEmpty) {
                                Text("Describe your biggest challenge...")
                                    .foregroundColor(.appTextTertiary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appCardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
                            )
                            .lineLimit(2...4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 7
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isStruggleValid)
            .opacity(viewModel.isStruggleValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 5: Time Selection
    
    private var screen4_TimeSelection: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 6
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.appTextPrimary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Text("When do you work best?")
                            .font(.title.bold())
                            .foregroundColor(.appTextPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("We'll remind you at the right time")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.top, 20)
                    
                    // Time Options
                    VStack(spacing: 12) {
                        TimeOptionButton(
                            title: "Morning",
                            subtitle: "6:00 AM - 9:00 AM",
                            timeValue: "morning",
                            isSelected: viewModel.selectedTime == "morning",
                            action: { viewModel.selectTime("morning") }
                        )
                        
                        TimeOptionButton(
                            title: "Midday",
                            subtitle: "12:00 PM - 3:00 PM",
                            timeValue: "midday",
                            isSelected: viewModel.selectedTime == "midday",
                            action: { viewModel.selectTime("midday") }
                        )
                        
                        TimeOptionButton(
                            title: "Evening",
                            subtitle: "5:00 PM - 8:00 PM",
                            timeValue: "evening",
                            isSelected: viewModel.selectedTime == "evening",
                            action: { viewModel.selectTime("evening") }
                        )
                        
                        TimeOptionButton(
                            title: "Night",
                            subtitle: "8:00 PM - 11:00 PM",
                            timeValue: "night",
                            isSelected: viewModel.selectedTime == "night",
                            action: { viewModel.selectTime("night") }
                        )
                        
                        TimeOptionButton(
                            title: "I'll set it later",
                            subtitle: "Choose your own time",
                            timeValue: "custom",
                            isSelected: viewModel.selectedTime == "custom",
                            action: { viewModel.selectTime("custom") }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Notification Info
                    if !viewModel.selectedTime.isEmpty {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.appAccent)
                                Text("We'll ask for notification permission")
                                    .font(.caption)
                                    .foregroundColor(.appTextSecondary)
                            }
                        }
                        .padding(.top, 8)
                        .transition(.opacity)
                    }
                }
            }
            
            // Complete Button
            Button {
                Task {
                    await viewModel.completeOnboarding()
                    setupComplete = false
                    showProfileSetup = true
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Complete Setup")
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(viewModel.selectedTime.isEmpty || viewModel.isLoading)
            .opacity(viewModel.selectedTime.isEmpty || viewModel.isLoading ? 0.5 : 1)
            .padding()
        }
    }
}

// MARK: - Button Components (unchanged)

struct GoalOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.appTextPrimary)
                
                Spacer()
                
                Circle()
                    .strokeBorder(Color.appCardBorder, lineWidth: 2)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.appAccent : Color.clear)
                    )
                    .frame(width: 24, height: 24)
            }
            .padding()
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
            )
        }
    }
}

struct StruggleOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Circle()
                    .strokeBorder(Color.appCardBorder, lineWidth: 2)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.appAccent : Color.clear)
                    )
                    .frame(width: 24, height: 24)
            }
            .padding()
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
            )
        }
    }
}

struct TimeOptionButton: View {
    let title: String
    let subtitle: String
    let timeValue: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.appTextPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
                
                Spacer()
                
                Circle()
                    .strokeBorder(Color.appCardBorder, lineWidth: 2)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.appAccent : Color.clear)
                    )
                    .frame(width: 24, height: 24)
            }
            .padding()
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.appCardBorder, lineWidth: 1)
            )
        }
    }
}

struct OnboardingButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appAccent)
            .cornerRadius(12)
            .shadow(color: Color.appAccent.opacity(0.3), radius: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// NOTE: MoodCard component removed - no longer needed with slider design

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct AdaptiveStarfieldView: View {
    @State private var stars: [Star] = []
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(stars) { star in
                    Circle()
                        .fill(starColor)
                        .frame(width: star.size, height: star.size)
                        .position(x: star.x, y: star.y)
                        .opacity(star.opacity * opacityMultiplier)
                        .blur(radius: star.blur)
                }
            }
            .onAppear {
                generateStars(in: geometry.size)
            }
        }
    }
    
    private var starColor: Color {
        colorScheme == .dark ? .white : Color(white: 0.3)
    }
    
    private var opacityMultiplier: Double {
        colorScheme == .dark ? 1.0 : 0.3
    }
    
    private func generateStars(in size: CGSize) {
        var generatedStars: [Star] = []
        
        for i in 0..<150 {
            let star = Star(
                id: i,
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 0.5...2.5),
                opacity: Double.random(in: 0.2...0.9),
                blur: CGFloat.random(in: 0...1.5),
                animationDelay: Double.random(in: 0...3)
            )
            generatedStars.append(star)
        }
        
        stars = generatedStars
        
        for (index, star) in stars.enumerated() {
            animateStar(at: index, delay: star.animationDelay)
        }
    }
    
    private func animateStar(at index: Int, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: Double.random(in: 1.5...3.5)).repeatForever(autoreverses: true)) {
                if index < stars.count {
                    stars[index].opacity = Double.random(in: 0.2...0.9)
                }
            }
        }
    }
}

struct Star: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    var opacity: Double
    let blur: CGFloat
    let animationDelay: Double
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
