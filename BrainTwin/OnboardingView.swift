import SwiftUI
import SuperwallKit
import UIKit
import CoreMotion
import Combine

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var motionManager = MotionManager() // Tracks device motion for parallax cards
    @Binding var isOnboardingComplete: Bool
    @State private var showProfileSetup = false
    @State private var isProcessingPurchase = false  // ✅ Show loading after purchase
    @State private var showCelebration = false  // ✅ NEW: Show celebration after purchase
    @State private var showNameCollection = false  // ✅ NEW: Show name collection after celebration
    @State private var userName: String = ""  // ✅ NEW: Store user's name
    
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("userName") private var storedUserName: String = ""  // ✅ NEW: Persist name
    
    @Environment(\.colorScheme) var colorScheme  // ✅ NEW: For dark mode support
    
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
    
    // MARK: - Transaction Namespace
    @Namespace private var animation // ✅ NEW: For Morph Transitions
    
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
                // Progress indicator - NOW 16 STEPS (0-15)
                HStack(spacing: 8) {
                    ForEach(0..<16, id: \.self) { index in
                        Capsule()
                            .fill(index <= viewModel.currentStep ? Color.appAccentGradient : LinearGradient(colors: [Color.appTextTertiary.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8) // Slight top breathing room
                
                // Content
                // Content
                ZStack {
                    switch viewModel.currentStep {
                    case 0:
                        screen0_WelcomeIntro
                            .transition(.opacity)
                    case 1:
                        screen0_5_ValueProp
                            .transition(.opacity)
                    case 2:
                        screen0_75_MoodCheck
                            .transition(.opacity)
                    case 3:
                        screen2_GoalSelection
                            .transition(.opacity) // Will be custom later
                    case 4:
                        screen1_AgeCollection
                            .transition(.opacity) // Will be custom later
                    case 5:
                        screen3_StruggleSelection
                            .transition(.opacity) // Will be custom later
                    case 6:
                        screen_DidYouKnow
                            .transition(.opacity)
                    case 7:
                        screen_GeneratingPlan
                            .transition(.opacity)
                    case 8:
                        screen_UhOh
                            .transition(.opacity)
                    case 9:
                        screen_FeedbackStats
                            .transition(.opacity)
                    case 10:
                        screen_UnlockCards
                            .transition(.opacity)
                    case 11:
                        screen_LifeWithoutHacks
                            .transition(.opacity)
                    case 12:
                        screen_LifeWithHacks
                            .transition(.opacity)
                    case 13:
                        screen_Rating
                            .transition(.opacity)
                    case 14:
                        screen_NotificationPermission
                            .transition(.opacity)
                    case 15:
                        screen_Commitment
                            .transition(.opacity)
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: viewModel.currentStep) // Smooth transition animation
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
            // ✅ Show loading overlay immediately after purchase
            if isProcessingPurchase {
                ZStack {
                    Color.appBackground.ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        ProgressView()
                            .tint(.appAccent)
                            .scaleEffect(1.5)
                        
                        Text("Setting up your journey...")
                            .font(.headline)
                            .foregroundColor(.appTextPrimary)
                    }
                }
                .transition(.opacity)
            }

            // ✅ NEW: Show celebration after purchase processing
            if showCelebration {
                celebrationView
                    .transition(.opacity)
            }

            // ✅ Show name collection after celebration
            if showNameCollection {
                nameCollectionView
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
            print("⏳ [Onboarding] isProcessingPurchase = true")

            // Process in background with retry logic
            Task {
                await processPostPurchaseWithRetry()
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


    
    // MARK: - Helpers
    
    /// Triggers haptic feedback and advances to the next step with a slight delay
    private func advanceWithHaptic(to step: Int) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Small delay for visual feedback before transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation {
                viewModel.currentStep = step
            }
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
            print("✅ [OnboardingView] Both conditions met! Ready for name collection...")
            // ✅ DON'T complete onboarding here - let name collection screen handle it
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
                    print("✅ [OnboardingView] Both conditions met on recheck! Ready for name collection...")
                    // ✅ DON'T complete onboarding here - let name collection screen handle it
                } else {
                    print("⚠️ [OnboardingView] Conditions still not met after recheck")
                    print("   → Showing paywall again...")
                    
                    // Show paywall again
                    showPaywall()
                }
            }
        }
    }

    /// Process post-purchase flow with retry logic for user creation
    private func processPostPurchaseWithRetry() async {
        print("🔄 [Onboarding] Starting post-purchase processing with retry...")

        let maxRetries = 3
        var attempt = 0
        var userCreated = false

        // Retry user identification up to 3 times with exponential backoff
        while attempt < maxRetries && !userCreated {
            attempt += 1
            print("🔄 [Onboarding] User creation attempt \(attempt)/\(maxRetries)...")

            // Check if user was already created
            if SupabaseManager.shared.userId != nil {
                print("✅ [Onboarding] User ID exists: \(SupabaseManager.shared.userId!)")
                userCreated = true
                break
            }

            // Try to create user from receipt
            do {
                try await SubscriptionManager.shared.identifyUserFromReceiptAfterPurchase()
                print("✅ [Onboarding] User created successfully on attempt \(attempt)")
                userCreated = true
            } catch {
                print("❌ [Onboarding] User creation failed on attempt \(attempt): \(error.localizedDescription)")

                if attempt < maxRetries {
                    // Exponential backoff: 2s, 4s, 8s
                    let delay = TimeInterval(pow(2.0, Double(attempt)))
                    print("⏳ [Onboarding] Waiting \(delay)s before retry...")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // Check final status
        await SubscriptionManager.shared.refreshSubscription()

        let hasUserId = SupabaseManager.shared.userId != nil
        let isSubscribed = SubscriptionManager.shared.isSubscribed

        print("📊 [Onboarding] Post-purchase status:")
        print("   User created: \(userCreated)")
        print("   Has user ID: \(hasUserId)")
        print("   Is subscribed: \(isSubscribed)")

        // Show celebration and continue flow
        await MainActor.run {
            print("🎉 [Onboarding] Showing celebration screen...")
            withAnimation(.easeInOut(duration: 0.3)) {
                isProcessingPurchase = false
                showCelebration = true
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
            // Back arrow to return to intro
            HStack {
                Button {
                    // No back action on first screen
                } label: {
                    EmptyView()
                }
                Spacer()
            }
            
            // Logo from Screenshot 1 (Gold Flower Loop)
            Image("NeuroHackLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.top, 24)

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
    
    // MARK: - Screen 0.5: Value Proposition (Momentum)
    
    private var screen0_5_ValueProp: some View {
        VStack(spacing: 0) {
            OnboardingBackButton(action: {
                withAnimation {
                    viewModel.currentStep = 0
                }
            })

            Spacer()

            VStack(spacing: 32) {
                if showValueIcon {
                    Text("⚡")
                        .font(.system(size: 64))
                        .transition(.scale.combined(with: .opacity))
                }

                VStack(spacing: 24) {
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
            OnboardingBackButton(action: {
                withAnimation {
                    viewModel.currentStep = 1
                }
            })
            
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
                .frame(width: 140, height: 140) // Ensure stable layout size
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
            .padding(.horizontal, 24)
            .padding(.bottom, 40)

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
            // Check spacing - reliance on global progress bar
            
            OnboardingBackButton(action: {
                withAnimation {
                    viewModel.currentStep = 3
                }
            })

            Spacer()

            // Lightning icon
            Text("⚡")
                .font(.system(size: 64))
                .matchedGeometryEffect(id: "lightning", in: animation) // Shared Element
                .padding(.bottom, 24)

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
            .padding(.bottom, 32)

            // Age Range Options
            VStack(spacing: 12) {
                AgeRangeButton(
                    title: "Under 18",
                    isSelected: viewModel.selectedAgeRange == "Under 18",
                    action: { 
                        viewModel.selectAgeRange("Under 18")
                        advanceWithHaptic(to: 5)
                    }
                )

                AgeRangeButton(
                    title: "18-24",
                    isSelected: viewModel.selectedAgeRange == "18-24",
                    action: { 
                        viewModel.selectAgeRange("18-24")
                        advanceWithHaptic(to: 5)
                    }
                )

                AgeRangeButton(
                    title: "25-34",
                    isSelected: viewModel.selectedAgeRange == "25-34",
                    action: { 
                        viewModel.selectAgeRange("25-34")
                        advanceWithHaptic(to: 5)
                    }
                )

                AgeRangeButton(
                    title: "35-44",
                    isSelected: viewModel.selectedAgeRange == "35-44",
                    action: { 
                        viewModel.selectAgeRange("35-44")
                        advanceWithHaptic(to: 5)
                    }
                )

                AgeRangeButton(
                    title: "45-54",
                    isSelected: viewModel.selectedAgeRange == "45-54",
                    action: { 
                        viewModel.selectAgeRange("45-54")
                        advanceWithHaptic(to: 5)
                    }
                )

                AgeRangeButton(
                    title: "55+",
                    isSelected: viewModel.selectedAgeRange == "55+",
                    action: { 
                        viewModel.selectAgeRange("55+")
                        advanceWithHaptic(to: 5)
                    }
                )
            }
            .padding(.horizontal)

            Spacer()

            // Continue Button
            Spacer()
                .frame(height: 20)
        }
    }

    // MARK: - Screen 3: Struggle Selection
    
    private var screen2_GoalSelection: some View {
        VStack(spacing: 0) {
            OnboardingBackButton(action: {
                withAnimation {
                    viewModel.currentStep = 2
                }
            })

            Spacer()

            // Lightning icon - consistent with other screens
            Text("⚡")
                .font(.system(size: 64))
                .matchedGeometryEffect(id: "lightning", in: animation) // Shared Element
                .padding(.bottom, 24) // Increased for premium feel

            // Header
            VStack(spacing: 16) { // Increased spacing
                Text("What's your main goal?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Your hacks will be designed for this")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.bottom, 32) // Increased breathing room

            // Goal Options - Compact list
            VStack(spacing: 12) {
                GoalOptionButton(
                    title: "Succeed at my current mission",
                    isSelected: viewModel.selectedGoal == "Succeed at my current mission",
                    action: { 
                        viewModel.selectGoal("Succeed at my current mission")
                        advanceWithHaptic(to: 4)
                    }
                )

                GoalOptionButton(
                    title: "Rewire my brain to unlock potential",
                    isSelected: viewModel.selectedGoal == "Rewire my brain to unlock potential",
                    action: { 
                        viewModel.selectGoal("Rewire my brain to unlock potential")
                        advanceWithHaptic(to: 4)
                    }
                )

                GoalOptionButton(
                    title: "Think outside the box",
                    isSelected: viewModel.selectedGoal == "Think outside the box",
                    action: { 
                        viewModel.selectGoal("Think outside the box")
                        advanceWithHaptic(to: 4)
                    }
                )

                GoalOptionButton(
                    title: "Attract luck or happiness",
                    isSelected: viewModel.selectedGoal == "Attract luck or happiness",
                    action: { 
                        viewModel.selectGoal("Attract luck or happiness")
                        advanceWithHaptic(to: 4)
                    }
                )

                GoalOptionButton(
                    title: "Learn manifesting",
                    isSelected: viewModel.selectedGoal == "Learn manifesting",
                    action: { 
                        viewModel.selectGoal("Learn manifesting")
                        advanceWithHaptic(to: 4)
                    }
                )

                // Custom Goal Option - Inline Compact Style
                Button {
                    viewModel.selectedGoal = "custom"
                    showCustomGoalSheet = true
                } label: {
                    HStack {
                        Text("Other - Set custom goal")
                            .font(.system(.subheadline, design: .default).bold()) // Compact bold font
                            .foregroundColor(.appTextPrimary)

                        Spacer()

                        // Radio button style
                        ZStack {
                            Circle()
                                .strokeBorder(viewModel.selectedGoal == "custom" ? Color.appAccent : Color.appTextTertiary, lineWidth: 1.5) // 1.5 border width
                                .frame(width: 20, height: 20) // Smaller radio circle

                            if viewModel.selectedGoal == "custom" {
                                Circle()
                                    .fill(Color.appAccent)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                    .padding(.vertical, 16) // Increased vertical padding
                    .padding(.horizontal, 16)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.selectedGoal == "custom" ? AnyShapeStyle(Color.appAccentGradient) : AnyShapeStyle(Color.appTextTertiary), lineWidth: viewModel.selectedGoal == "custom" ? 2 : 1.5) // 1.5 width
                    )
                }
            }
            .padding(.horizontal)

            Spacer()

            // Continue Button - Fixed at bottom
            Spacer()
                .frame(height: 20)
        }
        .onAppear {
            // ✅ OPTIMIZATION: Create anonymous account early
            // This gives us a user ID so we can generate hack later
            Task {
                guard !SupabaseManager.shared.isSignedIn else {
                    print("ℹ️ [GoalSelection] User already signed in, skipping anonymous sign-in")
                    return
                }

                do {
                    try await SupabaseManager.shared.signInAnonymously()
                    print("✅ [GoalSelection] Anonymous account created! User ID: \(SupabaseManager.shared.userId ?? "nil")")
                } catch {
                    print("❌ [GoalSelection] Failed to create anonymous account: \(error)")
                }
            }
        }
        .sheet(isPresented: $showCustomGoalSheet) {
            CustomInputBottomSheet(
                title: "What's your goal?",
                placeholder: "e.g., Build discipline to finish my startup tasks",
                text: $viewModel.customGoalText
            )
        }
        .onChange(of: showCustomGoalSheet) { isPresented in
            if !isPresented && viewModel.selectedGoal == "custom" && !viewModel.customGoalText.isEmpty {
                advanceWithHaptic(to: 4)
            }
        }
    }
    
    private var screen3_StruggleSelection: some View {
        VStack(spacing: 0) {
            OnboardingBackButton(action: {
                withAnimation {
                    viewModel.currentStep = 4
                }
            })

            Spacer()

            // Lightning icon - consistent with other screens
            Text("⚡")
                .font(.system(size: 64))
                .matchedGeometryEffect(id: "lightning", in: animation) // Shared Element
                .padding(.bottom, 24)

            // Header
            VStack(spacing: 16) {
                Text("What holds you back?")
                    .font(.title.bold())
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Pick what resonates most")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.bottom, 32)
            


            // Struggle Options - VStack for better spacing
            VStack(spacing: 12) {
                StruggleOptionButton(
                    title: "I have negative self-talk",
                    isSelected: viewModel.selectedStruggle == "I have negative self-talk",
                    action: { 
                        viewModel.selectStruggle("I have negative self-talk")
                        advanceWithHaptic(to: 6)
                    }
                )

                StruggleOptionButton(
                    title: "I tend to overreact to everything",
                    isSelected: viewModel.selectedStruggle == "I tend to overreact to everything",
                    action: { 
                        viewModel.selectStruggle("I tend to overreact to everything")
                        advanceWithHaptic(to: 6)
                    }
                )

                StruggleOptionButton(
                    title: "I take everything too seriously",
                    isSelected: viewModel.selectedStruggle == "I take everything too seriously",
                    action: { 
                        viewModel.selectStruggle("I take everything too seriously")
                        advanceWithHaptic(to: 6)
                    }
                )

                StruggleOptionButton(
                    title: "I have low self-esteem",
                    isSelected: viewModel.selectedStruggle == "I have low self-esteem",
                    action: { 
                        viewModel.selectStruggle("I have low self-esteem")
                        advanceWithHaptic(to: 6)
                    }
                )

                StruggleOptionButton(
                    title: "I overthink everything",
                    isSelected: viewModel.selectedStruggle == "I overthink everything",
                    action: { 
                        viewModel.selectStruggle("I overthink everything")
                        advanceWithHaptic(to: 6)
                    }
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
                                    .strokeBorder(viewModel.selectedStruggle == "other" ? Color.appAccent : Color.appTextTertiary, lineWidth: 1.5)
                                    .frame(width: 20, height: 20)

                                if viewModel.selectedStruggle == "other" {
                                    Circle()
                                        .fill(Color.appAccent)
                                        .frame(width: 10, height: 10)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .background(Color.clear)  // Transparent background
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.selectedStruggle == "other" ? AnyShapeStyle(Color.appAccentGradient) : AnyShapeStyle(Color.appTextTertiary), lineWidth: viewModel.selectedStruggle == "other" ? 2 : 1.5)
                        )
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()

            // Continue Button - Fixed at bottom
            Spacer()
                .frame(height: 20)
        }
        .sheet(isPresented: $showCustomStruggleSheet) {
            CustomInputBottomSheet(
                title: "What holds you back?",
                placeholder: "Describe your biggest challenge...",
                text: $viewModel.customStruggleText
            )
        }
        .onChange(of: showCustomStruggleSheet) { isPresented in
            if !isPresented && viewModel.selectedStruggle == "other" && !viewModel.customStruggleText.isEmpty {
                advanceWithHaptic(to: 6)
            }
        }
    }

    // MARK: - Screen 6: Did You Know? Facts

    private var screen_DidYouKnow: some View {
        VStack(spacing: 0) {
            OnboardingBackButton(action: {
                withAnimation {
                    viewModel.currentStep = 5
                }
            })

            Spacer()

            // Header - Centered & Bold
            Text("Did you know?")
                .font(.title.bold())
                .foregroundColor(.appTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
                .scaleEffect(1.1) // Slightly larger presence

            // 3D Floating Cards - Parallax Stack
            VStack(spacing: 16) {
                DidYouKnowCard3D(
                    iconName: "bolt.fill",
                    iconColor: .clear, // Value ignored
                    title: "Small habits beat motivation — daily micro-actions create real change",
                    index: 0,
                    motionManager: motionManager
                )

                DidYouKnowCard3D(
                    iconName: "bubble.fill", // Single bubble
                    iconColor: .clear,
                    title: "Negative self-talk becomes your default setting over time",
                    index: 1,
                    motionManager: motionManager
                )

                DidYouKnowCard3D(
                    iconName: "leaf.fill",
                    iconColor: .clear,
                    title: "You're always reinforcing something — calm, clarity, stress, or doubt",
                    index: 2,
                    motionManager: motionManager
                )

                DidYouKnowCard3D(
                    iconName: "flame.fill",
                    iconColor: .clear,
                    title: "Emotion accelerates transformation — feelings make habits stick faster",
                    index: 3,
                    motionManager: motionManager
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Footer Text
            Text("We're here to help you rewire these patterns")
                .font(.subheadline)
                .foregroundColor(.appTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            Spacer()

            // Continue Button
            Button("Continue") {
                withAnimation {
                    viewModel.currentStep = 7  // Go to generating plan
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            motionManager.start() // ✅ Start gyroscope tracking
            // ✅ OPTIMIZATION: Start generating hack + audio IN BACKGROUND
            // User is reading facts - perfect time to generate!
            // By the time they finish onboarding + paywall, hack will be ready
            Task.detached {
                guard await SupabaseManager.shared.isSignedIn else {
                    print("⚠️ [DidYouKnow] Cannot generate hack - user not signed in")
                    return
                }

                print("🚀 [DidYouKnow] Starting hack generation in background...")
                await MeterDataManager.shared.fetchMeterData(force: true)
                print("✅ [DidYouKnow] Hack generation completed!")

                // ✅ Pre-download audio files while user is still on screens
                if let audioUrls = await MeterDataManager.shared.todaysHack?.audioUrls, !audioUrls.isEmpty {
                    print("🎵 [DidYouKnow] Pre-downloading \(audioUrls.count) audio files...")
                    await AudioCacheManager.shared.preDownloadAudioFiles(audioUrls)
                    print("✅ [DidYouKnow] Audio files cached!")
                }
                
                // ✅ Pre-download today's hero image for dashboard
                print("🖼️ [DidYouKnow] Pre-downloading dashboard hero image...")
                await ImageCacheManager.shared.prefetchImage(from: ImageService.getTodaysImage())
                print("✅ [DidYouKnow] Dashboard image cached!")
            }
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
            },
            onBack: {
                withAnimation {
                    viewModel.currentStep = 6 // Back to DidYouKnow (skipping loading/uh-oh)
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
            },
            onBack: {
                withAnimation {
                    viewModel.currentStep = 10 // Back to UnlockCards
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
            },
            onBack: {
                withAnimation {
                    viewModel.currentStep = 11 // Back to LifeWithoutHacks
                }
            }
        )
    }

    // MARK: - Screen 13: Rating Screen
    
    private var screen_Rating: some View {
        RatingView(
            onContinue: { rating in
                withAnimation {
                    // viewModel.saveRating(rating) 
                    viewModel.currentStep = 14  // Go to notification permission
                }
            },
            onBack: {
                withAnimation {
                    viewModel.currentStep = 12 // Back to LifeWithHacks
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
            },
            onBack: {
                withAnimation {
                    viewModel.currentStep = 13 // Back to Rating
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
            },
            onBack: {
                withAnimation {
                    viewModel.currentStep = 14 // Back to NotificationPermission
                }
            }
        )
    }

    // MARK: - Screen 12: Unlock Solution Cards (Gamified)

    private var screen_UnlockCards: some View {
        UnlockCardsView(
            onNext: {
                withAnimation {
                    viewModel.currentStep = 11  // Go to red graph (life without hacks)
                }
            },
            onBack: {
                withAnimation {
                    viewModel.currentStep = 9 // Back to Feedback Stats
                }
            }
        )
    }

    // MARK: - Screen 13: Time Selection

    private var screen4_TimeSelection: some View {
        VStack(spacing: 0) {
            OnboardingBackButton(action: {
                withAnimation {
                    viewModel.currentStep = 12
                }
            })
            
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
                    .font(.system(.subheadline, design: .default).bold()) // Smaller, bolder text
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.leading) // Ensure text wraps nicely

                Spacer()

                // Radio button style - Compact
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.appAccent : Color.appTextTertiary, lineWidth: 1.5) // 1.5 width, visible border
                        .frame(width: 20, height: 20) // Smaller radio

                    if isSelected {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.vertical, 16) // Increased vertical padding
            .padding(.horizontal, 16)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AnyShapeStyle(Color.appAccentGradient) : AnyShapeStyle(Color.appTextTertiary), lineWidth: isSelected ? 2 : 1.5) // 1.5 width
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
                    .font(.system(.subheadline, design: .default).bold()) // Matched styling
                    .foregroundColor(.appTextPrimary)

                Spacer()

                // Radio button style
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.appAccent : Color.appTextTertiary, lineWidth: 1.5) // 1.5 width
                        .frame(width: 20, height: 20) // Smaller radio

                    if isSelected {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.vertical, 16) // Increased size
            .padding(.horizontal, 16)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AnyShapeStyle(Color.appAccentGradient) : AnyShapeStyle(Color.appTextTertiary), lineWidth: isSelected ? 2 : 1.5) // 1.5 width
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
                    .font(.system(.subheadline, design: .default).bold()) // Matched styling
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Radio button style
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.appAccent : Color.appTextTertiary, lineWidth: 1.5) // 1.5 width
                        .frame(width: 20, height: 20) // Smaller radio

                    if isSelected {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.vertical, 16) // Increased size
            .padding(.horizontal, 16)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AnyShapeStyle(Color.appAccentGradient) : AnyShapeStyle(Color.appTextTertiary), lineWidth: isSelected ? 2 : 1.5) // 1.5 width
            )
        }
    }
}

// MARK: - Celebration View

extension OnboardingView {
    private var celebrationView: some View {
        ZStack {
            // Background - Warm onboarding palette
            Color.appBackground.ignoresSafeArea()
            
            // Subtle warm gradient overlay matching intro screen
            RadialGradient(
                colors: [
                    Color.appAccent.opacity(0.05),
                    Color.clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            // ✨ REALISTIC CONFETTI ANIMATION
            CelebrationConfettiView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Celebration message
                VStack(spacing: 24) {
                    Text("Congrats!")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("You just rewired your future")
                        .font(.title2.bold())
                        .foregroundColor(.appAccent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("Neuroplasticity kicks in with daily micro-actions.\nYou're about to hack your brain's default settings.")
                        .font(.body)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                }

                Spacer()

                // Continue button with gradient
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCelebration = false
                        showNameCollection = true
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.appAccentGradient)
                        .cornerRadius(16)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Celebration haptics
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Celebration Confetti Animation View

enum ConfettiShapeType {
    case rectangle
    case circle
    case ribbon
}

struct CelebrationConfettiView: View {
    @State private var confettiPieces: [CelebrationConfettiPiece] = []
    @State private var animationTimer: Timer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces) { piece in
                    CelebrationConfettiShape(shapeType: piece.shapeType)
                        .fill(piece.color)
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: piece.x, y: piece.y)
                        .opacity(piece.opacity)
                }
            }
            .onAppear {
                startConfetti(in: geometry.size)
            }
            .onDisappear {
                animationTimer?.invalidate()
            }
        }
    }

    private func startConfetti(in size: CGSize) {
        // Warm color palette matching onboarding theme
        let colors: [Color] = [
            Color(red: 1.0, green: 0.84, blue: 0.0),  // Gold
            Color(red: 1.0, green: 0.6, blue: 0.2),   // Warm orange
            Color(red: 1.0, green: 0.8, blue: 0.4),   // Light gold
            Color(red: 1.0, green: 0.5, blue: 0.3),   // Coral
            Color(red: 1.0, green: 0.7, blue: 0.5),   // Peach
            Color(red: 1.0, green: 0.9, blue: 0.6),   // Champagne
        ]
        
        let shapeTypes: [ConfettiShapeType] = [.rectangle, .circle, .ribbon]

        // Generate 100 confetti pieces for a fuller effect, starting from all over the screen
        for i in 0..<100 {
            let shapeType = shapeTypes.randomElement() ?? .rectangle
            let baseSize = CGFloat.random(in: 10...16)
            
            // Ribbons are longer
            let width = shapeType == .ribbon ? baseSize * 0.5 : baseSize
            let height = shapeType == .ribbon ? baseSize * 2.5 : baseSize
            
            let piece = CelebrationConfettiPiece(
                id: UUID(),
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -size.height * 0.3...size.height * 0.3), // Start from top and center of screen
                width: width,
                height: height,
                velocityX: CGFloat.random(in: -15...15), // Slower horizontal movement
                velocityY: CGFloat.random(in: 20...50), // Much slower initial fall speed
                angularVelocity: Double.random(in: -90...90), // Slower rotation
                color: colors.randomElement() ?? .appAccent,
                rotation: Double.random(in: 0...360),
                shapeType: shapeType,
                flutterOffset: CGFloat.random(in: 0...100),
                opacity: 1.0
            )
            confettiPieces.append(piece)
        }
        
        // Start physics simulation
        startPhysicsAnimation(screenSize: size)
    }

    private func startPhysicsAnimation(screenSize: CGSize) {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1/60.0, repeats: true) { _ in
            for i in 0..<confettiPieces.count {
                var piece = confettiPieces[i]
                
                // Physics constants - SLOWED DOWN for visibility
                let gravity: CGFloat = 0.8 // Reduced from 2.0 for slower fall
                let airResistance: CGFloat = 0.995 // Less resistance = more natural movement
                let flutterSpeed: CGFloat = 0.08 // Slower flutter for more graceful sway
                
                // Apply gravity
                piece.velocityY += gravity
                
                // Apply air resistance
                piece.velocityX *= airResistance
                piece.velocityY *= airResistance
                
                // Add horizontal flutter/sway (sine wave motion)
                piece.flutterOffset += flutterSpeed
                let flutter = sin(piece.flutterOffset) * 3.0 // Wider sway
                
                // Update position
                piece.x += piece.velocityX + flutter
                piece.y += piece.velocityY
                
                // Update rotation (tumbling effect)
                piece.rotation += piece.angularVelocity / 60.0
                
                // Only fade out after confetti goes well below the screen
                if piece.y > screenSize.height + 200 {
                    piece.opacity = max(0, piece.opacity - 0.02) // Slower fade
                }
                
                confettiPieces[i] = piece
            }
            
            // Remove fully transparent pieces for performance
            confettiPieces.removeAll { $0.opacity <= 0 }
            
            // Stop timer when all confetti is gone
            if confettiPieces.isEmpty {
                animationTimer?.invalidate()
            }
        }
    }
}

struct CelebrationConfettiPiece: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let width: CGFloat
    let height: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var angularVelocity: Double
    let color: Color
    var rotation: Double
    let shapeType: ConfettiShapeType
    var flutterOffset: CGFloat
    var opacity: Double
}

struct CelebrationConfettiShape: Shape {
    let shapeType: ConfettiShapeType
    
    func path(in rect: CGRect) -> Path {
        switch shapeType {
        case .rectangle:
            return Path { path in
                path.addRect(rect)
            }
        case .circle:
            return Path { path in
                path.addEllipse(in: rect)
            }
        case .ribbon:
            return Path { path in
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.width / 3, height: rect.width / 3))
            }
        }
    }
}

// MARK: - Name Collection View

extension OnboardingView {
    private var nameCollectionView: some View {
        ZStack {
            // Background
            Color.appBackground.ignoresSafeArea()
            
            // Subtle depth gradient (only in dark mode)
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
            
            VStack(spacing: 0) {
                Spacer()
                
                // Lightning bolt with glow effect
                ZStack {
                    // Glow layers
                    Text("⚡")
                        .font(.system(size: 80))
                        .blur(radius: 20)
                        .opacity(0.6)
                    
                    Text("⚡")
                        .font(.system(size: 80))
                        .blur(radius: 10)
                        .opacity(0.4)
                    
                    // Main lightning
                    Text("⚡")
                        .font(.system(size: 80))
                }
                .padding(.bottom, 24)
                
                // Header with gradient text
                VStack(spacing: 16) {
                    Text("You're all set!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("What should we call you?")
                        .font(.title3)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 40)
                
                // Name input field with gradient border
                ZStack {
                    // Gradient border effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.appAccent.opacity(0.3),
                                    Color.orange.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 60)
                        .blur(radius: 8)
                    
                    // Input field
                    TextField("Enter your name", text: $userName)
                        .font(.title3)
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.appCardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Continue button with gradient
                Button {
                    completeNameCollection()
                } label: {
                    HStack(spacing: 12) {
                        Text("Continue")
                            .font(.headline)
                        
                        Image(systemName: "arrow.right")
                            .font(.headline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Group {
                            if userName.trimmingCharacters(in: .whitespaces).isEmpty {
                                Color.gray.opacity(0.3)
                            } else {
                                Color.appAccentGradient
                            }
                        }
                    )
                    .cornerRadius(16)
                    .shadow(
                        color: userName.trimmingCharacters(in: .whitespaces).isEmpty ? 
                            .clear : 
                            Color.appAccent.opacity(0.3),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                }
                .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 40)
                .padding(.bottom, 16)
                
                // Skip button
                Button {
                    userName = ""
                    completeNameCollection()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func completeNameCollection() {
        // Save name to UserDefaults (for offline cache)
        let trimmedName = userName.trimmingCharacters(in: .whitespaces)
        storedUserName = trimmedName.isEmpty ? "" : trimmedName
        
        // Save name to Supabase backend (for persistence across reinstalls)
        if !trimmedName.isEmpty {
            Task {
                do {
                    try await SupabaseManager.shared.updateUserName(name: trimmedName)
                    print("✅ [Onboarding] Name saved to backend: '\(trimmedName)'")
                } catch {
                    print("❌ [Onboarding] Failed to save name to backend: \(error)")
                    // Still proceed with onboarding even if backend save fails
                }
            }
        }
        
        // Complete onboarding
        withAnimation(.easeInOut(duration: 0.3)) {
            showNameCollection = false
            isOnboardingComplete = true
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
                
                // Milestone haptics - every 20%
                if Int(progress) % 20 == 0 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else if progress < 34 {
                // Switch to message 2 - special haptic combo
                currentMessage = messages[1]
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                progress += 1
            } else if progress < 66 {
                progress += 1
                
                // Milestone haptics - every 20%
                if Int(progress) % 20 == 0 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else if progress < 67 {
                // Switch to message 3 - special haptic combo
                currentMessage = messages[2]
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                progress += 1
            } else if progress < 100 {
                progress += 1
                
                // Milestone haptics - every 20%
                if Int(progress) % 20 == 0 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } else {
                timer.invalidate()
                
                // 100% completion - TRIPLE CELEBRATION!
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                
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
    case "I overthink everything":
        return StruggleMetrics(
            metric1: "Decision confidence",
            metric2: "Mental stillness",
            metric3: "Present awareness"
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
    case "I overthink everything":
        return StruggleStatistic(percentage: 76, struggleText: "struggle with overthinking")
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

// MARK: - Standardized Back Button
struct OnboardingBackButton: View {
    let action: () -> Void
    var color: Color = .appTextPrimary

    var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                    .padding(8) // Touch target
                    .contentShape(Rectangle())
            }
            Spacer()
        }
        .padding(.horizontal, 16) // Exact same horizontal alignment
        .padding(.top, 8)        // Exact same top spacing
        .padding(.bottom, 0)     // Remove bottom padding to avoid pushing content too far; screens can add spacer if needed
    }
}

// MARK: - Feedback Stats View

struct FeedbackStatsView: View {
    let mood: String
    let struggle: String
    let customStruggle: String
    let onContinue: () -> Void
    let onBack: () -> Void

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
                OnboardingBackButton(action: onBack)

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
    let onBack: () -> Void // ✅ Added onBack parameter

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
                OnboardingBackButton(action: onBack)

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
    let onBack: () -> Void // ✅ Added onBack param

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
                OnboardingBackButton(action: onBack)
                
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

// MARK: - Rating View

// (Deleted legacy zombie code)



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
    let onBack: () -> Void // ✅ Added onBack parameter
    
    @State private var showingSystemPrompt = false

    @State private var selectedTime: Date = {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 5
        components.minute = 30
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Adaptive background
            backgroundColor
                .ignoresSafeArea(.all)
                .animation(.easeInOut(duration: 0.5), value: isNightMode) // Smooth transition
            
            // Star Field (Night Mode)
            StarFieldView(opacity: isNightMode ? 1.0 : 0.0)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Back Button (Top Left)
                OnboardingBackButton(action: onBack, color: isNightMode ? .white : .appTextPrimary)

                // Padding for top spacing
                Spacer().frame(height: 10)
                
                Spacer()

                // Main Content
                VStack(spacing: 32) {
                    // Title
                    Text("When do you want to evolve?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(isNightMode ? .white : .appTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    // Subtitle
                    Text("We'll send your daily brain hack at this time to help rewire your habits.")
                        .font(.system(size: 17))
                        .foregroundColor(isNightMode ? .white.opacity(0.8) : .appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .lineSpacing(4)
                    
                    // Golden Time Ring
                    TimeDialView(selectedTime: $selectedTime)
                        .scaleEffect(isAnimating ? 1.0 : 0.95)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        
                }
                
                Spacer()

                // Dynamic Action Button
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await requestNotificationPermission()
                            onContinue()
                        }
                    } label: {
                        Text("Schedule for \(formattedTime(selectedTime))")
                    }
                    .buttonStyle(OnboardingButtonStyle())
                    .padding(.horizontal, 24)
                    
                    // Skip button
                    Button {
                        onContinue()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundColor(isNightMode ? .white.opacity(0.7) : .appTextSecondary)
                            .opacity(isNightMode ? 0.7 : 1.0)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                isAnimating = true
            }
        }
    }
    
    // Theme Helpers
    
    private var isNightMode: Bool {
        let hour = Calendar.current.component(.hour, from: selectedTime)
        // Night is 8 PM (20) to 4 AM (4)
        return hour >= 20 || hour < 4
    }
    
    private var backgroundColor: Color {
        isNightMode ? Color(hex: "0B0F19") : Color.appBackground // Deep Midnight vs Cream
    }
    
    // ... rest of class functions ...
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
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

// MARK: - Star Field View (Night Mode)

struct StarFieldView: View {
    let opacity: Double
    
    var body: some View {
        Canvas { context, size in
            // Draw random stars
            for _ in 0..<50 {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                let radius = Double.random(in: 1...2.5)
                let opacity = Double.random(in: 0.3...1.0)
                
                let rect = CGRect(x: x, y: y, width: radius, height: radius)
                context.opacity = opacity
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
        .opacity(opacity)
        .animation(.easeInOut(duration: 1.0), value: opacity)
    }
}

// MARK: - Commitment View (Before Paywall)

struct CommitmentView: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var isCommitted = false

    var body: some View {
        ZStack {
            // Adaptive background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Back Button (Top Left)
                OnboardingBackButton(action: onBack)

                // Main Content
                VStack(spacing: 24) {
                    Spacer().frame(height: 10)

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
                }
                .padding(.horizontal, 24)

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
                .padding(.horizontal, 24)
            }
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

// MARK: - Unlockable Card (Hyper-Spring Pop Animation) 🍬 💥
struct UnlockableCard: View {
    let emoji: String
    let text: String
    let isUnlocked: Bool
    let isReady: Bool
    let onTap: () -> Void

    // Animation State
    @State private var isPressed: Bool = false
    
    // Constant Dimensions
    private let cardWidth: CGFloat = 320
    private let cardHeight: CGFloat = 200
    private let cardCornerRadius: CGFloat = 36

    var body: some View {
        ZStack {
            // 1. CARD BACKGROUND (Always clean white base)
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color.white)
                .shadow(
                    color: Color(hex: "3E3322").opacity(isUnlocked ? 0.12 : 0.05),
                    radius: isUnlocked ? 20 : 10,
                    x: 0,
                    y: isUnlocked ? 8 : 4
                )
            
            // 2. CONTENT LAYER (Emoji + Text)
            VStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: isUnlocked ? 48 : 52)) // Scale down slightly on unlock
                
                if isUnlocked {
                    Text(text)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "2D2418"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .lineSpacing(2)
                        .transition(.scale(scale: 0.9).combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.7)))
                } else {
                     // Locked state text placeholder
                    Text(text)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "2D2418").opacity(0.3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .redacted(reason: .placeholder)
                }
            }
            // BLUR SHATTER: 12px blur -> 0px instantly on unlock
            .blur(radius: isUnlocked ? 0 : 12)
            .opacity(isUnlocked ? 1.0 : 0.7)
            
            // 3. FROSTED GUMMY OVERLAY (Locked State)
            if !isUnlocked {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(Color(hex: "FDFBF7").opacity(0.4))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                    .overlay(
                        VStack(spacing: 8) {
                            if !isReady {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "B0ADA5"))
                            } else {
                                Text("Tap to reveal")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "B0ADA5"))
                                    .tracking(0.5)
                            }
                        }
                    )
                    // Immediate removal on unlock for "Shatter" effect
                    .transition(.identity) 
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(isUnlocked ? Color.appAccent.opacity(0.3) : Color.white.opacity(0.5), lineWidth: 1)
        )
        // HYPER-SPRING PHYSICS 🍬
        // 1. Locked: Default scale 0.95 (Recessed)
        // 2. Press: Scale 0.90 (Compression)
        // 3. Unlocked: Scale 1.0 (Expansion)
        .scaleEffect(
            isUnlocked ? 1.0 : (isPressed ? 0.90 : 0.95)
        )
        .animation(
            isPressed 
                ? .interactiveSpring(response: 0.3, dampingFraction: 0.6) // Squishy Press
                : .spring(response: 0.4, dampingFraction: 0.5),          // Bouncy Release
            value: isPressed
        )
        .animation(
            .spring(response: 0.4, dampingFraction: 0.5), // Bouncy Unlock
            value: isUnlocked
        )
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            if isReady && !isUnlocked {
                isPressed = pressing
            }
        }, perform: {
            // Action handled in onTapGesture for better reliability or here?
            // Using logic: Pressing handled visual state. Tap triggers unlock.
        })
        .simultaneousGesture(
            TapGesture().onEnded {
                if isReady && !isUnlocked {
                    triggerPopUnlock()
                }
            }
        )
    }
    
    private func triggerPopUnlock() {
        // Haptic Explosion
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        
        // Trigger State Change (this will cause the "Release" animation)
        onTap()
    }
}

// ============================================
// UnlockCardsView - Simplified parent
// ============================================

struct UnlockCardsView: View {
    let onNext: () -> Void
    let onBack: () -> Void // ✅ Added onBack parameter

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
                OnboardingBackButton(action: onBack)

                Spacer()
                
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
                
                Spacer()

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

                // Navigation Buton
                // Action Buttons
                VStack(spacing: 16) {
                    // Skip Button only (Cards auto-advance)
                    Button {
                        onNext()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
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
        
        // Auto-advance after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onNext()
        }
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

struct RatingView: View {
    let onContinue: (Int) -> Void
    let onBack: () -> Void

    @State private var selectedRating = 0
    @State private var hasInteracted = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingBackButton(action: onBack)
                
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Text("First impressions?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("How are you liking the experience?")
                        .font(.system(size: 17)) // Subheadline size
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                
                // Rating Card
                VStack(spacing: 24) {
                    // Stars
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    selectedRating = star
                                    hasInteracted = true
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                
                                // Auto-advance after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    onContinue(star)
                                }
                            } label: {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(star <= selectedRating ? .appAccent : Color.gray.opacity(0.3))
                                    .scaleEffect(selectedRating == star ? 1.2 : 1.0)
                            }
                        }
                    }
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Continue Button
                // Action Buttons
                VStack(spacing: 16) {
                    // Skip button only (Star tap advances)
                    Button {
                        onContinue(0)
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
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
            
            // BOOM - Dramatic thunder haptic when "Uh oh" appears
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            
            // Echo/aftershock
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            // Delay subtitle appearance + haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSubtitle = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            // Auto-advance to next screen after animations complete + success haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSkip()
            }
        }
    }
}

// MARK: - Did You Know Fact View with Animation

struct DidYouKnowCard3D: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let index: Int
    @ObservedObject var motionManager: MotionManager
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "FFF9E5")) // Soft yellow/cream background
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .bold)) // Bolder icon
                    .foregroundColor(Color(hex: "FFD60A")) // Gold/Yellow icon color
            }
            .padding(.leading, 4) // Slight inset
            
            // Text
            Text(title)
                .font(.system(size: 16, weight: .medium)) // Slightly smaller, crisper font
                .foregroundColor(.appTextPrimary) // Dark text
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                .lineSpacing(4) // Increased line spacing for readability
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 100) // Fixed height for uniform size
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "FDFBF7")) // ✅ Solid warm off-white background
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.appTextTertiary, lineWidth: 1.5) // Subtle border
        )
        // 3D PARALLAX EFFECT (Kept but subtle)
        .rotation3DEffect(
            .degrees(motionManager.pitch * 3), // Reduced intensity
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(motionManager.roll * 3), // Reduced intensity
            axis: (x: 0, y: 1, z: 0)
        )
        // ANIMATION - DOMINO CASCADE
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1.0 : 0.93) // Subtle expansion
        .offset(y: isVisible ? 0 : 30)       // Increased slide distance
        .onAppear {
            // Slower, liquid stagger for "chain reaction" feel
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + (Double(index) * 0.7)) { // Even slower premium stagger
                withAnimation(.spring(response: 1.0, dampingFraction: 0.85)) { // Heavy, luxurious motion
                    isVisible = true
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
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
                
                // Radio button style
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.appAccent : Color.appCardBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding()
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AnyShapeStyle(Color.appAccentGradient) : AnyShapeStyle(Color.appCardBorder), lineWidth: isSelected ? 2 : 1)
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

// MARK: - Premium Design Components

struct LightningPatternView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<15) { index in
                    Text("⚡️")
                        .font(.system(size: CGFloat.random(in: 10...20)))
                        .opacity(Double.random(in: 0.1...0.3))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .rotationEffect(.degrees(Double.random(in: -30...30)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct LaurelWreathView: View {
    var body: some View {
        HStack(spacing: 240) { // Spacing defines width of wreath
            // Left Branch
            Image(systemName: "laurel.leading")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.appAccent.opacity(0.6))
            
            // Right Branch
            Image(systemName: "laurel.trailing")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.appAccent.opacity(0.6))
        }
    }
}


// MARK: - Time Dial View (Golden Ring - Solar Winder)

struct TimeDialView: View {
    @Binding var selectedTime: Date
    
    // Config
    private let calendar = Calendar.current
    private let dialRadius: CGFloat = 120
    private let knobRadius: CGFloat = 16
    
    // Haptics
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium) // Stronger click
    private let selectionGenerator = UIImpactFeedbackGenerator(style: .light)
    
    // State for drag logic
    @State private var previousAngle: Double = 0.0
    
    // Theme Colors
    private var isNightMode: Bool {
        let hour = calendar.component(.hour, from: selectedTime)
        return hour >= 20 || hour < 4
    }
    
    private var accentColor: Color {
        isNightMode ? Color.white : Color.appAccent
    }
    
    private var knobColor: Color {
        isNightMode ? Color(hex: "FDB813") : Color.appAccent
    }
    
    var body: some View {
        ZStack {
            // 0. Inner Background Circle (Theme Based)
            Circle()
                .fill(isNightMode ? Color.blue.opacity(0.1) : Color.appAccent.opacity(0.1))
                .frame(width: dialRadius * 2, height: dialRadius * 2)

            // 1. Ticks
            ForEach(0..<48) { index in
                let isMajor = index % 12 == 0
                let isHour = index % 4 == 0
                
                Rectangle()
                    .fill(isMajor ? (isNightMode ? Color.white.opacity(0.8) : Color.black.opacity(0.6)) 
                          : (isNightMode ? Color.white.opacity(0.3) : Color.gray.opacity(0.5)))
                    .frame(width: isMajor ? 3 : (isHour ? 2 : 1), 
                           height: isMajor ? 10 : (isHour ? 8 : 4))
                    .offset(y: -(dialRadius - 8))
                    .rotationEffect(.degrees(Double(index) * 7.5))
            }
            
            // 2. Main Ring Path
            Circle()
                .trim(from: 0.0, to: angleToProgress())
                .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: dialRadius * 2, height: dialRadius * 2)
                .rotationEffect(.degrees(-90))
            
            // 3. Numbers
            ForEach(1...12, id: \.self) { hour in
                Text("\(hour)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isNightMode ? Color.white.opacity(0.8) : Color.gray)
                    .position(
                        x: dialRadius + 20,
                        y: dialRadius + 20
                    )
                    .offset(
                        x: (dialRadius - 32) * sin(Double(hour) * .pi / 6),
                        y: -(dialRadius - 32) * cos(Double(hour) * .pi / 6)
                    )
            }
            .frame(width: dialRadius * 2 + 40, height: dialRadius * 2 + 40)
            
            // 4. Draggable Knob
            Circle()
                .fill(accentColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(color: accentColor.opacity(0.8), radius: isNightMode ? 12 : 8, x: 0, y: 0) // Glow stronger at night
                .offset(y: -dialRadius)
                .rotationEffect(timeToAngle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateTime(from: value.location)
                        }
                )
            
            // 5. Central Display
            VStack(spacing: 2) {
                Text(timeString(from: selectedTime))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(isNightMode ? .white : .appTextPrimary)
                    .monospacedDigit()
                
                Text(amPmString(from: selectedTime))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accentColor)
                
                Text("DAILY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(accentColor.opacity(0.8))
                    .padding(.top, 4)
            }
        }
        .frame(width: dialRadius * 2 + 40, height: dialRadius * 2 + 40)
        .padding()
    }
    
    // MARK: - Helpers
    
    private func angleToProgress() -> CGFloat {
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        let hour12 = hour % 12
        let minuteFraction = Double(minute) / 60.0
        let totalFraction = (Double(hour12) + minuteFraction) / 12.0
        return totalFraction == 0 ? 1.0 : totalFraction
    }
    
    private func updateTime(from location: CGPoint) {
        let center = CGPoint(x: dialRadius + 20, y: dialRadius + 20)
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        var angle = atan2(vector.dy, vector.dx) + .pi / 2
        
        if angle < 0 { angle += 2 * .pi }
        
        // Solar Winder Logic: Detect Wrap
        // If angle jumps from near 2pi (11:59) to near 0 (12:01), or vice versa
        let threshold: Double = 5.0 // ~280 degrees gap to ignore glitches
        
        if abs(angle - previousAngle) > threshold {
            // A wrap occurred!
            toggleAmPm()
            impactGenerator.impactOccurred()
        }
        previousAngle = angle
        
        // Time Calculation
        let totalMinutes = (angle / (2 * .pi)) * 12 * 60
        let snappedMinutes = round(totalMinutes / 15) * 15
        
        let hour = Int(snappedMinutes / 60)
        let minute = Int(snappedMinutes.truncatingRemainder(dividingBy: 60))
        
        var newComponents = calendar.dateComponents([.year, .month, .day], from: selectedTime)
        
        // Preserve current AM/PM state (logic handled by toggleAmPm separately)
        let currentHour = calendar.component(.hour, from: selectedTime)
        let isCurrentPM = currentHour >= 12
        var newHour24 = hour
        
        if isCurrentPM {
            if hour < 12 { newHour24 += 12 }
            if hour == 12 { newHour24 = 12 }
        } else {
             if hour == 12 { newHour24 = 0 }
        }
        
        if newHour24 == 24 { newHour24 = 0 }
        
        newComponents.hour = newHour24
        newComponents.minute = minute
        
        if let newDate = calendar.date(from: newComponents) {
            if abs(newDate.timeIntervalSince(selectedTime)) > 0 {
                selectedTime = newDate
                if Int(snappedMinutes) % 60 == 0 { // Click on hour
                     selectionGenerator.impactOccurred()
                }
            }
        }
    }
    
    private func timeToAngle() -> Angle {
        let hour = calendar.component(.hour, from: selectedTime)
        let minute = calendar.component(.minute, from: selectedTime)
        let hour12 = hour % 12
        let minuteFraction = Double(minute) / 60.0
        let angleDegrees = (Double(hour12) + minuteFraction) * 30.0
        return .degrees(angleDegrees)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
    
    private func amPmString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: date)
    }
    
    private func toggleAmPm() {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
        if let currentHour = components.hour {
             components.hour = (currentHour + 12) % 24
             if let newDate = calendar.date(from: components) {
                 selectedTime = newDate
             }
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}

// MARK: - Motion Manager (Internal) -> REMOVED (Using PrismMotionManager from PrismComponents.swift)


// MARK: - Sparkle Effect
struct SparkleView: View {
    @State private var particles: [SparkleParticle] = []
    
    struct SparkleParticle: Hashable, Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var speedX: CGFloat
        var speedY: CGFloat
    }
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .offset(x: particle.x, y: particle.y)
            }
        }
        .onAppear {
            createParticles()
        }
    }
    
    private func createParticles() {
        for _ in 0..<15 {
            let angle = Double.random(in: 0...2 * .pi)
            let distance = Double.random(in: 40...100) // Spread out
            let speed = Double.random(in: 0.5...1.0)
            
            particles.append(
                SparkleParticle(
                    x: 0,
                    y: 0,
                    scale: Double.random(in: 0.5...1.0),
                    opacity: 1.0,
                    speedX: cos(angle) * distance * speed,
                    speedY: sin(angle) * distance * speed
                )
            )
        }
        
        withAnimation(.easeOut(duration: 1.2)) {
            for i in 0..<particles.count {
                particles[i].x = particles[i].speedX
                particles[i].y = particles[i].speedY
                particles[i].opacity = 0
                particles[i].scale = 0
            }
        }
    }
}

// MARK: - Motion Manager
class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    
    init() {
        self.motionManager.deviceMotionUpdateInterval = 1/60
        self.start()
    }
    
    func start() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self = self, let motion = motion else { return }
                
                withAnimation(.linear(duration: 0.1)) {
                    self.pitch = motion.attitude.pitch
                    self.roll = motion.attitude.roll
                }
            }
        }
    }
    
    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
