import SwiftUI
import SuperwallKit
import UIKit

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Binding var isOnboardingComplete: Bool
    @State private var showProfileSetup = false
    @State private var isProcessingPurchase = false  // ✅ NEW: Show loading after purchase
    
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
//    @AppStorage("welcomeTypewriterCompleted") private var welcomeTypewriterCompleted = false
    
    @State private var welcomeTypewriterCompleted = false
    @State private var valuePropTypewriterCompleted = false
    
    // MARK: - Typewriter config
    private let typewriterCharacterDelay: TimeInterval = 0.065   // slightly slower
    
    @FocusState private var isAgeFieldFocused: Bool
    
    // Bottom sheet states for custom inputs
    @State private var showCustomGoalSheet = false
    @State private var showCustomStruggleSheet = false
    
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
    private let welcomeTypingDelay: TimeInterval = 0.06   // faster
    private let quoteTypingDelay: TimeInterval = 0.045    // faster
    private let valueTypingDelay: TimeInterval = 0.05     // faster

    // MARK: - NeuroMeter State (for mood slider)
    @State private var moodLevel: Double = 0.5  // 0.0 to 1.0
    @State private var hasInteractedWithSlider = false
    @State private var showContinuePulse = false

    
    private let fullWelcomeText = "Welcome"
    private let fullQuoteText = "If you don't program your mind, someone else will."
    private let fullValueHeadline = "Momentum starts now."
    private let fullValueSubtext = "Backed by neuroscience. Powered by AI. Tailored to you."
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
            
            AdaptiveStarfieldView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator - NOW 15 STEPS
                HStack(spacing: 8) {
                    ForEach(0..<15, id: \.self) { index in
                        Capsule()
                            .fill(index <= viewModel.currentStep ? Color.appAccentGradient : LinearGradient(colors: [Color.appTextTertiary], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 4)
                    }
                }
                .padding()
                
                // Content
                TabView(selection: $viewModel.currentStep) {
                    screen0_WelcomeIntro.tag(0)
                    screen0_5_ValueProp.tag(1)         // Value proposition
                    screen0_75_MoodCheck.tag(2)        // Mood check (NeuroMeter Slider)
                    screen2_GoalSelection.tag(3)       // Goal selection after mood
                    screen1_AgeCollection.tag(4)       // Age selection (no name screen)
                    screen3_StruggleSelection.tag(5)   // Struggle selection
                    screen_DidYouKnow.tag(6)           // Did you know? facts
                    screen_GeneratingPlan.tag(7)       // Loading/generating plan
                    screen_UhOh.tag(8)                 // Uh Oh animation screen
                    screen_FeedbackStats.tag(9)        // Personalized feedback based on mood + struggle
                    screen_UnlockCards.tag(10)         // Unlock solution cards - moved before graphs
                    screen_LifeWithoutHacks.tag(11)    // Red graph declining - life without hacks
                    screen_LifeWithHacks.tag(12)       // Green graph rising - life with hacks
                    screen_Rating.tag(13)              // Rating screen
                    screen_NotificationPermission.tag(14)  // Notification permission
                    screen_Commitment.tag(15)          // Commitment screen (before paywall)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .disabled(false) // Allows button interaction
                .onAppear {
                    UIScrollView.appearance().isScrollEnabled = false
                }
                .onDisappear {
                    UIScrollView.appearance().isScrollEnabled = true
                }
            }
            .onChange(of: showProfileSetup) { newValue in
                if newValue {
                    // Directly show paywall when triggered
                    print("🎉 Showing paywall...")
                    showProfileSetup = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPaywall()
                    }
                }
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

            // Centered group: icon + text
            VStack(spacing: 32) {
                // Lightning icon - animated entrance
                if showValueIcon {
                    Text("⚡")
                        .font(.system(size: 64))
                        .transition(.scale.combined(with: .opacity))
                }

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
                }
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
                
                // Lightning Emoji - Clean and simple
                ZStack {
                    // Outer glow layers - multiple for brighter effect
                    ForEach(0..<3) { index in
                        Text("⚡️")
                            .font(.system(size: 96))
                            .opacity(0.3 * moodLevel)
                            .blur(radius: 20 + (CGFloat(index) * 10))
                    }

                    // Main lightning emoji
                    Text("⚡️")
                        .font(.system(size: 96))
                        .shadow(
                            color: Color.appAccent.opacity(0.4 + (moodLevel * 0.6)),
                            radius: 20 + (moodLevel * 40),
                            x: 0,
                            y: 0
                        )
                        .shadow(
                            color: Color.appAccent.opacity(moodLevel * 0.8),
                            radius: 30 + (moodLevel * 30),
                            x: 0,
                            y: 0
                        )
                }
                .scaleEffect(0.85 + (moodLevel * 0.25))
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
                            
                            // Active track (gradient fill)
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
                    viewModel.currentStep = 3  // Go to goal selection
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
    
    // MARK: - Age Selection (Redesigned with buttons)

    private var screen1_AgeCollection: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 3  // Back to goal selection
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
            .padding(.bottom, 12)  // ✅ Reduced from 20 to 12

            // Lightning icon - consistent with goal screen
            Text("⚡")
                .font(.system(size: 64))
                .padding(.bottom, 12)  // ✅ Reduced from 16 to 12

            // Header
            VStack(spacing: 12) {
                Text("How old are you?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)

                Text("This helps us personalize your journey")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.bottom, 20)  // ✅ Reduced from 24 to 20

            // Age Range Options
            VStack(spacing: 12) {
                AgeRangeButton(
                    title: "Under 18",
                    isSelected: viewModel.selectedAgeRange == "Under 18",
                    action: { viewModel.selectAgeRange("Under 18") }
                )

                AgeRangeButton(
                    title: "18-24",
                    isSelected: viewModel.selectedAgeRange == "18-24",
                    action: { viewModel.selectAgeRange("18-24") }
                )

                AgeRangeButton(
                    title: "25-34",
                    isSelected: viewModel.selectedAgeRange == "25-34",
                    action: { viewModel.selectAgeRange("25-34") }
                )

                AgeRangeButton(
                    title: "35-44",
                    isSelected: viewModel.selectedAgeRange == "35-44",
                    action: { viewModel.selectAgeRange("35-44") }
                )

                AgeRangeButton(
                    title: "45-54",
                    isSelected: viewModel.selectedAgeRange == "45-54",
                    action: { viewModel.selectAgeRange("45-54") }
                )

                AgeRangeButton(
                    title: "55+",
                    isSelected: viewModel.selectedAgeRange == "55+",
                    action: { viewModel.selectAgeRange("55+") }
                )
            }
            .padding(.horizontal)

            Spacer()

            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 5  // Go to struggle selection
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(viewModel.selectedAgeRange.isEmpty)
            .opacity(viewModel.selectedAgeRange.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 24)
            .padding(.top, 12)  // ✅ Reduced from 16 to 12
            .padding(.bottom, 40)
        }
    }

    // MARK: - Screen 3: Struggle Selection
    
    private var screen2_GoalSelection: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 2  // Back to mood check
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
            .padding(.bottom, 12)  // ✅ Reduced from 20 to 12

            // ✅ Centered content group
            VStack(spacing: 0) {
                // Lightning icon - matching Value Prop screen
                Text("⚡")
                    .font(.system(size: 64))
                    .padding(.bottom, 12)  // ✅ Reduced from 16 to 12

                // Header
                VStack(spacing: 12) {
                    Text("What's your main goal?")
                        .font(.title.bold())
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your hacks will be designed for this")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.bottom, 20)  // ✅ Reduced from 24 to 20

                // Goal Options - Scrollable
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                GoalOptionButton(
                    title: "Succeed at my current mission",
                    isSelected: viewModel.selectedGoal == "Succeed at my current mission",
                    action: { viewModel.selectGoal("Succeed at my current mission") }
                )

                GoalOptionButton(
                    title: "Rewire my brain to unlock potential",
                    isSelected: viewModel.selectedGoal == "Rewire my brain to unlock potential",
                    action: { viewModel.selectGoal("Rewire my brain to unlock potential") }
                )

                GoalOptionButton(
                    title: "Think outside the box",
                    isSelected: viewModel.selectedGoal == "Think outside the box",
                    action: { viewModel.selectGoal("Think outside the box") }
                )

                GoalOptionButton(
                    title: "Attract luck or happiness",
                    isSelected: viewModel.selectedGoal == "Attract luck or happiness",
                    action: { viewModel.selectGoal("Attract luck or happiness") }
                )

                GoalOptionButton(
                    title: "Learn manifesting",
                    isSelected: viewModel.selectedGoal == "Learn manifesting",
                    action: { viewModel.selectGoal("Learn manifesting") }
                )

                // Custom Goal Option
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        viewModel.selectedGoal = "custom"
                        showCustomGoalSheet = true
                    } label: {
                        HStack {
                            Text("Other - Set custom goal")
                                .font(.body)
                                .foregroundColor(.appTextPrimary)

                            Spacer()

                            // Checkmark when selected, empty circle when not
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.appCardBorder, lineWidth: 2)
                                    .frame(width: 24, height: 24)

                                if viewModel.selectedGoal == "custom" {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.appAccent)
                                }
                            }
                        }
                        .padding()
                        .background(Color.clear)  // Transparent background
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.selectedGoal == "custom" ? Color.appAccentGradient : LinearGradient(colors: [Color.appCardBorder], startPoint: .leading, endPoint: .trailing), lineWidth: viewModel.selectedGoal == "custom" ? 2 : 1)
                        )
                    }
                }
            }
            .padding(.horizontal)
            }
            }  // ✅ End of centered content group

            // Continue Button - Fixed at bottom
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 4  // Go to name collection
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isGoalValid)
            .opacity(viewModel.isGoalValid ? 1 : 0.5)
            .padding(.horizontal, 24)
            .padding(.top, 12)  // ✅ Reduced from 16 to 12
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showCustomGoalSheet) {
            CustomInputBottomSheet(
                title: "What's your goal?",
                placeholder: "e.g., Build discipline to finish my startup tasks",
                text: $viewModel.customGoalText
            )
        }
    }
    
    private var screen3_StruggleSelection: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 4  // Back to age collection
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
            .padding(.bottom, 12)

            // Lightning icon - consistent with other screens
            Text("⚡")
                .font(.system(size: 64))
                .padding(.bottom, 12)

            // Header
            VStack(spacing: 12) {
                Text("What holds you back?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Pick what resonates most")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.bottom, 20)

            // Struggle Options - Scrollable
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                StruggleOptionButton(
                    title: "I have negative self-talk",
                    isSelected: viewModel.selectedStruggle == "I have negative self-talk",
                    action: { viewModel.selectStruggle("I have negative self-talk") }
                )

                StruggleOptionButton(
                    title: "I tend to overreact to everything",
                    isSelected: viewModel.selectedStruggle == "I tend to overreact to everything",
                    action: { viewModel.selectStruggle("I tend to overreact to everything") }
                )

                StruggleOptionButton(
                    title: "I take everything too seriously",
                    isSelected: viewModel.selectedStruggle == "I take everything too seriously",
                    action: { viewModel.selectStruggle("I take everything too seriously") }
                )

                StruggleOptionButton(
                    title: "I have low self-esteem",
                    isSelected: viewModel.selectedStruggle == "I have low self-esteem",
                    action: { viewModel.selectStruggle("I have low self-esteem") }
                )
                
                // Custom Struggle Option
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        viewModel.selectedStruggle = "other"
                        showCustomStruggleSheet = true
                    } label: {
                        HStack {
                            Text("Something else...")
                                .font(.body)
                                .foregroundColor(.appTextPrimary)

                            Spacer()

                            // Checkmark when selected, empty circle when not
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.appCardBorder, lineWidth: 2)
                                    .frame(width: 24, height: 24)

                                if viewModel.selectedStruggle == "other" {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.appAccent)
                                }
                            }
                        }
                        .padding()
                        .background(Color.clear)  // Transparent background
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.selectedStruggle == "other" ? Color.appAccentGradient : LinearGradient(colors: [Color.appCardBorder], startPoint: .leading, endPoint: .trailing), lineWidth: viewModel.selectedStruggle == "other" ? 2 : 1)
                        )
                    }
                }
            }
            .padding(.horizontal)
            }

            // Continue Button - Fixed at bottom
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 6  // Go to Did You Know screen
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isStruggleValid)
            .opacity(viewModel.isStruggleValid ? 1 : 0.5)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showCustomStruggleSheet) {
            CustomInputBottomSheet(
                title: "What holds you back?",
                placeholder: "Describe your biggest challenge...",
                text: $viewModel.customStruggleText
            )
        }
    }

    // MARK: - Screen 6: Did You Know? Facts

    private var screen_DidYouKnow: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 5  // Back to struggle selection
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
            .padding(.bottom, 12)

            // Lightning icon
            Text("⚡")
                .font(.system(size: 64))
                .padding(.bottom, 12)

            // Header
            VStack(spacing: 12) {
                Text("Did you know?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Key insights about how your mind works")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 20)

            // Facts - Scrollable with animations + fade gradient
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        DidYouKnowFactView(
                            emoji: "⚡",
                            title: "Small habits beat motivation",
                            description: "Daily micro-actions create real change far more effectively than waiting to feel motivated.",
                            index: 0
                        )

                        DidYouKnowFactView(
                            emoji: "💭",
                            title: "Negative self-talk becomes your default setting",
                            description: "Repeating certain thoughts conditions your mind to follow those patterns automatically.",
                            index: 1
                        )

                        DidYouKnowFactView(
                            emoji: "🌱",
                            title: "You're always reinforcing something",
                            description: "Whatever you focus on each day becomes easier to repeat — calm, clarity, stress, or doubt.",
                            index: 2
                        )

                        DidYouKnowFactView(
                            emoji: "🔥",
                            title: "Emotion accelerates transformation",
                            description: "Emotionally charged moments make new habits and realizations stick much faster.",
                            index: 3
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)  // ✅ Added bottom padding for breathing room
                }

                // ✅ Fade gradient at bottom
                LinearGradient(
                    colors: [
                        Color.appBackground.opacity(0),
                        Color.appBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                .allowsHitTesting(false)
            }

            // Continue Button - Fixed at bottom
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 7  // Go to generating plan
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Screen 7: Generating Plan (Loading Animation)

    private var screen_GeneratingPlan: some View {
        GeneratingPlanView(onComplete: {
            withAnimation {
                viewModel.currentStep = 8  // Go to Uh Oh screen
            }
        })
    }

    // MARK: - Screen 8: Uh Oh Animation

    private var screen_UhOh: some View {
        UhOhAnimationView(onSkip: {
            withAnimation {
                viewModel.currentStep = 9  // Go to feedback stats
            }
        })
    }

    // MARK: - Screen 9: Feedback Stats (Personalized based on mood + struggle)

    private var screen_FeedbackStats: some View {
        FeedbackStatsView(
            mood: viewModel.selectedMood,
            struggle: viewModel.selectedStruggle,
            customStruggle: viewModel.customStruggleText,
            onContinue: {
                withAnimation {
                    viewModel.currentStep = 10  // Go to red graph (life without hacks)
                }
            }
        )
    }

    // MARK: - Screen 10: Life Without Hacks (Red/Declining)

    private var screen_LifeWithoutHacks: some View {
        LifeWithoutHacksView(
            struggle: viewModel.selectedStruggle,
            goal: viewModel.finalGoalText,
            onSkip: {
                withAnimation {
                    viewModel.currentStep = 12  // Go to green graph (life with hacks)
                }
            }
        )
    }

    // MARK: - Screen 11: Life With Hacks (Green/Rising)

    private var screen_LifeWithHacks: some View {
        LifeWithHacksView(
            struggle: viewModel.selectedStruggle,
            goal: viewModel.finalGoalText,
            onNext: {
                withAnimation {
                    viewModel.currentStep = 13  // Go to rating screen
                }
            }
        )
    }

    // MARK: - Screen 13: Rating Screen

    private var screen_Rating: some View {
        RatingView(
            onContinue: { rating in
                withAnimation {
                    viewModel.currentStep = 14  // Go to notification permission
                }
            }
        )
    }

    // MARK: - Screen 14: Notification Permission

    private var screen_NotificationPermission: some View {
        NotificationPermissionView(
            onContinue: {
                withAnimation {
                    viewModel.currentStep = 15  // Go to commitment screen
                }
            }
        )
    }

    // MARK: - Screen 15: Commitment (Before Paywall)

    private var screen_Commitment: some View {
        CommitmentView(
            onContinue: {
                Task {
                    // Save onboarding data but don't mark complete yet
                    await viewModel.completeOnboarding()
                    // Show paywall - only mark complete after subscription
                    showPaywall()
                }
            }
        )
    }

    // MARK: - Screen 12: Unlock Solution Cards (Gamified)

    private var screen_UnlockCards: some View {
        UnlockCardsView(onNext: {
            withAnimation {
                viewModel.currentStep = 11  // Go to red graph (life without hacks)
            }
        })
    }

    // MARK: - Screen 13: Time Selection

    private var screen4_TimeSelection: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        viewModel.currentStep = 12  // Back to unlock cards
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
                    showProfileSetup = true
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
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

                // Checkmark when selected, empty circle when not
                ZStack {
                    Circle()
                        .strokeBorder(Color.appCardBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appAccent)
                    }
                }
            }
            .padding()
            .background(Color.clear)  // Transparent background
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.appAccentGradient : LinearGradient(colors: [Color.appCardBorder], startPoint: .leading, endPoint: .trailing), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

struct AgeRangeButton: View {
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

                // Checkmark when selected, empty circle when not
                ZStack {
                    Circle()
                        .strokeBorder(Color.appCardBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appAccent)
                    }
                }
            }
            .padding()
            .background(Color.clear)  // Transparent background
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.appAccentGradient : LinearGradient(colors: [Color.appCardBorder], startPoint: .leading, endPoint: .trailing), lineWidth: isSelected ? 2 : 1)
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

                // Checkmark when selected, empty circle when not
                ZStack {
                    Circle()
                        .strokeBorder(Color.appCardBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .overlay(
                                Color.appAccentGradient
                                    .mask(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                    )
                            )
                    }
                }
            }
            .padding()
            .background(Color.clear)  // Transparent background
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.appAccentGradient : LinearGradient(colors: [Color.appCardBorder], startPoint: .leading, endPoint: .trailing), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

// MARK: - Generating Plan Loading View

struct GeneratingPlanView: View {
    let onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var currentMessage = ""
    @Environment(\.colorScheme) var colorScheme

    private let messages = [
        "Identifying your goals and struggles",
        "Looking at your current state",
        "Generating a custom plan"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Lightning icon
            Text("⚡")
                .font(.system(size: 64))
                .padding(.bottom, 32)

            // Status message
            Text(currentMessage)
                .font(.title3.weight(.medium))
                .foregroundColor(.appTextPrimary)
                .multilineTextAlignment(.center)
                .frame(height: 60)
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.3), value: currentMessage)

            Spacer()
                .frame(height: 40)

            // Percentage
            Text("\(Int(progress))%")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.appTextPrimary)
                .monospacedDigit()
                .padding(.bottom, 24)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appCardBorder)
                        .frame(height: 8)

                    // Filled progress
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appAccentGradient)
                        .frame(width: geometry.size.width * (progress / 100), height: 8)
                        .animation(.linear(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear {
            startLoadingAnimation()
        }
    }

    private func startLoadingAnimation() {
        // Message 1: "Identifying your goals and struggles" (0-33%)
        currentMessage = messages[0]

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if progress < 33 {
                progress += 1
            } else if progress < 34 {
                // Switch to message 2
                currentMessage = messages[1]
                progress += 1
            } else if progress < 66 {
                progress += 1
            } else if progress < 67 {
                // Switch to message 3
                currentMessage = messages[2]
                progress += 1
            } else if progress < 100 {
                progress += 1
            } else {
                timer.invalidate()
                // Complete - advance to next screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Struggle Statistics Data

struct StruggleStatistic {
    let percentage: Int
    let struggleText: String
}

// MARK: - Struggle Metrics Mapping

struct StruggleMetrics {
    let metric1: String
    let metric2: String
    let metric3: String
}

func getMetricsForStruggle(_ struggle: String, goal: String) -> StruggleMetrics {
    switch struggle {
    case "I have negative self-talk":
        return StruggleMetrics(
            metric1: "Self-confidence",
            metric2: "Focus on \(goal.isEmpty ? "your goals" : goal.lowercased())",
            metric3: "Mental clarity"
        )
    case "I tend to overreact to everything":
        return StruggleMetrics(
            metric1: "Emotional control",
            metric2: "Calm decision-making",
            metric3: "Stress management"
        )
    case "I take everything too seriously":
        return StruggleMetrics(
            metric1: "Mental flexibility",
            metric2: "Life enjoyment",
            metric3: "Relaxation ability"
        )
    case "I have low self-esteem":
        return StruggleMetrics(
            metric1: "Self-worth",
            metric2: "Confidence in abilities",
            metric3: "Positive self-image"
        )
    default: // "other" or custom
        return StruggleMetrics(
            metric1: "Progress on goals",
            metric2: "Mental wellbeing",
                metric3: "Daily consistency"
        )
    }
}

// MARK: - Custom Struggle Text Formatter

/// Returns a generic, safe message for custom struggles to avoid grammar issues
/// Custom input is unpredictable, so we use a catch-all phrase instead
func formatCustomStruggleText(_ text: String) -> String {
    return "face personal challenges like this"
}


func getStruggleStatistic(for struggle: String, customText: String) -> StruggleStatistic {
    switch struggle {
    case "I have negative self-talk":
        return StruggleStatistic(percentage: 80, struggleText: "struggle with negative self-talk")
    case "I tend to overreact to everything":
        return StruggleStatistic(percentage: 65, struggleText: "tend to overreact emotionally")
    case "I take everything too seriously":
        return StruggleStatistic(percentage: 58, struggleText: "take things too seriously")
    case "I have low self-esteem":
        return StruggleStatistic(percentage: 85, struggleText: "struggle with low self-esteem")
    case "other":
        // Use generic message for custom struggles
        let formattedText = formatCustomStruggleText(customText)
        return StruggleStatistic(percentage: 70, struggleText: formattedText)
    default:
        return StruggleStatistic(percentage: 70, struggleText: "face similar challenges")
    }
}

func getMoodBasedMessage(mood: String) -> String {
    switch mood {
    case "overwhelmed", "anxious", "low_energy":
        return "You're not alone in this. This is your starting point, not your destination."
    case "neutral", "calm":
        return "Recognizing this pattern is the first step to changing it."
    case "good", "motivated", "inspired":
        return "Even the most motivated people face this. Awareness is your superpower."
    default:
        return "You're not alone in this journey."
    }
}

// MARK: - Feedback Stats View

struct FeedbackStatsView: View {
    let mood: String
    let struggle: String
    let customStruggle: String
    let onContinue: () -> Void

    @State private var showPercentage = false
    @State private var showText = false
    @State private var showMessage = false

    private var statistic: StruggleStatistic {
        getStruggleStatistic(for: struggle, customText: customStruggle)
    }

    private var empathyMessage: String {
        getMoodBasedMessage(mood: mood)
    }

    var body: some View {
        ZStack {
            // Adaptive background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    // Percentage with gradient (appears first)
                    Text("You're one of \(statistic.percentage)%")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Color.appAccentGradient)
                        .multilineTextAlignment(.center)
                        .opacity(showPercentage ? 1 : 0)
                        .scaleEffect(showPercentage ? 1 : 0.9)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showPercentage)
                        .padding(.horizontal, 32)

                    // Struggle description (appears after percentage)
                    Text("of people who \(statistic.struggleText)")
                        .font(.title3)
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7), value: showText)
                        .padding(.horizontal, 40)

                    // Empathy message based on mood (appears last)
                    Text(empathyMessage)
                        .font(.body)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(showMessage ? 1 : 0)
                        .offset(y: showMessage ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.3), value: showMessage)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                }

                Spacer()

                // Next button
                Button {
                    onContinue()
                } label: {
                    Text("Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccentGradient)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Trigger animations in sequence - percentage first, then text, then message
            showPercentage = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showText = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showMessage = true
            }
        }
    }
}

// MARK: - Life Without Hacks View (Red/Declining)

struct LifeWithoutHacksView: View {
    let struggle: String
    let goal: String
    let onSkip: () -> Void

    @State private var animationProgress: CGFloat = 0
    @State private var showText = false

    // 3 declining lines with different rates
    let line1Points: [CGFloat] = [0.70, 0.65, 0.55, 0.45, 0.38, 0.33, 0.31, 0.30]
    let line2Points: [CGFloat] = [0.65, 0.58, 0.48, 0.38, 0.32, 0.28, 0.26, 0.25]
    let line3Points: [CGFloat] = [0.60, 0.52, 0.42, 0.32, 0.26, 0.22, 0.21, 0.20]

    // Red/orange color scheme
    let lineColors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24), // #E74C3C bright red
        Color(red: 0.90, green: 0.49, blue: 0.13), // #E67E22 orange-red
        Color(red: 0.95, green: 0.61, blue: 0.07)  // #F39C12 orange
    ]

    var metrics: StruggleMetrics {
        getMetricsForStruggle(struggle, goal: goal)
    }

    var body: some View {
        ZStack {
            // Adaptive background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Personalized headline
                Text("Without daily neuroscience hacks...")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(showText ? 1 : 0)
                    .animation(.easeIn(duration: 0.5), value: showText)
                    .padding(.bottom, 32)

                // Multi-line graph with legend
                MultiLineGraphView(
                    lines: [line1Points, line2Points, line3Points],
                    colors: lineColors,
                    labels: [metrics.metric1, metrics.metric2, metrics.metric3],
                    animationProgress: animationProgress
                )
                .frame(height: 320)
                .padding(.horizontal, 32)

                Spacer()

                // Skip button
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            showText = true

            // Animate graph drawing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    animationProgress = 1.0
                }
            }

            // Auto-advance after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                onSkip()
            }
        }
    }
}

// MARK: - Life With Hacks View (Green Upward Graph)

struct LifeWithHacksView: View {
    let struggle: String
    let goal: String
    let onNext: () -> Void

    @State private var showText = false
    @State private var animationProgress: CGFloat = 0.0

    // Upward trending lines (opposite of red screen)
    let line1Points: [CGFloat] = [0.30, 0.33, 0.38, 0.45, 0.55, 0.65, 0.69, 0.70]
    let line2Points: [CGFloat] = [0.25, 0.28, 0.32, 0.38, 0.48, 0.58, 0.63, 0.65]
    let line3Points: [CGFloat] = [0.20, 0.22, 0.26, 0.32, 0.42, 0.52, 0.58, 0.60]

    // Green/positive color scheme
    let lineColors: [Color] = [
        Color(red: 0.18, green: 0.80, blue: 0.44), // #2ECC71
        Color(red: 0.10, green: 0.74, blue: 0.61), // #1ABC9C
        Color(red: 0.20, green: 0.67, blue: 0.86)  // #3498DB
    ]

    var metrics: StruggleMetrics {
        getMetricsForStruggle(struggle, goal: goal)
    }

    var body: some View {
        ZStack {
            // Adaptive background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Headline
                Text("With daily neuroscience hacks...")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(showText ? 1 : 0)
                    .animation(.easeIn(duration: 0.5), value: showText)
                    .padding(.bottom, 32)

                // Multi-line graph with legend
                MultiLineGraphView(
                    lines: [line1Points, line2Points, line3Points],
                    colors: lineColors,
                    labels: [metrics.metric1, metrics.metric2, metrics.metric3],
                    animationProgress: animationProgress
                )
                .frame(height: 320)
                .padding(.horizontal, 32)

                Spacer()

                // Next button (orange-gold gradient)
                Button {
                    onNext()
                } label: {
                    Text("Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccentGradient)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            showText = true

            // Animate graphs
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    animationProgress = 1.0
                }
            }
        }
    }
}

// MARK: - Rating View

struct RatingView: View {
    let onContinue: (Int) -> Void

    @State private var selectedRating: Int = 5  // Default to 5 stars

    var body: some View {
        ZStack {
            // Adaptive background
            Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    // Title
                    Text("Give us a rating")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // Star rating card
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { index in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedRating = index
                                    }
                                } label: {
                                    Image(systemName: index <= selectedRating ? "star.fill" : "star")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                        .overlay(
                                            Color.appAccentGradient
                                                .mask(
                                                    Image(systemName: index <= selectedRating ? "star.fill" : "star")
                                                        .font(.system(size: 36))
                                                )
                                        )
                                }
                                .scaleEffect(index == selectedRating ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRating)
                            }
                        }
                        .padding(.vertical, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appCardBorder, lineWidth: 1)
                    )
                    .cornerRadius(16)
                    .padding(.horizontal, 32)

                    // "Made for people like you"
                    Text("Made for people like you")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.appTextPrimary)

                    // Avatar row
                    HStack(spacing: -12) {
                        Image("avatarAlex")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.appBackground, lineWidth: 3))
                            .zIndex(3)

                        Image("avatarMaya")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.appBackground, lineWidth: 3))
                            .zIndex(2)

                        Image("avatarAnna")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.appBackground, lineWidth: 3))
                            .zIndex(1)
                    }

                    // Caption
                    Text("+12,000 people started their rewiring journey")
                        .font(.system(size: 14))
                        .foregroundColor(.appTextSecondary)

                    // Testimonials
                    VStack(spacing: 16) {
                        TestimonialCard(
                            avatarImage: "avatarSima",
                            name: "Sabrina",
                            testimonial: "Tiny daily hacks have helped me stay more consistent than ever."
                        )

                        TestimonialCard(
                            avatarImage: "avatarYen",
                            name: "Adam",
                            testimonial: "I feel calmer and more focused throughout my day."
                        )
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 8)
                }
            }

            // Bottom button
            VStack {
                Spacer()

                Button {
                    onContinue(selectedRating)
                } label: {
                    Text("Continue")
                }
                .buttonStyle(OnboardingButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Testimonial Card Component

struct TestimonialCard: View {
    let avatarImage: String
    let name: String
    let testimonial: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Image(avatarImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Name and stars
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.appTextPrimary)

                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .overlay(
                                    Color.appAccentGradient
                                        .mask(
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10))
                                        )
                                )
                        }
                    }
                }

                // Testimonial text
                Text(testimonial)
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Notification Permission View

struct NotificationPermissionView: View {
    let onContinue: () -> Void

    @State private var isAnimating = false
    @State private var moodLevel: CGFloat = 0.0

    var body: some View {
        ZStack {
            // Adaptive background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Lightning emoji with glow effect
                ZStack {
                    // Glow layers
                    ForEach(0..<3, id: \.self) { index in
                        Text("⚡️")
                            .font(.system(size: 96))
                            .opacity(0.3 * moodLevel)
                            .blur(radius: 20 + (CGFloat(index) * 10))
                    }

                    // Main lightning emoji
                    Text("⚡️")
                        .font(.system(size: 96))
                        .shadow(
                            color: Color.appAccent.opacity(0.4 + (moodLevel * 0.6)),
                            radius: 20 + (moodLevel * 40),
                            x: 0,
                            y: 0
                        )
                        .shadow(
                            color: Color.appAccent.opacity(moodLevel * 0.8),
                            radius: 30 + (moodLevel * 30),
                            x: 0,
                            y: 0
                        )
                }
                .scaleEffect(0.85 + (moodLevel * 0.25))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: moodLevel)

                VStack(spacing: 16) {
                    // Title
                    Text("Get your daily brain hack")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)

                    // Subtitle
                    Text("We'll send you a personalized hack each day to help rewire your brain and build better habits")
                        .font(.system(size: 17))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    // Enable Notifications button
                    Button {
                        Task {
                            await requestNotificationPermission()
                            onContinue()
                        }
                    } label: {
                        Text("Enable Notifications")
                    }
                    .buttonStyle(OnboardingButtonStyle())
                    .padding(.horizontal, 24)

                    // Skip button
                    Button {
                        onContinue()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                moodLevel = 1.0
            }
        }
    }

    private func requestNotificationPermission() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied")
            }
        } catch {
            print("❌ Error requesting notification permission: \(error)")
        }
    }
}

// MARK: - Commitment View (Before Paywall)

struct CommitmentView: View {
    let onContinue: () -> Void

    @State private var isCommitted = false

    var body: some View {
        ZStack {
            // Adaptive background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Large emoji
                Text("⚡️")
                    .font(.system(size: 80))

                // Title
                Text("Ready to rewire?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)

                // Subtitle
                Text("Make a small commitment to yourself.")
                    .font(.system(size: 17))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)

                // Commitment card
                VStack(alignment: .leading, spacing: 12) {
                    Text("I commit to:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appTextPrimary)

                    VStack(alignment: .leading, spacing: 10) {
                        CommitmentLine(text: "Showing up for one tiny hack a day")
                        CommitmentLine(text: "Trying the experiments instead of overthinking")
                        CommitmentLine(text: "Using this space to be honest with myself")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.appCardBorder, lineWidth: 1)
                )
                .cornerRadius(16)

                // Tap here text
                Button {
                    // Stub - no action for now
                } label: {
                    Text("Tap here ↓")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .overlay(
                            Color.appAccentGradient
                                .mask(
                                    Text("Tap here ↓")
                                        .font(.system(size: 16, weight: .medium))
                                )
                        )
                }

                // Toggle row
                HStack {
                    Text("I'm ready to start rewiring")
                        .font(.system(size: 17))
                        .foregroundColor(.appTextPrimary)

                    Spacer()

                    Toggle("", isOn: $isCommitted)
                        .labelsHidden()
                        .tint(Color.appAccent)
                }
                .padding(16)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.appCardBorder, lineWidth: 1)
                )
                .cornerRadius(16)

                Spacer()

                // Continue button
                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                }
                .buttonStyle(OnboardingButtonStyle())
                .disabled(!isCommitted)
                .opacity(isCommitted ? 1 : 0.5)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Commitment Line Component

struct CommitmentLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 17))
                .foregroundColor(.appTextSecondary)

            Text(text)
                .font(.system(size: 17))
                .foregroundColor(.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// ============================================
// THE ACTUAL FINAL FIX - UnlockableCard
// ============================================
// The width constraint must be INSIDE the component,
// not just on the parent call

struct UnlockableCard: View {
    let emoji: String
    let text: String
    let isUnlocked: Bool
    let isReady: Bool
    let onTap: () -> Void

    @State private var flipRotation: Double = 0
    @State private var cardScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0

    // ✅ Card dimensions - WIDTH AND HEIGHT
    private let cardWidth: CGFloat = 320
    private let cardHeight: CGFloat = 200
    private let cardCornerRadius: CGFloat = 20

    var body: some View {
        ZStack {
            // Card back - with WIDTH constraint
            VelvetBackground(
                baseColor: Color(red: 1.0, green: 0.6, blue: 0.2),
                cornerRadius: cardCornerRadius
            )
            .frame(width: cardWidth, height: cardHeight)  // ✅ EXPLICIT WIDTH
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            .overlay(
                VStack(spacing: 12) {
                    Text(emoji)
                        .font(.system(size: 48))
                    
                    if !isReady {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
            .rotation3DEffect(.degrees(flipRotation), axis: (x: 0, y: 1, z: 0))
            .opacity(flipRotation < 90 ? 1 : 0)

            // Card front - with WIDTH constraint
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color.white)
                .frame(width: cardWidth, height: cardHeight)  // ✅ EXPLICIT WIDTH
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .stroke(Color.appAccentGradient, lineWidth: 2.5)
                )
                .overlay(
                    VStack(spacing: 12) {
                        Text(emoji)
                            .font(.system(size: 40))

                        Text(text)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.appTextPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 20)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                .rotation3DEffect(.degrees(flipRotation - 180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipRotation >= 90 ? 1 : 0)

            // Glow - with WIDTH constraint
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(Color(red: 1.0, green: 0.84, blue: 0.0), lineWidth: 3)
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0), radius: 15)
                .frame(width: cardWidth, height: cardHeight)  // ✅ EXPLICIT WIDTH
                .opacity(glowOpacity)
        }
        .frame(width: cardWidth, height: cardHeight)  // ✅ CONSTRAIN THE ZSTACK TOO
        .scaleEffect(cardScale)
        .onTapGesture {
            if isReady && !isUnlocked {
                onTap()
            }
        }
        .onChange(of: isUnlocked) { oldValue, newValue in
            if newValue {
                withAnimation(.easeOut(duration: 0.15)) {
                    cardScale = 1.03
                    glowOpacity = 0.8
                }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    flipRotation = 180
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        cardScale = 1.0
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        glowOpacity = 0
                    }
                }
            }
        }
    }
}

// ============================================
// UnlockCardsView - Simplified parent
// ============================================

struct UnlockCardsView: View {
    let onNext: () -> Void

    @State private var isCard1Unlocked = false
    @State private var isCard2Unlocked = false
    @State private var isCard2Ready = false
    @State private var card1Confetti: [ConfettiParticle] = []
    @State private var card2Confetti: [ConfettiParticle] = []

    var bothCardsUnlocked: Bool {
        isCard1Unlocked && isCard2Unlocked
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Here's the good news...")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.appAccentGradient)
                        .multilineTextAlignment(.center)
                    
                    Text("Tap to open")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 24)

                // Cards - NO PADDING, cards constrain themselves
                VStack(spacing: 16) {
                    // Card 1 - card handles its own width
                    UnlockableCard(
                        emoji: "⚡",
                        text: "Your personalized daily hack is tailored to rewire your brain patterns",
                        isUnlocked: isCard1Unlocked,
                        isReady: true,
                        onTap: { unlockCard1() }
                    )
                    .overlay(ConfettiView(particles: card1Confetti))

                    // Card 2 - card handles its own width
                    UnlockableCard(
                        emoji: "💬",
                        text: "24/7 AI neuro coach to guide and support your transformation",
                        isUnlocked: isCard2Unlocked,
                        isReady: isCard2Ready,
                        onTap: {
                            if isCard2Ready {
                                unlockCard2()
                            }
                        }
                    )
                    .overlay(ConfettiView(particles: card2Confetti))
                }

                Spacer()

                // Next button - matches card width
                Button {
                    onNext()
                } label: {
                    Text("Next")
                        .font(.headline)
                        .foregroundColor(bothCardsUnlocked ? .white : Color(red: 0.6, green: 0.6, blue: 0.6))
                        .frame(width: 320, height: 52)  // ✅ EXPLICIT WIDTH
                        .background(
                            Group {
                                if bothCardsUnlocked {
                                    Color.appAccentGradient
                                } else {
                                    LinearGradient(
                                        colors: [Color(red: 0.85, green: 0.85, blue: 0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .cornerRadius(12)
                        .opacity(bothCardsUnlocked ? 1.0 : 0.5)
                }
                .disabled(!bothCardsUnlocked)
                .padding(.bottom, 40)
            }
            .padding(.top, 24)
        }
    }

    private func unlockCard1() {
        guard !isCard1Unlocked else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isCard1Unlocked = true
        }
        createConfetti(for: .card1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                isCard2Ready = true
            }
        }
    }

    private func unlockCard2() {
        guard !isCard2Unlocked else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isCard2Unlocked = true
        }
        createConfetti(for: .card2)
    }

    private func createConfetti(for card: CardType) {
        let confettiCount = 20
        var particles: [ConfettiParticle] = []
        for _ in 0..<confettiCount {
            let particle = ConfettiParticle(
                x: 0, y: 0,
                velocityX: Double.random(in: -150...150),
                velocityY: Double.random(in: -200...(-50)),
                opacity: 1.0
            )
            particles.append(particle)
        }
        if card == .card1 {
            card1Confetti = particles
            animateConfetti(for: .card1)
        } else {
            card2Confetti = particles
            animateConfetti(for: .card2)
        }
    }

    private func animateConfetti(for card: CardType) {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] timer in
            if card == .card1 {
                for i in 0..<card1Confetti.count {
                    card1Confetti[i].x += card1Confetti[i].velocityX * 0.05
                    card1Confetti[i].y += card1Confetti[i].velocityY * 0.05
                    card1Confetti[i].velocityY += 500 * 0.05
                    card1Confetti[i].opacity -= 0.02
                }
                if card1Confetti.allSatisfy({ $0.opacity <= 0 }) {
                    timer.invalidate()
                }
            } else {
                for i in 0..<card2Confetti.count {
                    card2Confetti[i].x += card2Confetti[i].velocityX * 0.05
                    card2Confetti[i].y += card2Confetti[i].velocityY * 0.05
                    card2Confetti[i].velocityY += 500 * 0.05
                    card2Confetti[i].opacity -= 0.02
                }
                if card2Confetti.allSatisfy({ $0.opacity <= 0 }) {
                    timer.invalidate()
                }
            }
        }
    }

    enum CardType {
        case card1, card2
    }
}




// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var velocityX: Double
    var velocityY: Double
    var opacity: Double
}

// MARK: - Confetti View

struct ConfettiView: View {
    let particles: [ConfettiParticle]

    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(Color(red: 1.0, green: 0.84, blue: 0.0))
                    .frame(width: 8, height: 8)
                    .position(
                        x: geometry.size.width / 2 + CGFloat(particle.x),
                        y: geometry.size.height / 2 + CGFloat(particle.y)
                    )
                    .opacity(particle.opacity)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Velvet Background

struct VelvetBackground: View {
    let baseColor: Color
    let cornerRadius: CGFloat

    private var highlightColor: Color {
        baseColor.opacity(1.0).lighten(by: 0.25)
    }

    private var shadowColor: Color {
        baseColor.opacity(1.0).darken(by: 0.3)
    }

    var body: some View {
        ZStack {
            // Base gradient - vertical with subtle variation
            LinearGradient(
                colors: [
                    highlightColor.opacity(0.9),
                    baseColor,
                    shadowColor.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Diagonal folds - creating the velvet draping effect
            ZStack {
                // Fold 1 - top left diagonal
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                shadowColor.opacity(0.4),
                                Color.clear,
                                highlightColor.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 400, height: 60)
                    .blur(radius: 20)
                    .rotationEffect(.degrees(-35))
                    .offset(x: -50, y: -40)

                // Fold 2 - center diagonal
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                highlightColor.opacity(0.35),
                                Color.clear,
                                shadowColor.opacity(0.35)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 500, height: 70)
                    .blur(radius: 25)
                    .rotationEffect(.degrees(-40))
                    .offset(x: 20, y: 10)

                // Fold 3 - bottom right diagonal
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                shadowColor.opacity(0.3),
                                Color.clear,
                                highlightColor.opacity(0.25)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 450, height: 65)
                    .blur(radius: 22)
                    .rotationEffect(.degrees(-38))
                    .offset(x: 60, y: 70)

                // Sheen highlight - narrow band of light
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                highlightColor.opacity(0.4),
                                Color.white.opacity(0.15),
                                highlightColor.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 300, height: 40)
                    .blur(radius: 15)
                    .rotationEffect(.degrees(-42))
                    .offset(x: -30, y: -20)

                // Subtle noise/grain overlay for fabric texture
                NoiseTextureView()
                    .opacity(0.07)
                    .blendMode(.overlay)
            }
        }
        .clipped() // Prevent internal large capsules from expanding layout
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Noise Texture View

struct NoiseTextureView: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Create a fine grain noise pattern
                for _ in 0..<Int(size.width * size.height / 4) {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let opacity = Double.random(in: 0.3...1.0)

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

// MARK: - Color Extensions for Velvet

extension Color {
    func lighten(by percentage: Double) -> Color {
        return self.adjust(by: abs(percentage))
    }

    func darken(by percentage: Double) -> Color {
        return self.adjust(by: -abs(percentage))
    }

    func adjust(by percentage: Double) -> Color {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return Color(
            red: min(max(red + percentage, 0), 1),
            green: min(max(green + percentage, 0), 1),
            blue: min(max(blue + percentage, 0), 1),
            opacity: Double(alpha)
        )
        #else
        return self
        #endif
    }
}

// MARK: - Single Metric Mini Graph

struct SingleMetricMiniGraph: View {
    let label: String
    let points: [CGFloat]
    let color: Color
    let animationProgress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Metric label
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appTextSecondary)

            // Mini graph
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(points.count - 1)

                ZStack(alignment: .bottomLeading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.5))

                    // Gradient fill under line
                    Path { path in
                        guard points.count > 1 else { return }

                        path.move(to: CGPoint(x: 0, y: height))

                        for (index, point) in points.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height - (point * height)

                            if index == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                let previousX = CGFloat(index - 1) * stepX
                                let previousY = height - (points[index - 1] * height)
                                let controlX = (previousX + x) / 2

                                path.addQuadCurve(
                                    to: CGPoint(x: x, y: y),
                                    control: CGPoint(x: controlX, y: previousY)
                                )
                            }
                        }

                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.4),
                                color.opacity(0.1),
                                color.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask(
                        Rectangle()
                            .frame(width: width * animationProgress)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Main smooth line
                    Path { path in
                        guard points.count > 1 else { return }

                        for (index, point) in points.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height - (point * height)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                let previousX = CGFloat(index - 1) * stepX
                                let previousY = height - (points[index - 1] * height)
                                let controlX = (previousX + x) / 2

                                path.addQuadCurve(
                                    to: CGPoint(x: x, y: y),
                                    control: CGPoint(x: controlX, y: previousY)
                                )
                            }
                        }
                    }
                    .trim(from: 0, to: animationProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(height: 70)
        }
    }
}

// MARK: - Stacked Mini Graphs Container

struct StackedMiniGraphsView: View {
    let lines: [[CGFloat]]
    let colors: [Color]
    let labels: [String]
    let animationProgress: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<lines.count, id: \.self) { index in
                SingleMetricMiniGraph(
                    label: labels[index],
                    points: lines[index],
                    color: colors[index],
                    animationProgress: animationProgress
                )
            }
        }
    }
}

// MARK: - Multi-Line Graph View (3 lines on one graph)

struct MultiLineGraphView: View {
    let lines: [[CGFloat]]
    let colors: [Color]
    let labels: [String]
    let animationProgress: CGFloat

    var body: some View {
        VStack(spacing: 12) {
            // Legend
            HStack(spacing: 16) {
                ForEach(0..<labels.count, id: \.self) { index in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colors[index])
                            .frame(width: 8, height: 8)
                        Text(labels[index])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }

            // Graph with all 3 lines (no background, clean like trading apps)
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let maxPoints = lines.max(by: { $0.count < $1.count })?.count ?? 8
                let stepX = width / CGFloat(maxPoints - 1)

                ZStack {
                    // Very subtle grid lines (like real trading apps)
                    ForEach(0..<4, id: \.self) { i in
                        let y = height * CGFloat(i + 1) / 5
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                    }

                    // Draw all 3 lines
                    ForEach(0..<lines.count, id: \.self) { lineIndex in
                        let points = lines[lineIndex]
                        let color = colors[lineIndex]

                        // Gradient fill under each line (like trading apps)
                        Path { path in
                            guard points.count > 1 else { return }

                            path.move(to: CGPoint(x: 0, y: height))

                            for (index, point) in points.enumerated() {
                                let x = CGFloat(index) * stepX
                                let y = height * (1 - point)

                                if index == 0 {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                } else {
                                    let previousX = CGFloat(index - 1) * stepX
                                    let previousY = height * (1 - points[index - 1])
                                    let controlX = (previousX + x) / 2

                                    path.addQuadCurve(
                                        to: CGPoint(x: x, y: y),
                                        control: CGPoint(x: controlX, y: previousY)
                                    )
                                }
                            }

                            path.addLine(to: CGPoint(x: CGFloat(points.count - 1) * stepX, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.15),
                                    color.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .mask(
                            Rectangle()
                                .frame(width: width * animationProgress)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )

                        // Main line
                        Path { path in
                            guard points.count > 1 else { return }

                            for (index, point) in points.enumerated() {
                                let x = CGFloat(index) * stepX
                                let y = height * (1 - point)

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    let previousX = CGFloat(index - 1) * stepX
                                    let previousY = height * (1 - points[index - 1])
                                    let controlX = (previousX + x) / 2

                                    path.addQuadCurve(
                                        to: CGPoint(x: x, y: y),
                                        control: CGPoint(x: controlX, y: previousY)
                                    )
                                }
                            }
                        }
                        .trim(from: 0, to: animationProgress)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
    }
}

// MARK: - Graph Legend

struct GraphLegend: View {
    let labels: [String]
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<labels.count, id: \.self) { index in
                HStack(spacing: 8) {
                    Circle()
                        .fill(colors[index])
                        .frame(width: 8, height: 8)

                    Text(labels[index])
                        .font(.caption)
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                }
            }
        }
    }
}

// MARK: - Uh Oh Animation View

struct UhOhAnimationView: View {
    let onSkip: () -> Void

    @State private var showUhOh = false
    @State private var showSubtitle = false

    var body: some View {
        ZStack {
            // Adaptive background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // "Uh oh" text with orange-to-gold gradient - centered
                Text("Uh oh")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(Color.appAccentGradient)
                    .opacity(showUhOh ? 1 : 0)
                    .scaleEffect(showUhOh ? 1 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showUhOh)
                    .padding(.bottom, 16)

                // Subtitle "we need to talk." - dark, centered (appears after "Uh oh")
                Text("we need to talk.")
                    .font(.title2)
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: showSubtitle)

                Spacer()

                // Skip button at bottom
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Trigger animations - "Uh oh" first, then subtitle
            showUhOh = true

            // Delay subtitle appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSubtitle = true
            }

            // Auto-advance to next screen after animations complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onSkip()
            }
        }
    }
}

// MARK: - Did You Know Fact View with Animation

struct DidYouKnowFactView: View {
    let emoji: String
    let title: String
    let description: String
    let index: Int

    @State private var isVisible = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Emoji icon
            Text(emoji)
                .font(.system(size: 32))
                .frame(width: 40, height: 40)

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.appTextPrimary)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 30)
        .animation(
            .spring(response: 0.9, dampingFraction: 0.75)
                .delay(0.3 + (Double(index) * 0.5)),
            value: isVisible
        )
        .onAppear {
            isVisible = true
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
                            .fill(isSelected ? Color.appAccentGradient : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing))
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appAccentGradient)
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

// MARK: - Custom Input Bottom Sheet

struct CustomInputBottomSheet: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Icon
                    Text("✏️")
                        .font(.system(size: 48))
                        .padding(.top, 20)
                    
                    // Instructions
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.title2.bold())
                            .foregroundColor(.appTextPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Be specific - this helps us personalize your experience")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Text Input
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .foregroundColor(.appTextTertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: $text)
                            .focused($isTextFieldFocused)
                            .font(.body)
                            .foregroundColor(.appTextPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minHeight: 120)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appCardBackground.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appAccentGradient, lineWidth: 2)
                    )
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appTextSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appAccent)
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            // Auto-focus the text field when sheet appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
