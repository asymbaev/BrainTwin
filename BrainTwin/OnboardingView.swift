import SwiftUI
import SuperwallKit
import UIKit

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Binding var isOnboardingComplete: Bool
    @State private var showProfileSetup = false
    @State private var setupComplete = false
    
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
//    @AppStorage("welcomeTypewriterCompleted") private var welcomeTypewriterCompleted = false
    
    @State private var welcomeTypewriterCompleted = false
    
    // MARK: - Typewriter config
    private let typewriterCharacterDelay: TimeInterval = 0.065   // slightly slower



    
    @Environment(\.colorScheme) var colorScheme
    
    @FocusState private var isAgeFieldFocused: Bool
    
    // MARK: - Typewriter state 👇
    @State private var animatedWelcomeText = ""
    @State private var animatedQuoteText = ""
    @State private var isAnimatingWelcome = false
    @State private var isAnimatingQuote = false
    
    @State private var hasAnimatedStep0 = false
    
    // MARK: - Typewriter config
    private let welcomeTypingDelay: TimeInterval = 0.10   // slower, premium
    private let quoteTypingDelay: TimeInterval = 0.065    // slightly faster


    
    private let fullWelcomeText = "Welcome"
    private let fullQuoteText = "“If you don't program your mind, someone else will.”"
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
                // Progress indicator - NOW 5 STEPS
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        Capsule()
                            .fill(index <= viewModel.currentStep ? Color.appAccent : Color.appTextTertiary)
                            .frame(height: 4)
                    }
                }
                .padding()
                
                // Content
                TabView(selection: $viewModel.currentStep) {
                    screen0_WelcomeIntro.tag(0)
                    screen1_NameCollection.tag(1)      // NEW
                    screen1_AgeCollection.tag(2)       // NEW
                    screen2_GoalSelection.tag(3)       // Was 0
                    screen3_StruggleSelection.tag(4)   // Was 1
                    screen4_TimeSelection.tag(5)       // Was 2
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
        .onReceive(NotificationCenter.default.publisher(for: .purchaseCompleted)) { _ in
            // Purchase completed! Check subscription and complete onboarding
            print("🎉 Purchase notification received!")
            Task {
                await checkIfUserSubscribed()
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

        // Haptic every 2 characters so it feels smoother, not “machine gun”
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


    
    // MARK: - Paywall (Age-based routing)
    @State private var paywallAttempts = 0
    
    private func showPaywall() {
        paywallAttempts += 1
        
        // Prevent infinite loop - max 3 attempts
        if paywallAttempts > 3 {
            print("⚠️ Paywall failed to show after 3 attempts")
            print("⚠️ Check Superwall dashboard - placements may not have rules configured")
            
            // Show alert to user
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Paywall Configuration Issue",
                    message: "The paywall is not configured properly in Superwall. Please check your Superwall dashboard and ensure your age-based placements (18-22, 23-28, etc.) have rules configured.\n\nFor testing: Status is ACTIVE=\(Superwall.shared.subscriptionStatus), but no userId found.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(alert, animated: true)
                }
            }
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
            Text("NEUROWIRE")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.appTextPrimary)
                .padding(.top, 24)

            Spacer()

            VStack(spacing: 16) {
                // --- WELCOME TEXT ---
                Text(fullWelcomeText)
                    .font(.system(size: 36, weight: .bold))   // placeholder space
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.clear)
                    .overlay(
                        Text(animatedWelcomeText)
                            .font(.system(size: 36, weight: .bold))   // animated hero text
                            .multilineTextAlignment(.center)
                            .foregroundColor(.appTextPrimary)
                            .animation(nil, value: animatedWelcomeText)
                    )

                // --- QUOTE TEXT ---
                Text(fullQuoteText)
                    .font(.system(size: 20, weight: .medium))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.clear)
                    .overlay(
                        Text(animatedQuoteText)
                            .font(.system(size: 20, weight: .medium))
                            .italic()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, 32)
                            .animation(nil, value: animatedQuoteText)
                    )


                // --- STARS ---
                HStack(spacing: 4) {
                    Image(systemName: "laurel.leading")
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                    }
                    Image(systemName: "laurel.trailing")
                }
                .foregroundColor(.appAccent)
                .padding(.top, 12)
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
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding(.horizontal)
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
    
    // MARK: - Screen 0: Name Collection (NEW)
    
    private var screen1_NameCollection: some View {
        VStack(spacing: 24) {
            // 🔙 Back button
                HStack {
                    Button {
                        withAnimation {
                            viewModel.currentStep = 0
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
                    viewModel.currentStep = 2
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isNameValid)
            .opacity(viewModel.isNameValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 1: Age Collection (NEW)
    
    private var screen1_AgeCollection: some View {
        VStack(spacing: 24) {
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
                    viewModel.currentStep = 3
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isAgeValid)
            .opacity(viewModel.isAgeValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 2: Goal Selection (Was Screen 0)
    
    private var screen2_GoalSelection: some View {
        VStack(spacing: 24) {
            // Back button
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
                    viewModel.currentStep = 4
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isGoalValid)
            .opacity(viewModel.isGoalValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 3: Struggle Selection (Was Screen 1)
    
    private var screen3_StruggleSelection: some View {
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
                    viewModel.currentStep = 5
                }
            }
            .buttonStyle(OnboardingButtonStyle())
            .disabled(!viewModel.isStruggleValid)
            .opacity(viewModel.isStruggleValid ? 1 : 0.5)
            .padding()
        }
    }
    
    // MARK: - Screen 4: Time Selection (Was Screen 2)
    
    private var screen4_TimeSelection: some View {
        VStack(spacing: 0) {
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
